@echo off
echo ===============================================
echo    Graphify Antigravity Automated Installer
echo               (Python Venv Mode)
echo ===============================================

echo.
echo [1/4] Memeriksa Virtual Environment (Python_Venv)...
if not exist "Python_Venv\Scripts\python.exe" (
    echo Membuat virtual environment di Python_Venv...
    python -m venv Python_Venv
)
echo Virtual environment siap di Python_Venv.

echo.
echo [2/4] Mengaktifkan Venv & Menginstall Dependencies...
call Python_Venv\Scripts\activate.bat
pip install --no-cache-dir --upgrade pip
pip install --no-cache-dir --upgrade graphifyy mcp uv

echo.
echo [3/4] Mengonfigurasi integrasi Antigravity...
graphify antigravity install

echo.
echo [4/4] Instalasi Selesai!
echo -----------------------------------------------
echo Langkah selanjutnya:
echo 1. Buka AI Coding Assistant (Antigravity Chat)
echo 2. Ketik: /graphify .
echo ===============================================
pause
