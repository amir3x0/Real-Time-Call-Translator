# Get the first IPv4 address that isn't localhost
$RealIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "169.254*" } | Select-Object -First 1).IPAddress

Write-Host "🚀 Launching app connecting to Backend at: $RealIP"

# Navigate to the mobile directory relative to this script
Set-Location -Path "$PSScriptRoot/../mobile"

# Run Flutter with the detected IP
flutter run --release --dart-define=BACKEND_HOST=$RealIP
