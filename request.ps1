$now = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Define the URL and the headers
$uri = 'https://esmia.datuum.ai/api/cartographer/v1/command/esmia/gdx/upload'
$headers = @{
    'accept' = 'application/json'
    'Authorization' = 'Bearer eyJraWQiOiJkZWZhdWx0IiwidHlwIjoiSldUIiwiYWxnIjoiUlM1MTIifQ.eyJzdWIiOiJhbnRvaW5lQGVzbWlhLmNhIiwicHJvdmlkZXIiOiJtaWNyb3NvZnQiLCJpc3MiOiJEYXR1dW0uYWkiLCJuYW1lIjoiQW50b2luZSBEdXBsYW50aWUtR3JlbmllciIsImV4cCI6MTcyNTI4Mjk5MCwiaWF0IjoxNzIyNjA0NTkwLCJlbWFpbCI6ImFudG9pbmVAZXNtaWEuY2EifQ.MK99X-_4oWjcvL5U0IirJCM7ihSHChm0pRrsyB9y6C8Js3ei4LSqNnaj0l0v7v8IzAdJTtsY8VT665JyMEzR-785wOqgvISiB5Wjj2Sl3S7zaVX2zUjLEw8H11p7Rd5QliyJdO8gh-qTf-wSqAgvlqW-az1yzr99WZbhtdVOiDeAXaSbOHGay_-e1qNCvJQf_BGDsYw20VjdsZXq5FFZQVDqX8l4tYFeQ0FGvcUbt1ag8zcrU5oU8PZPZq6dx7bqfoZ6fhoKHkIPnuR4TvCi1YoTWHMS5TEUzj3bFYsoNT7jwTnul-6FB_y3-_gaTFh-_tkga6zSqEvZchNT_vepYw'
    'X-Project' = '66b129bf77a2703a65dbb561'
}

# File to upload
$filePath = "C:\Users\AntoineDuplantie-Gre\OneDrive - esmia.ca\Desktop\POWERSHELL\Scenarios\on_aref_nco.gdx"
$fileBytes = [System.IO.File]::ReadAllBytes($filePath)
$boundary = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"

# Construct the body with the file and additional form data
$bodyLines = (
    "--$boundary",
    'Content-Disposition: form-data; name="file"; filename="on_aref_nco.gdx"',
    "Content-Type: application/octet-stream$LF",
    [System.Text.Encoding]::UTF8.GetString($fileBytes),
    "--$boundary",
    'Content-Disposition: form-data; name="scenario"',
    "$LF",
    "from_API",
    "--$boundary",
    'Content-Disposition: form-data; name="timestamp"',
    "$LF",
    "$now",
    "--$boundary--"
) -join $LF

# Convert the body into bytes
$bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($bodyLines)

# Additional headers
$headers['Content-Type'] = "multipart/form-data; boundary=$boundary"

# Send the request
$response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $bodyBytes -ContentType $headers['Content-Type']

# Display the response
$response
