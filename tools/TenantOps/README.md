# Tenant Operations

## Quick Run Commands

To run scripts, use the following command structure in PowerShell:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Path\To\Your\Script.ps1"
```

## First-Time Setup Steps
1. Install the required modules:
   - Run: `Install-Module -Name ExchangeOnlineManagement`
   - If you need RSAT for Active Directory, install it via Windows Features.
2. Authenticate to Microsoft Exchange:
   - Use `Connect-ExchangeOnline -UserPrincipalName your_username@domain.com`

## Prerequisites
- **ExchangeOnlineManagement**: Ensure that you have this module installed. Use the command mentioned in setup steps.
- **Optional**: RSAT Active Directory can be installed for managing AD features.

## Common Fixes
1. **Connection Issues**: Ensure your credentials are correct and that you have the necessary permissions.
2. **Execution Policy**: If you encounter execution policy errors, run the command: `Set-ExecutionPolicy RemoteSigned`.

## Safety Rules
- Always backup your data before performing bulk operations.
- Test scripts in a non-production environment before deployment.

## Roadmap
- 2026 Q2: Implement new features for user management.
- 2026 Q3: Enhance documentation and add more examples.
- 2026 Q4: Review feedback and improve the toolkit based on user experience.