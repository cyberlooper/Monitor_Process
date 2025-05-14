# Monitor_Process

Monitor and manage Windows server processes using PowerShell.

## Features

- List running processes on a Windows server
- Monitor specific processes for uptime and resource usage
- Send alerts or notifications if a process stops or exceeds resource limits
- Generate logs and reports for process activity

## Requirements

- Windows Server (any recent version)
- [Powershell 7.5 or Later](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5)

## Install
1. Clone this repository.
2. Open PowerShell and navigate to the project directory.
3. Run install.sh as Administrator

   ### install Steps
   The script will perform the following:
   - Copy the Monitor_Process script to C:\Windows\scripts
   - Copy the supporting packages to the same folder
   - Create a scheduled task to run on boot as system

## Usage

1. Run the script:

   ```powershell
   .\Monitor_Process.ps
   ```

   In Monitor_process.ps1 locate the SMTP block and fill in your required details
   ```
   # SMTP Settings
   $smtpServer = "" # Required
   $smtpPort = "" # Required
   $smtpUser = "" # Required
   $smtpPass = "" # Required
   $smtpFrom = "" # Required
   $smtpTo = "" # Required
   ```

   Additionally locate the 'Services to watch' block and add the service names needed.
   ```
   # Services to watch (Add in the format below)
   $servicesToWatch = @{
      "wuauserv"  = "Windows Update"
      "Spooler"   = "Print Spooler"
      "WinDefend" = "Microsoft Defender Antivirus"
   }
   ```