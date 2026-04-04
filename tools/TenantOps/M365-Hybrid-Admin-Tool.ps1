#requires -Version 5.1
<#
M365 Hybrid Admin Tool (AD-first) - Compliance Always ON
Testing build: StrictMode disabled to avoid param-binding issues in some hosts.

Run (unsigned testing):
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\M365-Hybrid-Admin-Tool.ps1

Show version:
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\M365-Hybrid-Admin-Tool.ps1 -ShowVersion
#>

$ErrorActionPreference = "Stop"

param(
    [switch]$ShowVersion
)

# -----------------------------
# Version metadata
# -----------------------------
$script:AppName    = "M365 Hybrid Admin Tool"
$script:AppVersion = "0.3.3-test"
$script:BuildDate  = "2026-02-20"

function Get-VersionInfo {
    "$($script:AppName) v$($script:AppVersion) ($($script:BuildDate))"
}

if ($ShowVersion) {
    Get-VersionInfo
    exit 0
}

# -----------------------------
# Compliance (always ON)
# -----------------------------
$script:ToolRoot = Join-Path $env:ProgramData "M365HybridAdminTool"
$script:LogDir   = Join-Path $script:ToolRoot "Logs"
New-Item -Path $script:LogDir -ItemType Directory -Force | Out-Null

$script:CorrelationId  = [guid]::NewGuid().ToString()
$script:AuditLogPath   = Join-Path $script:LogDir ("Audit-{0:yyyy-MM-dd}.jsonl" -f (Get-Date))
$script:TranscriptPath = Join-Path $script:LogDir ("Transcript-{0:yyyy-MM-dd_HHmmss}.txt" -f (Get-Date))

function Write-AuditEvent {
    param(
        [Parameter(Mandatory)] [string] $Action,
        [Parameter()] [hashtable] $Data = @{},
        [Parameter()] [ValidateSet("Success","Failure","Info")] [string] $Result = "Info"
    )

    $evt = [ordered]@{
        timestamp_utc  = (Get-Date).ToUniversalTime().ToString("o")
        correlation_id = $script:CorrelationId
        operator       = "$env:USERDOMAIN\$env:USERNAME"
        computer       = $env:COMPUTERNAME
        action         = $Action
        result         = $Result
        data           = $Data
    }

    ($evt | ConvertTo-Json -Depth 6 -Compress) | Add-Content -Path $script:AuditLogPath -Encoding UTF8
}

Start-Transcript -Path $script:TranscriptPath -Append | Out-Null
Write-AuditEvent -Action "ToolStart" -Result "Info" -Data @{
    version    = $script:AppVersion
    build_date = $script:BuildDate
    ps_version = $PSVersionTable.PSVersion.ToString()
}

# -----------------------------
# UI / Theme
# -----------------------------
function Set-AppTheme {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Magenta"
    Clear-Host
}

function Write-Header([string]$Text) {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ("  " + $Text) -ForegroundColor Magenta
    Write-Host "==================================================" -ForegroundColor Magenta
    Write-Host ""
}

function Write-AppBanner {
    Write-Header ("{0}  |  CorrelationId: {1}" -f (Get-VersionInfo), $script:CorrelationId)
}

# -----------------------------
# Input helpers / validation
# -----------------------------
function Read-NonEmpty([string]$Prompt) {
    while ($true) {
        $v = Read-Host $Prompt
        if (-not [string]::IsNullOrWhiteSpace($v)) { return $v.Trim() }
        Write-Host "Value cannot be empty. Try again." -ForegroundColor Magenta
    }
}

function Test-LooksLikeUpn([string]$Value) {
    return ($Value -match '^[^@\s]+@[^@\s]+\.[^@\s]+$')
}

function Read-Upn([string]$Prompt) {
    while ($true) {
        $v = Read-NonEmpty $Prompt
        if (Test-LooksLikeUpn $v) { return $v }
        Write-Host "That doesn't look like an email/UPN. Try again." -ForegroundColor Magenta
    }
}

