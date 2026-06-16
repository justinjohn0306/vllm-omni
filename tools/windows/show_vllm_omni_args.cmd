@echo off
setlocal EnableExtensions

if not defined VLLM_OMNI_ENV if defined CONDA_PREFIX set "VLLM_OMNI_ENV=%CONDA_PREFIX%"
set "SECTION=%~1"
if "%SECTION%"=="" set "SECTION=all"
if not defined VLLM_LOGGING_LEVEL set "VLLM_LOGGING_LEVEL=ERROR"

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

"%VLLM_OMNI_EXE%" serve "--help=%SECTION%" --omni
exit /b %ERRORLEVEL%
