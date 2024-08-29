
function Start_WebSocketConnection {
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


$wsUrl = 'wss://esmia-r1.datuum.ai/ws/cartographer/v1/task-service?token=eyJraWQiOiJkZWZhdWx0IiwiYWxnIjoiUlM1MTIiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJEYXR1dW0uYWkiLCJpYXQiOjE3MjM1NjE5MzIsImV4cCI6MTcyNjI0MDMzMiwic3ViIjoiYW50b2luZUBlc21pYS5jYSIsImVtYWlsIjoiYW50b2luZUBlc21pYS5jYSIsIm5hbWUiOiJBbnRvaW5lIER1cGxhbnRpZS1HcmVuaWVyIiwicHJvdmlkZXIiOiJtaWNyb3NvZnQifQ.MJAWWLlcXDoL_oInx1_G8ntO86F2VwXK6d4XOepfhtrKKUpiK2wiUQL8MV7iBYmM2l7mdFYWpzrvkMMesNF3dm1ND5pQz7QX6ccik_O0r1Zn9eUO-e1XaOcAwObu_AZ0iv7SgP4S3xU6EM0wki_e3TsAVSrnbyPQGY1tG7XiB3rvBBk2oUa-gk95Rh8TdKaG7wRmzcGp734N0zn_2KmiPcF5MrJ5W5s01tmuKEoAKBSD6oGmBIIcCRTmjmxpr6yW6UXnXEW6rgA7ZIVF0yVcnRsGBxn1xmjToGNP_29tkErPKHr8oCoj7Gg_Ytj_LBa0Idk1jp1MTQQd7q4K6HSZ7g&project=66b27353256cf952a3150057'
Start_WebSocketConnection -Url $wsUrl