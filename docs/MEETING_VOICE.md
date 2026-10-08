# The doorway meeting: voice pipeline

How the argument between Ophelia and Mathilda at the cabin door goes from script to scene. The script is `docs/MATHILDA_MEETING.md`; the tree that joins its lines is `assets/dialogue/meeting.json`; the runtime is `docs/DIALOGUE.md`.

## Principles

- **The script is the source of truth.** `MATHILDA_MEETING.md` carries speaker, mood, pause, reaction, what each line answers, and intensity. The pipeline adds to that file and never replaces it.
- **Clips are baked dry; the game does the room.** Voices are positional `AudioStreamPlayer3D`s on the `Voice` bus, and the Room/Cellar reverbs already exist. Reverb baked into a clip would give the doorstep two acoustics. The offline mix is for review only.
- **One fixed identity per speaker.** Ophelia is conditioned only on `tools/voice/ref/<mood>.wav`, and Mathilda only on `tools/voice/ref/mathilda/<mood>.wav`. They are never mixed.
- **Every stage writes a file that can be checked.** `--check` fails when the script and anything derived from it drift apart.
- **Coherence is a hard requirement.** In a heated exchange, one line that answers the wrong thing or comes in the wrong voice breaks the scene. The checks below are gates, not polish.

## Coherence rules

These are enforced by `python tools/bake_meeting.py --check`, which fails otherwise:

1. **Each line answers the line before it.** Every line has an `Action / reaction:` and an `Answers: <id> "<quote>"`. The quote must appear in that line's text. Only the opening line answers `none`. Leaving and coming back answer `any`.
2. **Emotion carries over.** Every line has an `Intensity:` from 0 to 1. Between any two lines the tree can play back to back, including where side topics rejoin the spine, the jump may not exceed 0.4 unless the later line is marked `Break: yes`. 10 "Yes." and 16 "the milk" are marked breaks. Coming back after walking away is exempt, because a real silence falls there.
3. **Overlaps only where written.** `Overlap: <seconds>` lets a line cut in over the end of the previous one. It is never added automatically, and is refused between two lines of the same speaker. None are written yet.
4. **Timing is exact.** Authored pauses go through `timing.json` unchanged; there is no global gap. A skipped line still leaves a beat (`Conversation.SKIP_BEAT`, 0.35 s, or the authored pause if shorter).
5. **Review the argument, not the clips.** `python tools/bake_meeting.py --paths` prints every path through the tree as a transcript; there are 64 now. `tools/meeting_probe.tscn` plays two of them through the real game and prints them. A path with one weak line fails as a whole.

The intensity curve in the script is a first draft for the author to correct.

## Stages

| # | Stage | Tool | Output | Status |
|---|---|---|---|---|
| 0 | Script | the author, in `MATHILDA_MEETING.md` | lines with id, speaker, mood, pause, reaction, answers, intensity, break, overlap | **built**; `--check` enforces it |
| 1 | Direction pass | `tools/direct_meeting.py`, an optional LLM helper with a strict JSON schema | `build/voice/meeting/direction.json`: emphasis, breaths, intensity, each quoting the line it reacts to. Never words. The author accepts proposals line by line into the `.md` | not built (last in the build order) |
| 2 | Lines table | `bake_meeting.py --write` | `assets/audio/voice/meeting/lines.json` and `timing.json` | **built** |
| 3a | Impressions | `bake_speech.py --impressions` / `--unify` | Ophelia: `tools/voice/ref/<mood>.wav` (exists). Mathilda: `tools/voice/ref/mathilda/<mood>.wav`, designed from her own identity prompt or from Kokoro af_bella performances unified by voice conversion, then locked in `voice_lock.json` | Ophelia done; **Mathilda not built** |
| 3b | Performance | `bake_meeting.py --engine chatterbox` (desktop, CUDA, `build/voice/cb-venv`) | 3 takes per line; exaggeration leans on the mood's own value by intensity | **written, not yet run** (needs CUDA and Mathilda's refs) |
| 3c | Drafts | `bake_meeting.py --engine kokoro` (CPU) | `meeting/draft/<key>.wav`, used by the game only when no final clip exists | **built** |
| 4 | Scratch-track path | `tools/revoice.py` on Chatterbox VC | your recorded read of a key beat (09, 16, 17, 24) converted to the speaker's timbre, keeping your timing and breath. Recorded with consent; scratch audio stays out of the repo (`build/voice/scratch/`) | not built |
| 5 | Judge | `bake_speech.Judge` inside 3b | Whisper WER ≤ 0.15 **and** speaker similarity ≥ `MIN_SIMILARITY` (0.72, stricter than the field lines) against that speaker's ref; among the passing takes, the one whose loudness change from the line it answers best fits the intensity change wins | **written, not yet run** |
| 6 | Clean and level | `dialogue_post.clean()` | shared 70 Hz high-pass, trim, 8 ms de-click fades, per-mood dBFS level, one matched noise floor (−72 dBFS), so both voices sit in one dry room | **built** (applied to drafts and takes) |
| 7 | Timing sheet | `tools/dialogue_post.py` | `meeting/timing.json`: per line the source (final, draft, none), file, length, pause, overlap. `Conversation` reads it | **built** |
| 8 | Preview mix | `dialogue_post.py --preview` | `build/voice/meeting/preview_<path>.wav` per path through the tree (doorstep impulse response, ambience bed, authored overlaps) and `review.html`. Never shipped | not built |
| 9 | In game | `Conversation`, `OpheliaNpc`, `Loudness.voice`, reverb buses, Ambience/Dread duck | the live scene | **built** |

## Who decides what

- Words, mood, pause, what a line answers, intensity: the author, in the `.md`.
- Emphasis and breaths: stage 1 proposes, the author accepts, the `.md` records.
- Timbre and identity: the locked refs (3a).
- Delivery: Chatterbox (3b), or the author's own read through voice conversion (4).
- Correct words, the right voice, continuity: the Judge (5).
- Loudness, tone match, cadence: post (6, 7).
- Space and acoustics: the game (9), never the clips.

## Sign-off

Nothing moves from `draft/` to final until the full-path previews (stage 8) have been heard start to finish and signed off in `review.html`. A weak line is re-taken in context: conditioned on the previous line's audio and text where the engine allows, and judged against it.

## Files

```
docs/MATHILDA_MEETING.md            script of record
assets/dialogue/meeting.json        the tree
tools/bake_meeting.py               lines table, coherence check, paths, drafts, Chatterbox bake
tools/dialogue_post.py              clean, level, timing sheet (preview mix to come)
tools/meeting_probe.tscn            the meeting on the real chapter
tools/voice/ref/mathilda/*.wav      Mathilda's locked mood refs (to come)
assets/audio/voice/meeting/         final clips, lines.json, timing.json
assets/audio/voice/meeting/draft/   Kokoro drafts (fallback only)
build/voice/meeting/                direction.json, takes, previews, review.html
```

## Commands

```powershell
python tools/bake_meeting.py --check     # script, tree, lines.json, timing.json; coherence
python tools/bake_meeting.py --write     # after editing the script
python tools/bake_meeting.py --paths     # every path as a transcript
build/voice/venv/Scripts/python.exe tools/bake_meeting.py --engine kokoro        # drafts (CPU)
build/voice/cb-venv/Scripts/python.exe tools/bake_meeting.py --engine chatterbox # finals (CUDA)
godot --headless --path . tools/meeting_probe.tscn
```
