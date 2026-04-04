<#
.SYNOPSIS
    User provisioning and offboarding automation for M365 / hybrid environments.

.DESCRIPTION
    Dot-sourced by M365-Hybrid-Admin-Tool.ps1. Each function is independently
    callable for scripted / scheduled use.

    Functions:
        Invoke-NewUserProvisioning  — create AD account + assign M365 license
        Invoke-LicenseAssignment    — assign or swap licenses on an existing user
        Invoke-AddUserToGroups      — bulk-add a user to AD/M365 groups
        Invoke-CreateSharedMailbox  — provision a shared mailbox + set delegates
        Invoke-UserOffboarding      — disable account, revoke sessions, hide from GAL
#>

Set-StrictMode -Version Latest

# ── New User Provisioning ─────────────────────────────────────────────────────

function Invoke-NewUserProvisioning {
    <#
    .SYNOPSIS
        Provisions a new user in Active Directory and assigns an M365 license.

    .DESCRIPTION
        Collects the minimum required fields interactively, creates the AD user
        account in the specified OU, waits for Entra ID sync (or instructs the
        operator to trigger one), then assigns the chosen M365 license SKU.

    .PARAMETER SkipAD
        Skip the Active Directory account creation step (M365-only environments).
    #>

    [CmdletBinding()]
    param([switch]$SkipAD)

    Write-Host "`n[New User Provisioning]" -ForegroundColor Cyan

    # Collect user details
    $firstName   = Read-Host "First name"
    $lastName    = Read-Host "Last name"
    $upn         = Read-Host "UPN / email (e.g. jsmith@contoso.com)"
    $displayName = "$firstName $lastName"
    $samAccount  = Read-Host "SAM account name (e.g. jsmith) [leave blank to derive from UPN]"
    if ([string]::IsNullOrWhiteSpace($samAccount)) {
        $samAccount = $upn.Split('@')[0]
    }
    $department  = Read-Host "Department"
    $jobTitle    = Read-Host "Job title"
    $manager     = Read-Host "Manager UPN or SAM (optional)"
    $ouPath      = Read-Host "Target OU (distinguished name, e.g. OU=Users,DC=contoso,DC=local)"

    # ── AD account creation ───────────────────────────────────────────────────

    if (-not $SkipAD) {
        if (-not (Get-Module -Name ActiveDirectory)) {
            Write-Warning "ActiveDirectory module not loaded — skipping AD step."
        } else {
            Write-Host "`n  Creating AD account…" -ForegroundColor DarkGray

            $securePass = Read-Host "Initial password (will not echo)" -AsSecureString

            $adParams = @{
                Name                  = $displayName
                GivenName             = $firstName
                Surname               = $lastName
                SamAccountName        = $samAccount
                UserPrincipalName     = $upn
                DisplayName           = $displayName
                Department            = $department
                Title                 = $jobTitle
                AccountPassword       = $securePass
                Enabled               = $true
                ChangePasswordAtLogon = $true
                Path                  = $ouPath
            }
            if ($manager) { $adParams['Manager'] = $manager }

            New-ADUser @adParams
            Write-Host "  ✓ AD account created: $samAccount" -ForegroundColor Green
            Write-Host "  → Trigger an Entra ID Connect sync now if needed:" -ForegroundColor Yellow
            Write-Host "       Start-ADSyncSyncCycle -PolicyType Delta" -ForegroundColor DarkGray
            Write-Host "     Then wait ~5 min for the account to appear in M365." -ForegroundColor DarkGray
            Read-Host "`n  Press Enter once the account is visible in M365 (or to skip licensing)"
        }
    }

    # ── M365 license assignment ───────────────────────────────────────────────

    if (-not (Get-Module -ListAvailable -Name MSOnline)) {
        Write-Warning "MSOnline module not found — skipping license step. Install: Install-Module MSOnline -Scope CurrentUser"
        return
    }

    if (-not (Get-MsolDomain -ErrorAction SilentlyContinue)) {
        Connect-MsolService
    }

    # Show available SKUs
    Write-Host "`n  Available license SKUs:" -ForegroundColor White
    $skus = Get-MsolAccountSku | Select-Object SkuPartNumber,
                                                @{N='Available';E={$_.ActiveUnits - $_.ConsumedUnits}}
    $skus | Format-Table -AutoSize

    $chosenSku = Read-Host "SKU to assign (SkuPartNumber from above)"
    $usageLocation = Read-Host "Usage location (2-letter country code, e.g. US)"

    $licSku = Get-MsolAccountSku | Where-Object { $_.SkuPartNumber -eq $chosenSku }
    if (-not $licSku) {
        Write-Warning "SKU '$chosenSku' not found. No license assigned."
        return
    }

    Set-MsolUser -UserPrincipalName $upn -UsageLocation $usageLocation
    Set-MsolUserLicense -UserPrincipalName $upn -AddLicenses $licSku.AccountSkuId
    Write-Host "  ✓ License '$chosenSku' assigned to $upn." -ForegroundColor Green
}

