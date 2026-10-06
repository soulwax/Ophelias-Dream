# Her voice and journal

The story is the search for Mathilda. Read the [complete story and spoken script](MATHILDA_STORY.md) before changing it: that document is the **script of record**. `python tools/script_to_lines.py` writes `assets/audio/voice/lines.json` from it, and `--check` exits 1 if the two have drifted. The [voice README](../assets/audio/voice/README.md) covers editing and re-performing single lines. Do not run `tools/bake_voice.py`: its old format overwrites the script.

`lines.json` holds 137 lines. Every entry has text and one of fourteen moods: steady, warm, hushed, shaken, breaking, resolve, calling, numb, bitter, pleading, wry, remembering, panicked, spent. Plain strings load as steady. An entry may carry `exaggeration`, `cfg` or `temperature` for the baker; the game ignores them.

The HUD has a journal notice instead of an objective. J or Tab (pad Y) opens the journal; the bindings can be changed in the Esc menu. Each smudge has three readings and a key: a page read, a place visited or an event heard. `Game.known` unlocks readings and `Game.decipher` settles the right one; solving a whole page reveals its sentence between the lines. With voice off, visiting the snow stands in for hearing a call, and reading the last page stands in for an echo. The world goes on in `Phase.JOURNAL` (`Game.awake()`) while movement and look are locked.

## When she speaks

| Group | When | Priority |
|---|---|---|
| `endings` (road, prints) | over the escape card, after `Tune.ENDING_DELAY` | 4 |
| `pages`, `deciphered` | reading a page, solving its last smudge | 3 |
| `turned` | `Game.turn_around()` | 3 |
| `places`, `revisits` | first visit; first return in doubt or resolve after `Tune.REVISIT_AFTER` | 2 |
| `spent` | the sprint runs her out of breath (`Player.exhausted`), at most once per `Tune.SPENT_GAP` | 2 |
| `falls` | a landing at `Tune.FALL_HARD` or faster (`Player.landed_hard`), at most once per `Tune.FALL_GAP` | 2 |
| `bored` | standing still for `Tune.BORED_AFTER` | 1 |
| `memories` | walking outdoors after `Tune.MEMORY_GAP` of quiet | 1 |
| `calls` | outdoors, first after `Tune.CALL_FIRST`, then every `Tune.CALL_EVERY` | 1 |
| `cold` | outdoors for `Tune.COLD_AFTER` in a whiteout or hard gust, then a pause of `Tune.COLD_GAP` | 1 |
| `misread` | a wrong reading in the journal, at most once per `Tune.MISREAD_GAP` | 1 |

**Stages.** `bored`, `memories` and `calls` come in stages:
- **hope:** 0–1 trail pages
- **doubt:** 2–3
- **resolve:** 4 or more, or the last page
- **after:** once she has turned around. Only `bored` has an `after` set; she stops calling and stops remembering.

**Repeats.** `call`, `misread`, `spent` and `fall` may repeat. Every other line plays once per run.

**Interruption.** Only a strictly higher priority interrupts, though a misread may cut a misread. An interrupted line is forgotten as if it never played: its subtitle is cleared, it loses its heard status, and it plays whole at its next chance. Page and deciphered lines queue. Endings interrupt everything.

**The trees answer, in her own voice** (`answers`). After *on the post* is read, the first call she makes in each of the doubt and resolve stages is answered, up to `Tune.ECHO_MAX`:
- **doubt:** "Go, then!" from the nearest pine 25–60 m off, at `CALL_SPL - ANSWER_DROP_DB`
- **resolve:** "I'm right behind you." from 1.4 m behind her (`Player.facing()`), at `VOICE_SPL`

Answers show a subtitle with a leading ellipsis and count as `event:echo`. Without an answer clip, the old wordless echo of her call plays at `ECHO_DROP_DB` down. At the road, if she did not turn around, "Okay." comes from behind the car `Tune.ANSWER_ROAD_DELAY` after her plea. Once she has turned around, nothing answers.

Clips are mono PCM16 WAVs named by the SHA-256 of the exact UTF-8 `text|mood`, plus `.wav`. Voice plays through the Voice bus under Effects, and answers through Dread. Missing clips fall back to timed subtitles. `RUN_VOICE=0`, capture and headless runs disable Voice. No model runs in the game or ships with it.

## Performing her lines

Two environments live in ignored `build/voice/`:

- **`gpu-venv`** (Qwen3-TTS, for the impressions)
- **`cb-venv`** (Chatterbox, for the lines)

Both judge with faster-whisper and SpeechBrain ECAPA.

```powershell
# Once: Chatterbox, plus CUDA torch matching its pin
uv venv build/voice/cb-venv --python 3.12
$env:HF_HOME = "$PWD\build\voice\hf\cache"
uv pip install --python build/voice/cb-venv/Scripts/python.exe chatterbox-tts faster-whisper speechbrain soundfile numpy
uv pip install --python build/voice/cb-venv/Scripts/python.exe --reinstall "torch==2.6.0" "torchaudio==2.6.0" --index-url https://download.pytorch.org/whl/cu124
```

The `gpu-venv` setup and model downloads (`VoiceDesign`, `whisper-model`, `ecapa-model` under `build/voice/hf/`) are as before:

