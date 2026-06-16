# Native Windows Setup

This fork adds experimental native Windows support for vLLM-Omni. The examples
below use `cmd.exe` / Anaconda Prompt.

## Before You Start

Install:

- NVIDIA driver
- CUDA Toolkit for Windows
- Anaconda or Miniconda
- Git for Windows
- The Windows vLLM wheel that matches your Python/CUDA version

This setup was tested with:

```text
Python 3.12
vllm-0.23.0+cu132-cp312-cp312-win_amd64.whl
Higgs Audio V3 TTS
```

The tested vLLM wheel came from:

```text
https://github.com/SystemPanic/vllm-windows/releases/tag/v0.23.0
```

## One-Time Setup

### 1. Create The Conda Env

Open Anaconda Prompt or a CMD window where `conda` works:

```bat
conda create -n vllm-omni python=3.12 -y
conda activate vllm-omni

python -m pip install --upgrade pip setuptools wheel
python --version
```

### 2. Install vLLM For Windows

Put the downloaded Windows vLLM wheel somewhere easy, then install it:

```bat
set VLLM_WHEEL=C:\wheels\vllm-0.23.0+cu132-cp312-cp312-win_amd64.whl
python -m pip install "%VLLM_WHEEL%"
```

Check that PyTorch sees your GPU:

```bat
python -c "import torch; print(torch.__version__); print(torch.cuda.is_available()); print(torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'no cuda')"
```

If that prints `False`, fix your NVIDIA driver / CUDA / wheel setup before
continuing.

### 3. Clone And Install This Repo

```bat
mkdir C:\src 2>nul
cd /d C:\src
git clone https://github.com/justinjohn0306/vllm-omni.git
cd /d C:\src\vllm-omni

python -m pip install -e .
python -m pip check
vllm-omni --version
```

If `pip install -e .` ever replaces the Windows vLLM wheel with a non-Windows
wheel, reinstall the Windows wheel and then reinstall this repo:

```bat
python -m pip install --force-reinstall "%VLLM_WHEEL%"
python -m pip install -e .
python -m pip check
```

### 4. Make CUDA Easy For Windows

Some CUDA tools live under `C:\Program Files\...`, and spaces in that path can
break JIT builds. The easiest fix is a no-spaces junction.

Run CMD as Administrator:

```bat
mklink /J C:\cuda-v13.2 "C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.2"
```

If your CUDA Toolkit is somewhere else, use that path instead.

### 5. Save The Runtime Vars Once

This avoids typing a pile of `set ...` commands every time.

With `vllm-omni` activated:

```bat
conda activate vllm-omni
mkdir "%CONDA_PREFIX%\etc\conda\activate.d"
notepad "%CONDA_PREFIX%\etc\conda\activate.d\vllm-omni-windows.bat"
```

Paste this into Notepad, then save it:

```bat
set CUDA_HOME=C:\cuda-v13.2
set CUDA_PATH=C:\cuda-v13.2
set VLLM_HOST_IP=127.0.0.1
set VLLM_DP_MASTER_IP=127.0.0.1
set VLLM_LOOPBACK_IP=127.0.0.1
set VLLM_USE_DEEP_GEMM=0
set VLLM_MOE_USE_DEEP_GEMM=0
set VLLM_USE_FLASHINFER_SAMPLER=0
set FLASHINFER_DISABLE_VERSION_CHECK=1
set HF_HUB_DISABLE_SYMLINKS=1
set HF_HUB_DISABLE_SYMLINKS_WARNING=1
set VLLM_DISABLE_LOG_LOGO=1
set PYTHONUTF8=1
set PYTHONIOENCODING=utf-8
set PATH=%CUDA_HOME%\bin;%CONDA_PREFIX%\Lib\site-packages\torch\lib;%PATH%
```

If your CUDA Toolkit is not at `C:\cuda-v13.2`, change those first two lines.

Reactivate the env so those vars load:

```bat
conda deactivate
conda activate vllm-omni
```

### 6. Get The Higgs Model

You can serve directly from Hugging Face:

```bat
set MODEL_PATH=bosonai/higgs-audio-v3-tts-4b
```

Or download it first:

```bat
set MODEL_PATH=C:\models\higgs-audio-v3-tts-4b
python -m pip install -U huggingface_hub
huggingface-cli download bosonai/higgs-audio-v3-tts-4b --local-dir "%MODEL_PATH%"
```