function Read-YesNo([string]$Prompt, [bool]$DefaultNo = $true) {
    $suffix = " (y/N)"
    if (-not $DefaultNo) { $suffix = " (Y/n)" }

    $v = Read-Host ($Prompt + $suffix)
    if ([string]::IsNullOrWhiteSpace($v)) {
        if ($DefaultNo) { return $false } else { return $true }
    }
    return ($v -match '^(y|yes)$')
}

function Read-ListInput {
    param([Parameter(Mandatory)][string]$Prompt)

    Write-Host ""
    Write-Host $Prompt -ForegroundColor Magenta
    Write-Host "Paste comma/newline-separated values. Submit an empty line to finish." -ForegroundColor Magenta

    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        $line = Read-Host
        if ([string]::IsNullOrWhiteSpace($line)) { break }
        $lines.Add($line)
    }

    $raw = ($lines -join "`n")
    $items =
        $raw -split "[,`r`n]+" |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }

    $items | Select-Object -Unique
}

# -----------------------------
# Module helpers
# -----------------------------
function Ensure-PSGalleryModule([string]$Name) {
    if (-not (Get-Module -ListAvailable -Name $Name)) {
        Write-Host "Module '$Name' not found. Installing..." -ForegroundColor Magenta
        Write-AuditEvent -Action "InstallModule" -Result "Info" -Data @{ module = $Name }
        Install-Module $Name -Scope CurrentUser -Force -AllowClobber
    }
    Import-Module $Name -Force
}

function Ensure-ADModule {
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        throw "ActiveDirectory module not found. Install RSAT: 'RSAT: Active Directory Domain Services and Lightweight Directory Services Tools'."
    }
    Import-Module ActiveDirectory -Force
}

# -----------------------------
# Diagnostics / prerequisites
# -----------------------------
function Test-Prereqs {
    Set-AppTheme
    Write-AppBanner
    Write-Header "Diagnostics / Prerequisites"

    $items = New-Object System.Collections.Generic.List[object]
    $items.Add([pscustomobject]@{ Check="PowerShellVersion"; Status=$PSVersionTable.PSVersion.ToString(); Pass=$true })

    $adMod = [bool](Get-Module -ListAvailable -Name ActiveDirectory)
    $adStatus = "Missing"
    if ($adMod) { $adStatus = "Present" }
    $items.Add([pscustomobject]@{ Check="ActiveDirectoryModule (RSAT)"; Status=$adStatus; Pass=$adMod })

    $exoMod = [bool](Get-Module -ListAvailable -Name ExchangeOnlineManagement)
    $exoStatus = "Missing (will auto-install)"
    if ($exoMod) { $exoStatus = "Present" }
    $items.Add([pscustomobject]@{ Check="ExchangeOnlineManagement"; Status=$exoStatus; Pass=$true })

    $graphMod = [bool](Get-Module -ListAvailable -Name Microsoft.Graph)
    $graphStatus = "Missing (optional, auto-install)"
    if ($graphMod) { $graphStatus = "Present" }
    $items.Add([pscustomobject]@{ Check="Microsoft.Graph"; Status=$graphStatus; Pass=$true })

    $adsync = [bool](Get-Module -ListAvailable -Name ADSync)
    $adsyncStatus = "Missing (optional)"
    if ($adsync) { $adsyncStatus = "Present" }
    $items.Add([pscustomobject]@{ Check="ADSync module (AAD Connect server only)"; Status=$adsyncStatus; Pass=$true })

    $items | Format-Table -AutoSize

    Write-Host ""
    Write-Host "Logs:" -ForegroundColor Magenta
    Write-Host " - Transcript: $script:TranscriptPath" -ForegroundColor Magenta
    Write-Host " - Audit JSONL: $script:AuditLogPath" -ForegroundColor Magenta

    Write-AuditEvent -Action "DiagnosticsRun" -Result "Info" -Data @{
        has_ad_module     = $adMod
        has_exo_module    = $exoMod
        has_graph_module  = $graphMod
        has_adsync_module = $adsync
    }

    Read-Host "Press Enter to return" | Out-Null
}

# -----------------------------
# Cloud connections
# -----------------------------
$script:ConnectedEXO = $false
$script:ConnectedGraph = $false

