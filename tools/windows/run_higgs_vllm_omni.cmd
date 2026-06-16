@echo off
setlocal EnableExtensions

if /I "%~1"=="--help" goto usage
if /I "%~1"=="/?" goto usage

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_DEFAULT=%%~fI"

if not defined VLLM_OMNI_ENV if defined CONDA_PREFIX set "VLLM_OMNI_ENV=%CONDA_PREFIX%"
if not defined VLLM_OMNI_REPO set "VLLM_OMNI_REPO=%REPO_DEFAULT%"
if not defined MODEL_PATH set "MODEL_PATH=bosonai/higgs-audio-v3-tts-4b"
if not defined PORT set "PORT=8095"
if not defined GPU_MEMORY_UTILIZATION set "GPU_MEMORY_UTILIZATION=0.6"
if not defined CUDA_TOOLKIT_PATH if defined CUDA_PATH set "CUDA_TOOLKIT_PATH=%CUDA_PATH%"
if not defined HOST_IP set "HOST_IP=127.0.0.1"
if not defined OUT_LOG set "OUT_LOG=%VLLM_OMNI_REPO%\higgs_server.out.log"
if not defined ERR_LOG set "ERR_LOG=%VLLM_OMNI_REPO%\higgs_server.err.log"

if /I "%~1"=="status" goto status
if /I "%~1"=="logs" goto logs
if /I "%~1"=="stop" goto stop
if /I "%~1"=="restart" goto restart

if not "%~1"=="" set "PORT=%~1"
if not "%~2"=="" set "MODEL_PATH=%~2"
if not "%~3"=="" set "GPU_MEMORY_UTILIZATION=%~3"

call :is_ready
if "%READY%"=="1" (
    echo vLLM-Omni Higgs Audio server is already running.
    echo Model stays loaded at http://%HOST_IP%:%PORT%
    echo Generate with:
    echo   tools\windows\clone_higgs_voice.cmd "Text to synthesize."
    exit /b 0
)

call :server_process_exists
if "%SERVER_PROCESS%"=="1" (
    echo vLLM-Omni Higgs Audio server process already exists and is still loading.
    echo Check it with:
    echo   tools\windows\run_higgs_vllm_omni.cmd status
    echo   tools\windows\run_higgs_vllm_omni.cmd logs
    exit /b 0
)

if defined VLLM_OMNI_ENV (
    set "VLLM_OMNI_EXE=%VLLM_OMNI_ENV%\Scripts\vllm-omni.exe"
) else (
    set "VLLM_OMNI_EXE=vllm-omni.exe"
)

if defined VLLM_OMNI_ENV if not exist "%VLLM_OMNI_EXE%" (
    echo vllm-omni.exe not found: "%VLLM_OMNI_EXE%"
    echo Activate your Python environment or set VLLM_OMNI_ENV to the env path.
    exit /b 1
)
if not defined VLLM_OMNI_ENV where vllm-omni.exe >nul 2>nul
if not defined VLLM_OMNI_ENV if errorlevel 1 (
    echo vllm-omni.exe was not found on PATH.
    echo Activate your Python environment or set VLLM_OMNI_ENV to the env path.
    exit /b 1
)

set "CUDA_VISIBLE_DEVICES=0"
if defined CUDA_TOOLKIT_PATH set "CUDA_HOME=%CUDA_TOOLKIT_PATH%"
if defined CUDA_TOOLKIT_PATH set "CUDA_PATH=%CUDA_TOOLKIT_PATH%"
set "VLLM_HOST_IP=%HOST_IP%"
set "VLLM_DP_MASTER_IP=%HOST_IP%"
set "VLLM_LOOPBACK_IP=%HOST_IP%"
set "VLLM_USE_DEEP_GEMM=0"
set "VLLM_MOE_USE_DEEP_GEMM=0"
set "VLLM_USE_FLASHINFER_SAMPLER=0"
set "FLASHINFER_DISABLE_VERSION_CHECK=1"
set "HF_HUB_DISABLE_SYMLINKS=1"
set "HF_HUB_DISABLE_SYMLINKS_WARNING=1"
set "VLLM_DISABLE_LOG_LOGO=1"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
if defined VLLM_OMNI_ENV set "PATH=%VLLM_OMNI_ENV%\Scripts;%VLLM_OMNI_ENV%\Lib\site-packages\torch\lib;%PATH%"
if defined CUDA_TOOLKIT_PATH set "PATH=%CUDA_TOOLKIT_PATH%\bin;%PATH%"

del /q "%OUT_LOG%" "%ERR_LOG%" 2>nul