```powershell
uv venv build/voice/gpu-venv --python 3.12
uv pip install --python build/voice/gpu-venv/Scripts/python.exe qwen-tts faster-whisper speechbrain soundfile numpy huggingface_hub
uv pip install --python build/voice/gpu-venv/Scripts/python.exe --reinstall torch torchaudio --index-url https://download.pytorch.org/whl/cu128
build/voice/gpu-venv/Scripts/hf.exe download Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign --local-dir build/voice/hf/VoiceDesign
build/voice/gpu-venv/Scripts/hf.exe download mobiuslabsgmbh/faster-whisper-large-v3-turbo --local-dir build/voice/hf/whisper-model
build/voice/gpu-venv/Scripts/hf.exe download speechbrain/spkrec-ecapa-voxceleb --local-dir build/voice/hf/ecapa-model
```

The run itself:

```powershell
python tools/script_to_lines.py --check
python tools/bake_speech.py --self-test
# 1. Impressions: 4 candidate performances per mood; one is picked automatically
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --impressions
# 2. One voice: convert every mood's impression to steady's voice
$env:HF_HOME = "$PWD\build\voice\hf\cache"
build/voice/cb-venv/Scripts/python.exe tools/bake_speech.py --unify
# 3. Every line, cloned from its mood's reference
build/voice/cb-venv/Scripts/python.exe tools/bake_speech.py --force
```

**What is committed.** Everything a bake depends on lives in `tools/voice/`, which Godot ignores (`.gdignore`) so none of it ships:
- the per-mood references (`ref/<mood>.wav`)
- the raw impression picks (`ref/raw/`)
- the approved anchor (`ref/anchor.wav`)
- `voice_lock.json`: models, package versions, seeds, the mood table and the picks
- the frozen `requirements-gpu-venv.txt` and `requirements-cb-venv.txt`

To rebuild an environment exactly, install from its requirements file with `uv pip install -r`, using the CUDA index noted for torch. After changing the environments or moods, run `--lock` in each venv; with gpu-venv, add `--picks mood=n,...`. Candidates, `review.html` and `impressions.html` are regenerable scratch in `build/voice/`.

**Impressions.** Each impression is a short reference performance written to draw out its mood: a whisper, a crack, a shout into wind.
- **Rendering:** Qwen3-TTS VoiceDesign renders four candidates per mood from her identity description plus the mood's direction, into `build/voice/candidates/`.
- **Picking:** *steady* is picked by ECAPA similarity to `ref/anchor.wav`, and every other mood by similarity to *steady*. The pick is copied to `tools/voice/ref/<mood>.wav` and `ref/raw/<mood>.wav`.
- **Listening:** `build/voice/impressions.html` lets you listen to every candidate.
- **Changing them:** swap a pick with `--impressions --moods hushed --pick hushed=2`; re-roll a mood with `--moods <m> --candidates 6`.

**One voice.** VoiceDesign renders each mood as a slightly different woman: before unifying, similarity to *steady* ran 0.13–0.50. `--unify` (in cb-venv) runs Chatterbox's voice conversion over each raw pick with *steady* as the target. That keeps the delivery and gives it her voice, raising similarity to 0.58–0.85 with the words intact. Run it after any change to the impressions.

**Lines.** Chatterbox clones each line from its mood's impression and drives it with that mood's `exaggeration`, `cfg_weight` and `temperature` (the table in `tools/bake_speech.py`). It renders three takes:
- takes Whisper hears with more than 15% word error rate are dropped ("Mathilda" and "Matilda" count as the same)
- the remaining take most similar to the impression wins
- that take is trimmed and levelled per mood

`build/voice/review.html` lists every clip by group with its mood and scores. **Listening to it is the real check.**

**Single lines.** `--only "exact text"` or `--mood <mood>` re-performs just those. A line with no passing take is skipped with exit 1; keep its best take with `--accept-bad`. `--engine kokoro` is the old CPU voice without moods.

**Nothing is deleted.** `--scrap` moves every clip to `build/voice/archive/<date>-qwen/`. A replaced clip goes to `<date>-replaced/`, and a clip no longer in the script to `<date>-stale/`.

```powershell
godot-mono --headless --path . --import
godot-mono --headless --path . tools/journal_probe.tscn
$env:PROBE_CLIPS = "1"; godot-mono --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS
```

[Chatterbox](https://github.com/resemble-ai/chatterbox) is MIT. [Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) and [SpeechBrain ECAPA](https://huggingface.co/speechbrain/spkrec-ecapa-voxceleb) are Apache-2.0, and [faster-whisper](https://github.com/SYSTRAN/faster-whisper) is MIT. All are build tools, not game dependencies.

## Mathilda’s optional chapter

Her separate first-person chapter uses `docs/MATHILDA_POV.md` as its script and `tools/bake_mathilda.py` to write and perform `assets/audio/voice/mathilda/lines.json`. The initial distinct performance uses the existing local Kokoro models with af_bella, speed 0.94; mood labels are editorial direction rather than Chatterbox mood cloning. Ophelia’s 137 lines and trees remain unchanged. All 36 Mathilda clips are namespaced separately and follow the same text|mood SHA-256 convention.
