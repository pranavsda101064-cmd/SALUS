param(
    [string]$ApiBase = "http://localhost:8000"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Frontend = Join-Path $Root "frontend"
$Landing = Join-Path $Frontend "landing"
$Dist = Join-Path $Frontend "dist"

Write-Host "Building SALUS site for $ApiBase" -ForegroundColor Cyan
Push-Location $Frontend
try {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    & flutter build web --release --base-href /app/ --dart-define=API_BASE=$ApiBase 2>&1 | Out-Host
    $buildCode = $LASTEXITCODE
    $ErrorActionPreference = $previous
    if ($buildCode -ne 0) {
        throw "flutter build failed with exit code $buildCode"
    }
}
finally {
    Pop-Location
}

if (Test-Path $Dist) {
    Remove-Item $Dist -Recurse -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $Dist "app") | Out-Null

Copy-Item (Join-Path $Frontend "build\web\*") (Join-Path $Dist "app") -Recurse -Force
Copy-Item (Join-Path $Landing "index.html") $Dist -Force
Copy-Item (Join-Path $Landing "styles.css") $Dist -Force
Copy-Item (Join-Path $Landing "app.js") $Dist -Force
Copy-Item (Join-Path $Landing "simulation.css") $Dist -Force
Copy-Item (Join-Path $Landing "simulation.js") $Dist -Force
Copy-Item (Join-Path $Landing "simulation-data.json") $Dist -Force
Copy-Item (Join-Path $Landing "privacy.html") $Dist -Force
Copy-Item (Join-Path $Landing "terms.html") $Dist -Force
Copy-Item (Join-Path $Landing "404.html") $Dist -Force
Copy-Item (Join-Path $Landing "robots.txt") $Dist -Force
Copy-Item (Join-Path $Landing "sitemap.xml") $Dist -Force
Copy-Item (Join-Path $Landing "favicon.svg") $Dist -Force
Copy-Item (Join-Path $Landing "favicon-32.png") $Dist -Force
Copy-Item (Join-Path $Landing "favicon-192.png") $Dist -Force
Copy-Item (Join-Path $Landing "favicon-512.png") $Dist -Force
Copy-Item (Join-Path $Landing "apple-touch-icon.png") $Dist -Force
Copy-Item (Join-Path $Landing "og-image.png") $Dist -Force
Copy-Item (Join-Path $Landing "assets") $Dist -Recurse -Force

$indexPath = Join-Path $Dist "index.html"
$indexHtml = Get-Content -LiteralPath $indexPath -Raw
$indexHtml = $indexHtml.Replace("__SALUS_API_BASE__", $ApiBase)
Set-Content -LiteralPath $indexPath -Value $indexHtml -NoNewline

Write-Host "Site built at $Dist" -ForegroundColor Green
Write-Host "  Landing: http://localhost:8080/"
Write-Host "  App:     http://localhost:8080/app/"
