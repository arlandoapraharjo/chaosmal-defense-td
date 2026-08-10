# Script Instalasi Otomatis Graphify Antigravity (dengan Python Venv)
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   Graphify Antigravity Automated Installer    " -ForegroundColor Cyan
Write-Host "               (Python Venv Mode)              " -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

$VENV_PATH = Join-Path (Get-Location) "Python_Venv"
$VENV_PYTHON = Join-Path $VENV_PATH "Scripts\python.exe"

# 1. Cek & Buat Virtual Environment jika belum ada
Write-Host "`n[1/4] Memeriksa Virtual Environment (Python_Venv)..." -ForegroundColor Yellow
if (-not (Test-Path $VENV_PYTHON)) {
    Write-Host "Membuat virtual environment di Python_Venv..." -ForegroundColor Gray
    python -m venv Python_Venv
}
Write-Host "Virtual environment siap: $VENV_PATH" -ForegroundColor Green

# 2. Upgrade pip & Install Graphify di Venv
Write-Host "`n[2/4] Menginstall graphifyy & dependencies ke dalam Python_Venv..." -ForegroundColor Yellow
& $VENV_PYTHON -m pip install --no-cache-dir --upgrade pip
& $VENV_PYTHON -m pip install --no-cache-dir --upgrade graphifyy mcp uv

# 3. Jalankan graphify antigravity install dari venv
Write-Host "`n[3/4] Mengonfigurasi integrasi Antigravity..." -ForegroundColor Yellow
$VENV_GRAPHIFY = Join-Path $VENV_PATH "Scripts\graphify.exe"
if (Test-Path $VENV_GRAPHIFY) {
    & $VENV_GRAPHIFY antigravity install
} else {
    & $VENV_PYTHON -m graphify antigravity install
}

# 4. Ringkasan Petunjuk
Write-Host "`n[4/4] Instalasi Venv & Graphify Selesai!" -ForegroundColor Green
Write-Host "-----------------------------------------------" -ForegroundColor White
Write-Host "Langkah selanjutnya:" -ForegroundColor White
Write-Host "1. Buka AI Coding Assistant (Antigravity Chat)" -ForegroundColor White
Write-Host "2. Ketik: /graphify ." -ForegroundColor White
Write-Host "===============================================" -ForegroundColor Cyan
