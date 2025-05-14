#Requires -PSEdition Core
#requires -version 7.5



# Services to watch (Add in the format below) The service name needs to be exact, the name you give it after `=` can be anything you want
$servicesToWatch = @{
    "wuauserv"  = "Windows Update"
    "Spooler"   = "Print Spooler"
    "WinDefend" = "Microsoft Defender Antivirus"
}

# SMTP Settings > Check with your email provider. This assumes SSL is required based on the port provided
$smtpServer = "" # Required
$smtpPort = "" # Required
$smtpUser = "" # Required
$smtpPass = "" # Required
$smtpFrom = "" # Required
$smtpTo = "" # Required

<# DO NOT CHANGE ANYTHIN PAST THIS LINE#>

# Load MimeKit and MailKit if not already loaded

if ((test-path c:\windows\scripts) -eq $false) { # Test if the package directory exists. if not, most likely that install was not run.
        if ((test-path c:\windows\scripts\packages) -eq $false) {
            write-host "No packages directory found. Run install.ps1 as admin first" 
        }
    }

if (-not ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match 'MimeKit' })) {
    try {
        
    Add-Type -Path "$($psscriptroot)\packages\mimekit\3.5.0\lib\netstandard2.0\MimeKit.dll" #This loads the assembly into the system so the script can use it in scope
    }
    catch {
        write-host Error loading
        write-host $_.Exception
    }
}

if (-not ([AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.FullName -match 'MailKit' })) { #Same as above
    try {
    Add-Type -Path "$($psscriptroot)\packages\mailkit\3.5.0\lib\netstandard2.0\MailKit.dll"
    }
    catch {
        write-host Error loading
        write-host $_.Exception
    }
}

#Function to create SMTP connection, structure email, and send with response.
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

# Initialize service state tracking. Key to make sure that a flood does not occur for services that are not running at script start.
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
    while ($true) { #When the end of the block is reached, it will return to the top. $True will always be $true, so this is an infinite loop
        foreach ($svcName in $servicesToWatch.keys) { #For each service in the list specified...
            try { #Run the following in a try/catch block for error capture
                $currentStatus = (Get-Service -Name $svcName).Status #pull the current status directly from service control....
                if ($lastStates[$svcName] -ne $currentStatus) { #If the service state made at at script start doesnt equal the current state... go to indent
                    $timestamp = Get-Date #Get the time it happened

                    # Get last 5 event log entries for this service from System log
                    $eventLogs = Get-WinEvent -LogName System -MaxEvents 20 |
                        Where-Object { $_.Message -match $svcName } |
                        Select-Object -First 5

                    #Create email secment struction of last 5 event log entries for context if available
                    $eventLogText = if ($eventLogs) {
                        $eventLogs | ForEach-Object {
                            "[$($_.TimeCreated)] $($_.Id): $($_.Message)"
                        } | Out-String
                    } else {
                        "No recent event log entries found for $svcName."
                    }

                    Write-Host "[$timestamp] $svcName changed: $($lastStates[$svcName]) ➜ $currentStatus" #Write state to console (Wont be visible as a running task, but here for debugging)
                    Send-ServiceChangeEmail -ServiceName $svcName -OldState $lastStates[$svcName] -NewState $currentStatus -Timestamp $timestamp -EventLogText $eventLogText #Send contextual email
                    $lastStates[$svcName] = $currentStatus #Update the last state variable with the change
                }
            } catch { #catch errors and write to console
                Write-Warning "Failed to check status for $($svcName): $_"
            } #end of second try/catch
        } #end of foreach
        Start-Sleep -Seconds 1
    } #end of while block
} catch { #catch and output errors
    Write-Error "Monitoring stopped due to error: $($_)"
} #End of first try/catch block
