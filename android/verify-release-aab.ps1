param(
    [string]$AabPath = "..\build\app\outputs\bundle\release\app-release.aab"
)

$resolved = Resolve-Path $AabPath -ErrorAction Stop
Write-Host "Checking: $resolved"

$jarsigner = Get-Command jarsigner -ErrorAction SilentlyContinue
if (-not $jarsigner) {
    $jarsigner = Get-ChildItem "C:\Program Files\Java\*\bin\jarsigner.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
}

if (-not $jarsigner) {
    Write-Error "jarsigner not found. Install JDK or Android Studio."
    exit 1
}

& $jarsigner.Source -verify -verbose -certs $resolved 2>&1 | Select-String -Pattern "CN=|jar verified|Android Debug|debug"

Write-Host ""
Write-Host "Expected certificate owner: CN=Winsoft"
Write-Host "If you see 'Android Debug', do NOT upload this file."
