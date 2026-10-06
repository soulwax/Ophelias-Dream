# Editing and generating voice lines

The [complete story and spoken script](../../../docs/MATHILDA_STORY.md) is the place to review wording and story continuity. The actual speech source is [`lines.json`](lines.json). The game reads that JSON and looks for a WAV named by the SHA-256 hash of each line's exact `text|mood`. [`manifest.json`](manifest.json) records the generated clips and their quality scores. Only the WAVs, JSON, and Godot imports are used by the game; the models and Python environment stay under the ignored `build/voice/` directory.

## Change a line by hand

1. Edit the `text` and, if needed, `mood` in `assets/audio/voice/lines.json`. Keep valid JSON and the existing category/key unless you also intend to change when the line plays. The categories are `pages` and `deciphered` (page title), `places` and `revisits` (place name), `bored` and `calls` (`hope`, `doubt`, `resolve` arrays), and `misread` (array). The seven moods are `steady`, `warm`, `hushed`, `shaken`, `breaking`, `resolve`, and `calling`.
2. Change the corresponding line in `docs/MATHILDA_STORY.md` so the review script remains current. Written page text is separate, in `scripts/notes/note_catalog.gd`; changing `lines.json` does not change a page.
3. Run the self-test, then re-bake the exact new text. In PowerShell from the repository root, this example selects the edited **by the bed** reaction directly from JSON, so its punctuation is passed unchanged:

   ```powershell
   python tools/bake_speech.py --self-test
   $line = (Get-Content assets/audio/voice/lines.json -Raw | ConvertFrom-Json).pages.'by the bed'.text
   build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --only $line
   ```

   For another category, change the JSON lookup after `ConvertFrom-Json`. For an idle or call line, select an item from its stage array, such as `.calls.hope[0].text`. `--only` matches the line's text exactly, including punctuation. Editing the mood alone still needs a re-bake: use the same text with `--only`.
4. Listen to the resulting WAV, then run the import and clip probe shown below. A full normal bake later removes old WAVs whose hashes are no longer referenced. Before committing a one-line edit, remove the superseded WAV and its `.import` file yourself if they remain; only remove files you have confirmed are obsolete. Stage the changed JSON, story, manifest, new WAV, and deletions explicitly.

The script currently expects **62 distinct text/mood combinations** in its self-test. If you deliberately add or remove a line, update that assertion in `tools/bake_speech.py` and keep the story script in sync. If you change a page title or place key, update the matching key in `scripts/notes/note_catalog.gd` or `scripts/player/voice.gd` as appropriate and run the journal and voice probes.

## First-time GPU setup

This project uses Qwen3-TTS VoiceDesign on a CUDA GPU. The baker renders four directed takes per line and uses Whisper word error rate and ECAPA similarity to choose a take. If the voice drifts from the anchor, it can render two Base-model clone takes. The game itself never loads these models.

From the repository root on Windows, with `uv` available:

```powershell
uv python install 3.12
uv venv build/voice/gpu-venv --python 3.12
uv pip install --python build/voice/gpu-venv/Scripts/python.exe qwen-tts faster-whisper speechbrain soundfile numpy huggingface_hub
uv pip install --python build/voice/gpu-venv/Scripts/python.exe --reinstall torch torchaudio --index-url https://download.pytorch.org/whl/cu128
build/voice/gpu-venv/Scripts/python.exe -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign --local-dir build/voice/hf/VoiceDesign
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-Base --local-dir build/voice/hf/Base
build/voice/gpu-venv/Scripts/hf.exe download mobiuslabsgmbh/faster-whisper-large-v3-turbo --local-dir build/voice/hf/whisper-model
build/voice/gpu-venv/Scripts/hf.exe download speechbrain/spkrec-ecapa-voxceleb --local-dir build/voice/hf/ecapa-model
python tools/bake_speech.py --self-test
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --anchor-only
```

Listen to `build/voice/ref/anchor.wav`. To try a different base voice, run `--anchor-only --new-anchor --anchor-seed 8` (or another integer), listen again, then use `--force` to re-bake all clips against the chosen anchor. Keep the anchor and local models in `build/voice/`; they are ignored by Git.

## Bake, review, and verify

```powershell
# Resume a partial batch, generating only missing clip hashes:
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py

# Re-generate the complete reviewed script:
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --force

# Import new WAVs and check that every scripted line has a playable clip:
godot-mono --headless --path . --import
$env:PROBE_CLIPS = '1'
godot-mono --headless --path . tools/voice_probe.tscn
Remove-Item Env:PROBE_CLIPS
godot-mono --headless --path . tools/journal_probe.tscn
```

The chosen WAV is saved immediately, and `manifest.json` is checkpointed after each accepted line. A missing or failed line exits nonzero. A transcript with word error rate above 15% is rejected; inspect and listen to that line before explicitly keeping a best take with `--only 'exact line' --accept-bad`. `manifest.json` shows the chosen engine, model, duration, WER, and speaker similarity for each clip. Listen to every changed clip: the scores check words and voice consistency, not acting quality.

For a CPU fallback, `tools/bake_speech.py --engine kokoro` supports the older Kokoro ONNX voice if `kokoro-onnx` and the files under `build/voice/models/` are installed. That path does not provide the Qwen mood direction. See [the voice implementation notes](../../../docs/VOICE.md) for playback behavior and dependencies.

To version a reviewed change, stage only the intended files. For example:

```powershell
git add assets/audio/voice/lines.json assets/audio/voice/manifest.json assets/audio/voice/*.wav docs/MATHILDA_STORY.md
git status --short
git commit -m "Revise Mathilda's reviewed voice script and clips."
```

Do not stage `build/voice/`, `.godot/`, or scratch recordings. The `*.wav` wildcard in the example stages all current voice clips; inspect `git status` before committing.
