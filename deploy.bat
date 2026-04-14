@echo off
:: ============================================================
:: BlenderMCP — One-Click Deployment  (deploy.bat)
:: ============================================================
:: Double-click this file (or run from a terminal) to:
::   1. Verify Python 3.10+ is installed
::   2. Install uv if it is missing
::   3. Configure Claude Desktop, Cursor, and VS Code / GitHub Copilot
::   4. Launch Blender with the BlenderMCP addon pre-loaded
::
:: Optional: pass your Blender executable path as the first argument
::   deploy.bat "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe"
:: ============================================================

setlocal EnableDelayedExpansion

:: ── Change to the script's own directory so relative paths work ─
cd /d "%~dp0"

:: ── Forward optional Blender path argument to the PowerShell script ─
set "BLENDER_ARG="
if not "%~1"=="" (
    set "BLENDER_ARG=-BlenderPath ""%~1"""
)

echo.
echo ========================================
echo   BlenderMCP -- One-Click Deployment
echo ========================================
echo.

:: ── Check PowerShell availability ───────────────────────────
where powershell >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERROR] PowerShell is not available on this system.
    echo         Please install PowerShell or run deploy.ps1 manually.
    pause
    exit /b 1
)

:: ── Run the PowerShell deployment script ────────────────────
echo [*] Starting deployment via PowerShell...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0deploy.ps1" %BLENDER_ARG%
set "PS_EXIT=%ERRORLEVEL%"

echo.
if %PS_EXIT% neq 0 (
    echo [!] Deployment finished with warnings or errors (exit code %PS_EXIT%).
) else (
    echo [+] Deployment completed successfully.
)

echo.
echo Press any key to close this window...
pause >nul
exit /b %PS_EXIT%
