param(
    [int]$Port = 8080
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root "frontend\dist"

if (-not (Test-Path (Join-Path $Dist "index.html"))) {
    throw "Site build is missing. Run scripts/build_site.ps1 first."
}

Write-Host "Serving $Dist on http://localhost:$Port" -ForegroundColor Cyan
Write-Host "  Landing: http://localhost:$Port/"
Write-Host "  App:     http://localhost:$Port/app/"
Write-Host "Start the API separately on port 8000."

python -m http.server $Port --bind 127.0.0.1 --directory $Dist
