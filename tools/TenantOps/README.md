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
| Skip AD (M365-only machine) | append `-SkipAD` to any of the above |
| Install EXO module | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |
| Install MSOnline module | `Install-Module MSOnline -Scope CurrentUser` |
| Install AD tools (RSAT) | `Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0` |

---

## ✅ Known Good Environment

- **Windows**: 10/11 (domain-joined)
- **PowerShell**: Windows PowerShell 5.1 or PowerShell 7 (Windows)
- **Network**: corporate LAN / VPN not required in this setup

---

## What's in here

<table>
  <tr>
    <td valign="top">
      <h3>M365-Hybrid-Admin-Tool.ps1</h3>
      <p>Interactive menu launcher. Connects to Exchange Online, dot-sources the three script modules below, and presents a top-level menu.</p>
      <ul>
        <li>Connects to <strong>Exchange Online</strong> (and optionally loads the AD module)</li>
        <li>Top-level menu → sub-menus for each workflow area</li>
        <li>Disconnects cleanly on exit</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>AuditReports.ps1</h3>
      <p>Audit reporting functions. All results are exported to CSV in <code>$env:TEMP</code>.</p>
      <ul>
        <li><strong>Mailbox Access Audit</strong> — queries the unified audit log for non-owner <code>MailboxLogin</code> / <code>FolderBind</code> events; filters out owner access by logon type.</li>
        <li><strong>Admin Role Assignments</strong> — iterates every Exchange role group and emits a flat <em>(RoleGroup, Member, RecipientType)</em> report.</li>
        <li><strong>MFA / Sign-in Compliance</strong> — per-user MFA registration state via MSOnline; flags licensed users with no MFA method registered.</li>
        <li><strong>License Report</strong> — SKU totals (active / consumed / available) plus a per-user license detail export.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>DelegationManagement.ps1</h3>
      <p>Mailbox and group delegation functions. Write operations require explicit Y/N confirmation.</p>
      <ul>
        <li><strong>List Mailbox Delegates</strong> — shows FullAccess, SendAs, and SendOnBehalf grants side-by-side.</li>
        <li><strong>Add Mailbox Delegate</strong> — grants FullAccess (<code>Add-MailboxPermission</code>), SendAs (<code>Add-RecipientPermission</code>), or SendOnBehalf (<code>Set-Mailbox</code>).</li>
        <li><strong>Remove Mailbox Delegate</strong> — revokes any of the three permission types.</li>
        <li><strong>Calendar Permissions</strong> — view current folder permissions and set/update roles (Owner → None) for any user, Default, or Anonymous.</li>
        <li><strong>Distribution Group Membership</strong> — list, add, or remove members from DLs and mail-enabled security groups.</li>
      </ul>
    </td>
  </tr>
  <tr>
    <td valign="top">
      <h3>ProvisioningAutomation.ps1</h3>
      <p>End-to-end provisioning and offboarding workflows.</p>
      <ul>
        <li><strong>New User Provisioning</strong> — creates an AD account in the specified OU (first name, last name, UPN, SAM, department, title, manager, initial password), then assigns an M365 license SKU after prompting for usage location.</li>
        <li><strong>License Assignment</strong> — add or remove individual SKUs on an existing M365 user; shows available SKUs and current state before prompting.</li>
        <li><strong>Add User to Groups</strong> — accepts a comma-separated list of group names/emails; tries EXO distribution groups first, then AD security groups.</li>
        <li><strong>Create Shared Mailbox</strong> — provisions a shared mailbox with a custom display name, alias, and SMTP address, then optionally grants FullAccess + SendAs to a list of delegates in one pass.</li>
        <li><strong>User Offboarding</strong> — stepped checklist (each confirmed before applying): disable AD account → reset password → revoke M365 refresh tokens → block sign-in → convert mailbox to Shared → hide from GAL → remove from all distribution groups.</li>
      </ul>
    </td>
  </tr>
</table>

---

## First-time setup

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
3. Open PowerShell and navigate to:
```powershell
cd "...\admin-tools-main\tools\TenantOps\"
```

### Step 2 — Install required modules

```powershell
# Required — Exchange Online connectivity and mailbox/delegation cmdlets
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Required for MFA reports and license management
Install-Module MSOnline -Scope CurrentUser
```

### Step 3 — Optional: install AD tools (hybrid environments only)

```powershell
# Run PowerShell as Administrator
Add-WindowsCapability -Online -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0
```

Verify:
```powershell
Get-Module ActiveDirectory -ListAvailable
```

---

## Common fixes

| Error | Fix |
|---|---|
| `Connect-ExchangeOnline` not recognised | `Install-Module ExchangeOnlineManagement -Scope CurrentUser` |
| `Get-MsolUser` not recognised | `Install-Module MSOnline -Scope CurrentUser` |
| `Get-ADUser` not recognised | Install RSAT (Step 3 above) |
| Script won't run (execution policy) | Use `-ExecutionPolicy Bypass` as shown in Quick Commands |
| Machine has no AD / not domain-joined | Run with `-SkipAD` |

---

## Safety rules (non-negotiable)

- **No secrets** in code — no passwords, tokens, or tenant keys ever committed.
- **Read before write** — audit and list functions are always available without making changes.
- **Explicit confirmation** — every write/delete operation prompts `[Y/N]` before applying.

---

## Roadmap

- [x] Audit reports (mailbox access, admin roles, MFA, licenses)
- [x] Delegation management (FullAccess / SendAs / SendOnBehalf / calendar / DL)
- [x] Provisioning automation (new user, license, groups, shared mailbox, offboarding)
- [ ] Standardise CSV output path (configurable export directory)
- [ ] Add scheduled / headless mode (parameter-driven, no `Read-Host`)
- [ ] Add `Get-Help` examples and operator runbook notes
