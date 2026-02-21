# Tenant Operations

## Path
To navigate to this directory, run:

```bash
cd admin-tools/tools/TenantOps
```

## Prerequisites
Make sure you have the following module installed:

- **ExchangeOnlineManagement** 
To connect to Exchange, use the following command:

```powershell
Connect-ExchangeOnline
```

## Newbie-Friendly Windows Instructions
1. **Installing Git**
   - Download the Git installer from [git-scm.com](https://git-scm.com/downloads) and run it. Follow the installation prompts.
   
2. **Installing PowerShell**
   - If you're using Windows 10 or later, PowerShell comes pre-installed. If not, download PowerShell from the [PowerShell GitHub repository](https://github.com/PowerShell/PowerShell/releases).
   
3. **Setting Execution Policy**  
   - Open PowerShell as an administrator.
   - Run the following command to allow script execution:
   ```powershell
   Set-ExecutionPolicy RemoteSigned
   ```  
   - Confirm your choice if prompted.
  
4. **Installing the ExchangeOnlineManagement Module**
   - Run the following command in PowerShell:
   ```powershell
   Install-Module -Name ExchangeOnlineManagement -Force
   ```  

5. **Running the Script**  
   - After completing the previous steps, you can run the script as follows:
   ```powershell
   .\YourScriptName.ps1 -TenantId 'your-tenant-id'
   ```  
   - Replace `YourScriptName.ps1` with the actual name of your script and provide the appropriate Tenant ID.
  
   
Feel free to reach out if you encounter any issues!