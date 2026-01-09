# Get the active network adapter's IPv4 address
# Priority: Wi-Fi or Ethernet with valid IP (not virtual, not link-local)
$RealIP = $null

# Try Wi-Fi first (common for mobile development)
$RealIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
    $_.InterfaceAlias -like "*Wi-Fi*" -and 
    $_.IPAddress -notlike "169.254*" 
} | Select-Object -First 1).IPAddress

# Try Ethernet if Wi-Fi not found
if (-not $RealIP) {
    $RealIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -like "*Ethernet*" -and 
        $_.InterfaceAlias -notlike "vEthernet*" -and
        $_.IPAddress -notlike "169.254*"
    } | Select-Object -First 1).IPAddress
}

# Fallback: any non-virtual adapter
if (-not $RealIP) {
    $RealIP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { 
        $_.InterfaceAlias -notlike "*Loopback*" -and 
        $_.InterfaceAlias -notlike "vEthernet*" -and 
        $_.IPAddress -notlike "169.254*" -and
        $_.IPAddress -notlike "172.1*" -and
        $_.IPAddress -notlike "172.2*"
    } | Select-Object -First 1).IPAddress
}

if (-not $RealIP) {
    Write-Host "❌ Could not detect network IP address!" -ForegroundColor Red
    exit 1
}

Write-Host "🚀 Launching app connecting to Backend at: $RealIP" -ForegroundColor Green

# Navigate to the mobile directory relative to this script
# Set-Location -Path "$PSScriptRoot/../mobile"

# Run Flutter with the detected IP
flutter run --dart-define=BACKEND_HOST=$RealIP
