


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
        'Authorization' = 'Bearer eyJraWQiOiJkZWZhdWx0IiwidHlwIjoiSldUIiwiYWxnIjoiUlM1MTIifQ.eyJzdWIiOiJhbnRvaW5lQGVzbWlhLmNhIiwicHJvdmlkZXIiOiJtaWNyb3NvZnQiLCJpc3MiOiJEYXR1dW0uYWkiLCJuYW1lIjoiQW50b2luZSBEdXBsYW50aWUtR3JlbmllciIsImV4cCI6MTcyNTU3MTk3OSwiaWF0IjoxNzIyODkzNTc5LCJlbWFpbCI6ImFudG9pbmVAZXNtaWEuY2EifQ.l3-G5sLVftcINQYJi1wya7lIK55VIhveGDeZLp2kYMzMzB_YVBAhH6UXQzFTU-9uMsJ5WYgvN5sS1yG-JDMXaw3jLzYp9tTde2FkwWkCv0Fj6fm_2vjDCo6sCMWSE9AXwBAfwo6by4Sie45QKCvhydUjZkRr7dCSqxtMLoCNRIVAfYSVvfnkHSF_DpANAf9DZ2YzrYRmbStHmsYq8hTL8VUvjt9jadsEgR5KYWN-uxxLRVh26nzaFiQwSWV__aO5rym6eyMBt8tNhND2kwuR3IrQbfx5L3NRX02DM-901Y1OU0XIegYqnAEcSwtGPmQUzW7EtWzGeK65tjsjojHc-g'
    }


    $form = @{
        "file" = Get-Item -Path $Path
        "scenario" = $cleanName
        "timestamp" = $timestamp
    }


    $response = Invoke-WebRequest -Uri "https://esmia.datuum.ai/api/cartographer/v1/command/esmia/gdx/upload" `
        -Method Post `
        -Headers $headers `
        -ContentType "multipart/form-data" `
        -Form $form
    

    switch ($response.StatusCode) {
            200 {
                Write-Host "Success: " $response.Content
            }
            201 {
                Write-Host "Created: " $response.Content
            }
            204 {
                Write-Host "No Content: The request was successful but there is no representation to return."
            }
            400 {
                Write-Host "Bad Request: " $response.Content
            }
            401 {
                Write-Host "Unauthorized: Check your credentials and try again."
            }
            403 {
                Write-Host "Forbidden: You do not have permission to access this resource."
            }
            404 {
                Write-Host "Not Found: The requested resource could not be found."
            }
            500 {
                Write-Host "Internal Server Error: " $response.Content
            }
            502 {
                Write-Host "Bad Gateway: Invalid responses from another server/proxy."
            }
            503 {
                Write-Host "Service Unavailable: The server is currently unable to handle the request."
            }
            default {
                Write-Host "Unexpected response ($($response.StatusCode)): " $response.Content
            }
        }
    
    catch [System.Net.WebException] {
        $errorResponse = $_.Exception.Response
        if ($errorResponse -ne $null) {
            $reader = [System.IO.StreamReader]::new($errorResponse.GetResponseStream())
            $errorContent = $reader.ReadToEnd()
            Write-Host "WebException: " $errorContent
        } else {
            Write-Host "WebException: " $_.Exception.Message
        }
    }
    catch {
        Write-Host "An unexpected error occurred: " $_.Exception.Message
    }

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

            switch ($ChangeType) {
                'Changed'  { "CHANGE" }
                'Created'  {
                    Write-Host "This file will be pushed to Datuum"
                    Start-Job -ScriptBlock {
                        param($FullPath, $Name)
                        Push_to_datuum -Path $FullPath -FileName $Name
                    } -ArgumentList $FullPath, $Name
                }
                'Deleted'  {
                    "DELETED"
                    Write-Host "Deletion Handler Start" -ForegroundColor Gray
                    Start-Sleep -Seconds 4
                    Write-Host "Deletion Handler End" -ForegroundColor Gray
                }
                'Renamed'  {
                    $OldName = $details.OldName
                    $text = "File {0} was renamed to {1}" -f $OldName, $Name
                    Write-Host $text -ForegroundColor Yellow
                }
                default   { Write-Host $_ -ForegroundColor Red -BackgroundColor White }
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

        do {
            Wait-Event -Timeout 1
            Write-Host "." -NoNewline
        } while ($true)
    }
    finally {
        $watcher.EnableRaisingEvents = $false
        $handlers | ForEach-Object {
            Unregister-Event -SourceIdentifier $_.Name
        }
        $handlers | Remove-Job
        $watcher.Dispose()
        Write-Warning "Event Handler disabled, monitoring ends."
    }
}

# Ensure the Push_to_datuum function is defined elsewhere in your script
function Push_to_datuum {
    param (
        [string]$Path,
        [string]$FileName
    )
    # Simulate a long-running task
    Start-Sleep -Seconds 10
    Write-Host "Pushed $FileName to Datuum"
}

# Start the file monitor
files_monitor

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



Function main{

$global:project = Get-ProjectID -defaultID "66b27353256cf952a3150057"


files_monitor 



}

main

