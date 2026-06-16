# Higgs-Audio V3 TTS

> Multilingual text-to-speech with voice cloning on 1×H100

## Summary

- Vendor: Boson AI
- Model: `bosonai/higgs-audio-v3-tts-4b`
- Task: Text-to-speech synthesis with optional voice cloning (100+ languages)
- Mode: Online serving with the OpenAI-compatible `/v1/audio/speech` API; offline batch inference
- Maintainer: @yuekaiz

## When to use this recipe

Use this recipe to serve `bosonai/higgs-audio-v3-tts-4b` for high-quality
multilingual TTS. The model generates 24 kHz speech, supports zero-shot voice
cloning from a reference clip, and handles 100+ languages with inline control
tokens for emotion, style, and prosody. The architecture is a ~4B Qwen3
backbone with fused multi-codebook embedding/head (8 codebooks × 1026 vocab,
MusicGen-style delay pattern).

## References

- Model card: [bosonai/higgs-audio-v3-tts-4b](https://huggingface.co/bosonai/higgs-audio-v3-tts-4b)
- Offline example: [`examples/offline_inference/text_to_speech/higgs_audio_v3/end2end.py`](../../examples/offline_inference/text_to_speech/higgs_audio_v3/end2end.py)
- Online example: [`examples/online_serving/text_to_speech/higgs_audio_v3/`](../../examples/online_serving/text_to_speech/higgs_audio_v3/)
- Benchmark results: see Performance section below

## Hardware Support

## GPU

### 1×H100 80GB

#### Environment

- OS: Linux
- Python: 3.12+
- CUDA: 12.x
- vLLM version: 0.22.0
- vLLM-Omni version or commit: `36e048fd` (branch `higgs-v3`)

#### Command

**Online serving:**

```bash
vllm-omni serve bosonai/higgs-audio-v3-tts-4b \
    --host 0.0.0.0 --port 8095 \
    --trust-remote-code --omni
```

The default deploy config `vllm_omni/deploy/higgs_multimodal_qwen3.yaml` is
loaded automatically by model registry (HF `model_type=higgs_multimodal_qwen3`).
It matches the high-throughput profile.

**Offline batch inference:**

```bash
python examples/offline_inference/text_to_speech/higgs_audio_v3/end2end.py \
    --texts "Hello world." "The quick brown fox jumps over the lazy dog." \
    --output-dir results/higgs_v3_wavs
```

**Offline voice clone:**

```bash
python examples/offline_inference/text_to_speech/higgs_audio_v3/end2end.py \
    --texts "Text to synthesize in the cloned voice." \
    --ref-audio path/to/reference.wav \
    --ref-text "Transcript of the reference clip." \
    --output-dir results/higgs_v3_clone
```

#### Verification

Basic TTS via curl:

```bash
curl -X POST http://localhost:8095/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d '{
        "model": "bosonai/higgs-audio-v3-tts-4b",
        "input": "Hello, how are you?"
    }' --output hello.wav
```

Voice clone via Python client:

```bash
python examples/online_serving/text_to_speech/higgs_audio_v3/batch_speech_client.py \
    --base-url http://localhost:8095 \
    --model bosonai/higgs-audio-v3-tts-4b \
    --ref-audio path/to/reference.wav \
    --ref-text "Transcript of the reference." \
    --prompts "Text to clone."
```

#### Notes

- Memory usage: Stage 0 (talker, ~4B) uses ~60% GPU memory; Stage 1 (codec decoder) uses ~25%.
- Key flags: `--trust-remote-code` and `--omni` are required.
- Output: 24 kHz mono WAV.
- Voice cloning: `ref_audio` accepts WAV/FLAC/MP3; `ref_text` is optional but improves fidelity.
- Deploy config: `vllm_omni/deploy/higgs_multimodal_qwen3.yaml` (auto-discovered from `model_type`).
  - `max_num_seqs=16` for both stages.
  - Stage 0 and Stage 1 default to the same device (`0`) for single-GPU serving.
  - Stage 0 intentionally keeps `enforce_eager=true`. This preserves the Higgs-specific local MLP CUDA graph path, which is the current high-throughput default.
  - Stage 1 remains `enforce_eager=true` for the codec decoder.
- Deploy profiles:
  - High throughput: `vllm_omni/deploy/higgs_multimodal_qwen3_high_throughput.yaml`.
    Use this for medium/high concurrency. The auto-discovered
    `higgs_multimodal_qwen3.yaml` is kept as a compatibility/default alias for
    this profile.
  - Low latency: `vllm_omni/deploy/higgs_multimodal_qwen3_low_latency.yaml`.
    Use this for low-concurrency serving (for example c1-c4). It sets Stage 0
    `enforce_eager=false` and enables vLLM `FULL_DECODE_ONLY` CUDA graph through
    YAML `compilation_config`; no environment variable is required.
  - Profile details: `vllm_omni/deploy/README_higgs_audio_v3.md`.
- Performance note:
  - Do not switch the auto-discovered default Stage 0 profile to vLLM
    `FULL_DECODE_ONLY` CUDA graph without an end-to-end throughput and
    audio-quality revalidation. On the H20 SeedTTS c16/full-dataset benchmark,
    the eager Stage 0 path with Higgs local MLP CUDA graph reproduced
    ~35 audio_s/s (`1088/1088` OK per run, three runs around 134-136s). A
    separate H20 low-concurrency smoke after the FULL_DECODE audio-feedback
    capture fix showed lower c1/c4 latency, so the FULL_DECODE profile is kept
    as an explicit low-latency option rather than the throughput default.
- Known limitations:
  - Stage 1 (code2wav) must use `enforce_eager=true` (`@torch.inference_mode` incompatible with graph capture).
  - Stage 0 full-decode CUDA graph is experimental; sampler, delay-state updates, staging, and request postprocess remain outside the graph.

### Native Windows, single NVIDIA GPU (experimental)

#### Environment

- OS: Windows 11
- Python: 3.12+
- CUDA: Windows CUDA toolkit, with a no-spaces path recommended for JIT tools
- vLLM version: `0.23.0+cu132` Windows wheel
- vLLM-Omni: native Windows compatibility patches from this fork
- Example local model path: `C:\models\higgs-audio-v3-tts-4b`

#### Command

For complete Windows setup, see `README-WINDOWS.md`. The short version is:

```bat
conda create -n vllm-omni python=3.12 -y
conda activate vllm-omni
python -m pip install path\to\vllm-0.23.0+cu132-cp312-cp312-win_amd64.whl
python -m pip install -e C:\src\vllm-omni
```

After the one-time environment variables from `README-WINDOWS.md` are saved,
start the server with:

```bat
conda activate vllm-omni
cd /d C:\src\vllm-omni
set MODEL_PATH=C:\models\higgs-audio-v3-tts-4b

tools\windows\run_higgs_vllm_omni.cmd
tools\windows\run_higgs_vllm_omni.cmd status
```

Running `tools\windows\run_higgs_vllm_omni.cmd` again checks the existing
server and does not reload the model if it is already running.

On Windows, `--attention-backend TRITON_ATTN` and
`VLLM_USE_FLASHINFER_SAMPLER=0` avoid FlashInfer JIT paths that can fail when
CUDA tools live under paths containing spaces.

Voice cloning through the loaded server:

```bat
set MODEL_ID=C:\models\higgs-audio-v3-tts-4b
set REF_AUDIO=C:\audio\reference.wav
set REF_TEXT=Transcript of the reference clip.

tools\windows\clone_higgs_voice.cmd "Text to synthesize in the cloned voice."
```

The offline voice-clone example also works, but it creates its own engine and
reloads the model every time:

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

The offline example defaults to `TRITON_ATTN` on Windows. Pass
`--attention-backend FLASHINFER` only if your shell has the Visual C++ compiler
available as `cl.exe`.

#### Verification

Check the served model id:

```bat
curl.exe http://127.0.0.1:8095/v1/models
```

If serving from a local model path, the `/v1/audio/speech` request must use
that exact local path as the `model` value:

```bat
set MODEL_ID_JSON=%MODEL_PATH:\=\\%

curl.exe -X POST http://127.0.0.1:8095/v1/audio/speech ^
  -H "Content-Type: application/json" ^
  -d "{\"model\":\"%MODEL_ID_JSON%\",\"input\":\"Hello from native Windows vLLM Omni.\"}" ^
  --output hello_higgs_cmd.wav
```

The output should be a 24 kHz mono WAV.

#### Notes

- The Windows path uses TCP loopback ZeroMQ endpoints instead of Unix `ipc://`.
- Shared payload exchange and stage/device locks use Windows-safe file-backed helpers.
- `fa3-fwd` is skipped on Windows because no compatible Windows wheel is available.
- Keep `CUDA_HOME` and `CUDA_PATH` pointed at a path without spaces, such as a
  junction to the CUDA toolkit directory.
- See `README-WINDOWS.md` for a full CMD runbook, logging commands, stop
  commands, and generated `vllm-omni serve` argument references.
