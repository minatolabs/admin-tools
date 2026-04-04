<#
.SYNOPSIS
    Mailbox delegation and permission management for M365 / hybrid environments.

.DESCRIPTION
    Dot-sourced by M365-Hybrid-Admin-Tool.ps1. Each function is independently
    callable for scripted use.

    Functions:
        Invoke-ListMailboxDelegates        — show FullAccess / SendAs / SendOnBehalf
        Invoke-AddMailboxDelegate          — grant delegate access with permission choice
        Invoke-RemoveMailboxDelegate       — revoke delegate access
        Invoke-CalendarPermissions         — view or set calendar folder permissions
        Invoke-DistributionGroupMembership — list or modify DL / M365 group members
#>

Set-StrictMode -Version Latest

# ── List Delegates ────────────────────────────────────────────────────────────

function Invoke-ListMailboxDelegates {
    <#
    .SYNOPSIS
        Displays FullAccess, SendAs, and SendOnBehalf delegates for a mailbox.
    #>

    Write-Host "`n[List Mailbox Delegates]" -ForegroundColor Cyan
    $mailbox = Read-Host "Mailbox (UPN or alias)"

    Write-Host "`n  ── FullAccess ──────────────────────────" -ForegroundColor DarkYellow
    Get-MailboxPermission -Identity $mailbox |
        Where-Object { $_.User -notlike 'NT AUTHORITY\*' -and $_.IsInherited -eq $false } |
        Select-Object Identity, User, AccessRights |
        Format-Table -AutoSize

    Write-Host "  ── SendAs ──────────────────────────────" -ForegroundColor DarkYellow
    Get-RecipientPermission -Identity $mailbox |
        Where-Object { $_.Trustee -notlike 'NT AUTHORITY\*' } |
        Select-Object Identity, Trustee, AccessRights |
        Format-Table -AutoSize

    Write-Host "  ── SendOnBehalf ────────────────────────" -ForegroundColor DarkYellow
    (Get-Mailbox -Identity $mailbox).GrantSendOnBehalfTo |
        ForEach-Object { [PSCustomObject]@{ GrantedTo = $_ } } |
        Format-Table -AutoSize
}

# ── Add Delegate ──────────────────────────────────────────────────────────────

function Invoke-AddMailboxDelegate {
    <#
    .SYNOPSIS
        Grants FullAccess, SendAs, or SendOnBehalf to a delegate user.

    .DESCRIPTION
        Prompts for mailbox, delegate, and permission type. Performs a dry-run
        confirmation before applying the change.
    #>

    Write-Host "`n[Add Mailbox Delegate]" -ForegroundColor Cyan
    $mailbox   = Read-Host "Target mailbox (UPN or alias)"
    $delegate  = Read-Host "Delegate user (UPN or alias)"

    Write-Host "  Permission types:"
    Write-Host "    1  FullAccess (open the mailbox)"
    Write-Host "    2  SendAs (send as the mailbox)"
    Write-Host "    3  SendOnBehalf (send on behalf of)"
    $permChoice = Read-Host "Select permission type [1/2/3]"

    switch ($permChoice) {
        '1' {
            Write-Host "  → Granting FullAccess to $delegate on $mailbox" -ForegroundColor Yellow
            $confirm = Read-Host "Confirm? [Y/N]"
            if ($confirm -eq 'Y') {
                Add-MailboxPermission -Identity $mailbox -User $delegate -AccessRights FullAccess -InheritanceType All -AutoMapping $true
                Write-Host "  ✓ FullAccess granted." -ForegroundColor Green
            }
        }
        '2' {
            Write-Host "  → Granting SendAs to $delegate on $mailbox" -ForegroundColor Yellow
            $confirm = Read-Host "Confirm? [Y/N]"
            if ($confirm -eq 'Y') {
                Add-RecipientPermission -Identity $mailbox -Trustee $delegate -AccessRights SendAs -Confirm:$false
                Write-Host "  ✓ SendAs granted." -ForegroundColor Green
            }
        }
        '3' {
            Write-Host "  → Granting SendOnBehalf to $delegate on $mailbox" -ForegroundColor Yellow
            $confirm = Read-Host "Confirm? [Y/N]"
            if ($confirm -eq 'Y') {
                Set-Mailbox -Identity $mailbox -GrantSendOnBehalfTo @{Add = $delegate}
                Write-Host "  ✓ SendOnBehalf granted." -ForegroundColor Green
            }
        }
        default { Write-Warning "Invalid selection — no changes made." }
    }
}

# ── Remove Delegate ───────────────────────────────────────────────────────────

