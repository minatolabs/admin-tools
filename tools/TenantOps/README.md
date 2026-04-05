# Tenant-Ops · M365 Hybrid Admin Tool

> _"Because clicking through the Exchange Admin Center for the 47th time is not a personality trait."_

A PowerShell 7 toolkit for wrangling Microsoft 365 hybrid environments — AD, Exchange Online, and Azure AD Connect — without losing your mind.

![Version](https://img.shields.io/badge/version-v0.3.3--test-blue?style=flat-square)
![PowerShell](https://img.shields.io/badge/PowerShell-7%2B-5391FE?style=flat-square&logo=powershell)
![License](https://img.shields.io/badge/license-MIT-green?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6?style=flat-square&logo=windows)

---

## What's this for?

Hybrid M365 environments are a pain. You've got AD on-prem, Exchange Online in the cloud, AAD Connect syncing between them, and every onboarding/offboarding flow touching all three. This tool stitches that together into a clean interactive menu so you're not tabbing between five different admin consoles and one ancient runbook doc from 2019.

---

## What it does

| Feature | What actually happens |
|---|---|
| **User Onboarding** | Creates the AD account, sets the password, drops them in the right groups, fires off an AAD Connect delta sync |
| **User Offboarding** | Disables the AD account, moves it to the disabled OU, syncs — all in one go |
| **Mailbox Permissions** | FullAccess / SendAs / SendOnBehalf — grant or revoke, one-to-many or many-to-one |
| **Cloud Connectivity** | One command to connect Exchange Online + Microsoft Graph; one to kill both |
| **Audit Logging** | Every action lands in a structured JSONL log + full console transcript — great for compliance, better for blame |
| **Diagnostics** | Checks that RSAT, ExchangeOnlineManagement, Microsoft.Graph, and ADSync are all present before you need them |

---

## Requirements

You'll need these before anything works:

| Requirement | Notes |
|---|---|
| **PowerShell 7+** | Not Windows PowerShell 5.1 — actually 7. [Get it here.](https://github.com/PowerShell/PowerShell/releases) |
| **RSAT: AD DS Tools** | For all on-prem AD operations |
| **ExchangeOnlineManagement** | Auto-installs if missing |
| **Microsoft.Graph** | Optional — auto-installs if you connect to Graph |
| **ADSync module** | Only needed on the AAD Connect server itself |

---

## Getting started

```powershell
# Standard run
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\M365-Hybrid-Admin-Tool.ps1

# Check the version
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\M365-Hybrid-Admin-Tool.ps1 -ShowVersion
```

> `-ExecutionPolicy Bypass` is fine in a controlled admin context. Don't pipe random scripts off the internet into this and call it a day.

---

## Menu layout

```
Main Menu
├── 1) Connect to Exchange Online / Graph
├── 2) Onboard user (AD-first)
├── 3) Offboard user (AD-first)
├── 4) Mailbox permissions
│   ├── Grant: FullAccess / SendAs / SendOnBehalf
│   └── Remove: FullAccess / SendAs / SendOnBehalf / ALL
├── 5) Diagnostics / prerequisites
├── 6) Disconnect cloud sessions
└── 7) Exit
```

---

## Audit logs

Every action is written to disk. No silent failures, no "I think it worked."

```
%ProgramData%\M365HybridAdminTool\Logs\
  Audit-YYYY-MM-DD.jsonl          ← structured JSON, queryable
  Transcript-YYYY-MM-DD_*.txt     ← full console output
```

Each audit event includes: UTC timestamp · correlation ID · operator (`domain\user`) · hostname · action · result (`Success / Failure / Info`) · contextual data payload.

Handy for compliance reviews, incident timelines, or answering "wait, who offboarded that account?"

---

## Version

`v0.3.3-test` — build date 2026-02-20

---

## License

[MIT](../../LICENSE) — use it, break it, fix it, ship it.