function Connect-CloudSessions {
    Write-Header "Connect Cloud Sessions"
    $adminUpn = Read-Upn "Enter admin account UPN (email) to connect with"

    try {
        Ensure-PSGalleryModule "ExchangeOnlineManagement"
        Write-Host "Connecting to Exchange Online..." -ForegroundColor Magenta
        Connect-ExchangeOnline -UserPrincipalName $adminUpn -ShowBanner:$false
        $script:ConnectedEXO = $true
        Write-AuditEvent -Action "ConnectExchangeOnline" -Result "Success" -Data @{ admin_upn = $adminUpn }
    } catch {
        Write-AuditEvent -Action "ConnectExchangeOnline" -Result "Failure" -Data @{ admin_upn = $adminUpn; error = $_.Exception.Message }
        throw
    }

    if (Read-YesNo "Connect Microsoft Graph too?" $true) {
        Ensure-PSGalleryModule "Microsoft.Graph"
        $scopes = @("User.ReadWrite.All","Group.ReadWrite.All","Directory.ReadWrite.All")
        try {
            Write-Host "Connecting to Microsoft Graph..." -ForegroundColor Magenta
            Connect-MgGraph -Scopes $scopes | Out-Null
            $script:ConnectedGraph = $true
            Write-AuditEvent -Action "ConnectMgGraph" -Result "Success" -Data @{ admin_upn = $adminUpn; scopes = ($scopes -join ",") }
        } catch {
            Write-AuditEvent -Action "ConnectMgGraph" -Result "Failure" -Data @{ admin_upn = $adminUpn; error = $_.Exception.Message }
            throw
        }
    }
}

function Disconnect-CloudSessions {
    if ($script:ConnectedEXO) {
        Disconnect-ExchangeOnline -Confirm:$false
        $script:ConnectedEXO = $false
        Write-AuditEvent -Action "DisconnectExchangeOnline" -Result "Success"
    }
    if ($script:ConnectedGraph) {
        Disconnect-MgGraph | Out-Null
        $script:ConnectedGraph = $false
        Write-AuditEvent -Action "DisconnectMgGraph" -Result "Success"
    }
}

function Require-EXO {
    if (-not $script:ConnectedEXO) {
        Write-Host "Not connected to Exchange Online. Connecting now..." -ForegroundColor Magenta
        Connect-CloudSessions
    }
}

# -----------------------------
# Hybrid AD helpers
# -----------------------------
function Select-ADOrganizationalUnit {
    Ensure-ADModule
    Write-Header "Select OU"

    $base = Read-Host "Optional: enter a search base DN (or press Enter for whole domain)"
    if ([string]::IsNullOrWhiteSpace($base)) {
        $ous = Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName | Sort-Object DistinguishedName
    } else {
        $ous = Get-ADOrganizationalUnit -Filter * -SearchBase $base -Properties DistinguishedName | Sort-Object DistinguishedName
    }

    if (-not $ous -or $ous.Count -eq 0) { throw "No OUs found (check permissions/search base)." }

    $i = 1
    foreach ($ou in $ous) {
        Write-Host ("{0,3}) {1}" -f $i, $ou.DistinguishedName) -ForegroundColor Magenta
        $i++
    }

    while ($true) {
        $sel = Read-Host "Choose OU number (1-$($ous.Count))"
        if ($sel -as [int] -and $sel -ge 1 -and $sel -le $ous.Count) { return $ous[$sel-1].DistinguishedName }
        Write-Host "Invalid selection." -ForegroundColor Magenta
    }
}

function Invoke-AADConnectDeltaSync {
    Write-Header "AAD Connect Delta Sync (Optional)"
    if (-not (Read-YesNo "Start delta sync now? (requires ADSync module on this machine)" $true)) { return }

    if (-not (Get-Module -ListAvailable -Name ADSync)) {
        Write-Host "ADSync module not found on this machine. Run on AAD Connect server or use remoting." -ForegroundColor Magenta
        Write-AuditEvent -Action "StartADSyncSyncCycle" -Result "Failure" -Data @{ reason = "ADSync module missing" }
        return
    }

    Import-Module ADSync -Force
    Start-ADSyncSyncCycle -PolicyType Delta | Out-Null
    Write-Host "Delta sync started." -ForegroundColor Magenta
    Write-AuditEvent -Action "StartADSyncSyncCycle" -Result "Success" -Data @{ policy = "Delta" }
}

