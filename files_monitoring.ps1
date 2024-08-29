function Push_to_datuum {
    param (
        [string]$Path,
        [string]$FileName
    )

    $cleanName = $FileName.Replace(".gdx", "")
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    
    # Define the headers
    $headers = @{
        'accept' = 'application/json'
        'X-Project' = $Global:project
        'Authorization' = $global:auth
    }

    $form = @{
        "file" = Get-Item -Path $Path
        "scenario" = $cleanName
        "timestamp" = $timestamp
    }

    Log_Action "Starting upload of $FileName to Datuum"

    $response = Invoke-WebRequest -Uri "https://esmia.datuum.ai/api/cartographer/v1/command/esmia/gdx/upload" `
        -Method Post `
        -Headers $headers `
        -ContentType "multipart/form-data" `
        -Form $form

    switch ($response.StatusCode) {
        200 {
            Write-Host "Success: " $response.Content
            Log_Action "SUCCESS: Uploaded $FileName - Response: $($response.Content)"
        }
        201 {
            Write-Host "Created: " $response.Content
            Log_Action "CREATED: Uploaded $FileName - Response: $($response.Content)"
        }
        204 {
            Write-Host "No Content: The request was successful but there is no representation to return."
            Log_Action "SUCCESS with NO CONTENT: Uploaded $FileName"
        }
        400 {
            Write-Host "Bad Request: " $response.Content
            Log_Action "FAILURE: Bad request while uploading $FileName - Response: $($response.Content)"
        }
        401 {
            Write-Host "Unauthorized: Check your credentials and try again."
            Log_Action "FAILURE: Unauthorized access while uploading $FileName"
        }
        403 {
            Write-Host "Forbidden: You do not have permission to access this resource."
            Log_Action "FAILURE: Forbidden access while uploading $FileName"
        }
        404 {
            Write-Host "Not Found: The requested resource could not be found."
            Log_Action "FAILURE: Resource not found while uploading $FileName"
        }
        500 {
            Write-Host "Internal Server Error: " $response.Content
            Log_Action "ERROR: Internal server error while uploading $FileName - Response: $($response.Content)"
        }
        502 {
            Write-Host "Bad Gateway: Invalid responses from another server/proxy."
            Log_Action "ERROR: Bad gateway while uploading $FileName"
        }
        503 {
            Write-Host "Service Unavailable: The server is currently unable to handle the request."
            Log_Action "ERROR: Service unavailable while uploading $FileName"
        }
        default {
            Write-Host "Unexpected response ($($response.StatusCode)): " $response.Content
            Log_Action "ERROR: Unexpected response while uploading $FileName - Response: $($response.Content)"
        }
    }
}

 
function Delete_from_datuum {
    param (
        [string]$Path,
        [string]$FileName
    )

    $cleanName = $FileName.Replace(".gdx", "")

    # Define the headers
    $headers = @{
        'accept' = 'application/json'
        'X-Project' = $Global:project
        'Authorization' = $global:auth
    }

    $url = "https://esmia.datuum.ai/api/cartographer/v1/command/esmia/gdx/remove/$cleanName"

    Log_Action "Attempting to delete $FileName from Datuum"

    $response = Invoke-RestMethod -Uri $url -Method Put -Headers $headers
            Write-Host  $response.Content
            Log_Action "Deleted $FileName - Response: $response"

    
}


