# ⚙️ AssistAI — IT Onboarding Assistant

> _"Because copying field values from an HR email into a ticket tracker, by hand, in 2026, is a war crime."_

AssistAI is a lightweight, self-hosted AI assistant that reads HR onboarding emails and Spiceworks tickets, then spits out a clean task checklist for your IT team. Paste text in. Get a checklist out. No cloud, no subscriptions, no data leaving your building.

![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Python](https://img.shields.io/badge/Python-3.14-3776AB?style=flat-square&logo=python)
![FastAPI](https://img.shields.io/badge/FastAPI-latest-009688?style=flat-square&logo=fastapi)
![Ollama](https://img.shields.io/badge/Ollama-llama3.1%3A8b-black?style=flat-square)

---

## 🏗️ Architecture

```
Browser (sessionStorage only)
        │
        ▼
┌─────────────────────────────┐
│  AssistAI App (FastAPI)     │  :8080
│  ┌──────────┐ ┌──────────┐  │
│  │ parser   │ │  rules   │  │
│  │ (LLM +  │ │ engine   │  │
│  │ fallback)│ │(YAML cfg)│  │
│  └────┬─────┘ └──────────┘  │
└───────┼─────────────────────┘
        │
        ▼
┌─────────────────────────────┐
│  Ollama (llama3.1:8b)       │  :11434
│  NVIDIA T1000 8GB GPU       │
└─────────────────────────────┘
```

**No database. No server-side sessions. Zero persistence.**  
All checklist state lives in browser `sessionStorage` — close the tab and it's gone. Intentionally.

---

## 🚨 Before You Deploy — Read This

**This repo ships with placeholder data.** The company names, codes, email patterns, and roles in `config/onboarding_rules.yml` are all examples (`ACR`, `Acme Retail`, etc.). None of it will match your actual environment out of the box.

**You need to customize it.** The good news: it's just a YAML file and takes maybe 20 minutes. The [Configuration](#️-configuration) section below walks you through every part of it.

Here's the short version of what you'll need to swap out:

| What | Where | Example |
|------|-------|---------|
| Company names & codes | `config/onboarding_rules.yml` → `companies` | `TES`, `CORP` |
| Email subject patterns | `config/onboarding_rules.yml` → `email_patterns` | `"TES\\s*-\\s*RNH"` |
| RNH roles & their tasks | `config/onboarding_rules.yml` → `hire_types.RNH.roles` | `GM`, `Key Holder` |
| CNH form field names | `config/onboarding_rules.yml` → `hire_types.CNH.form_field_mappings` | Must match your Spiceworks form exactly |
| LLM hint examples | `app/parser.py` → `SYSTEM_PROMPT` → `company_raw` line | Update to match your actual company names |

> **Tip on CNH form fields:** The field names in the YAML must be **character-for-character identical** to the labels in your Spiceworks ticket form. Copy-paste them — don't retype.

---

## 📋 Prerequisites

- Docker & Docker Compose v2
- NVIDIA Container Toolkit (for GPU passthrough)
- NVIDIA T1000 8GB (or compatible GPU) — the T1000 is the tested config

### Install NVIDIA Container Toolkit (Ubuntu)
```bash
distribution=$(. /etc/os-release; echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list \
  | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

---

## 🚀 Quick Start

```bash
# 1. Customize the config first (seriously, don't skip this)
#    Edit config/onboarding_rules.yml to match your company

# 2. Start both services
docker compose up -d

# 3. First run pulls llama3.1:8b (~4.7GB) — grab a coffee
docker compose logs -f ollama

# 4. Open it up
#    http://your-server-ip:8080
```

---

## 📖 Usage Guide

### Retail New Hire (RNH)

1. Copy the full HR onboarding email from your inbox
2. Paste it into the **Email / Ticket Content** textarea
3. Leave **Hire Type Override** as "Auto-detect" (or force it to "RNH")
4. Click **⚡ Parse & Generate Checklist**

The AI extracts: employee name, start date, position, manager, location, company, and role — then maps the role to tasks defined in your YAML config.

### Corporate New Hire (CNH)

1. Open the Spiceworks ticket for the new hire
2. Copy the full ticket description
3. Paste it in, hit parse

The LLM reads every form field and maps them to tasks. If Ollama is down, a regex fallback kicks in for basic RNH parsing — CNH really does need the LLM.

### Checklist Workflow

- **Click a task** to check it off — progress bar updates live
- **Refresh** — your progress survives (sessionStorage)
- **Close the tab** — everything is wiped. On purpose.
- **Clear button** — manual reset mid-session

---

## ⚙️ Configuration

Everything lives in `config/onboarding_rules.yml`. No code changes needed — the rules engine reads it at startup and hot-reloads aren't even necessary since you'll restart Docker anyway.

### Companies

```yaml
companies:
  MYCO:
    name: "My Company Name"
    scope: "domestic"   # or "international"
  INTL-MYCO:
    name: "My Company Name"
    scope: "international"
```

Multiple codes can share the same `name` — the scope field is used to pick the right one when both match (e.g. domestic vs international entities of the same brand).

### Email subject patterns

These are regex patterns matched against the email subject line to detect company and hire type:

```yaml
email_patterns:
  - pattern: "MYCO\\s*-\\s*RNH"
    company: "MYCO"
    hire_type: "RNH"
  - pattern: "MYCO\\s*-\\s*CNH"
    company: "MYCO"
    hire_type: "CNH"
```

### RNH roles

```yaml
hire_types:
  RNH:
    roles:
      Senior Associate:
        level: "mid"
        additional_tasks:
          - name: "Extended System Access"
            priority: 2
            category: "Identity"
```

Roles support inheritance — a `GM` can `inherits: "AGM"` to get all AGM tasks plus its own.

### CNH form fields

```yaml
hire_types:
  CNH:
    form_field_mappings:
      my_system_access:
        field_name: "My System Access"   # must match your Spiceworks label exactly
        type: "yes_no"
        task_on_yes:
          name: "Set Up My System"
          priority: 2
          category: "Business Systems"
```

Field types: `yes_no`, `select` (dropdown), `text` (freeform with skip values).

### Also update the LLM prompt

In `app/parser.py`, find the `company_raw` line in `SYSTEM_PROMPT` and update the examples to match your real company names — it helps the LLM normalize them correctly:

```python
"company_raw": "<company name as written in the text or null>",
# e.g. "My Company", "My Co International", "MC"
```

---

## 🔧 Troubleshooting

### Ollama not starting / GPU not detected

```bash
# Is NVIDIA visible to Docker at all?
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Ollama logs
docker compose logs ollama

# Toolkit version check
nvidia-ctk --version
```

### Model taking forever to download

`llama3.1:8b` is ~4.7GB. It's a one-time pull. Watch it:

```bash
docker compose logs -f ollama
```

### "Ollama Unavailable (fallback mode)" in the UI

The app still works — it falls back to regex parsing for basic RNH email detection. CNH parsing without the LLM will be incomplete. Fix Ollama, then it auto-recovers:

```bash
curl http://localhost:11434/api/tags   # should return model list
```

### Port conflicts

```yaml
# docker-compose.yml
ports:
  - "9090:8080"   # swap 9090 for whatever's free
```

---

## 📊 Example Inputs & Outputs

### Example 1: Retail New Hire (RNH) — GM

**Input email:**
```
Sub : ACR - RNH Alex Johnson

Employee: Alex Johnson
Start Date: Monday, March 9, 2026
Manager: Jordan Lee
Position: General Manager, Midtown
Status: RFT
Company: Acme Retail
Location: Acme Retail Midtown store
```

**Generated checklist:**
| Task | Category | Priority |
|------|----------|----------|
| Create Email Account | Identity | 🔴 1 |
| Create NewStore Account | Retail Systems | 🔴 1 |
| Full Admin POS Access | Retail Systems | 🔴 1 |
| Order Laptop | Hardware | 🟠 2 |
| Create Filecloud Account | Cloud Access | 🟠 2 |
| POS Manager Permissions | Retail Systems | 🟠 2 |
| Store Alarm Codes | Security | 🟠 2 |
| Camera Access | Security | ⚫ 3 |
| Vendor Portal Access | Business | ⚫ 3 |

---

### Example 2: Corporate New Hire (CNH) — International

**Input ticket:**
```
Summary: Welcoming Jamie Chen in the London Office

Preferred Name: Jamie Chen
Start Date: 2026-03-02
Computer Requirements: Windows
FileCloud (Shared Drive) Access: yes
For FileCloud (Shared Drive) access, enter current or former user to mirror access: Sophie Martin
Zoom Phone Extension: no
NewStore System Access?: Yes
If yes, please select New Store access level: Corporate Office User
Full Circle Account: No
BlueCherry ERP: no
BlueCherry PLM: no
Organization: Acme Corp
```

**Generated checklist:**
| Task | Category | Priority |
|------|----------|----------|
| Create Email Account | Identity | 🔴 1 |
| Create AD Account | Identity | 🔴 1 |
| Verify International Email Domain | Identity | 🔴 1 |
| Set Up VPN Access | Network | 🟠 2 |
| Order Windows Laptop | Hardware | 🟠 2 |
| Set Up FileCloud Access | Cloud Access | 🟠 2 |
| Create NewStore Account — Corporate Office User | Retail Systems | 🟠 2 |
| Set Timezone / Regional Settings | Configuration | 🟠 2 |

**Skipped:** Zoom Phone Extension, Full Circle Account, BlueCherry ERP, BlueCherry PLM

---

## 📁 File Reference

| File | Purpose |
|------|---------|
| `docker-compose.yml` | Orchestrates Ollama (GPU) + AssistAI app |
| `Dockerfile` | Python 3.14-slim container for the app |
| `requirements.txt` | FastAPI, uvicorn, httpx, pyyaml |
| `config/onboarding_rules.yml` | **Start here** — all business rules, companies, roles, form fields |
| `app/main.py` | FastAPI entry point, API routes, static file serving |
| `app/parser.py` | Ollama LLM integration + regex fallback |
| `app/rules.py` | Rules engine — turns parsed data into task lists |
| `web/index.html` | Single page app |
| `web/app.js` | Frontend logic, sessionStorage, progress tracking |
| `web/style.css` | Dark theme |

---

## ⚠️ Privacy & Security

- **Zero server-side persistence** — the API processes and discards immediately
- **No logging of employee data** — and please keep it that way
- **sessionStorage only** — checklist state never leaves the tab
- **Internal network only** — do not expose port 8080 to the internet. Seriously.
