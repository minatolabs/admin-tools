# ⚙️ AssistAI — IT Onboarding Assistant

AssistAI is a lightweight, self-hosted AI assistant that parses HR onboarding emails and Spiceworks tickets and auto-generates task checklists for IT technicians.

---

## 🔐 Security Design Decisions

AssistAI handles sensitive HR and employee data during onboarding. Every architectural choice was made with data minimization and least-privilege as first-order constraints — not afterthoughts.

### Zero Server-Side Persistence

**Decision:** The FastAPI backend processes each request in-memory and immediately discards all parsed data. There is no database, no log sink, no session store.

**Why:** Onboarding emails and tickets contain PII (names, start dates, roles, managers, locations). Storing this data server-side — even temporarily — creates a data-at-rest liability and expands the blast radius of any compromise. With zero persistence, there is nothing to exfiltrate.

### sessionStorage-Only Client State

**Decision:** Checklist state is held exclusively in browser `sessionStorage`. It is destroyed automatically when the tab closes.

**Why:** `sessionStorage` is scoped to a single tab and is never sent to the server, never written to disk, and never accessible cross-origin. Compared to `localStorage` or cookies, it provides the shortest possible data lifetime. A technician closing a tab after completing setup leaves no residual employee data on the workstation — important in shared-desk or open-office environments.

### No PII Logging

**Decision:** The application explicitly avoids logging parsed employee fields (names, emails, roles). Log output is limited to request metadata and error conditions.

**Why:** Application logs are often shipped to centralized log aggregators, retained for months, and accessible to a broader set of operators than the application itself. Logging PII widens the data access surface significantly. Keeping logs free of employee data keeps that surface narrow.

### Internal Network Constraint

**Decision:** AssistAI is designed to run on an internal network only. The Docker configuration binds to the host interface without TLS termination, making accidental public exposure obvious rather than silent.

**Why:** The tool runs a local LLM (Ollama) and processes onboarding data — neither should be reachable from the internet. Requiring a deliberate infrastructure change (reverse proxy + TLS + firewall rule) to expose the service externally enforces a security gate by default. This reflects a zero-trust posture: internal tools stay internal unless explicitly promoted.

### LLM Isolation

**Decision:** The LLM (llama3.1:8b via Ollama) runs locally on-prem hardware. No data is sent to external AI APIs.

**Why:** Sending HR onboarding data to cloud AI providers (OpenAI, Anthropic, etc.) would require data processing agreements, expose PII to third-party retention policies, and create audit trail gaps. Running the model locally keeps all inference within the trust boundary.

### Threat Model Summary

| Threat | Mitigated By |
|--------|-------------|
| PII exposure via server breach | Zero server-side persistence |
| Data leakage via browser storage | sessionStorage (tab-scoped, ephemeral) |
| Log aggregator PII exposure | No employee data in logs |
| Accidental public exposure | Internal-only network binding |
| Third-party AI data retention | Local LLM (Ollama, on-prem) |
| Overprivileged data access | No auth required internally; no data stored to protect |

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
All checklist state is stored in browser `sessionStorage` — destroyed when the tab is closed.

---

## 📋 Prerequisites

- Docker & Docker Compose v2
- NVIDIA Container Toolkit (for GPU passthrough)
- NVIDIA T1000 8GB (or compatible GPU) — the T1000 is the tested configuration

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
# 1. Navigate to the assist-ai directory
cd assist-ai

# 2. Start both services (Ollama + AssistAI app)
docker compose up -d

# 3. Wait for the Llama 3.1 8B model to download (first run only)
#    This may take several minutes depending on your connection
docker compose logs -f ollama