echo Starting vLLM-Omni Higgs Audio server...
echo URL:      http://%HOST_IP%:%PORT%
echo Model id: %MODEL_PATH%
echo Logs:
echo   %OUT_LOG%
echo   %ERR_LOG%

if /I "%FOREGROUND%"=="1" (
    pushd "%VLLM_OMNI_REPO%"
    "%VLLM_OMNI_EXE%" serve "%MODEL_PATH%" ^
        --deploy-config "vllm_omni/deploy/higgs_multimodal_qwen3.yaml" ^
        --host "%HOST_IP%" ^
        --port "%PORT%" ^
        --gpu-memory-utilization "%GPU_MEMORY_UTILIZATION%" ^
        --attention-backend "TRITON_ATTN" ^
        --trust-remote-code ^
        --omni ^
        %EXTRA_VLLM_ARGS%
    set "EXIT_CODE=%ERRORLEVEL%"
    popd
    exit /b %EXIT_CODE%
)

start "vLLM-Omni Higgs" /min /d "%VLLM_OMNI_REPO%" "%ComSpec%" /c ""%VLLM_OMNI_EXE%" serve "%MODEL_PATH%" --deploy-config "vllm_omni/deploy/higgs_multimodal_qwen3.yaml" --host "%HOST_IP%" --port "%PORT%" --gpu-memory-utilization "%GPU_MEMORY_UTILIZATION%" --attention-backend "TRITON_ATTN" --trust-remote-code --omni %EXTRA_VLLM_ARGS% 1>"%OUT_LOG%" 2>"%ERR_LOG%""
exit /b 0

:usage
echo Usage:
echo   tools\windows\run_higgs_vllm_omni.cmd [PORT] [MODEL_PATH] [GPU_MEMORY_UTILIZATION]
echo   tools\windows\run_higgs_vllm_omni.cmd status
echo   tools\windows\run_higgs_vllm_omni.cmd logs
echo   tools\windows\run_higgs_vllm_omni.cmd stop
echo   tools\windows\run_higgs_vllm_omni.cmd restart
echo.
echo Examples:
echo   tools\windows\run_higgs_vllm_omni.cmd
echo   tools\windows\run_higgs_vllm_omni.cmd 8096 C:\models\higgs-audio-v3-tts-4b 0.7
echo.
echo Optional environment variables:
echo   VLLM_OMNI_ENV, VLLM_OMNI_REPO, MODEL_PATH, PORT, GPU_MEMORY_UTILIZATION
echo   CUDA_TOOLKIT_PATH, HOST_IP, OUT_LOG, ERR_LOG, EXTRA_VLLM_ARGS
echo   FOREGROUND=1 runs in the current CMD window instead of a minimized window.
exit /b 0

:status
call :is_ready
if "%READY%"=="1" (
    curl.exe http://%HOST_IP%:%PORT%/v1/models
    exit /b 0
)
call :server_process_exists
if "%SERVER_PROCESS%"=="1" (
    echo Server process exists, but the API is not ready yet.
    echo Wait a bit, then run:
    echo   tools\windows\run_higgs_vllm_omni.cmd status
    exit /b 1
)
echo Server is not running.
exit /b 1

:logs
echo === OUT LOG ===
if exist "%OUT_LOG%" (type "%OUT_LOG%") else echo Missing: "%OUT_LOG%"
echo.
echo === ERR LOG ===
if exist "%ERR_LOG%" (type "%ERR_LOG%") else echo Missing: "%ERR_LOG%"
exit /b 0

:stop
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%PORT%" ^| findstr "LISTENING"') do taskkill /PID %%P /T /F
powershell -NoProfile -ExecutionPolicy Bypass -Command "$port='%PORT%'; Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*vllm-omni* serve *' -and $_.CommandLine -like ('*--port ' + $port + '*') } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>nul
exit /b 0

:restart
call "%~f0" stop
timeout /t 2 /nobreak >nul
call "%~f0"
exit /b %ERRORLEVEL%

:is_ready
set "READY=0"
curl.exe -fsS http://%HOST_IP%:%PORT%/v1/models >nul 2>nul
if not errorlevel 1 set "READY=1"
exit /b 0

:server_process_exists
set "SERVER_PROCESS=0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$port='%PORT%'; $p=Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*vllm-omni* serve *' -and $_.CommandLine -like ('*--port ' + $port + '*') }; if ($p) { exit 0 } exit 1" >nul 2>nul
if not errorlevel 1 set "SERVER_PROCESS=1"
exit /b 0
