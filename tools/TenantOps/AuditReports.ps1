<#
.SYNOPSIS
    Audit reporting functions for M365 / hybrid environments.

.DESCRIPTION
    Dot-sourced by M365-Hybrid-Admin-Tool.ps1. Each function is independently
    callable for scripted / scheduled use.

    Functions:
        Invoke-MailboxAccessAudit    — non-owner mailbox access events (EXO audit log)
        Invoke-AdminRoleReport       — current admin role assignments across all roles
        Invoke-MFAComplianceReport   — per-user MFA registration state
        Invoke-LicenseReport         — SKU totals + per-user assignments
#>

Set-StrictMode -Version Latest

# ── Helpers ───────────────────────────────────────────────────────────────────

function Export-CsvReport {
    <#
    .SYNOPSIS Saves $Data to a CSV and prints the path. Returns the path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object[]]$Data,
        [Parameter(Mandatory)] [string]$BaseName
    )
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $outPath   = Join-Path $env:TEMP "$BaseName`_$timestamp.csv"
    $Data | Export-Csv -Path $outPath -NoTypeInformation -Encoding UTF8
    Write-Host "  Report saved → $outPath" -ForegroundColor Green
    return $outPath
}

# ── Mailbox Access Audit ──────────────────────────────────────────────────────

function Invoke-MailboxAccessAudit {
    <#
    .SYNOPSIS
        Reports non-owner mailbox access events from the EXO unified audit log.

    .DESCRIPTION
        Searches the Exchange Online unified audit log for MailboxLogin and
        FolderBind operations performed by accounts other than the mailbox owner.
        Results are written to the console and exported to CSV.
    #>

    Write-Host "`n[Mailbox Access Audit]" -ForegroundColor Cyan

    $targetMailbox = Read-Host "Mailbox to audit (UPN or leave blank for all)"
    $daysBack      = Read-Host "How many days back to search? [default: 7]"
    if ([string]::IsNullOrWhiteSpace($daysBack)) { $daysBack = 7 }
    $daysBack = [int]$daysBack

    $startDate = (Get-Date).AddDays(-$daysBack)
    $endDate   = Get-Date

    Write-Host "  Searching unified audit log ($daysBack day(s))…" -ForegroundColor DarkGray

    $searchParams = @{
        StartDate   = $startDate
        EndDate     = $endDate
        Operations  = 'MailboxLogin','FolderBind'
        ResultSize  = 5000
    }
    if ($targetMailbox) {
        $searchParams['ObjectIds'] = $targetMailbox
    }

    $rawResults = Search-UnifiedAuditLog @searchParams

    if (-not $rawResults) {
        Write-Host "  No non-owner access events found in this window." -ForegroundColor Yellow
        return
    }

    $report = foreach ($entry in $rawResults) {
        $data = $entry.AuditData | ConvertFrom-Json
        [PSCustomObject]@{
            Timestamp       = $entry.CreationDate
            Operation       = $entry.Operations
            Mailbox         = $data.MailboxOwnerUPN
            AccessedBy      = $data.UserId
            ClientIP        = $data.ClientIPAddress
            LogonType       = $data.LogonType
            ResultStatus    = $data.ResultStatus
        }
    }

    # Exclude pure owner access (logon type 0 = owner)
    $nonOwner = $report | Where-Object { $_.LogonType -ne 0 -and $_.AccessedBy -ne $_.Mailbox }

    if (-not $nonOwner) {
        Write-Host "  No non-owner access events after filtering." -ForegroundColor Yellow
        return
    }

    $nonOwner | Format-Table -AutoSize
    Export-CsvReport -Data $nonOwner -BaseName 'MailboxAccessAudit'
}

# ── Admin Role Report ─────────────────────────────────────────────────────────

function Invoke-AdminRoleReport {
    <#
    .SYNOPSIS
        Lists all users assigned to each Exchange admin role group.

    .DESCRIPTION
        Iterates every role group in the Exchange Online organization and emits
        a flat list of (RoleGroup, Member, MemberType) for easy review.
    #>

    Write-Host "`n[Admin Role Assignments]" -ForegroundColor Cyan
    Write-Host "  Retrieving role groups…" -ForegroundColor DarkGray

    $roleGroups = Get-RoleGroup -ResultSize Unlimited

    $report = foreach ($group in $roleGroups) {
        $members = Get-RoleGroupMember -Identity $group.Name -ResultSize Unlimited
        foreach ($member in $members) {
            [PSCustomObject]@{
                RoleGroup  = $group.Name
                Member     = $member.Name
                Alias      = $member.Alias
                RecipType  = $member.RecipientType
            }
        }
    }

    if (-not $report) {
        Write-Host "  No role group members found." -ForegroundColor Yellow
        return
    }

    $report | Sort-Object RoleGroup, Member | Format-Table -AutoSize
    Export-CsvReport -Data $report -BaseName 'AdminRoleReport'
}

