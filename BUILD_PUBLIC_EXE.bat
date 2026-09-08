@echo off
setlocal
cd /d "%~dp0"
echo Building WL Simplistic SnowRunner Mod Editor v1.0.0...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0BUILD_PUBLIC_EXE.ps1"
if errorlevel 1 (
  echo.
  echo BUILD FAILED. Please send a screenshot of this window.
  pause
  exit /b 1
)
echo.
echo Build succeeded.
pause
endlocal