function files_monitor {
    $Path = "C:\Users\AntoineDuplantie-Gre\OneDrive - esmia.ca\Desktop\POWERSHELL\Scenarios"
    $FileFilter = "*.gdx"
    $IncludeSubfolders = $false
    $AttributeFilter = [IO.NotifyFilters]::FileName, [IO.NotifyFilters]::LastWrite 

    try {
        $watcher = New-Object -TypeName System.IO.FileSystemWatcher -Property @{
            Path = $Path
            Filter = $FileFilter
            IncludeSubdirectories = $IncludeSubfolders
            NotifyFilter = $AttributeFilter
        }

        $action = {
            $details = $event.SourceEventArgs
            $Name = $details.Name
            $FullPath = $details.FullPath
            $ChangeType = $details.ChangeType
            $Timestamp = $event.TimeGenerated

            $text = "{0} was {1} at {2}" -f $FullPath, $ChangeType, $Timestamp
            Write-Host ""
            Write-Host $text -ForegroundColor DarkYellow
            Log_Action $text  # Log each file change event

            switch ($ChangeType) {
                'Changed'  {
                    Log_Action "CHANGE: $FullPath"
                    "CHANGE"
                }
                'Created'  {
                    Write-Host "This file will be pushed to Datuum"
                    Write-Host "Job started Handler Start" -ForegroundColor Gray
                    Write-Host "Creation Handler Start" -ForegroundColor Gray
                    Log_Action "CREATED: Starting push to Datuum for $FullPath"
                    Invoke-Command -ScriptBlock {
                        param($FullPath, $Name)
                        Push_to_datuum -Path $FullPath -FileName $Name
                    } -ArgumentList $FullPath, $Name

                }
                'Deleted'  {
                    "DELETED"
                    Write-Host "Deletion Handler Start" -ForegroundColor Gray
                    Log_Action "DELETED: Initiating deletion for $FullPath"
                    Invoke-Command -ScriptBlock {
                        param($FullPath, $Name)
                        Delete_from_datuum -Path $FullPath -FileName $Name
                    } -ArgumentList $FullPath, $Name
                }
                'Renamed'  {
                    $OldName = $details.OldName
                    $text = "File {0} was renamed to {1}" -f $OldName, $Name
                    Write-Host $text -ForegroundColor Yellow
                    Log_Action "RENAMED: $OldName to $Name"
                }
                default   { 
                    Write-Host $_ -ForegroundColor Red -BackgroundColor White 
                    Log_Action "ERROR: Unknown Change Type $_ for $FullPath"
                }
            }
        }

        $handlers = . {
            Register-ObjectEvent -InputObject $watcher -EventName Changed  -Action $action 
            Register-ObjectEvent -InputObject $watcher -EventName Created  -Action $action 
            Register-ObjectEvent -InputObject $watcher -EventName Deleted  -Action $action 
            Register-ObjectEvent -InputObject $watcher -EventName Renamed  -Action $action 
        }

        $watcher.EnableRaisingEvents = $true
        Write-Host "Watching for changes to $Path"
        Log_Action "Monitoring started for path: $Path"

        do {
            Wait-Event -Timeout 2
            Write-Host "." -NoNewline
        } while ($true)

    } finally {
        $watcher.EnableRaisingEvents = $false
        $handlers | ForEach-Object {
            Unregister-Event -SourceIdentifier $_.Name
        }
        $handlers | Remove-Job
        $watcher.Dispose()
        Write-Warning "Event Handler disabled, monitoring ends."
        Log_Action "Monitoring disabled for path: $Path"
    }
}

function Log_Action($message) {
    $currentDirectory = Get-Location
    $LogFilePath = "$currentDirectory\ActivityLog.log"  # Log file named 'ActivityLog.log' in the current directory
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$($timestamp): $message"
    Add-Content -Path $LogFilePath -Value $logEntry
}


function Get-ProjectID {
    param(
        [string]$defaultID   # Default value for the project ID
    )

    Write-Host 'You are starting a watcher that will upload to Datuum any new .gdx files in the directory. You should not play manually with files in the directory'

    $Project_id = Read-Host "Enter the ID of the project you are working ON"
    if ([string]::IsNullOrWhiteSpace($Project_id)) {
        $Project_id = $defaultID
        Write-Host "No ID was entered. Using default ID: $Project_id"
    } else {
        Write-Host "The entered project ID is: $Project_id"
    }

    return $Project_id
}

