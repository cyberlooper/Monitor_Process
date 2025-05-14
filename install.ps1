#Requires -RunAsAdministrator
#Requires -PSEdition Core
#requires -version 7.5

# Installer script for Monitor_Process

$destDir = "C:\Windows\scripts"
$srcDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Ensure destination directory exists
if (-not (Test-Path $destDir)) {
    New-Item -ItemType Directory -Path $destDir -Force
}

# Copy the two folders from 'packages'
$packageFolders = Get-ChildItem -Path "$srcDir\packages" -Directory
foreach ($folder in $packageFolders) {
    Copy-Item -Path $folder.FullName -Destination $destDir -Recurse -Force -passthru
}

# Copy the main script
Copy-Item -Path "$srcDir\Monitor_Process.ps1" -Destination $destDir -Force

# Create a scheduled task to run Monitor_Process.ps1 at startup as SYSTEM
$taskName = "Monitor_Process"
$taskPath = "$destDir\Monitor_Process.ps1"
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$taskPath`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest

# Register the scheduled task
try {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
} catch {}
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal

Write-Host "Monitor_Process and dependencies installed to $destDir"
Write-Host "Scheduled task '$taskName' created to run at startup as SYSTEM."
Start-process "Monitor_Process" -passthru

