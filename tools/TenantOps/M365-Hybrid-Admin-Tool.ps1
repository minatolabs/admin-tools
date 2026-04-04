<#
.SYNOPSIS
    M365 Hybrid Admin Tool — interactive menu for day-to-day tenant operations.

.DESCRIPTION
    Connects to Exchange Online (and optionally Active Directory) and exposes a
    menu-driven interface for the three main admin workflows:

        1. Audit Reports       — mailbox access, admin roles, MFA/sign-in, licenses
        2. Delegation Mgmt     — mailbox delegates, calendar perms, DL management
        3. Provisioning        — new-user provisioning (AD + M365), license/group ops

    Each workflow is implemented in its own script in this directory and is
    dot-sourced at startup so all helper functions are available in the session.

.PARAMETER TenantId
    Optional. Azure AD tenant ID (GUID or verified domain). Required when the
    authenticated account has access to more than one tenant.

.PARAMETER SkipAD
    Switch. Skip importing the ActiveDirectory module (useful on machines
    without RSAT installed).

.EXAMPLE
    .\M365-Hybrid-Admin-Tool.ps1
    .\M365-Hybrid-Admin-Tool.ps1 -TenantId contoso.onmicrosoft.com
    .\M365-Hybrid-Admin-Tool.ps1 -SkipAD
#>

[CmdletBinding()]
param(
    [string]$TenantId = $null,
    [switch]$SkipAD
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── Dot-source sibling scripts ───────────────────────────────────────────────

$scriptDir = $PSScriptRoot

foreach ($sibling in @('AuditReports.ps1', 'DelegationManagement.ps1', 'ProvisioningAutomation.ps1')) {
    $path = Join-Path $scriptDir $sibling
    if (Test-Path $path) {
        . $path
    } else {
        Write-Warning "[$sibling] not found — related menu items will be unavailable."
    }
}

# ── Module checks ────────────────────────────────────────────────────────────

if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Error "ExchangeOnlineManagement module not found. Run: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
}

if (-not $SkipAD -and -not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Warning "ActiveDirectory module not found. AD-related functions will be skipped. Use -SkipAD to suppress this warning."
    $SkipAD = $true
}

# ── Connect ──────────────────────────────────────────────────────────────────

Write-Host "`nConnecting to Exchange Online…" -ForegroundColor Cyan

$exoParams = @{ ShowBanner = $false }
if ($TenantId) { $exoParams['TenantId'] = $TenantId }
Connect-ExchangeOnline @exoParams

if (-not $SkipAD) {
    Import-Module ActiveDirectory -ErrorAction SilentlyContinue
}

Write-Host "Connected.`n" -ForegroundColor Green

# ── Menu ─────────────────────────────────────────────────────────────────────

function Show-MainMenu {
    Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "   M365 Hybrid Admin Tool" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor DarkCyan
    Write-Host "  1  Audit Reports"
    Write-Host "  2  Delegation Management"
    Write-Host "  3  Provisioning Automation"
    Write-Host "  Q  Quit"
    Write-Host "───────────────────────────────────────────" -ForegroundColor DarkCyan
}

function Show-AuditMenu {
    Write-Host "`n── Audit Reports ──────────────────────────" -ForegroundColor DarkYellow
    Write-Host "  1  Mailbox access audit (non-owner)"
    Write-Host "  2  Admin role assignments"
    Write-Host "  3  MFA / sign-in compliance"
    Write-Host "  4  License assignment report"
    Write-Host "  B  Back"
    Write-Host "───────────────────────────────────────────" -ForegroundColor DarkYellow
}

function Show-DelegationMenu {
    Write-Host "`n── Delegation Management ──────────────────" -ForegroundColor DarkYellow
    Write-Host "  1  List mailbox delegates"
    Write-Host "  2  Add mailbox delegate"
    Write-Host "  3  Remove mailbox delegate"
    Write-Host "  4  Calendar permissions"
    Write-Host "  5  Distribution group membership"
    Write-Host "  B  Back"
    Write-Host "───────────────────────────────────────────" -ForegroundColor DarkYellow
}

function Show-ProvisioningMenu {
    Write-Host "`n── Provisioning Automation ─────────────────" -ForegroundColor DarkYellow
    Write-Host "  1  Provision new user (AD + M365)"
    Write-Host "  2  Assign / change licenses"
    Write-Host "  3  Add user to groups"
    Write-Host "  4  Create shared mailbox"
    Write-Host "  5  Offboard user"
    Write-Host "  B  Back"
    Write-Host "───────────────────────────────────────────" -ForegroundColor DarkYellow
}

# ── Main loop ────────────────────────────────────────────────────────────────

:main while ($true) {
    Show-MainMenu
    $top = (Read-Host "Select").Trim().ToUpper()

    switch ($top) {

        '1' {
            :audit while ($true) {
                Show-AuditMenu
                $sel = (Read-Host "Select").Trim().ToUpper()
                switch ($sel) {
                    '1' { Invoke-MailboxAccessAudit }
                    '2' { Invoke-AdminRoleReport }
                    '3' { Invoke-MFAComplianceReport }
                    '4' { Invoke-LicenseReport }
                    'B' { break audit }
                    default { Write-Warning "Invalid selection." }
                }
            }
        }

        '2' {
            :delegation while ($true) {
                Show-DelegationMenu
                $sel = (Read-Host "Select").Trim().ToUpper()
                switch ($sel) {
                    '1' { Invoke-ListMailboxDelegates }
                    '2' { Invoke-AddMailboxDelegate }
                    '3' { Invoke-RemoveMailboxDelegate }
                    '4' { Invoke-CalendarPermissions }
                    '5' { Invoke-DistributionGroupMembership }
                    'B' { break delegation }
                    default { Write-Warning "Invalid selection." }
                }
            }
        }

        '3' {
            :provisioning while ($true) {
                Show-ProvisioningMenu
                $sel = (Read-Host "Select").Trim().ToUpper()
                switch ($sel) {
                    '1' { Invoke-NewUserProvisioning -SkipAD:$SkipAD }
                    '2' { Invoke-LicenseAssignment }
                    '3' { Invoke-AddUserToGroups }
                    '4' { Invoke-CreateSharedMailbox }
                    '5' { Invoke-UserOffboarding -SkipAD:$SkipAD }
                    'B' { break provisioning }
                    default { Write-Warning "Invalid selection." }
                }
            }
        }

        'Q' { break main }
        default { Write-Warning "Invalid selection." }
    }
}

# ── Disconnect ───────────────────────────────────────────────────────────────

Write-Host "`nDisconnecting…" -ForegroundColor Cyan
Disconnect-ExchangeOnline -Confirm:$false
Write-Host "Done. Session closed." -ForegroundColor Green
