function Get-USBDriveLetter {
    $usbDrive = Get-CimInstance -ClassName Win32_Volume -Filter "Label = 'TINY_DRIVE'" | Select-Object -First 1
    return $usbDrive.DriveLetter
}

# USB-Laufwerksbuchstaben ermitteln
$usbDriveLetter = Get-USBDriveLetter

if ($usbDriveLetter) {
    # Pfad zur PowerShell-Datei auf dem USB-Laufwerk
    $usbScriptPath = Join-Path -Path $usbDriveLetter -ChildPath "go.vbs"
    
    # Pfad zum temporären Ordner
    $tempScriptPath = Join-Path -Path $env:TEMP -ChildPath "go.vbs"

    # Datei st.ps1 in den temporären Ordner kopieren
    Copy-Item -Path $usbScriptPath -Destination $tempScriptPath -Force

    # PowerShell-Skript im Hintergrund ausführen
    & $tempScriptPath

    # Sound abspielen
    [System.Media.SystemSounds]::Beep.Play()

} else {
    Write-Host "USB-Laufwerk wurde nicht gefunden."
}
