# Debug CodeMagic API response
$CODEMAGIC_API_TOKEN = "Mx0tOKSDa9W0dLPSRUrWqlwmnhv43KrFKclPrtqpuNM"
$CODEMAGIC_APP_ID = "69bc03348aebba642bb60c85"

Write-Host "=== Fetching CodeMagic builds ===" -ForegroundColor Cyan
Write-Host "API Token: $($CODEMAGIC_API_TOKEN.Substring(0, 10))..."
Write-Host "App ID: $CODEMAGIC_APP_ID"
Write-Host ""

# Fetch raw response
Write-Host "=== Full API Response (Latest 3 Builds) ===" -ForegroundColor Cyan
$response = Invoke-WebRequest -Uri "https://api.codemagic.io/builds?appId=${CODEMAGIC_APP_ID}&status=finished&limit=3" `
  -Headers @{"x-auth-token" = $CODEMAGIC_API_TOKEN} `
  -ContentType "application/json" | ConvertFrom-Json

$response | ConvertTo-Json -Depth 10

Write-Host ""
Write-Host "=== Build Summary ===" -ForegroundColor Cyan
$response.builds | ForEach-Object {
  Write-Host "Build ID: $($_.id.Substring(0, 8))... | Platform: $($_.platform) | Status: $($_.buildStatus) | Mode: $($_.mode) | Artifacts: $($_.artifacts.Count)" -ForegroundColor Yellow
  Write-Host "  Artifact URLs:" -ForegroundColor Gray
  $_.artifacts | ForEach-Object {
    Write-Host "    - $($_.filename): $($_.downloadUrl.Substring(0, 60))..." -ForegroundColor Gray
  }
}

Write-Host ""
Write-Host "=== Latest Successful iOS Build ===" -ForegroundColor Green
$iosBuild = $response.builds | Where-Object {$_.platform -eq "ios" -and $_.buildStatus -eq "success" -and $_.artifacts.Count -gt 0} | Select-Object -First 1
if ($iosBuild) {
  Write-Host "ID: $($iosBuild.id.Substring(0, 8))..." 
  Write-Host "Status: $($iosBuild.buildStatus)"
  Write-Host "Mode: $($iosBuild.mode)"
  Write-Host "Finished At: $($iosBuild.finishedAt)"
  Write-Host "Download URL: $($iosBuild.artifacts[0].downloadUrl)"
} else {
  Write-Host "No successful iOS builds found with artifacts" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Latest Successful Android Build ===" -ForegroundColor Green
$androidBuild = $response.builds | Where-Object {$_.platform -eq "android" -and $_.buildStatus -eq "success" -and $_.artifacts.Count -gt 0} | Select-Object -First 1
if ($androidBuild) {
  Write-Host "ID: $($androidBuild.id.Substring(0, 8))..."
  Write-Host "Status: $($androidBuild.buildStatus)"
  Write-Host "Mode: $($androidBuild.mode)"
  Write-Host "Finished At: $($androidBuild.finishedAt)"
  Write-Host "Download URL: $($androidBuild.artifacts[0].downloadUrl)"
} else {
  Write-Host "No successful Android builds found with artifacts" -ForegroundColor Red
}
