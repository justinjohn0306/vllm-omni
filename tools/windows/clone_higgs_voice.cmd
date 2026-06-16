@echo off
setlocal EnableExtensions

if /I "%~1"=="--help" goto usage
if /I "%~1"=="/?" goto usage

set "SCRIPT_DIR=%~dp0"
for %%I in ("%SCRIPT_DIR%..\..") do set "REPO_DEFAULT=%%~fI"

if not defined VLLM_OMNI_REPO set "VLLM_OMNI_REPO=%REPO_DEFAULT%"
if not defined VLLM_OMNI_ENV if defined CONDA_PREFIX set "VLLM_OMNI_ENV=%CONDA_PREFIX%"
if not defined PORT set "PORT=8095"
if not defined MODEL_ID if defined MODEL_PATH set "MODEL_ID=%MODEL_PATH%"
if not defined MODEL_ID set "MODEL_ID=bosonai/higgs-audio-v3-tts-4b"
if not defined OUT_DIR set "OUT_DIR=results\higgs_v3_clone_api"

set "PROMPT=%~1"
if "%PROMPT%"=="" goto usage
if not defined REF_AUDIO if not "%~2"=="" set "REF_AUDIO=%~2"
if not defined REF_TEXT if not "%~3"=="" set "REF_TEXT=%~3"
if not "%~4"=="" set "OUT_DIR=%~4"

if not defined REF_AUDIO (
    echo REF_AUDIO is required.
    echo Set REF_AUDIO or pass it as the second argument.
    exit /b 1
)

if defined VLLM_OMNI_ENV (
    set "PYTHON_EXE=%VLLM_OMNI_ENV%\python.exe"
) else (
    set "PYTHON_EXE=python.exe"
)

curl.exe -fsS http://127.0.0.1:%PORT%/v1/models >nul 2>nul
if errorlevel 1 (
    echo Server is not ready.
    echo Start it with:
    echo   tools\windows\run_higgs_vllm_omni.cmd
    exit /b 1
)

pushd "%VLLM_OMNI_REPO%" || exit /b 1
if defined REF_TEXT (
    "%PYTHON_EXE%" examples\online_serving\text_to_speech\higgs_audio_v3\batch_speech_client.py ^
        --base-url http://127.0.0.1:%PORT% ^
        --model "%MODEL_ID%" ^
        --output-dir "%OUT_DIR%" ^
        --ref-audio "%REF_AUDIO%" ^
        --ref-text "%REF_TEXT%" ^
        --prompts "%PROMPT%"
) else (
    "%PYTHON_EXE%" examples\online_serving\text_to_speech\higgs_audio_v3\batch_speech_client.py ^
        --base-url http://127.0.0.1:%PORT% ^
        --model "%MODEL_ID%" ^
        --output-dir "%OUT_DIR%" ^
        --ref-audio "%REF_AUDIO%" ^
        --prompts "%PROMPT%"
)
set "EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %EXIT_CODE%

:usage
echo Usage:
echo   set MODEL_ID=C:\models\higgs-audio-v3-tts-4b
echo   set REF_AUDIO=C:\audio\reference.wav
echo   set REF_TEXT=Transcript of the reference clip.
echo   tools\windows\clone_higgs_voice.cmd "Text to synthesize."
echo.
echo Or:
echo   tools\windows\clone_higgs_voice.cmd "Text to synthesize." C:\audio\reference.wav "Transcript" results\clone
echo.
echo Optional environment variables:
echo   PORT, MODEL_ID, MODEL_PATH, REF_AUDIO, REF_TEXT, OUT_DIR
echo   VLLM_OMNI_ENV, VLLM_OMNI_REPO
exit /b 0
