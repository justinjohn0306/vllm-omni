@echo off
setlocal EnableExtensions

if /I "%~1"=="--help" goto usage
if /I "%~1"=="/?" goto usage

if not defined PORT set "PORT=8095"
if not defined MODEL_ID set "MODEL_ID=bosonai/higgs-audio-v3-tts-4b"
if not defined OUT_FILE set "OUT_FILE=%CD%\hello_higgs_cmd.wav"

set "HIGGS_TEXT=%~1"
if "%HIGGS_TEXT%"=="" set "HIGGS_TEXT=Hello from vLLM Omni running natively on Windows."
if not "%~2"=="" set "OUT_FILE=%~2"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $body=@{ model=$env:MODEL_ID; input=$env:HIGGS_TEXT } | ConvertTo-Json; Invoke-WebRequest -Uri ('http://127.0.0.1:' + $env:PORT + '/v1/audio/speech') -Method Post -ContentType 'application/json' -Body $body -OutFile $env:OUT_FILE -TimeoutSec 600; $item=Get-Item -LiteralPath $env:OUT_FILE; Write-Host ('Wrote ' + $item.FullName + ' (' + $item.Length + ' bytes)')"
exit /b %ERRORLEVEL%

:usage
echo Usage:
echo   tools\windows\test_higgs_tts.cmd ["TEXT"] [OUT_FILE]
echo.
echo Examples:
echo   tools\windows\test_higgs_tts.cmd
echo   tools\windows\test_higgs_tts.cmd "This is a CMD smoke test." C:\temp\smoke.wav
echo.
echo Optional environment variables:
echo   PORT, MODEL_ID, OUT_FILE
exit /b 0