# ── License Assignment ────────────────────────────────────────────────────────

function Invoke-LicenseAssignment {
    <#
    .SYNOPSIS
        Assigns or replaces M365 licenses on an existing user account.
    #>

    Write-Host "`n[License Assignment]" -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name MSOnline)) {
        Write-Warning "MSOnline module required. Run: Install-Module MSOnline -Scope CurrentUser"
        return
    }

    if (-not (Get-MsolDomain -ErrorAction SilentlyContinue)) {
        Connect-MsolService
    }

    $upn = Read-Host "User UPN"

    try {
        $user = Get-MsolUser -UserPrincipalName $upn -ErrorAction Stop
    } catch {
        Write-Warning "User '$upn' not found."
        return
    }

    Write-Host "`n  Current licenses:" -ForegroundColor White
    $user.Licenses | Select-Object @{N='SKU';E={$_.AccountSkuId}} | Format-Table -AutoSize

    Write-Host "  Available SKUs:" -ForegroundColor White
    $skus = Get-MsolAccountSku | Select-Object SkuPartNumber,
                                                @{N='Available';E={$_.ActiveUnits - $_.ConsumedUnits}}
    $skus | Format-Table -AutoSize

    Write-Host "  Actions:"
    Write-Host "    1  Add a license"
    Write-Host "    2  Remove a license"
    $action = Read-Host "Select [1/2]"

    switch ($action) {
        '1' {
            $chosenSku = Read-Host "SKU to add"
            $licSku = Get-MsolAccountSku | Where-Object { $_.SkuPartNumber -eq $chosenSku }
            if (-not $licSku) { Write-Warning "SKU '$chosenSku' not found."; return }

            if ([string]::IsNullOrWhiteSpace($user.UsageLocation)) {
                $loc = Read-Host "Usage location required (e.g. US)"
                Set-MsolUser -UserPrincipalName $upn -UsageLocation $loc
            }

            Set-MsolUserLicense -UserPrincipalName $upn -AddLicenses $licSku.AccountSkuId
            Write-Host "  ✓ License '$chosenSku' added." -ForegroundColor Green
        }
        '2' {
            $chosenSku = Read-Host "SKU to remove"
            $licSku = Get-MsolAccountSku | Where-Object { $_.SkuPartNumber -eq $chosenSku }
            if (-not $licSku) { Write-Warning "SKU '$chosenSku' not found."; return }

            $confirm = Read-Host "Remove '$chosenSku' from $upn? [Y/N]"
            if ($confirm -eq 'Y') {
                Set-MsolUserLicense -UserPrincipalName $upn -RemoveLicenses $licSku.AccountSkuId
                Write-Host "  ✓ License removed." -ForegroundColor Green
            }
        }
        default { Write-Warning "Invalid selection." }
    }
}

# ── Add User to Groups ────────────────────────────────────────────────────────

