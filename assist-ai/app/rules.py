import os
import re
import yaml

RULES_PATH = os.path.join(os.path.dirname(__file__), "..", "config", "onboarding_rules.yml")

with open(RULES_PATH, "r") as f:
    _rules = yaml.safe_load(f)

COMPANIES = _rules.get("companies", {})
HIRE_TYPES = _rules.get("hire_types", {})
SCOPE_MODIFIERS = _rules.get("scope_modifiers", {})


def _resolve_company(company_raw: str | None, scope: str = "domestic") -> str | None:
    if not company_raw:
        return None
    normalized = (company_raw or "").strip()
    if normalized in COMPANIES:
        return normalized
    # When multiple company codes share the same name (e.g. D-AURA / I-AURA),
    # prefer the one whose scope matches the parsed scope.
    matches = []
    for code, info in COMPANIES.items():
        if info["name"].lower() == normalized.lower() or code.lower() == normalized.lower():
            matches.append(code)
    if len(matches) == 1:
        return matches[0]
    if matches:
        for code in matches:
            if COMPANIES[code].get("scope", "domestic") == scope:
                return code
        return matches[0]
    return None


def _make_task(name: str, priority: int, category: str, subtasks: list | None = None, details: str | None = None) -> dict:
    task = {
        "name": name,
        "priority": priority,
        "category": category,
        "subtasks": subtasks or [],
        "details": details,
        "checked": False,
    }
    return task


def _is_yes(value: str | None) -> bool:
    if not value:
        return False
    return str(value).strip().lower() in ("yes", "y", "true", "1")


def _is_skippable(value: str | None, skip_values: list) -> bool:
    if value is None:
        return True
    normalized = str(value).strip().lower()
    return normalized in [s.lower() for s in skip_values]


def generate_checklist(parsed: dict) -> dict:
    hire_type = (parsed.get("hire_type") or "").upper()
    company_raw = parsed.get("company_raw")
    scope = (parsed.get("scope") or "domestic").lower()
    role_name = parsed.get("role")
    form_fields = parsed.get("form_fields") or {}

    company_code = _resolve_company(company_raw, scope)

    if not company_code and company_raw:
        company_code = company_raw

    if company_code in COMPANIES:
        company_scope = COMPANIES[company_code].get("scope", "domestic")
        if scope == "domestic" and company_scope == "international":
            scope = "international"

    tasks = []
    skipped = []

    if hire_type == "RNH":
        rnh_config = HIRE_TYPES.get("RNH", {})
        for t in rnh_config.get("base_tasks", []):
            tasks.append(_make_task(t["name"], t["priority"], t["category"]))

        roles_config = rnh_config.get("roles", {})
        role_config = None
        matched_role = None

        if role_name and role_name in roles_config:
            role_config = roles_config[role_name]
            matched_role = role_name

        if role_config:
            inherits = role_config.get("inherits")
            if inherits and inherits in roles_config:
                for t in roles_config[inherits].get("additional_tasks", []):
                    tasks.append(_make_task(t["name"], t["priority"], t["category"]))

            for t in role_config.get("additional_tasks", []):
                tasks.append(_make_task(t["name"], t["priority"], t["category"]))

    elif hire_type == "CNH":
        cnh_config = HIRE_TYPES.get("CNH", {})
        for t in cnh_config.get("base_tasks", []):
            tasks.append(_make_task(t["name"], t["priority"], t["category"]))

        mappings = cnh_config.get("form_field_mappings", {})
        for key, mapping in mappings.items():
            field_name = mapping["field_name"]
            field_type = mapping["type"]
            field_value = form_fields.get(field_name)

            if field_type == "select":
                skip_values = mapping.get("skip_values", ["", "n/a"])
                if _is_skippable(field_value, skip_values):
                    skipped.append({"field": field_name, "value": field_value})
                    continue
                tmpl = mapping["task_template"]
                name = tmpl["name"].replace("{value}", str(field_value))
                tasks.append(_make_task(name, tmpl["priority"], tmpl["category"]))

            elif field_type == "yes_no":
                if _is_yes(field_value):
                    task_def = mapping["task_on_yes"]
                    subtasks = []
                    details = None

                    if "mirror_field" in mapping:
                        mirror_val = form_fields.get(mapping["mirror_field"])
                        if mirror_val:
                            subtask_tmpl = task_def.get("subtask", "")
                            if subtask_tmpl:
                                subtasks.append(subtask_tmpl.replace("{mirror_value}", str(mirror_val)))

                    if "followup_field" in mapping:
                        followup_val = form_fields.get(mapping["followup_field"])
                        if _is_yes(followup_val):
                            subtask = task_def.get("subtask_if_followup")
                            if subtask:
                                subtasks.append(subtask)

                    name = task_def["name"]
                    if "level_field" in mapping:
                        level_val = form_fields.get(mapping["level_field"]) or "Standard"
                        name = name.replace("{level_value}", str(level_val))

                    tasks.append(_make_task(name, task_def["priority"], task_def["category"], subtasks=subtasks, details=details))
                else:
                    skipped.append({"field": field_name, "value": field_value})

            elif field_type == "text":
                skip_values = mapping.get("skip_values", ["-", "", "n/a", "no"])
                if _is_skippable(field_value, skip_values):
                    skipped.append({"field": field_name, "value": field_value})
                    continue
                task_def = mapping["task_on_value"]
                details = task_def.get("details", "").replace("{value}", str(field_value))
                tasks.append(_make_task(task_def["name"], task_def["priority"], task_def["category"], details=details))

    if scope == "international":
        intl_config = SCOPE_MODIFIERS.get("international", {})
        for t in intl_config.get("additional_tasks", []):
            tasks.append(_make_task(t["name"], t["priority"], t["category"]))

    tasks.sort(key=lambda t: t["priority"])

    company_info = COMPANIES.get(company_code, {})

    return {
        "employee": {
            "name": parsed.get("employee_name"),
            "preferred_name": parsed.get("preferred_name"),
            "start_date": parsed.get("start_date"),
            "position": parsed.get("position"),
            "manager": parsed.get("manager"),
            "company_code": company_code,
            "company_name": company_info.get("name", company_raw),
            "location": parsed.get("location"),
            "hire_type": hire_type,
            "scope": scope,
            "role": parsed.get("role"),
        },
        "tasks": tasks,
        "skipped": skipped,
    }