function Get-ApiData {
    param (
        [string]$apiUrl = 'https://esmia.datuum.ai/api/cartographer/v1/query/om/list'
    )

    # Using global variables for project key and bearer token
    

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("X-Project", $Global:project)
    $headers.Add("Accept", "application/json")
    $headers.Add("Authorization", $Global:auth)

    $response = Invoke-RestMethod -Uri $apiUrl -Method 'GET' -Headers $headers
    $global:ApiResponse = $response | ConvertTo-Json -Depth 5
    
    # Pretty print the response for easy reading
    $formattedData = $response | Format-List id, name, @{n='SourceID';e={$_.source.id}}, @{n='SourceName';e={$_.source.name}}, @{n='TargetID';e={$_.target.id}}, @{n='TargetName';e={$_.target.name}}, project, label, created, updated, origin 
    Write-Output "Project Information:"
    Write-Output $formattedData

    return $formattedData
}





Function main{

$global:project = Get-ProjectID -defaultID "66b27353256cf952a3150057"
$global:auth =  'Bearer eyJraWQiOiJkZWZhdWx0IiwidHlwIjoiSldUIiwiYWxnIjoiUlM1MTIifQ.eyJzdWIiOiJhbnRvaW5lQGVzbWlhLmNhIiwicHJvdmlkZXIiOiJtaWNyb3NvZnQiLCJpc3MiOiJEYXR1dW0uYWkiLCJuYW1lIjoiQW50b2luZSBEdXBsYW50aWUtR3JlbmllciIsImV4cCI6MTcyNTU3MTk3OSwiaWF0IjoxNzIyODkzNTc5LCJlbWFpbCI6ImFudG9pbmVAZXNtaWEuY2EifQ.l3-G5sLVftcINQYJi1wya7lIK55VIhveGDeZLp2kYMzMzB_YVBAhH6UXQzFTU-9uMsJ5WYgvN5sS1yG-JDMXaw3jLzYp9tTde2FkwWkCv0Fj6fm_2vjDCo6sCMWSE9AXwBAfwo6by4Sie45QKCvhydUjZkRr7dCSqxtMLoCNRIVAfYSVvfnkHSF_DpANAf9DZ2YzrYRmbStHmsYq8hTL8VUvjt9jadsEgR5KYWN-uxxLRVh26nzaFiQwSWV__aO5rym6eyMBt8tNhND2kwuR3IrQbfx5L3NRX02DM-901Y1OU0XIegYqnAEcSwtGPmQUzW7EtWzGeK65tjsjojHc-g'


files_monitor 



}

main


$wsUrl = 'wss://esmia-r1.datuum.ai/ws/cartographer/v1/task-service?token=eyJraWQiOiJkZWZhdWx0IiwiYWxnIjoiUlM1MTIiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJEYXR1dW0uYWkiLCJpYXQiOjE3MjM1NjE5MzIsImV4cCI6MTcyNjI0MDMzMiwic3ViIjoiYW50b2luZUBlc21pYS5jYSIsImVtYWlsIjoiYW50b2luZUBlc21pYS5jYSIsIm5hbWUiOiJBbnRvaW5lIER1cGxhbnRpZS1HcmVuaWVyIiwicHJvdmlkZXIiOiJtaWNyb3NvZnQifQ.MJAWWLlcXDoL_oInx1_G8ntO86F2VwXK6d4XOepfhtrKKUpiK2wiUQL8MV7iBYmM2l7mdFYWpzrvkMMesNF3dm1ND5pQz7QX6ccik_O0r1Zn9eUO-e1XaOcAwObu_AZ0iv7SgP4S3xU6EM0wki_e3TsAVSrnbyPQGY1tG7XiB3rvBBk2oUa-gk95Rh8TdKaG7wRmzcGp734N0zn_2KmiPcF5MrJ5W5s01tmuKEoAKBSD6oGmBIIcCRTmjmxpr6yW6UXnXEW6rgA7ZIVF0yVcnRsGBxn1xmjToGNP_29tkErPKHr8oCoj7Gg_Ytj_LBa0Idk1jp1MTQQd7q4K6HSZ7g&project=66b27353256cf952a3150057'
Start-WebSocketConnection -Url $wsUrl


