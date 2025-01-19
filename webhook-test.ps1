# Erstelle die Nachricht, die gesendet werden soll
$message = @{
    text = "Hallo, dies ist eine Testnachricht von PowerShell!"
} | ConvertTo-Json

# Erstelle ein Webclient-Objekt
$webClient = New-Object System.Net.WebClient

# Setze den Content-Type auf application/json
$webClient.Headers["Content-Type"] = "application/json"

# Sende die Nachricht an den Webhook
try {
    $response = $webClient.UploadString($whuri, $message)
    Write-Output "Nachricht erfolgreich gesendet: $response"
} catch {
    Write-Output "Fehler beim Senden der Nachricht: $_"
}

# Bereinige das Webclient-Objekt
$webClient.Dispose()