function Invoke-AddUserToGroups {
    <#
    .SYNOPSIS
        Adds a user to one or more distribution groups or AD security groups.

    .DESCRIPTION
        Accepts a comma-separated list of group names/emails and adds the user
        to each. Supports both EXO distribution groups and (when the AD module
        is available) on-prem AD security groups.
    #>

    Write-Host "`n[Add User to Groups]" -ForegroundColor Cyan
    $upn    = Read-Host "User UPN or alias"
    $groups = (Read-Host "Groups to add (comma-separated names or emails)") -split ',' | ForEach-Object { $_.Trim() }

    foreach ($g in $groups) {
        Write-Host "  Processing group: $g" -ForegroundColor DarkGray
        try {
            Add-DistributionGroupMember -Identity $g -Member $upn -ErrorAction Stop
            Write-Host "  ✓ Added to EXO group: $g" -ForegroundColor Green
        } catch {
            Write-Warning "  EXO group '$g' not found or already a member. Trying AD…"
            if (Get-Module -Name ActiveDirectory) {
                try {
                    Add-ADGroupMember -Identity $g -Members $upn -ErrorAction Stop
                    Write-Host "  ✓ Added to AD group: $g" -ForegroundColor Green
                } catch {
                    Write-Warning "  AD group '$g' also not found or error: $_"
                }
            }
        }
    }
}

# ── Create Shared Mailbox ─────────────────────────────────────────────────────

function Invoke-CreateSharedMailbox {
    <#
    .SYNOPSIS
        Creates a new shared mailbox and optionally grants delegate access.

    .DESCRIPTION
        Provisions a shared mailbox in Exchange Online, then allows the operator
        to grant FullAccess and SendAs permissions to one or more users.
    #>

    Write-Host "`n[Create Shared Mailbox]" -ForegroundColor Cyan
    $displayName = Read-Host "Display name (e.g. IT Helpdesk)"
    $alias       = Read-Host "Alias (e.g. it-helpdesk)"
    $smtpAddress = Read-Host "Primary SMTP address (e.g. it-helpdesk@contoso.com)"

    $confirm = Read-Host "Create shared mailbox '$displayName' <$smtpAddress>? [Y/N]"
    if ($confirm -ne 'Y') { return }

    New-Mailbox -Shared -Name $displayName -Alias $alias -PrimarySmtpAddress $smtpAddress
    Write-Host "  ✓ Shared mailbox created: $smtpAddress" -ForegroundColor Green

    # Delegates
    $addDelegates = Read-Host "Grant access to delegates now? [Y/N]"
    if ($addDelegates -ne 'Y') { return }

    $delegateList = (Read-Host "Delegates (comma-separated UPNs)") -split ',' | ForEach-Object { $_.Trim() }

    foreach ($delegate in $delegateList) {
        Add-MailboxPermission   -Identity $smtpAddress -User $delegate -AccessRights FullAccess -InheritanceType All -AutoMapping $true
        Add-RecipientPermission -Identity $smtpAddress -Trustee $delegate -AccessRights SendAs -Confirm:$false
        Write-Host "  ✓ FullAccess + SendAs granted to $delegate." -ForegroundColor Green
    }
}

# ── User Offboarding ──────────────────────────────────────────────────────────