function Start-WebSocketConnection {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $client_id = [System.GUID]::NewGuid()

    $recv_queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[String]'
    $send_queue = New-Object 'System.Collections.Concurrent.ConcurrentQueue[String]'

    $ws = New-Object Net.WebSockets.ClientWebSocket
    $cts = New-Object Threading.CancellationTokenSource
    $ct = [Threading.CancellationToken]::new($false)

    Write-Output "Connecting..."
    $connectTask = $ws.ConnectAsync("$Url/$client_id", $cts.Token)
    do { Sleep(1) }
    until ($connectTask.IsCompleted)
    Write-Output "Connected!"

    $recv_job = {
        param($ws, $client_id, $recv_queue)

        $buffer = [Net.WebSockets.WebSocket]::CreateClientBuffer(1024,1024)
        $ct = [Threading.CancellationToken]::new($false)
        $taskResult = $null

        while ($ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
            $jsonResult = ""
            do {
                $taskResult = $ws.ReceiveAsync($buffer, $ct)
                while (-not $taskResult.IsCompleted -and $ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
                    [Threading.Thread]::Sleep(10)
                }

                $jsonResult += [Text.Encoding]::UTF8.GetString($buffer, 0, $taskResult.Result.Count)
            } until (
                $ws.State -ne [Net.WebSockets.WebSocketState]::Open -or $taskResult.Result.EndOfMessage
            )

            if (-not [string]::IsNullOrEmpty($jsonResult)) {
                $recv_queue.Enqueue($jsonResult)
            }
        }
    }

    $send_job = {
        param($ws, $client_id, $send_queue)

        $ct = [Threading.CancellationToken]::new($false)
        $workitem = $null
        while ($ws.State -eq [Net.WebSockets.WebSocketState]::Open) {
            if ($send_queue.TryDequeue([ref] $workitem)) {
                [ArraySegment[byte]]$msg = [Text.Encoding]::UTF8.GetBytes($workitem)
                $ws.SendAsync(
                    $msg,
                    [System.Net.WebSockets.WebSocketMessageType]::Binary,
                    $true,
                    $ct
                ).GetAwaiter().GetResult() | Out-Null
            }
        }
    }

    Write-Output "Starting recv runspace"
    $recv_runspace = [PowerShell]::Create()
    $recv_runspace.AddScript($recv_job).
        AddParameter("ws", $ws).
        AddParameter("client_id", $client_id).
        AddParameter("recv_queue", $recv_queue).BeginInvoke() | Out-Null

    Write-Output "Starting send runspace"
    $send_runspace = [PowerShell]::Create()
    $send_runspace.AddScript($send_job).
        AddParameter("ws", $ws).
        AddParameter("client_id", $client_id).
        AddParameter("send_queue", $send_queue).BeginInvoke() | Out-Null

    try {
        do {
            $msg = $null
            while ($recv_queue.TryDequeue([ref] $msg)) {
                Write-Output "Processed message: $msg"

                $hash = @{
                    ClientID = $client_id
                    Payload = "Wat"
                }

                $test_payload = New-Object PSObject -Property $hash
                $json = ConvertTo-Json $test_payload
                $send_queue.Enqueue($json)
            }
        } until ($ws.State -ne [Net.WebSockets.WebSocketState]::Open)
    }
    finally {
        Write-Output "Closing WS connection"
        $closetask = $ws.CloseAsync(
            [System.Net.WebSockets.WebSocketCloseStatus]::Empty,
            "",
            $ct
        )

        do { Sleep(1) }
        until ($closetask.IsCompleted)
        $ws.Dispose()

        Write-Output "Stopping runspaces"
        $recv_runspace.Stop()
        $recv_runspace.Dispose()

        $send_runspace.Stop()
        $send_runspace.Dispose()
    }
}
