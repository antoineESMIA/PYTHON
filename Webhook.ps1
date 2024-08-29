function Send-SimpleAdaptiveCard {
    param (
        [string]$webhookUrl
    )

    $card = @{
        type = "message"
        attachments = @(
            @{
                contentType = "application/vnd.microsoft.card.adaptive"
                content = @{
                    '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                    type = "AdaptiveCard"
                    version = "1.5"
                    body = @(
                        @{
                            type = "TextBlock"
                            text = "Simple Test Card"
                            wrap = $true
                        }
                    )
                }
            }gsgasdagdfgsdgfdssdd
        )
    }

    $json = $card | ConvertTo-Json -Depth 10 -Compress
    Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType 'application/json' -Body $json
}

# Usage example with your specific URI
$webhookUrl = 'https://prod2-07.canadacentral.logic.azure.com:443/workflows/3ae02f7904924a4687c7617e3c220a3f/triggers/manual/paths/invoke?api-version=2016-06-01&sp=%2Ftriggers%2Fmanual%2Frun&sv=1.0&sig=MO5Y0JNoUfH_4U3Ns-fG-cD1ClFu6OJx2FPB1rx07qg'
Send-SimpleAdaptiveCard -webhookUrl $webhookUrl
