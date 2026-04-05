import os
import re
import json
import httpx
import yaml

OLLAMA_HOST = os.environ.get("OLLAMA_HOST", "http://ollama:11434")
MODEL_NAME = os.environ.get("MODEL_NAME", "llama3.1:8b")

RULES_PATH = os.path.join(os.path.dirname(__file__), "..", "config", "onboarding_rules.yml")

with open(RULES_PATH, "r") as f:
    _rules = yaml.safe_load(f)

EMAIL_PATTERNS = _rules.get("email_patterns", [])

SYSTEM_PROMPT = """You are an IT onboarding assistant. Extract structured employee data from the pasted HR email or Spiceworks ticket.

Return ONLY a valid JSON object with these fields (use null for missing values):
{
  "employee_name": "<full name>",
  "preferred_name": "<preferred name or null>",
  "start_date": "<date string or null>",
  "position": "<job title or null>",
  "manager": "<manager name or null>",
  "company_raw": "<company name as written in the text or null>",
  "location": "<location or null>",
  "hire_type": "<RNH or CNH or null>",
  "scope": "<domestic or international or null>",
  "role": "<GM, AGM, Key Holder, Sales Associate, or null — for RNH only>",
  "form_fields": {
    "Computer Requirements": "<value or null>",
    "FileCloud (Shared Drive) Access": "<yes/no or null>",
    "For FileCloud (Shared Drive) access, enter current or former user to mirror access": "<value or null>",
    "Zoom Phone Extension": "<yes/no or null>",
    "If yes for Zoom Phone Extension, direct number needed?": "<yes/no or null>",
    "NewStore System Access?": "<yes/no or null>",
    "If yes, please select New Store access level": "<value or null>",
    "Full Circle Account": "<yes/no or null>",
    "For Full Circle access, enter current or former user to mirror access": "<value or null>",
    "BlueCherry ERP": "<yes/no or null>",
    "For BlueCherry (ERP) access, enter current or former user to mirror access": "<value or null>",
    "BlueCherry PLM": "<yes/no or null>",
    "For BlueCherry (PLM) access, enter current or former user to mirror access": "<value or null>",
    "Additional Equipment for Office/WFH": "<value or null>",
    "Other system access not listed needed": "<value or null>",
    "Distro Lists other than office/retail location": "<value or null>",
    "For any other IT Onboarding requests or requirements not listed": "<value or null>"
  }
}

Rules:
- hire_type: RNH = Retail New Hire (usually from HR email), CNH = Corporate New Hire (usually from Spiceworks form)
- scope: if location mentions Paris, London, Tokyo, or any non-US/non-domestic location, set "international"; otherwise "domestic"
- company_raw: copy exactly what the text says (e.g. "Acme Retail", "Acme Corp", "I-ACM", "D-ACM")
- role: only for RNH — map position to GM, AGM, Key Holder, or Sales Associate
- form_fields: only for CNH — extract all field values from the Spiceworks ticket
- For yes/no fields, normalize to lowercase "yes" or "no"
- Do not include any explanation, markdown, or extra text — ONLY the JSON object."""


def _regex_fallback(text: str) -> dict:
    result = {
        "employee_name": None,
        "preferred_name": None,
        "start_date": None,
        "position": None,
        "manager": None,
        "company_raw": None,
        "location": None,
        "hire_type": None,
        "scope": None,
        "role": None,
        "form_fields": {},
    }

    for pat in EMAIL_PATTERNS:
        if re.search(pat["pattern"], text, re.IGNORECASE):
            result["hire_type"] = pat["hire_type"]
            result["company_raw"] = pat["company"]
            break

    name_match = re.search(r"Employee[:\s]+([A-Z][a-z]+(?: [A-Z][a-z]+)+)", text)
    if name_match:
        result["employee_name"] = name_match.group(1).strip()

    date_match = re.search(
        r"Start\s*Date[:\s]+([A-Za-z]+,?\s+[A-Za-z]+\s+\d{1,2},?\s+\d{4}|\d{4}-\d{2}-\d{2})",
        text,
        re.IGNORECASE,
    )
    if date_match:
        result["start_date"] = date_match.group(1).strip()

    pos_match = re.search(r"Position[:\s]+(.+)", text, re.IGNORECASE)
    if pos_match:
        result["position"] = pos_match.group(1).strip()

    mgr_match = re.search(r"Manager[:\s]+(.+)", text, re.IGNORECASE)
    if mgr_match:
        result["manager"] = mgr_match.group(1).strip()

    loc_match = re.search(r"Location[:\s]+(.+)", text, re.IGNORECASE)
    if loc_match:
        result["location"] = loc_match.group(1).strip()

    if result["hire_type"] == "RNH" and result["position"]:
        pos_lower = result["position"].lower()
        if "general manager" in pos_lower or pos_lower.startswith("gm"):
            result["role"] = "GM"
        elif "agm" in pos_lower or "assistant general manager" in pos_lower:
            result["role"] = "AGM"
        elif "key holder" in pos_lower:
            result["role"] = "Key Holder"
        else:
            result["role"] = "Sales Associate"

    intl_keywords = ["paris", "london", "tokyo", "milan", "hong kong", "international"]
    loc_text = (result["location"] or "").lower() + text.lower()
    if any(kw in loc_text for kw in intl_keywords):
        result["scope"] = "international"
    else:
        result["scope"] = "domestic"

    return result


async def parse_text(text: str) -> dict:
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                f"{OLLAMA_HOST}/api/chat",
                json={
                    "model": MODEL_NAME,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": text},
                    ],
                    "stream": False,
                    "format": "json",
                },
            )
            response.raise_for_status()
            data = response.json()
            content = data["message"]["content"]
            parsed = json.loads(content)
            return parsed
    except Exception:
        return _regex_fallback(text)


async def check_ollama_health() -> bool:
    try:
        async with httpx.AsyncClient(timeout=5.0) as client:
            resp = await client.get(f"{OLLAMA_HOST}/api/tags")
            return resp.status_code == 200
    except Exception:
        return False