# ── MFA Compliance Report ─────────────────────────────────────────────────────

function Invoke-MFAComplianceReport {
    <#
    .SYNOPSIS
        Reports per-user MFA registration status.

    .DESCRIPTION
        Uses Get-MsolUser (MSOL module) when available; falls back to a
        credential-state summary via Get-ExoMailbox strong-auth properties.
        Flags accounts with no MFA method registered.
    #>

    Write-Host "`n[MFA Compliance Report]" -ForegroundColor Cyan

    $msolAvailable = Get-Module -ListAvailable -Name MSOnline

    if ($msolAvailable) {
        Write-Host "  Using MSOnline module for MFA data…" -ForegroundColor DarkGray

        if (-not (Get-MsolDomain -ErrorAction SilentlyContinue)) {
            Connect-MsolService
        }

        $users  = Get-MsolUser -All
        $report = foreach ($user in $users) {
            $mfaMethods = $user.StrongAuthenticationMethods
            [PSCustomObject]@{
                UserPrincipalName   = $user.UserPrincipalName
                DisplayName         = $user.DisplayName
                IsLicensed          = $user.IsLicensed
                MFAEnabled          = ($mfaMethods.Count -gt 0)
                DefaultMFAMethod    = ($mfaMethods | Where-Object IsDefault).MethodType
                AllMFAMethods       = ($mfaMethods.MethodType -join ', ')
                BlockCredential     = $user.BlockCredential
            }
        }
    } else {
        Write-Host "  MSOnline module not found — reporting from EXO mailbox data…" -ForegroundColor Yellow

        $mailboxes = Get-ExoMailbox -ResultSize Unlimited -Properties UserPrincipalName, DisplayName
        $report = foreach ($mb in $mailboxes) {
            [PSCustomObject]@{
                UserPrincipalName = $mb.UserPrincipalName
                DisplayName       = $mb.DisplayName
                Note              = 'Install MSOnline module for full MFA detail'
            }
        }
    }

    if (-not $report) {
        Write-Host "  No user data returned." -ForegroundColor Yellow
        return
    }

    # Highlight non-MFA users in console
    if ($msolAvailable) {
        $noMfa = $report | Where-Object { -not $_.MFAEnabled -and $_.IsLicensed }
        if ($noMfa) {
            Write-Host "`n  ⚠ Licensed users with NO MFA registered:" -ForegroundColor Red
            $noMfa | Format-Table UserPrincipalName, DisplayName -AutoSize
        } else {
            Write-Host "  ✓ All licensed users have MFA registered." -ForegroundColor Green
        }
    }

    $report | Format-Table -AutoSize
    Export-CsvReport -Data $report -BaseName 'MFAComplianceReport'
}

# ── License Report ────────────────────────────────────────────────────────────

function Invoke-LicenseReport {
    <#
    .SYNOPSIS
        Summarises M365 license usage (SKU totals) and per-user assignments.

    .DESCRIPTION
        Requires the MSOnline module. Exports two CSVs: a SKU summary and a
        per-user license detail report.
    #>

    Write-Host "`n[License Report]" -ForegroundColor Cyan

    if (-not (Get-Module -ListAvailable -Name MSOnline)) {
        Write-Warning "MSOnline module required. Run: Install-Module MSOnline -Scope CurrentUser"
        return
    }

    if (-not (Get-MsolDomain -ErrorAction SilentlyContinue)) {
        Connect-MsolService
    }

    # SKU summary
    Write-Host "  Retrieving license SKUs…" -ForegroundColor DarkGray
    $skus = Get-MsolAccountSku
    $skuSummary = $skus | Select-Object @{N='SKU';E={$_.SkuPartNumber}},
                                         @{N='Total';E={$_.ActiveUnits}},
                                         @{N='Assigned';E={$_.ConsumedUnits}},
                                         @{N='Available';E={$_.ActiveUnits - $_.ConsumedUnits}}

    Write-Host "`n  License SKU summary:" -ForegroundColor White
    $skuSummary | Format-Table -AutoSize
    Export-CsvReport -Data $skuSummary -BaseName 'LicenseSKUSummary'

    # Per-user detail
    Write-Host "  Retrieving per-user license data (this may take a moment)…" -ForegroundColor DarkGray
    $users = Get-MsolUser -All

    $userDetail = foreach ($user in $users) {
        [PSCustomObject]@{
            UserPrincipalName = $user.UserPrincipalName
            DisplayName       = $user.DisplayName
            IsLicensed        = $user.IsLicensed
            Licenses          = ($user.Licenses.AccountSkuId -join ', ')
            UsageLocation     = $user.UsageLocation
            Department        = $user.Department
        }
    }

    Export-CsvReport -Data $userDetail -BaseName 'LicenseUserDetail'
}
