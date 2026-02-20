# 🛠️ Admin Tools

**Internal IT administration toolkit** — a collection of automation tools, AI assistants, and utilities built by the IT team, for the IT team.

---

## 📁 Tools

| Tool | Directory | Status | Description |
|------|-----------|--------|-------------|
| **AssistAI** | [`/assist-ai`](./assist-ai/) | 🚧 In Development | AI-powered onboarding assistant — parses HR emails & Spiceworks tickets, generates task checklists |
| *More coming...* | | | |

---

## 🏗️ Architecture

```
admin-tools/
├── assist-ai/          # AI onboarding assistant (Ollama + FastAPI)
├── <future-tool>/      # Placeholder for next tool
├── <future-tool>/      # Placeholder for next tool
└── README.md           # You are here
```

Each tool lives in its own directory with its own `README.md`, `Dockerfile`, and deployment instructions. Tools are **independent** — you can deploy one without the others.

---

## 🖥️ Infrastructure

| Resource | Detail |
|----------|--------|
| **Server OS** | Ubuntu 22.04 LTS |
| **GPU** | NVIDIA T1000 8GB |
| **Deployment** | Docker / Docker Compose |
| **Access** | Internal network only |

---

## 🚀 Getting Started

### Prerequisites
- Docker & Docker Compose installed
- NVIDIA Container Toolkit (for GPU-accelerated tools)
- Git access to this repository

### Deploy a Tool
```bash
# Clone the repo
git clone git@github.com:minatolabs/admin-tools.git
cd admin-tools

# Navigate to the tool you want
cd assist-ai

# Launch it
docker compose up -d
```

Each tool has its own setup instructions in its directory. Check the tool's `README.md` for specifics.

---

## 📋 Tool Index & Roadmap

### ✅ Phase 1 — AssistAI (Onboarding Assistant)
- [x] Parse HR onboarding emails (RNH/CNH)
- [x] Parse Spiceworks onboarding tickets
- [x] Auto-generate task checklists by company, role, and department
- [x] Ephemeral web UI — no data stored
- [ ] Multi-company support (TES, FRAME Domestic, FRAME International)

### 🔮 Phase 2 — SOP Finder *(Planned)*
- [ ] AI-assisted SOP search ("How do I set up VPN for a new user?")
- [ ] Points techs to the correct document on the file server
- [ ] Summarizes key steps from SOPs

### 🔮 Phase 3 — Credential Reference *(Planned)*
- [ ] Secure pointer to credential storage (KeePass, vault)
- [ ] "Where is the admin login for X?" → returns file location, not passwords
- [ ] Basic authentication layer for access control

---

## 👥 Team

| Role | Responsibility |
|------|---------------|
| **IT Admin** | Maintains tools, updates rules/configs |
| **IT Techs** | End users — use tools for daily tasks |

---

## ⚠️ Important

- **This is a private repository.** Do not share access outside the IT team.
- **No sensitive data** (passwords, PII) should be committed to this repo.
- **Employee data is never stored** — tools are designed to be ephemeral and stateless.

---

## 📄 License

Internal use only. Not licensed for distribution.