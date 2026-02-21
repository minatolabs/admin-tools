# TenantOps (Windows)

Hybrid admin scripts for when you want results, not 47 browser tabs.

Built for **domain-joined Windows laptops** in a **hybrid Entra + AD + M365** environment.

---

## ⚡ Quick Commands

| What you want | Command |
|---|---|
| Run (from this folder) | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\M365-Hybrid-Admin-Tool.ps1"` |
| Run (full path) | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Users\<YOUR_USERNAME>\admin-tools\tools\TenantOps\M365-Hybrid-Admin-Tool.ps1"` |
| Run (no username editing) | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\admin-tools\tools\TenantOps\M365-Hybrid-Admin-Tool.ps1"` |
| Install EXO module | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |
| Install AD tools (RSAT) | `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` |

---

## ✅ Known Good Environment

- **Windows**: 10/11 (domain-joined)
- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7 (Windows)
- **Network**: corporate LAN (same subnets) / VPN not required in this setup

---

## What this script does today (no surprises)

Right now, `M365-Hybrid-Admin-Tool.ps1` is a **scaffold**:

- Connects to **Exchange Online** (`Connect-ExchangeOnline`)
- Placeholder for admin logic
- Disconnects cleanly (`Disconnect-ExchangeOnline`)

More AD/Entra actions can be added as the toolkit grows.

---

## What’s in here

<table>
  <tr>
    <td width="60%" valign="top">
      <h3>M365 Hybrid Admin Tool</h3>
      <p><code>M365-Hybrid-Admin-Tool.ps1</code></p>
      <ul>
        <li>Connects to <strong>Exchange Online</strong></li>
        <li>Acts as a clean scaffold for hybrid workflows</li>
        <li>Disconnects automatically at the end</li>
      </ul>
    </td>
    <td width="40%" valign="top">
      <h3>TL;DR</h3>
      <ul>
        <li><strong>Windows only</strong></li>
        <li><strong>Run on your laptop</strong> (not a DC)</li>
        <li><strong>No secrets</strong> in code, ever</li>
      </ul>
    </td>
  </tr>
</table>

---

## First-time setup (newbie mode)

### Step 1 — Get the code

**Option A: Git (recommended)**
```powershell
cd $env:USERPROFILE
git clone https://github.com/minatolabs/admin-tools.git
cd .\admin-tools\tools\TenantOps\
```

**Option B: Download ZIP (no Git)**
1. Repo → **Code** → **Download ZIP**
2. Extract it
3. Open PowerShell and go to:
```powershell
cd "...\admin-tools-main\tools\TenantOps\"
```

### Step 2 — Install the Exchange Online module (required)
```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

Quick check:
```powershell
Get-Module ExchangeOnlineManagement -ListAvailable
```

### Step 3 — Optional: install AD tools (only needed once you add AD commands)
If you later add AD actions like `Get-ADUser`, install RSAT:

```powershell
# Run PowerShell as Administrator for this
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

Check:
```powershell
Get-Module ActiveDirectory -ListAvailable
```

---

## Common “why is it yelling at me” fixes

### `Connect-ExchangeOnline` not recognized
```powershell
Install-Module ExchangeOnlineManagement -Scope CurrentUser
```

### `Get-ADUser` not recognized
```powershell
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

### PowerShell profile weirdness / slow startup / random aliases
Run with `-NoProfile` (we already do).

---

## Safety rules (non‑negotiable)

- **No secrets** in code (no passwords, tokens, tenant keys).
- Prefer **read/validate** before **write**.
- If anything destructive is added later: require explicit confirmation and document it.

---

## Roadmap (a.k.a. “coming soon™”)

- [ ] Add real hybrid actions (AD + EXO) with a menu
- [ ] Standardize output/logging
- [ ] Add `Get-Help` examples and operator notes
