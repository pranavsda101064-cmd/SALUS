param(
    [switch]$Reset,
    [switch]$Serve
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

Write-Host "SALUS demo preparation" -ForegroundColor Cyan
Push-Location (Join-Path $Root "backend")
try {
    python manage.py migrate
    if ($Reset) {
        python manage.py seed_demo --reset
    } else {
        python manage.py seed_demo
    }
}
finally {
    Pop-Location
}

Push-Location $Root
try {
    python scripts/generate_dataset.py
    python scripts/ghost_copy.py
}
finally {
    Pop-Location
}

Write-Host ""
Write-Host "Demo ready" -ForegroundColor Green
Write-Host "  Login: meera@acmetraders.test"
Write-Host "  Suspect file: demo_data/clients_export_final.csv"
Write-Host ""
Write-Host "Start the API:  cd backend; python manage.py runserver 0.0.0.0:8000"
Write-Host "Start the app:  cd frontend; flutter run -d chrome --web-port 8080 --dart-define=API_BASE=http://localhost:8000"

if ($Serve) {
    Push-Location (Join-Path $Root "backend")
    try {
        python manage.py runserver 0.0.0.0:8000
    }
    finally {
        Pop-Location
    }
}