function Invoke-RemoveMailboxDelegate {
    <#
    .SYNOPSIS
        Revokes FullAccess, SendAs, or SendOnBehalf from a delegate user.
    #>

    Write-Host "`n[Remove Mailbox Delegate]" -ForegroundColor Cyan
    $mailbox  = Read-Host "Target mailbox (UPN or alias)"
    $delegate = Read-Host "Delegate user to remove (UPN or alias)"

    Write-Host "  Permission to remove:"
    Write-Host "    1  FullAccess"
    Write-Host "    2  SendAs"
    Write-Host "    3  SendOnBehalf"
    $permChoice = Read-Host "Select [1/2/3]"

    switch ($permChoice) {
        '1' {
            $confirm = Read-Host "Remove FullAccess for $delegate from $mailbox? [Y/N]"
            if ($confirm -eq 'Y') {
                Remove-MailboxPermission -Identity $mailbox -User $delegate -AccessRights FullAccess -Confirm:$false
                Write-Host "  ✓ FullAccess removed." -ForegroundColor Green
            }
        }
        '2' {
            $confirm = Read-Host "Remove SendAs for $delegate from $mailbox? [Y/N]"
            if ($confirm -eq 'Y') {
                Remove-RecipientPermission -Identity $mailbox -Trustee $delegate -AccessRights SendAs -Confirm:$false
                Write-Host "  ✓ SendAs removed." -ForegroundColor Green
            }
        }
        '3' {
            $confirm = Read-Host "Remove SendOnBehalf for $delegate from $mailbox? [Y/N]"
            if ($confirm -eq 'Y') {
                Set-Mailbox -Identity $mailbox -GrantSendOnBehalfTo @{Remove = $delegate}
                Write-Host "  ✓ SendOnBehalf removed." -ForegroundColor Green
            }
        }
        default { Write-Warning "Invalid selection — no changes made." }
    }
}

# ── Calendar Permissions ──────────────────────────────────────────────────────

function Invoke-CalendarPermissions {
    <#
    .SYNOPSIS
        Views or sets calendar folder permissions for a mailbox.

    .DESCRIPTION
        Lists current calendar permissions and optionally sets a new permission
        level for a specified user (or the Default / Anonymous role).

        Common permission roles: Owner, PublishingEditor, Editor, PublishingAuthor,
        Author, NonEditingAuthor, Reviewer, Contributor, AvailabilityOnly, LimitedDetails, None
    #>

    Write-Host "`n[Calendar Permissions]" -ForegroundColor Cyan
    $mailbox = Read-Host "Mailbox (UPN or alias)"

    # Try common calendar folder name variants
    $calFolder = "$mailbox`:\Calendar"
    try {
        $perms = Get-MailboxFolderPermission -Identity $calFolder -ErrorAction Stop
    } catch {
        $calFolder = "$mailbox`:\calendar"
        $perms = Get-MailboxFolderPermission -Identity $calFolder -ErrorAction SilentlyContinue
    }

    if (-not $perms) {
        Write-Warning "Could not retrieve calendar permissions for $mailbox. Check the mailbox identity and try again."
        return
    }

    Write-Host "`n  Current calendar permissions:" -ForegroundColor White
    $perms | Select-Object User, AccessRights | Format-Table -AutoSize

    $modify = Read-Host "Modify a permission? [Y/N]"
    if ($modify -ne 'Y') { return }

    $targetUser  = Read-Host "User to modify (UPN, 'Default', or 'Anonymous')"
    Write-Host "  Available roles: Owner | PublishingEditor | Editor | Author | Reviewer | AvailabilityOnly | LimitedDetails | None"
    $role = Read-Host "New permission role"

    $existing = $perms | Where-Object { $_.User -like $targetUser }
    if ($existing) {
        Set-MailboxFolderPermission -Identity $calFolder -User $targetUser -AccessRights $role
        Write-Host "  ✓ Updated '$targetUser' to '$role'." -ForegroundColor Green
    } else {
        Add-MailboxFolderPermission -Identity $calFolder -User $targetUser -AccessRights $role
        Write-Host "  ✓ Added '$targetUser' with role '$role'." -ForegroundColor Green
    }
}

# ── Distribution Group Membership ────────────────────────────────────────────

function Invoke-DistributionGroupMembership {
    <#
    .SYNOPSIS
        Lists or modifies membership of a distribution group or M365 group.

    .DESCRIPTION
        Supports view, add-member, and remove-member operations on any
        mail-enabled group (distribution lists, mail-enabled security groups,
        and Microsoft 365 groups).
    #>

    Write-Host "`n[Distribution Group Membership]" -ForegroundColor Cyan
    $group = Read-Host "Group name or email address"

    Write-Host "  Actions:"
    Write-Host "    1  List current members"
    Write-Host "    2  Add a member"
    Write-Host "    3  Remove a member"
    $action = Read-Host "Select [1/2/3]"

    switch ($action) {
        '1' {
            Write-Host "`n  Members of $group`:" -ForegroundColor White
            Get-DistributionGroupMember -Identity $group -ResultSize Unlimited |
                Select-Object Name, PrimarySmtpAddress, RecipientType |
                Sort-Object Name |
                Format-Table -AutoSize
        }
        '2' {
            $member  = Read-Host "Member to add (UPN or alias)"
            $confirm = Read-Host "Add $member to $group? [Y/N]"
            if ($confirm -eq 'Y') {
                Add-DistributionGroupMember -Identity $group -Member $member
                Write-Host "  ✓ $member added to $group." -ForegroundColor Green
            }
        }
        '3' {
            $member  = Read-Host "Member to remove (UPN or alias)"
            $confirm = Read-Host "Remove $member from $group? [Y/N]"
            if ($confirm -eq 'Y') {
                Remove-DistributionGroupMember -Identity $group -Member $member -Confirm:$false
                Write-Host "  ✓ $member removed from $group." -ForegroundColor Green
            }
        }
        default { Write-Warning "Invalid selection — no changes made." }
    }
}
