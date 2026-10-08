# Editing and performing her lines

The [story and spoken script](../../../docs/MATHILDA_STORY.md) is the script of record. [`lines.json`](lines.json) is generated from it by `tools/script_to_lines.py`; don't hand-edit the JSON. The game looks for a WAV named by the SHA-256 of each line's exact `text|mood`. [`manifest.json`](manifest.json) records each clip's mood, scores and the impression it was cloned from. Models, environments and references stay in ignored `build/voice/`. See [docs/VOICE.md](../../../docs/VOICE.md) for when each group plays and how to set up the two environments.

## Change a line

1. Edit the line, or its `[mood]`, in `docs/MATHILDA_STORY.md` under *Spoken script*. Keep the bullet format (`- [mood] text`, or `- **key:** [mood] text` for pages, places, answers and endings). The fourteen moods are steady, warm, hushed, shaken, breaking, resolve, calling, numb, bitter, pleading, wry, remembering, panicked and spent. Written page text is separate, in `scripts/notes/note_catalog.gd`.
2. Regenerate and check:

   ```powershell
   python tools/script_to_lines.py
   python tools/bake_speech.py --self-test
   ```

   If you added or removed lines on purpose, update the counts in the self-test, in `tools/voice_probe.gd`, and in the story's total.
3. Perform just that line (quote it exactly, punctuation included):

   ```powershell
   $env:HF_HOME = "$PWD\build\voice\hf\cache"
   build/voice/cb-venv/Scripts/python.exe tools/bake_speech.py --only "Every set of prints out here could be mine."
   ```

   The old clip, if any, moves to `build/voice/archive/<date>-replaced/`. A clip whose line left the script moves to `<date>-stale/` on the next full bake. Nothing is deleted.
4. Listen in `build/voice/review.html`, then import and probe:

   ```powershell
   godot-mono --headless --path . --import
   $env:PROBE_CLIPS = '1'; godot-mono --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS
   ```

## Change how a mood sounds

Each mood has a committed reference in `tools/voice/ref/<mood>.wav`. It is the picked impression (kept raw in `ref/raw/`), converted to *steady*'s voice by `--unify`. Listen to the candidates in `build/voice/impressions.html` and choose another with:

```powershell
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --impressions --moods hushed --pick hushed=2
$env:HF_HOME = "$PWD\build\voice\hf\cache"
build/voice/cb-venv/Scripts/python.exe tools/bake_speech.py --unify --moods hushed
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --lock --picks hushed=2
```

Commit the changed `tools/voice/` files with the new clips.

To re-roll a mood, run `--impressions --moods hushed --candidates 6`. Then re-perform the lines in that mood with `--mood hushed` (in `cb-venv`). Their acting controls (exaggeration, cfg_weight, temperature, level) are in the `MOODS` table in `tools/bake_speech.py`. A single line can override them in the script via `OVERRIDES` in `tools/script_to_lines.py`.

Stage only the intended files: `docs/MATHILDA_STORY.md`, `lines.json`, `manifest.json` and the new WAVs. Never stage `build/voice/` or `.godot/`.