## Start The Server

Open Anaconda Prompt:

```bat
conda activate vllm-omni
cd /d C:\src\vllm-omni

set MODEL_PATH=C:\models\higgs-audio-v3-tts-4b

tools\windows\run_higgs_vllm_omni.cmd
```

For Hugging Face instead of a local folder:

```bat
set MODEL_PATH=bosonai/higgs-audio-v3-tts-4b
```

The first launch loads the model. After that, running the same command again
checks the existing server and does not reload the model if it is already up.

Check readiness:

```bat
tools\windows\run_higgs_vllm_omni.cmd status
```

The server is ready when the status command returns a JSON model list. Logs are
available with:

```bat
tools\windows\run_higgs_vllm_omni.cmd logs
```

## Test TTS

Keep the server running and open another Anaconda Prompt:

```bat
conda activate vllm-omni
cd /d C:\src\vllm-omni

set MODEL_PATH=C:\models\higgs-audio-v3-tts-4b
set MODEL_ID=%MODEL_PATH%

tools\windows\test_higgs_tts.cmd "Hello from native Windows vLLM Omni." hello_higgs.wav
```

For Hugging Face:

```bat
set MODEL_PATH=bosonai/higgs-audio-v3-tts-4b
set MODEL_ID=%MODEL_PATH%
```

The output should be a 24 kHz mono WAV.

## Voice Clone With The Loaded Server

This path keeps the model loaded. Use it for normal repeated generation:

```bat
conda activate vllm-omni
cd /d C:\src\vllm-omni

set MODEL_ID=C:\models\higgs-audio-v3-tts-4b
set REF_AUDIO=C:\audio\reference.wav
set REF_TEXT=Transcript of the reference clip.

tools\windows\clone_higgs_voice.cmd "Text to synthesize in the cloned voice."
```

Files are written to `results\higgs_v3_clone_api` by default. To change that:

```bat
set OUT_DIR=C:\audio\higgs-results
tools\windows\clone_higgs_voice.cmd "Another line to synthesize."
```

## Offline Voice Clone

The offline example is useful for debugging or one-off batch runs. It creates
its own engine, so it reloads the model every time:

```bat
conda activate vllm-omni
cd /d C:\src\vllm-omni

set MODEL_PATH=C:\models\higgs-audio-v3-tts-4b

python examples\offline_inference\text_to_speech\higgs_audio_v3\end2end.py ^
  --model "%MODEL_PATH%" ^
  --deploy-config vllm_omni\deploy\higgs_multimodal_qwen3.yaml ^
  --texts "Text to synthesize in the cloned voice." ^
  --ref-audio C:\audio\reference.wav ^
  --ref-text "Transcript of the reference clip." ^
  --output-dir results\higgs_v3_clone
```

On Windows this example uses `TRITON_ATTN` by default. To force a different
backend, add `--attention-backend NAME`.

## Stop The Server

If the server was started with `tools\windows\run_higgs_vllm_omni.cmd`:

```bat
tools\windows\run_higgs_vllm_omni.cmd stop
```

Use `tools\windows\run_higgs_vllm_omni.cmd restart` to stop and start it again.

## Useful Checks

```bat
conda activate vllm-omni
python -m pip show vllm vllm-omni torch
python -m pip check
vllm-omni serve --help=OmniConfig --omni
curl.exe http://127.0.0.1:8095/v1/models
```

Full generated arg references are included here:

```text
docs\windows\vllm-omni-serve-help-all.txt
docs\windows\vllm-omni-serve-help-omni.txt
```

## What Was Installed / Built

- vLLM is installed from a prebuilt Windows wheel.
- vLLM-Omni is installed from this repo with `python -m pip install -e .`.
- There is no separate vLLM-Omni build command in this setup.
- PyTorch/Triton may JIT-compile kernels on first use, so the first request can
  be slower.

## Why These Windows Flags Exist

- `--attention-backend TRITON_ATTN`: avoids unsupported attention paths on this
  setup.
- `VLLM_USE_FLASHINFER_SAMPLER=0`: avoids FlashInfer sampler JIT issues on
  Windows.
- `VLLM_USE_DEEP_GEMM=0` and `VLLM_MOE_USE_DEEP_GEMM=0`: keep Higgs on the
  validated Windows path.
- `CUDA_HOME=C:\cuda-v13.2`: gives CUDA tools a no-spaces path.
