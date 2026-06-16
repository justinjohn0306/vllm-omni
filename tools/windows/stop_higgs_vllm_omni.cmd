@echo off
setlocal EnableExtensions EnableDelayedExpansion

if /I "%~1"=="--help" goto usage
if /I "%~1"=="/?" goto usage

if not defined PORT set "PORT=8095"
if not "%~1"=="" set "PORT=%~1"

set "KILLED=0"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do (
    set "KILLED=1"
    echo Stopping PID %%P on port %PORT%...
    taskkill /PID %%P /T /F
)

if "!KILLED!"=="0" (
    echo No listener found on port %PORT%.
)

exit /b 0

:usage
echo Usage:
echo   tools\windows\stop_higgs_vllm_omni.cmd [PORT]
echo.
echo Example:
echo   tools\windows\stop_higgs_vllm_omni.cmd 8095
exit /b 0
