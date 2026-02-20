param(
    [string]$TenantId = $null
)

# Connect to Exchange Online
Connect-ExchangeOnline -TenantId $TenantId

# Your logic for the Hybrid Admin Tool goes here

# Disconnect afterwards
Disconnect-ExchangeOnline -Confirm:$false
