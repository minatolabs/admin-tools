# Windows-only TenantOps

## Overview
This repository contains the `M365-Hybrid-Admin-Tool.ps1`, a PowerShell script designed for Windows environments to help manage Microsoft 365 with hybrid configurations.

## Features
- Seamless integration with Microsoft 365.
- Supports hybrid infrastructure setups.
- Simplifies admin tasks through automation.

## Prerequisites
- Windows OS (Windows 10 or later recommended)
- PowerShell 5.1+ 
- Required modules: `AzureAD`, `MSOnline` (install using `Install-Module` command)

## Usage Instructions
1. Clone the repository:
   ```bash
   git clone https://github.com/minatolabs/admin-tools.git
   cd admin-tools/TenantOps
   ```
2. Open PowerShell with administrative privileges.
3. Execute the script:
   ```powershell
   .\M365-Hybrid-Admin-Tool.ps1
   ```
4. Follow the prompts within the script to execute your desired operations.

### Important Notes
- Ensure you have the necessary permissions in your Azure AD.
- Test the script in a non-production environment to understand its impact before running it in production.

## Contributions
For any issues or feature requests, please open an issue in the GitHub repository. Contributions are welcome!