function Invoke-UserOffboarding {
    <#
    .SYNOPSIS
        Performs standard offboarding steps for a departing user.

    .DESCRIPTION
        Offboarding checklist (each step confirmed before applying):
          1. Disable AD account
          2. Reset password to a random value
          3. Revoke all active M365 sessions (invalidate refresh tokens)
          4. Block sign-in in Entra ID / MSOL
          5. Convert mailbox to shared (preserve data, release license)
          6. Hide mailbox from the Global Address List
          7. Remove from all distribution groups

    .PARAMETER SkipAD
        Skip Active Directory steps (disable account, reset password).
    #>

    [CmdletBinding()]
    param([switch]$SkipAD)

    Write-Host "`n[User Offboarding]" -ForegroundColor Cyan
    Write-Host "  ⚠  This will make changes to the user account. Proceed carefully." -ForegroundColor Red

    $upn = Read-Host "User UPN to offboard"

    # 1. Disable AD account
    if (-not $SkipAD -and (Get-Module -Name ActiveDirectory)) {
        $samAccount = Read-Host "AD SAM account name (leave blank to skip AD steps)"
        if ($samAccount) {
            $confirm = Read-Host "  Disable AD account '$samAccount'? [Y/N]"
            if ($confirm -eq 'Y') {
                Disable-ADAccount -Identity $samAccount
                Write-Host "  ✓ AD account disabled." -ForegroundColor Green
            }

            # 2. Reset AD password
            $confirm = Read-Host "  Reset AD password to a random value? [Y/N]"
            if ($confirm -eq 'Y') {
                $randomPass = [System.Web.Security.Membership]::GeneratePassword(20, 4)
                $securePass = ConvertTo-SecureString $randomPass -AsPlainText -Force
                Set-ADAccountPassword -Identity $samAccount -NewPassword $securePass -Reset
                Write-Host "  ✓ AD password reset (value not stored)." -ForegroundColor Green
            }
        }
    }

    # 3. Revoke M365 sessions
    if (Get-Module -ListAvailable -Name MSOnline) {
        if (-not (Get-MsolDomain -ErrorAction SilentlyContinue)) { Connect-MsolService }

        $confirm = Read-Host "  Revoke all active M365 sessions for $upn? [Y/N]"
        if ($confirm -eq 'Y') {
            Revoke-MsolUserAllRefreshToken -UserPrincipalName $upn
            Write-Host "  ✓ All refresh tokens revoked." -ForegroundColor Green
        }

        # 4. Block sign-in
        $confirm = Read-Host "  Block M365 sign-in for $upn? [Y/N]"
        if ($confirm -eq 'Y') {
            Set-MsolUser -UserPrincipalName $upn -BlockCredential $true
            Write-Host "  ✓ Sign-in blocked." -ForegroundColor Green
        }
    } else {
        Write-Warning "MSOnline module not found — skipping session revocation and sign-in block."
    }

    # 5. Convert mailbox to shared
    $confirm = Read-Host "  Convert mailbox to Shared (preserves data, releases license)? [Y/N]"
    if ($confirm -eq 'Y') {
        Set-Mailbox -Identity $upn -Type Shared
        Write-Host "  ✓ Mailbox converted to Shared." -ForegroundColor Green
    }

    # 6. Hide from GAL
    $confirm = Read-Host "  Hide mailbox from Global Address List? [Y/N]"
    if ($confirm -eq 'Y') {
        Set-Mailbox -Identity $upn -HiddenFromAddressListsEnabled $true
        Write-Host "  ✓ Mailbox hidden from GAL." -ForegroundColor Green
    }

    # 7. Remove from distribution groups
    $confirm = Read-Host "  Remove from all distribution groups? [Y/N]"
    if ($confirm -eq 'Y') {
        $groups = Get-DistributionGroup -ResultSize Unlimited |
                  Where-Object { (Get-DistributionGroupMember -Identity $_.PrimarySmtpAddress -ResultSize Unlimited).PrimarySmtpAddress -contains $upn }

        foreach ($g in $groups) {
            Remove-DistributionGroupMember -Identity $g.PrimarySmtpAddress -Member $upn -Confirm:$false
            Write-Host "  ✓ Removed from: $($g.DisplayName)" -ForegroundColor Green
        }

        if (-not $groups) {
            Write-Host "  — No distribution group memberships found." -ForegroundColor DarkGray
        }
    }

    Write-Host "`n  Offboarding steps complete for $upn." -ForegroundColor Cyan
    Write-Host "  Reminder: manually review calendar events, shared drives, and license reclamation." -ForegroundColor Yellow
}
