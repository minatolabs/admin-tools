# Tenant-Ops — M365 Hybrid Admin Tool

A PowerShell 7 admin toolkit for managing Microsoft 365 hybrid environments (Active Directory + Exchange Online + Azure AD Connect).

## Features

- **User Onboarding** — Create AD users (AD-first hybrid model), set passwords, assign AD groups, trigger AAD Connect delta sync
- **User Offboarding** — Disable AD accounts, move to disabled OU, trigger sync
- **Mailbox Permissions** — Grant or remove FullAccess, SendAs, and SendOnBehalf; supports bulk operations (one mailbox → many delegates, or many mailboxes → one delegate)
- **Cloud Connectivity** — Connect/disconnect Exchange Online and Microsoft Graph in one step
- **Compliance & Audit Logging** — Every action is written to a JSONL audit log and full transcript (stored in `%ProgramData%\M365HybridAdminTool\Logs`)
- **Diagnostics** — Prerequisites checker for RSAT, ExchangeOnlineManagement, Microsoft.Graph, and ADSync modules

## Requirements

| Requirement | Notes |
|---|---|
| PowerShell 7+ | [Download](https://github.com/PowerShell/PowerShell/releases) |
| RSAT: Active Directory DS Tools | Required for AD operations |
| ExchangeOnlineManagement module | Auto-installed if missing |
| Microsoft.Graph module | Optional, auto-installed if connecting to Graph |
| ADSync module | Only needed on the AAD Connect server |

## Usage

```powershell
# Run (bypass execution policy for testing)
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\M365-Hybrid-Admin-Tool.ps1

# Show version
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File .\M365-Hybrid-Admin-Tool.ps1 -ShowVersion
```

## Audit Logs

All actions are logged to:
```
%ProgramData%\M365HybridAdminTool\Logs\
  Audit-YYYY-MM-DD.jsonl       ← structured JSON audit trail
  Transcript-YYYY-MM-DD_*.txt  ← full console transcript
```

Each audit event includes: UTC timestamp, correlation ID, operator (domain\user), computer name, action, result (Success / Failure / Info), and contextual data.

## Menu Structure

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

## Version

`v0.3.3-test` — Build date: 2026-02-20

## License

MIT
