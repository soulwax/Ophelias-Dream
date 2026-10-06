# Looking for Mathilda, part two: the Jungian story, her performance, and the third ending

Date: 2026-10-06. This supersedes the *Pages*, *Frame text*, *Her lines* and *Voice baking* sections of `2026-10-06-mathilda-story-design.md`. The journal, smudges, keys, priorities and interruption rules from that spec stay as built.

The full text (every page, ending and spoken line) is in **`docs/MATHILDA_STORY.md`**, which is the script of record. This spec covers what has to change in the game and the tools to perform it.

## Intent

Make the search gripping and heartbreaking without losing the person. The symbolic layer (persona, shadow, descent, projection, mandala, union of opposites, read through alchemy's nigredo, albedo and rubedo) is carried only by images and never named. What the player hears is a woman who said a cruel thing to someone she loves, is out in a storm trying to take it back, and slowly understands that what she sent out into the cold was part of herself.

Success:

- The first two lines on screen ("Mathilda went out into the storm." / "You told her to.") make the player care before they move.
- Every spoken line sounds like a person talking to herself, not like narration: disfluencies, dark jokes, bargaining, memories that change as she tells them.
- Fourteen distinct, recognisable moods, all in one recognisable voice.
- Turning around matters: two endings that are both true and both cost something.
- All earlier voice output is scrapped. Nothing is reused, and nothing is deleted outright.

## What changes in the game

### Text (no new systems)

- `NoteCatalog`: the seven page bodies and their between-the-lines sentences, as in MATHILDA_STORY.md. Titles, smudge words, readings and keys are unchanged.
- `Hud` intro card: a second muted line under *Mathilda went out into the storm.*: *You told her to.*
- `EndCard`: the road text stays, and a second escape variant is added (below).

### New line categories

`lines.json` gains these groups (the full text is in MATHILDA_STORY.md):

| Group | Shape | Trigger | Priority |
|---|---|---|---|
| `revisits` | now all 11 places | unchanged rule | 2 |
| `bored` | `hope`, `doubt`, `resolve` (10 each), plus a new stage **`after`** (6) | unchanged: standing still | 1 |
| `memories` | `hope`, `doubt`, `resolve` (5 each) | outdoors, walking (flat speed > 1.0 m/s), `PLAYING`, nothing said for `Tune.MEMORY_GAP` (50 s); each once, in order within the stage | 1 |
| `calls` | 5 per stage | unchanged, but **never after she turns around** | 1 |
| `spent` | 8 | the exhaustion stumble starts (`Player.exhausted`); random, at most once per `Tune.SPENT_GAP` (20 s) | 2 |
| `cold` | 6 | outdoors without a break for `Tune.COLD_AFTER` (120 s) and `Game.weather.whiteout > 0.5` or `gust > 0.6`; each once, then not again for `Tune.COLD_GAP` (90 s) | 1 |
| `falls` | 5 | a landing with fall speed ≥ `Tune.FALL_HARD` (7.5 m/s) (`Player.landed_hard`); random, at most once per `Tune.FALL_GAP` (15 s) | 2 |
| `turned` | 1 | `Game.turn_around()` | 3 |
| `endings` | `road`, `prints` | spoken over the escape card | 4 |
| `misread` | 10 | unchanged | 1 |

The stage is `after` once `Game.turned_around`, otherwise as before. `memories` have no `after` set; she stops reminiscing once she has turned. `spent`, `falls` and `misread` may repeat; every other group plays each line once per run. A `spent` or `falls` line may interrupt idle talk, a memory or a call, and is forgotten if it is itself cut off, under the interruption rule from the first spec.

Each line may carry optional overrides for the baker: `"exaggeration"`, `"cfg"` and `"temperature"` (numbers) and `"note"` (a free comment for the reviewer). The game ignores them.

### The third ending: turning around

- `Player` exposes `glance` (0–1, it already exists). `Game._process`, while `PLAYING`, counts how long `glance > 0.9` has held. Once it reaches `Tune.TURN_HOLD` (1.0 s), `Game.turn_around()` runs, provided all three hold:
  - `read_last_page`
  - `not turned_around`
  - she is outdoors
- `turn_around()` sets `turned_around`, emits `turned`, calls `voice.turned()`, and marks the Blackbox.
- `Voice`: speaks the `turned` line; stops calls and scheduled echoes; switches the idle stage to `after`.
- `EndCard` on `ESCAPED`:
  - if `turned_around`: title **One set of prints**, with that body, plus *On the dash, two cups, one fitted inside the other.* if every page is deciphered
  - otherwise: **The road**, as before
  - the action stays "Walk the ridge again"
- `Voice` on `ESCAPED`: instead of falling silent, it waits 1.2 s and speaks `endings.prints` or `endings.road` (priority 4). It still interrupts and forgets any line that was playing, as before. `CAUGHT` still silences her.

### New hooks

- `Player`: `signal exhausted` (emitted where `exhaust_left = Tune.EXHAUST_LOCK` is set before `_stumble()`) and `signal landed_hard(fall_speed: float)` (emitted in `_land()` when `fall_speed >= Tune.FALL_HARD`).
- `Game`: `turned_around`, `signal turned`, `turn_around()`, `_turn_hold`; all cleared in `reset()`.
- `Tune`:
  - `MEMORY_GAP := 50.0`, `SPENT_GAP := 20.0`, `FALL_GAP := 15.0`, `FALL_HARD := 7.5`
  - `COLD_AFTER := 120.0`, `COLD_GAP := 90.0`, `TURN_HOLD := 1.0`, `ENDING_DELAY := 1.2`

## Her performance: the voice pipeline, redone

### Scrap, but keep a copy

The Qwen-era clips, their `.import` files and `manifest.json` move to `build/voice/archive/2026-10-06-qwen/`. From now on `bake_speech.py` **never deletes** a clip. A clip whose line no longer exists moves to `build/voice/archive/<date>/`.

### Model

**Chatterbox** (Resemble AI, MIT, 0.5B), the original model rather than Turbo, on CUDA in `build/voice/gpu-venv` (`pip install chatterbox-tts`). It clones a reference performance and has `exaggeration`/`cfg_weight` controls, so voice and acting come out of one pass. Clips stay named `sha256(text|mood).wav`.

### Step 1: impressions, one reference performance per mood

For each of the 14 moods, the baker renders **four candidate impressions** with Qwen3-TTS VoiceDesign (already installed): her identity description, the mood's direction, and a short performance text written to draw out that mood (below). Each candidate is 8–14 s. The ECAPA similarity of each to the chosen *steady* impression is printed to help keep one voice. **You pick one per mood by ear.** The pick is copied to `build/voice/ref/<mood>.wav`. The *steady* impression is chosen first and anchors the rest.

| Mood | Performance text for the impression |
|---|---|
| steady | Okay. The kettle's on, the door's shut, the lantern's lit. Everything is where it should be. I'm fine. |
| warm | You always do this. You show up late with snow in your hair and you think a smile fixes it. ...It does, a bit. |
| hushed | Shh. Don't move. If we stay very still, maybe it won't hear us breathing. |
| shaken | I don't... I don't understand, it was right here, I put it right here, I know I did. |
| breaking | I'm sorry. I'm so sorry. I didn't mean it, I never meant any of it, please come back. |
| resolve | No. I'm not stopping. Not now. I'll walk until there's nowhere left to walk. |
| calling | Can you hear me? Hello? I'm over here! Over here! |
| numb | It doesn't hurt any more. That's the strange part. Nothing hurts. It's all very far away. |
| bitter | Oh, of course. Of course you did. You always get to leave, and I always get to clean up after. |
| pleading | Please. I'll do anything. Just this once. Just let her be all right, and I won't ask for anything else. |
| wry | Well. That went about as well as everything else today. Brilliant. Really. |
| remembering | We used to skate on the lake when it froze. She'd hold my hands and go backwards, laughing, the whole way across. |
| panicked | No no no, where is it, where did it go, I can't, I can't breathe, where is it... |
| spent | Wait... wait... I just... I need... one second. Okay. Okay. |

### Step 2: bake every line

Each line is cloned from its mood's impression with that mood's controls, unless the line overrides them:

| Mood | exaggeration | cfg_weight | temperature | level (loudest 50 ms) |
|---|---|---|---|---|
| steady | 0.45 | 0.50 | 0.80 | −12 dBFS |
| warm | 0.55 | 0.45 | 0.80 | −12 |
| hushed | 0.35 | 0.55 | 0.70 | −18 |
| shaken | 0.70 | 0.40 | 0.85 | −12 |
| breaking | 0.85 | 0.35 | 0.90 | −13 |
| resolve | 0.55 | 0.45 | 0.75 | −12 |
| calling | 1.00 | 0.30 | 0.85 | −9 |
| numb | 0.25 | 0.60 | 0.60 | −15 |
| bitter | 0.75 | 0.40 | 0.85 | −11 |
| pleading | 0.70 | 0.35 | 0.85 | −13 |
| wry | 0.50 | 0.45 | 0.85 | −13 |
| remembering | 0.40 | 0.50 | 0.75 | −14 |
| panicked | 0.95 | 0.30 | 0.95 | −11 |
| spent | 0.80 | 0.35 | 0.90 | −13 |

- **Takes:** three per line, seeds 1–3.
- **Words:** `faster-whisper` `large-v3-turbo` transcribes each take. Takes with a WER above 0.15 are dropped; "Mathilda" and "Matilda" count as the same word.
- **Voice:** of the takes that pass, the one with the highest ECAPA similarity to its mood's impression wins.
- **Finish:** silence trimmed to 60 ms, then levelled per mood.
- **Bad lines:** a line with no passing take is reported and skipped unless `--accept-bad`.
- **Flags:** `--only "<text>"` and `--mood <mood>` re-bake a single line or one mood.
- **Engines:** `--engine qwen` stays (used for impressions) and `--engine kokoro` stays as the CPU fallback.

### Step 3: a review page

After a bake, the script writes `build/voice/review.html`: every line grouped by category, with its mood, an `<audio>` player pointing at the clip, and its WER and similarity. You open it in a browser, listen, and note lines to redo with `--only`. It is local and never published.

## Testing

- **`tools/voice_probe.tscn`:**
  - **Line counts:** 134 lines across the groups above; every mood is one of the 14.
  - **Ending lines:** they play on `ESCAPED`.
  - **Groups that may not repeat:** `memories` play once each and only while walking outdoors.
  - **Rate limits:** `spent` and `falls` respect their gaps.
  - **Turning around:** after `turn_around()`, calls stop and the stage is `after`.
  - **Clips:** with `PROBE_CLIPS=1`, every line has a clip.
- **`tools/journal_probe.tscn`:** unchanged, plus:
  - `turn_around()` is refused before the last page, indoors, or a second time
  - `reset()` clears `turned_around`
  - the end card picks its title from it
- `python tools/bake_speech.py --self-test`: line parsing (all groups), the clip-name rule, WER normalisation (Mathilda/Matilda), the mood table covering all 14.
- Screenshots: the intro card with both lines; each escape card, through a `RUN_ENDING=road|prints` dev hook with `RUN_CAPTURE`.
- The listening pass on `review.html` is the real acceptance test.

## Out of scope

Mathilda's model (piece 3); new threats; the caught ending; any change to the journal's rules or smudge keys.

## Risks

- **Chatterbox on Windows and Python 3.12.** It pins its own torch version. Install it before the CUDA torch reinstall, then verify `torch.cuda.is_available()`. If it can't share the venv with `qwen-tts`, use a second venv, `build/voice/cb-venv`.
- **Impressions drifting apart.** Fourteen VoiceDesign renders can sound like different women. Anchoring on *steady* and showing similarity scores helps; you have the final say.
- **Long lines.** Memories run 2–4 sentences, and Chatterbox can rush or drop words on long inputs. The WER check catches dropped words; a rushed line gets a per-line `cfg` override.
