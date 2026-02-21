# TenantOps (Windows)

**TenantOps** is a collection of PowerShell scripts designed to streamline administrative tasks within Microsoft 365 environments, particularly focusing on hybrid configurations involving both on-premises and cloud services. This guide will walk you through the prerequisites, installation steps, and provide examples of how to run the scripts properly.

## Prerequisites

Before using TenantOps, ensure you have the following installed:

- **RSAT Active Directory Tools**: These are needed for managing your Active Directory from a remote machine.
- **Exchange Online Management Module**: This module is necessary for managing Exchange Online environments.

## Installation Steps

1. **Clone the Repository**: Start by cloning the repository to your local machine.
   ```bash
   git clone https://github.com/minatolabs/admin-tools.git
   ```

2. **Navigate to the Directory**: Change to the TenantOps directory.
   ```bash
   cd admin-tools/tools/TenantOps
   ```

3. **Run the Scripts**: You can execute the PowerShell scripts using the following command for unsigned scripts:
   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "M365-Hybrid-Admin-Tool.ps1"
   ```

## Invocation Example

To run the main script, ensure you are in the correct directory and run the following command:
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "M365-Hybrid-Admin-Tool.ps1"
```

This will execute the primary script of the TenantOps suite, allowing you to perform administrative tasks with ease.

## Conclusion

With TenantOps, you can effectively manage your hybrid environment by following the steps outlined in this document. Ensure that you meet all prerequisites and carefully follow the execution commands for a smooth experience.