function Onboard-UserHybrid {
    Ensure-ADModule
    Write-Header "Onboard User (Hybrid AD-first)"

    $targetOU = Select-ADOrganizationalUnit
    $givenName = Read-NonEmpty "First name"
    $sn        = Read-NonEmpty "Last name"
    $sam       = Read-NonEmpty "sAMAccountName"
    $upn       = Read-Upn "UserPrincipalName (email/UPN)"
    $display   = "$givenName $sn"
    $pwd       = Read-Host "Temporary password" -AsSecureString

    if (-not (Read-YesNo "Create AD user '$upn' in selected OU?" $true)) { return }

    try {
        New-ADUser -Name $display -GivenName $givenName -Surname $sn -DisplayName $display `
            -SamAccountName $sam -UserPrincipalName $upn -AccountPassword $pwd -Enabled $true -Path $targetOU

        Write-Host "AD user created: $upn" -ForegroundColor Magenta
        Write-AuditEvent -Action "NewADUser" -Result "Success" -Data @{ upn = $upn; sam = $sam; ou = $targetOU }
    } catch {
        Write-AuditEvent -Action "NewADUser" -Result "Failure" -Data @{ upn = $upn; sam = $sam; ou = $targetOU; error = $_.Exception.Message }
        throw
    }

    if (Read-YesNo "Add this user to AD groups now?" $true) {
        while ($true) {
            $g = Read-Host "Enter AD group (name/DN) or blank to finish"
            if ([string]::IsNullOrWhiteSpace($g)) { break }
            try {
                Add-ADGroupMember -Identity $g -Members $sam
                Write-Host "Added to group: $g" -ForegroundColor Magenta
                Write-AuditEvent -Action "AddADGroupMember" -Result "Success" -Data @{ group = $g; member = $sam }
            } catch {
                Write-Host "Failed to add to group: $($_.Exception.Message)" -ForegroundColor Magenta
                Write-AuditEvent -Action "AddADGroupMember" -Result "Failure" -Data @{ group = $g; member = $sam; error = $_.Exception.Message }
            }
        }
    }

    Invoke-AADConnectDeltaSync
    Read-Host "Press Enter to return" | Out-Null
}

function Offboard-UserHybrid {
    Ensure-ADModule
    Write-Header "Offboard User (Hybrid AD-first)"

    $identity = Read-NonEmpty "User to offboard (sAMAccountName or UPN)"
    $user = Get-ADUser -Identity $identity -Properties DistinguishedName,Enabled,UserPrincipalName,SamAccountName
    Write-Host "Found: $($user.DistinguishedName)" -ForegroundColor Magenta

    if (Read-YesNo "Disable this AD account now?" $true) {
        Disable-ADAccount -Identity $user
        Write-Host "Account disabled." -ForegroundColor Magenta
        Write-AuditEvent -Action "DisableADAccount" -Result "Success" -Data @{ identity = $identity }
    }

    if (Read-YesNo "Move user to a different OU (e.g., Disabled Users OU)?" $true) {
        $disabledOU = Select-ADOrganizationalUnit
        Move-ADObject -Identity $user.DistinguishedName -TargetPath $disabledOU
        Write-Host "Moved to: $disabledOU" -ForegroundColor Magenta
        Write-AuditEvent -Action "MoveADObject" -Result "Success" -Data @{ identity = $identity; target_ou = $disabledOU }
    }

    Invoke-AADConnectDeltaSync
    Read-Host "Press Enter to return" | Out-Null
}

# -----------------------------
# Exchange Online recipient checks
# -----------------------------
function Assert-RecipientExists {
    param(
        [Parameter(Mandatory)] [string] $Upn,
        [Parameter(Mandatory)] [ValidateSet("Mailbox","Delegate")] [string] $Type
    )

    try {
        $null = Get-Recipient -Identity $Upn -ErrorAction Stop
        return $true
    } catch {
        Write-Host "$Type '$Upn' was not found in Exchange Online (or not synced yet)." -ForegroundColor Magenta
        Write-AuditEvent -Action "RecipientNotFound" -Result "Info" -Data @{ type = $Type; upn = $Upn }
        return $false
    }
}

# -----------------------------
# Mailbox permissions core ops
# -----------------------------
function Grant-FullAccessToMailbox {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)
    Add-MailboxPermission -Identity $Mailbox -User $Delegate -AccessRights FullAccess -InheritanceType All -AutoMapping $true
    Write-Host "Granted FullAccess: $Delegate -> $Mailbox" -ForegroundColor Magenta
    Write-AuditEvent -Action "GrantFullAccess" -Result "Success" -Data @{ mailbox = $Mailbox; delegate = $Delegate }
}

function Grant-SendAsToMailbox {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)
    Add-RecipientPermission -Identity $Mailbox -Trustee $Delegate -AccessRights SendAs -Confirm:$false
    Write-Host "Granted SendAs: $Delegate -> $Mailbox" -ForegroundColor Magenta
    Write-AuditEvent -Action "GrantSendAs" -Result "Success" -Data @{ mailbox = $Mailbox; delegate = $Delegate }
}

function Grant-SendOnBehalfToMailbox {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)

    $mbx = Get-Mailbox -Identity $Mailbox
    $current = @($mbx.GrantSendOnBehalfTo)
    if ($current -notcontains $Delegate) {
        Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo ($current + $Delegate)
        Write-Host "Granted SendOnBehalf: $Delegate -> $Mailbox" -ForegroundColor Magenta
        Write-AuditEvent -Action "GrantSendOnBehalf" -Result "Success" -Data @{ mailbox = $Mailbox; delegate = $Delegate }
    } else {
        Write-Host "SendOnBehalf already present. No change." -ForegroundColor Magenta
        Write-AuditEvent -Action "GrantSendOnBehalf" -Result "Info" -Data @{ mailbox = $Mailbox; delegate = $Delegate; note = "AlreadyPresent" }
    }
}

function Remove-FullAccessFromMailbox {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)
    Remove-MailboxPermission -Identity $Mailbox -User $Delegate -AccessRights FullAccess -InheritanceType All -Confirm:$false
    Write-Host "Removed FullAccess: $Delegate -> $Mailbox" -ForegroundColor Magenta
    Write-AuditEvent -Action "RemoveFullAccess" -Result "Success" -Data @{ mailbox = $Mailbox; delegate = $Delegate }
}

function Remove-SendAsFromMailbox {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)
    Remove-RecipientPermission -Identity $Mailbox -Trustee $Delegate -AccessRights SendAs -Confirm:$false
    Write-Host "Removed SendAs: $Delegate -> $Mailbox" -ForegroundColor Magenta
    Write-AuditEvent -Action "RemoveSendAs" -Result "Success" -Data @{ mailbox = $Mailbox; delegate = $Delegate }
}

function Remove-SendOnBehalfFromMailbox {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)

    $mbx = Get-Mailbox -Identity $Mailbox
    $current = @($mbx.GrantSendOnBehalfTo) | ForEach-Object { $_.ToString() }
    $updated = $current | Where-Object { $_ -ne $Delegate }

    if ($updated.Count -ne $current.Count) {
        Set-Mailbox -Identity $Mailbox -GrantSendOnBehalfTo $updated
        Write-Host "Removed SendOnBehalf: $Delegate -> $Mailbox" -ForegroundColor Magenta
        Write-AuditEvent -Action "RemoveSendOnBehalf" -Result "Success" -Data @{ mailbox = $Mailbox; delegate = $Delegate }
    } else {
        Write-Host "SendOnBehalf: delegate not present. No change." -ForegroundColor Magenta
        Write-AuditEvent -Action "RemoveSendOnBehalf" -Result "Info" -Data @{ mailbox = $Mailbox; delegate = $Delegate; note = "NotPresent" }
    }
}

function Remove-AllMailboxDelegation {
    param([Parameter(Mandatory)] [string]$Mailbox, [Parameter(Mandatory)] [string]$Delegate)

    $results = [ordered]@{}

    try { Remove-FullAccessFromMailbox -Mailbox $Mailbox -Delegate $Delegate; $results.fullAccess = "Removed" }
    catch { $results.fullAccess = "NotFoundOrFailed: $($_.Exception.Message)" }

    try { Remove-SendAsFromMailbox -Mailbox $Mailbox -Delegate $Delegate; $results.sendAs = "Removed" }
    catch { $results.sendAs = "NotFoundOrFailed: $($_.Exception.Message)" }

    try { Remove-SendOnBehalfFromMailbox -Mailbox $Mailbox -Delegate $Delegate; $results.sendOnBehalf = "RemovedOrNotPresent" }
    catch { $results.sendOnBehalf = "Failed: $($_.Exception.Message)" }

    Write-Host "Remove ALL results:" -ForegroundColor Magenta
    $results.GetEnumerator() | ForEach-Object { Write-Host (" - {0}: {1}" -f $_.Key, $_.Value) -ForegroundColor Magenta }

    Write-AuditEvent -Action "RemoveAllDelegatePermissions" -Result "Success" -Data @{
        mailbox  = $Mailbox
        delegate = $Delegate
        results  = $results
    }
}

# -----------------------------
# Mailbox menus (Grant/Remove with bulk support)
# -----------------------------
function Read-MailboxDelegateContext {
    Write-Header "Mailbox Permissions Context"
    Write-Host "1) Single mailbox + single delegate" -ForegroundColor Magenta
    Write-Host "2) Single mailbox + multiple delegates (bulk)" -ForegroundColor Magenta
    Write-Host "3) Multiple mailboxes + single delegate (bulk)" -ForegroundColor Magenta
    Write-Host "4) Back" -ForegroundColor Magenta
    Write-Host ""

    while ($true) {
        $c = Read-Host "Select an option (1-4)"
        switch ($c) {
            "1" {
                $mailbox  = Read-Upn "Mailbox owner UPN (email)"
                $delegate = Read-Upn "Delegate user UPN (email)"
                return @{ mode="single"; mailboxes=@($mailbox); delegates=@($delegate) }
            }
            "2" {
                $mailbox = Read-Upn "Mailbox owner UPN (email)"
                $delegates = Read-ListInput "Enter delegate UPN(s)"
                $delegates = $delegates | Where-Object { Test-LooksLikeUpn $_ }
                if (-not $delegates -or $delegates.Count -eq 0) {
                    Write-Host "No valid delegate UPNs provided." -ForegroundColor Magenta
                    continue
                }
                return @{ mode="mailbox-many-delegates"; mailboxes=@($mailbox); delegates=@($delegates) }
            }
            "3" {
                $delegate = Read-Upn "Delegate user UPN (email)"
                $mailboxes = Read-ListInput "Enter mailbox owner UPN(s)"
                $mailboxes = $mailboxes | Where-Object { Test-LooksLikeUpn $_ }
                if (-not $mailboxes -or $mailboxes.Count -eq 0) {
                    Write-Host "No valid mailbox UPNs provided." -ForegroundColor Magenta
                    continue
                }
                return @{ mode="many-mailboxes-delegate"; mailboxes=@($mailboxes); delegates=@($delegate) }
            }
            "4" { return $null }
            default { Write-Host "Invalid choice." -ForegroundColor Magenta; Start-Sleep 1 }
        }
    }
}

function Invoke-ForEachMailboxDelegate {
    param(
        [Parameter(Mandatory)] [string] $ActionName,
        [Parameter(Mandatory)] [string[]] $Mailboxes,
        [Parameter(Mandatory)] [string[]] $Delegates,
        [Parameter(Mandatory)] [scriptblock] $Operation
    )

    foreach ($m in $Mailboxes) {
        foreach ($d in $Delegates) {
            Write-Host ""
            Write-Host ("Target: mailbox={0}  delegate={1}" -f $m, $d) -ForegroundColor Magenta

            if (-not (Assert-RecipientExists -Upn $m -Type Mailbox)) { continue }
            if (-not (Assert-RecipientExists -Upn $d -Type Delegate)) { continue }

            try {
                & $Operation $m $d
            } catch {
                Write-Host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Magenta
                Write-AuditEvent -Action $ActionName -Result "Failure" -Data @{ mailbox=$m; delegate=$d; error=$_.Exception.Message }
            }
        }
    }
}

function Show-MailboxGrantMenu {
    param([Parameter(Mandatory)] [string[]]$Mailboxes, [Parameter(Mandatory)] [string[]]$Delegates)

    while ($true) {
        Set-AppTheme
        Write-AppBanner
        Write-Header "Mailbox Permissions > Grant"

        Write-Host ("Mailboxes : {0}" -f ($Mailboxes -join ", ")) -ForegroundColor Magenta
        Write-Host ("Delegates : {0}" -f ($Delegates -join ", ")) -ForegroundColor Magenta
        Write-Host ""
        Write-Host "1) Grant Full Access (Read/Manage)" -ForegroundColor Magenta
        Write-Host "2) Grant Send As" -ForegroundColor Magenta
        Write-Host "3) Grant Send on Behalf" -ForegroundColor Magenta
        Write-Host "4) Back" -ForegroundColor Magenta
        Write-Host ""

        $c = Read-Host "Select an option (1-4)"
        switch ($c) {
            "1" {
                Invoke-ForEachMailboxDelegate -ActionName "GrantFullAccess" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                    param($m,$d) Grant-FullAccessToMailbox -Mailbox $m -Delegate $d
                }
                Read-Host "Press Enter" | Out-Null
            }
            "2" {
                Invoke-ForEachMailboxDelegate -ActionName "GrantSendAs" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                    param($m,$d) Grant-SendAsToMailbox -Mailbox $m -Delegate $d
                }
                Read-Host "Press Enter" | Out-Null
            }
            "3" {
                Invoke-ForEachMailboxDelegate -ActionName "GrantSendOnBehalf" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                    param($m,$d) Grant-SendOnBehalfToMailbox -Mailbox $m -Delegate $d
                }
                Read-Host "Press Enter" | Out-Null
            }
            "4" { return }
            default { Write-Host "Invalid choice." -ForegroundColor Magenta; Start-Sleep 1 }
        }
    }
}

function Show-MailboxRemoveMenu {
    param([Parameter(Mandatory)] [string[]]$Mailboxes, [Parameter(Mandatory)] [string[]]$Delegates)

    while ($true) {
        Set-AppTheme
        Write-AppBanner
        Write-Header "Mailbox Permissions > Remove"

        Write-Host ("Mailboxes : {0}" -f ($Mailboxes -join ", ")) -ForegroundColor Magenta
        Write-Host ("Delegates : {0}" -f ($Delegates -join ", ")) -ForegroundColor Magenta
        Write-Host ""
        Write-Host "1) Remove Full Access (Read/Manage)" -ForegroundColor Magenta
        Write-Host "2) Remove Send As" -ForegroundColor Magenta
        Write-Host "3) Remove Send on Behalf" -ForegroundColor Magenta
        Write-Host "4) Remove ALL (FullAccess + SendAs + SendOnBehalf)" -ForegroundColor Magenta
        Write-Host "5) Back" -ForegroundColor Magenta
        Write-Host ""

        $c = Read-Host "Select an option (1-5)"
        switch ($c) {
            "1" {
                Invoke-ForEachMailboxDelegate -ActionName "RemoveFullAccess" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                    param($m,$d) Remove-FullAccessFromMailbox -Mailbox $m -Delegate $d
                }
                Read-Host "Press Enter" | Out-Null
            }
            "2" {
                Invoke-ForEachMailboxDelegate -ActionName "RemoveSendAs" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                    param($m,$d) Remove-SendAsFromMailbox -Mailbox $m -Delegate $d
                }
                Read-Host "Press Enter" | Out-Null
            }
            "3" {
                Invoke-ForEachMailboxDelegate -ActionName "RemoveSendOnBehalf" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                    param($m,$d) Remove-SendOnBehalfFromMailbox -Mailbox $m -Delegate $d
                }
                Read-Host "Press Enter" | Out-Null
            }
            "4" {
                if (Read-YesNo "Confirm REMOVE ALL for all listed targets?" $true) {
                    Invoke-ForEachMailboxDelegate -ActionName "RemoveAllDelegatePermissions" -Mailboxes $Mailboxes -Delegates $Delegates -Operation {
                        param($m,$d) Remove-AllMailboxDelegation -Mailbox $m -Delegate $d
                    }
                }
                Read-Host "Press Enter" | Out-Null
            }
            "5" { return }
            default { Write-Host "Invalid choice." -ForegroundColor Magenta; Start-Sleep 1 }
        }
    }
}

function Show-MailboxPermissionsMenu {
    Require-EXO

    while ($true) {
        Set-AppTheme
        Write-AppBanner
        Write-Header "Mailbox Permissions"

        $ctx = Read-MailboxDelegateContext
        if ($null -eq $ctx) { return }

        while ($true) {
            Set-AppTheme
            Write-AppBanner
            Write-Header "Mailbox Permissions (Context Loaded)"

            Write-Host ("Mode      : {0}" -f $ctx.mode) -ForegroundColor Magenta
            Write-Host ("Mailboxes : {0}" -f ($ctx.mailboxes -join ", ")) -ForegroundColor Magenta
            Write-Host ("Delegates : {0}" -f ($ctx.delegates -join ", ")) -ForegroundColor Magenta
            Write-Host ""
            Write-Host "1) Grant submenu" -ForegroundColor Magenta
            Write-Host "2) Remove submenu" -ForegroundColor Magenta
            Write-Host "3) Change context" -ForegroundColor Magenta
            Write-Host "4) Back to main menu" -ForegroundColor Magenta
            Write-Host ""

            $c = Read-Host "Select an option (1-4)"
            switch ($c) {
                "1" { Show-MailboxGrantMenu -Mailboxes $ctx.mailboxes -Delegates $ctx.delegates }
                "2" { Show-MailboxRemoveMenu -Mailboxes $ctx.mailboxes -Delegates $ctx.delegates }
                "3" { break }
                "4" { return }
                default { Write-Host "Invalid choice." -ForegroundColor Magenta; Start-Sleep 1 }
            }
        }
    }
}

# -----------------------------
# Main menu
# -----------------------------
function Show-MainMenu {
    Set-AppTheme
    Write-AppBanner
    Write-Host "1) Connect to Exchange Online / (optional) Graph" -ForegroundColor Magenta
    Write-Host "2) Onboard user (AD-first)" -ForegroundColor Magenta
    Write-Host "3) Offboard user (AD-first)" -ForegroundColor Magenta
    Write-Host "4) Mailbox permissions (Grant/Remove + Bulk)" -ForegroundColor Magenta
    Write-Host "5) Diagnostics / prerequisites" -ForegroundColor Magenta
    Write-Host "6) Disconnect cloud sessions" -ForegroundColor Magenta
    Write-Host "7) Exit" -ForegroundColor Magenta
    Write-Host ""
}

try {
    while ($true) {
        Show-MainMenu
        $choice = Read-Host "Select an option (1-7)"
        switch ($choice) {
            "1" { Connect-CloudSessions }
            "2" { Onboard-UserHybrid }
            "3" { Offboard-UserHybrid }
            "4" { Show-MailboxPermissionsMenu }
            "5" { Test-Prereqs }
            "6" { Disconnect-CloudSessions; Read-Host "Press Enter" | Out-Null }
            "7" { break }
            default { Write-Host "Invalid choice." -ForegroundColor Magenta; Start-Sleep 1 }
        }
    }
}
catch {
    Write-AuditEvent -Action "UnhandledError" -Result "Failure" -Data @{ error = $_.Exception.Message }
    throw
}
finally {
    Disconnect-CloudSessions
    Write-AuditEvent -Action "ToolExit" -Result "Info"
    try { Stop-Transcript | Out-Null } catch {}
    Write-Host "Exited. Logs: $script:LogDir" -ForegroundColor Magenta
}