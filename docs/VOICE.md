# Her voice and journal

The story is the search for Mathilda; see [the design](superpowers/specs/2026-10-06-mathilda-story-design.md). `assets/audio/voice/lines.json` holds 62 reviewed lines: pages, deciphered pages, places, revisits, bored lines and calls by stage, and misreads. Every entry has text and one of seven moods: steady, warm, hushed, shaken, breaking, resolve, calling. Old plain strings load as steady. Do not run `tools/bake_voice.py`: its older format overwrites this reviewed file.

The HUD has a journal notice instead of an objective. J or Tab (pad Y) opens the journal; these bindings can be changed in the Esc menu. Pages retain their order of discovery. Each smudge has three readings and a key from a read page, visited place or heard event. `Game.known` unlocks readings and `Game.decipher` settles the correct one. Solving a whole page reveals its sentence between the lines. With voice off, visiting the snow substitutes for hearing a call; reading the last page substitutes for an echo. The world continues in `Phase.JOURNAL` through `Game.awake()` while movement and look are locked.

## Playback

Zero or one trail pages means hope, two or three means doubt, and four or more (or the last page) means resolve. Earlier idle lines are left behind when the stage changes. Page and deciphered reactions have priority 3, places and revisits 2, and idle lines, calls and misreads 1. Only a strictly higher priority interrupts; a misread can interrupt a misread. Important reactions queue. An interrupted line loses its subtitle and heard status; page and deciphered lines queue again, other lines return at their next natural opportunity. Ending cards interrupt too. Revisits wait `Tune.REVISIT_AFTER`; misreads wait `Tune.MISREAD_GAP`.

Calls cycle within the stage outdoors during play, starting after `Tune.CALL_FIRST`, then waiting `Tune.CALL_EVERY`. The same mouth speaker uses `Tune.CALL_SPL` for calls and `Tune.VOICE_SPL` for other lines. After the post page, doubt and resolve can each produce an echo, up to `Tune.ECHO_MAX`. The same clip returns 1.6–2.4 seconds later from the nearest pine 25–60 metres away through Dread, with distant filtering and `Tune.ECHO_DROP_DB` less level. Echoes have no subtitle.

Clips are mono PCM16 WAVs named by SHA-256 of the exact UTF-8 `text|mood`, plus `.wav`. Voice loads imported resources and plays through the Voice bus under Effects. Missing clips use timed subtitles. `RUN_VOICE=0`, capture and headless runs disable Voice. Models never run in the game and never ship; environments, models and references stay in ignored `build/voice/`.

## GPU baking

From the repository root:

```powershell
uv python install 3.12
uv venv build/voice/gpu-venv --python 3.12
uv pip install --python build/voice/gpu-venv/Scripts/python.exe qwen-tts faster-whisper speechbrain soundfile numpy huggingface_hub
uv pip install --python build/voice/gpu-venv/Scripts/python.exe --reinstall torch torchaudio --index-url https://download.pytorch.org/whl/cu128
build/voice/gpu-venv/Scripts/python.exe -c "import torch; print(torch.__version__, torch.cuda.is_available(), torch.cuda.get_device_name(0))"
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign --local-dir build/voice/hf/VoiceDesign
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-Base --local-dir build/voice/hf/Base
build/voice/gpu-venv/Scripts/hf.exe download mobiuslabsgmbh/faster-whisper-large-v3-turbo --local-dir build/voice/hf/whisper-model
build/voice/gpu-venv/Scripts/hf.exe download speechbrain/spkrec-ecapa-voxceleb --local-dir build/voice/hf/ecapa-model
python tools/bake_speech.py --self-test
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --anchor-only
```

Listen to `build/voice/ref/anchor.wav` before baking the lines. Keep it explicitly, or re-roll with `--anchor-only --new-anchor --anchor-seed N`. Then run `build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --force`. Four VoiceDesign takes receive the identity and mood direction. Whisper measures word error rate (WER); takes with WER ≤ 0.15 compete by highest ECAPA speaker similarity to the anchor. If no take reaches similarity 0.60 with acceptable WER, two Base-clone takes provide a fallback. The final choice is the highest similarity among takes passing WER, so 0.60 triggers fallback rather than imposing a final rejection threshold.

The baker uses CUDA for Qwen. It scores on CUDA when enough memory remains and uses CPU scoring when the GPU is crowded. Each accepted clip is saved immediately, with a manifest checkpoint. Run the command without `--force` to resume missing clips.

`--only "exact line text"` re-bakes a single line. Failed lines are listed and return exit 1; listen and re-bake them, or explicitly keep the best with `--only "exact line text" --accept-bad`. `--engine kokoro` is an optional CPU fallback using the old `build/voice/models/` ONNX files; it needs kokoro-onnx installed in its environment and does not provide mood direction. `--voice` and `--speed` apply to Kokoro. `manifest.json` records text, mood, category, file, duration, engine, model, WER and similarity. Listen to all clips in manifest order after the bake.

Import and verify:

```powershell
godot-mono --headless --path . --import
godot-mono --headless --path . tools/journal_probe.tscn
$env:PROBE_CLIPS = "1"
godot-mono --headless --path . tools/voice_probe.tscn
Remove-Item Env:PROBE_CLIPS
```

[Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) and [SpeechBrain ECAPA](https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb) use Apache-2.0; [faster-whisper](https://github.com/SYSTRAN/faster-whisper) uses MIT. These are build dependencies.