# 4. Access AssistAI in your browser
#    http://your-server-ip:8080
```

The app will pull `llama3.1:8b` automatically on first startup via the Ollama container.

---

## 📖 Usage Guide

### Retail New Hire (RNH)

1. Copy the full HR onboarding email from your inbox
2. Paste it into the **Email / Ticket Content** textarea
3. Leave **Hire Type Override** as "Auto-detect" (or select "RNH" manually)
4. Click **⚡ Parse & Generate Checklist**

The AI will extract:
- Employee name, start date, position, manager, location
- Company (NVS, AURA)
- Role (GM, AGM, Key Holder, Sales Associate) to determine tasks

### Corporate New Hire (CNH)

1. Open the Spiceworks ticket for the new hire
2. Copy the full ticket description (all fields)
3. Paste it into the textarea
4. Click **⚡ Parse & Generate Checklist**

The AI will extract all form field values and map them to tasks.

### Using the Checklist

- **Check off tasks** as you complete them — progress bar updates in real-time
- **Refresh the page** — your progress is saved (sessionStorage)
- **Close the tab** — all data is destroyed (intentionally ephemeral)
- **Clear button** — resets the current session manually

---

## ⚙️ Configuration

All business rules are defined in `config/onboarding_rules.yml`.

### Add a new company

```yaml
companies:
  NEW-CO:
    name: "New Company Name"
    scope: "domestic"   # or "international"
```

Then add an email pattern:

```yaml
email_patterns:
  - pattern: "NEW\\s*-\\s*RNH"
    company: "NEW-CO"
    hire_type: "RNH"
```

### Add a new RNH role

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

### Add a new CNH form field

```yaml
hire_types:
  CNH:
    form_field_mappings:
      my_new_field:
        field_name: "My New System Access"
        type: "yes_no"
        task_on_yes:
          name: "Set Up My New System"
          priority: 2
          category: "Business Systems"
```

No code changes needed — the rules engine reads the YAML at startup.

---

## 🔧 Troubleshooting

### Ollama not starting / GPU not detected

```bash
# Check NVIDIA is visible to Docker
docker run --rm --gpus all nvidia/cuda:12.0-base nvidia-smi

# Check Ollama logs
docker compose logs ollama

# Verify NVIDIA Container Toolkit is installed
nvidia-ctk --version
```

### Model download taking too long

The `llama3.1:8b` model is ~4.7GB. Monitor with:

```bash
docker compose logs -f ollama
```

### App shows "Ollama Unavailable (fallback mode)"

The app will still work using the regex-based fallback parser. The fallback can extract basic data from RNH emails using email subject patterns. For CNH tickets, LLM parsing is recommended.

To check Ollama health directly:
```bash
curl http://localhost:11434/api/tags
```

### Port conflicts

Edit `docker-compose.yml` to change ports:
```yaml
ports:
  - "9090:8080"   # Change 9090 to any available port
```

---

## 📊 Example Inputs & Outputs

### Example 1: Retail New Hire (RNH) — GM

**Input email:**
```
Sub : NVS - RNH John Smith

Hi all,

We have a new hire today:

Employee: John Smith
Start Date: Monday, March 9, 2026
Manager: Sarah Johnson
Position: General Manager, Aspen
Status: RFT
Company: Nova Style Co.
Location: NVS Aspen retail store
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
Summary: Welcoming Alex Doe in the London Office
Description:
Dear All,
We are welcoming a new employee in the London Office.
Their name is Alex DOE and their position will be "Retail Coordinator".

Preferred Name: Alex Doe
Start Date: 2026-06-01
Computer Requirements: Windows
FileCloud (Shared Drive) Access: yes
For FileCloud (Shared Drive) access, enter current or former user to mirror access: Jordan Smith
Zoom Phone Extension: no
NewStore System Access?: Yes
If yes, please select New Store access level: Corporate Office User
Full Circle Account: No
BlueCherry ERP: no
BlueCherry PLM: no
Additional Equipment for Office/WFH: -
Other system access not listed needed: -
Distro Lists other than office/retail location: -
For any other IT Onboarding requests or requirements not listed: -
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
| `config/onboarding_rules.yml` | All business rules, companies, roles, form fields |
| `app/main.py` | FastAPI entry point, API routes, static serving |
| `app/parser.py` | Ollama LLM integration + regex fallback |
| `app/rules.py` | Rules engine — generates checklists from parsed data |
| `web/index.html` | Single page application |
| `web/app.js` | Frontend logic, sessionStorage, progress tracking |
| `web/style.css` | Dark professional theme |

---

## ⚠️ Privacy & Security

See the [Security Design Decisions](#-security-design-decisions) section at the top of this document for the full rationale behind these choices.

- **Zero server-side persistence** — the API processes and discards data immediately
- **No logging of employee data** — keep it that way
- **sessionStorage only** — data never leaves the browser tab
- **Internal network only** — do not expose port 8080 to the internet
