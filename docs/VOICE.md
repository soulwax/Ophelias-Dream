# Her voice

Her reviewed lines live in `assets/audio/voice/lines.json`: seven page reactions, eleven first-visit observations, and eight idle mutters. They stay close to the notes and what she can feel or see, without settling what happened in the house.

`tools/bake_voice.py` can draft replacement text using the local Qwen server at `127.0.0.1:8765`. Review its output before baking speech; running it overwrites the reviewed lines. The game never calls either model.

## Bake speech

Kokoro-82M ONNX runs on the CPU, with `af_sarah` at speed 0.92. Models and the isolated Python environment stay under ignored `build/voice/`, while the baked `.wav` clips and `manifest.json` are written directly to `assets/audio/voice/` as game assets. Setup from the repository root:

```powershell
python -m venv build/voice/venv
build/voice/venv/Scripts/python.exe -m pip install kokoro-onnx==0.4.7 soundfile==0.14.0
New-Item -ItemType Directory -Force build/voice/models
curl.exe -L --fail -o build/voice/models/kokoro-v1.0.int8.onnx https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.int8.onnx
curl.exe -L --fail -o build/voice/models/voices-v1.0.bin https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
build/voice/venv/Scripts/python.exe tools/bake_speech.py
godot --headless --path . --import
```

Repeat only the last two commands after editing the lines. `--voice` and `--speed` select another delivery. Clips are mono PCM16 wavs named by the SHA-256 of their exact text, levelled to the project's loudest-50-ms reference, with a peak ceiling. `manifest.json` records text, clip names, durations, and delivery settings.

Upstream: [Kokoro ONNX](https://github.com/thewh1teagle/kokoro-onnx), [model releases](https://github.com/thewh1teagle/kokoro-onnx/releases/tag/model-files-v1.0), [Kokoro model and Apache-2.0 license](https://huggingface.co/hexgrad/Kokoro-82M). Synthesis dependencies are build tools, not game dependencies.

## Playback

`Voice` loads imported `AudioStream` resources directly from `res://assets/audio/voice/` using the text hash. Speech plays from her mouth attachment through a Voice bus under Effects, at `Tune.VOICE_SPL` (55 dB at one metre), with the existing room reverb. The murmur plate follows clip duration. Page reactions replace current speech; first-visit observations wait for the cooldown and idle chatter waits until speech and the current subtitle finish. Pausing pauses speech with the scene; endings stop it. No lip sync.

Missing clips fall back to timed text. `RUN_VOICE=0`, `RUN_CAPTURE=1`, and headless mode suppress the feature. Because the baked `.wav` clips live in `assets/audio/voice/`, Godot imports and packs them into the release executable automatically during export; models and Python in `build/` are never shipped.

`tools/fetch_voice.ps1` downloads the optional Qwen writer into `build/llm/`. It uses llama.cpp on the CPU; no NVIDIA GPU is needed for writing or speech baking.
