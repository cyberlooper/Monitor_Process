# Load MimeKit and MailKit if not already loaded

if ((test-path c:\windows\scripts) -eq $false) {
        if ((test-path c:\windows\scripts\packages) -eq $false) {
            write-host "No packages directory found. Run install.ps1 as admin first" 
        }
    }
if (-not ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match 'MimeKit' })) {
    try {
        
    Add-Type -Path "$($psscriptroot)\packages\mimekit\3.5.0\lib\netstandard2.0\MimeKit.dll"
    }
    catch {
        write-host Error loading
        write-host $_.Exception
    }
}

if (-not ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match 'MailKit' })) {
    try {
    Add-Type -Path "$($psscriptroot)\packages\mailkit\3.5.0\lib\netstandard2.0\MailKit.dll"
    }
    catch {
        write-host Error loading
        write-host $_.Exception
    }
}

# Services to watch (Add in the format below)
$servicesToWatch = @{
    "wuauserv"  = "Windows Update"
    "Spooler"   = "Print Spooler"
    "WinDefend" = "Microsoft Defender Antivirus"
}

# SMTP Settings
$smtpServer = "" # Required
$smtpPort = "" # Required
$smtpUser = "" # Required
$smtpPass = "" # Required
$smtpFrom = "" # Required
$smtpTo = "" # Required

function Send-ServiceChangeEmail {
    param (
        [string]$ServiceName,
        [string]$OldState,
        [string]$NewState,
        [datetime]$Timestamp,
        [string]$EventLogText
    )

    $subject = "Service '$($servicesToWatch[$ServiceName])' changed: $OldState ➜ $NewState"
    $body = @"
Name: $($servicesToWatch[$ServiceName])
State: Changed from $OldState ➜ $NewState
Time: $Timestamp
Service: $ServiceName
Old State: $OldState
New State: $NewState

Recent Event Log Entries:
$EventLogText
"@

    $message = New-Object MimeKit.MimeMessage
    $message.From.Add([MimeKit.MailboxAddress]::Parse($smtpFrom))
    $message.To.Add([MimeKit.MailboxAddress]::Parse($smtpTo))
    $message.Subject = $subject

    $builder = New-Object MimeKit.BodyBuilder
    $builder.TextBody = $body
    $message.Body = $builder.ToMessageBody()

    $client = New-Object MailKit.Net.Smtp.SmtpClient
    $client.Connect($smtpServer, $smtpPort, [MailKit.Security.SecureSocketOptions]::StartTls)
    $client.Authenticate($smtpUser, $smtpPass)
    $client.Send($message)
    $client.Disconnect($true)
    $client.Dispose()
}

# Initialize service state tracking
$lastStates = @{}
foreach ($svcName in $servicesToWatch.keys) {
    try {
        $lastStates[$svcName] = (Get-Service -Name $svcName).Status
    } catch {
        $lastStates[$svcName] = "Unknown"
    }
}

Write-Host "Polling service status... Press Ctrl+C to stop."

try {
    while ($true) {
        foreach ($svcName in $servicesToWatch.keys) {
            try {
                $currentStatus = (Get-Service -Name $svcName).Status
                if ($lastStates[$svcName] -ne $currentStatus) {
                    $timestamp = Get-Date

                    # Get last 5 event log entries for this service from System log
                    $eventLogs = Get-WinEvent -LogName System -MaxEvents 20 |
                        Where-Object { $_.Message -match $svcName } |
                        Select-Object -First 5

                    $eventLogText = if ($eventLogs) {
                        $eventLogs | ForEach-Object {
                            "[$($_.TimeCreated)] $($_.Id): $($_.Message)"
                        } | Out-String
                    } else {
                        "No recent event log entries found for $svcName."
                    }

                    Write-Host "[$timestamp] $svcName changed: $($lastStates[$svcName]) ➜ $currentStatus"
                    Send-ServiceChangeEmail -ServiceName $svcName -OldState $lastStates[$svcName] -NewState $currentStatus -Timestamp $timestamp -EventLogText $eventLogText
                    $lastStates[$svcName] = $currentStatus
                }
            } catch {
                Write-Warning "Failed to check status for $($svcName): $_"
            }
        }
        Start-Sleep -Seconds 1
    }
} catch {
    Write-Error "Monitoring stopped due to error: $($_)"
}
