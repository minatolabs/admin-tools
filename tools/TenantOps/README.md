# Hybrid AD/Entra Guidance

This section provides guidance for running scripts in a hybrid environment with Active Directory and Microsoft Entra.

## Running Scripts on Domain-Joined Laptops

The scripts can be executed on domain-joined laptops. Ensure that you have the necessary permissions to run these scripts.

## RSAT Active Directory Module Installation Steps

To install the RSAT Active Directory module:  
1. Open PowerShell as an administrator.  
2. Run the following command:  
   ```powershell  
   Add-WindowsCapability -Name RSAT.ActiveDirectory.DS-LDS.Tools~~~0.0.1.0 -Online  
   ```
3. Wait for the installation to complete.

## Running the Command

To run the command, use the following:  
```powershell  
Set-ExecutionPolicy -ExecutionPolicy CurrentUser  
.\M365-Hybrid-Admin-Tool.ps1  
``` 

Ensure that the execution policy is set to allow scripts to run as the current user, and replace the path to the script if necessary.