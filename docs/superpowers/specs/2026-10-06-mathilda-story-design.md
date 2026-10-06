# Looking for Mathilda: story, journal and voice

Date: 2026-10-06. Pieces 1 and 2 of three. Piece 3, bringing Mathilda's model into the world hidden and later rigged to the elf skeleton, gets its own spec.

## Intent

The game had lost its story when the figure and the Listener were removed. The pages and her lines still talk about Mara, a skier, a figure in the tree line and three knocks, and none of that exists any more. The new story gives the snowfield a reason to cross: **she is looking for Mathilda in a snowstorm, and the question is where Mathilda could be.**

The HUD loses its objective. In its place is a **journal** where the pages she has collected can be studied and their smudged words deciphered. Her voice should sound alive: each line is acted with its own direction, she calls Mathilda's name into the storm, and what she says changes as she learns more.

Success:

- A first-time player understands within a minute that Mathilda is missing and that she is searching for her, with no objective on screen.
- The pages can be read and deciphered in any order. Each one changes the question rather than answering it.
- Deciphering rewards exploration: a smudge becomes readable because of something found elsewhere, not by guessing blind.
- The relationship and the final answer stay open: who went out, who is searching, who is under the sheet.
- No two consecutive lines sound like the same reading. An interrupted line leaves no trace and plays whole later.

## The story

Two women share the surname **Aune**. The strap stamp *M. Aune* fits either of them, and the text never says what Mathilda is to her. The protagonist is never named.

She wakes in the cabin during the storm. The lantern is lit and Mathilda is gone. Three threads run through everything:

- **A, the trail of her.** Pages and places are traces of Mathilda, and each points further on: the bed, the pack, the post, the pines, the lights.
- **B, two voices.** The pages are Mathilda writing to "you". The player hears the protagonist out loud and Mathilda only on paper.
- **C, the doubt.** Mathilda's letters say *she* is the one searching for *you*. The prints she describes stop at the pines and fit the reader. Her handwriting turns into the reader's. The intake record could be either of them. Deciphering pushes C further: several smudged words read the more unsettling way.

Nothing resolves C. Both endings are compatible with every reading.

## Pages

`NoteCatalog` keeps its shape: five trail pages in route order, then `bedside()` and `intake()`. `LAST_TITLE` becomes `"don't turn around"`. Lowercase text is the corrupted hand.

In the bodies below, `{word}` marks a **smudge**: a word that can't be read until it is deciphered (see *Journal*). Each page also has a hidden **between-the-lines** sentence that appears once all of its smudges are solved.

**by the bed** (`bedside()`, does not count)

> I lit the lantern so you would see it from the field. Leave it burning.
>
> If you are reading this, you came back and {I} did not. Stay in. I mean it this time. Do not do what you always do, which is come after me.
>
> Put your coat on before you argue with me.
>
> — {M.}

Between the lines: *I left the door unlatched so you could get back in. Or so I could.*

**from the pack** (trail 1)

> Packed for {two}: two cups, one candle (we share), the map. Lookout circled. That is where the road comes up. If the storm closes, go there. Someone always comes up the road.
>
> Left the pack here. Too heavy to run with. You will know it is mine. Follow the {posts}, not the prints. The prints lie in this wind.

Between the lines: *If you find this pack with one cup in it, do not count them again.*

**on the post** (trail 2)

> It is the same afternoon it was. The light has not moved since I left the cabin.
>
> I called your name until I could not hear it over the wind. Then I heard it again, from the trees, in {your} voice.
>
> I did not answer it. If you hear me from the trees, do not {answer} either.

Between the lines: *It called me by your name.*

**torn page** (trail 3)

> —your prints from the step. I followed them as far as the pines. They do not go on and they do not come back. They stop, both feet {together}, as if you stood there and the snow decided you had never been here.
>
> i stood in them. they {fit} me.
>
> I am going on to the lights. If you are behind me, you will find this. If I am behind you, I already did.

Between the lines: *The prints were smaller than mine. Then they were not.*

**the handwriting changes** (trail 4)

> I keep writing to you because writing is the only thing that stays where I put it. The snow does not. The prints do not. the cabin does not. i have passed it twice and it was lit both times and i never went back in.
>
> my letters are going wrong. they lean the way {yours} lean. i know your hand better than mine. i read every list you ever left me. this is your hand now and i am still writing.
>
> if you are reading this, which of us is holding the {pen}.

Between the lines: *hold this next to the page by the bed. same hand. it was always the same hand.*

**don't turn around** (trail 5, `LAST_TITLE`)

> stop looking for me.
>
> go to the lights. the engine has been running since before the snow. someone kept it warm for {one} of us. i will be there or i will not, but you will.
>
> i am right {behind} you. i always was. do not turn around until you reach the road.
>
> — m

Between the lines: *the sheet in the cellar is not me. say it back to me. the sheet is not me.*

**intake** (`intake()`, does not count)

> Brought in from the step during the storm. Length under the sheet: 1.6 m. Strap stamped M. Aune. Given name, as copied: {M—}. Personal effects: one cup. Next of kin: {out searching}. Not yet notified.

Between the lines: *Scratched inside the rim of the cup: M.*

## Journal

### The HUD

The objective plate and the note pips are removed. When a page is collected, a small plate fades in at the bottom left for 3 s: **Added to the journal**, with the journal key hint (`Game.settings.key_label("journal")`). Vignette, heart, warning line, subtitles and reticle stay as they are.

### Opening it

A new rebindable action `journal` goes in `Settings.ACTIONS`: **J** and **Tab**, pad **Back/Select**. It opens from `PLAYING` only, into a new phase `JOURNAL`. Like `READING`, that phase locks movement and look but not the world. The same key, Esc, or the close button returns to `PLAYING`. The note reader's footer gains a key row for it ("Journal").

### Layout

`Journal` (`scripts/ui/journal.gd`) is created by `Hud`, with `UiChrome.paper` styling:

- **Left:** the pages collected, in the order found. A page whose smudges are all solved gets a small ink tick.
- **Right:** the selected page in a `RichTextLabel`. Solved smudges show in ink with a faint underline. Unsolved smudges are a blot of noise glyphs (deterministic per smudge, density from the page's `corruption`) wrapped in a `[url]` meta.
- Clicking an unsolved smudge does one of two things:
  - **Locked:** a muted line under the page says *I can't make this out yet.* plus a hint naming the kind of key: *Something else she wrote might help*, or *Maybe if I saw the place*.
  - **Unlocked:** three readings appear as paper buttons, in an order shuffled per run. Choosing the right one settles it in ink. A wrong one flickers, is struck out, and stays visible but disabled. She may murmur a misread line. There's no penalty and no limit.
- When a page's last smudge is solved, its between-the-lines sentence fades in below the body in a fainter, smaller hand, and she reacts out loud.
- **Gamepad:** focus moves through the page list, the smudges and the readings. Confirm picks.

### Keys

A smudge unlocks when its key is known. A key is a page read (`page:<title>`), a place visited (`place:<name>`, from `Game.visit()`; `Voice._notice` already computes the place and now reports it), or an event (`event:echo`, `event:call`). `Game` stores `visited`, `heard_events` and `deciphered` (title → solved indexes) and clears them all in `reset()`.

| Page | Smudge | Readings (right first) | Key | Why it helps |
|---|---|---|---|---|
| by the bed | {I} | I · you · we | page:torn page | "If I am behind you, I already did." |
| by the bed | {M.} | M. · Mum · Me | page:from the pack | the strap shows how her M is made |
| from the pack | {two} | two · one · three | place:living | the two chairs at the table |
| from the pack | {posts} | posts · lights · trees | page:on the post | it was written on a post |
| on the post | {your} | your · my · her | event:call | she has heard her own call go into the wind |
| on the post | {answer} | answer · follow · listen | event:echo | something called back |
| torn page | {together} | together · bare · apart | place:snow | she has seen her own prints |
| torn page | {fit} | fit · followed · knew | page:the handwriting changes | the hands are already merging |
| the handwriting changes | {yours} | yours · mine · hers | page:by the bed | compare the two hands |
| the handwriting changes | {pen} | pen · lantern · sheet | page:intake | the record's unfinished stroke |
| don't turn around | {one} | one · both · neither | place:lights | she has seen the car |
| don't turn around | {behind} | behind · beside · ahead of | page:on the post | the voice from behind the trees |
| intake | {M—} | M— · Mathilda · nobody | page:from the pack | the strap she copied from |
| intake | {out searching} | out searching · notified · none | page:by the bed | "do what you always do" |

If an echo never happened (for example, she never called while outdoors after *on the post*), `event:echo` falls back to `page:don't turn around`, so every page can be finished.

### Data

`NoteEntry` gains `smudges: Array[Dictionary]` (`{"readings": [...], "key": "..."}`, with the right reading first) and `between: String`. `NoteCatalog._make` parses `{...}` out of the body: the stored body keeps a placeholder `\u0001<index>`, and the reader and journal render each placeholder by its state. `NoteReader` drops the random per-letter corruption. It shows the body with unsolved smudges as blots (the same renderer as the journal), so the first reading in the field already shows what is missing.

## Frame text

- Intro card, under **OPHELIAS DREAM**: *Mathilda went out into the storm.* The Esc line stays.
- No objective anywhere.
- Escape card: title **The road**, body *The engine is running. The driver's door is open, the seat still warm.*
  - If `read_last_page`: add *You didn't turn around.*
  - If every page is deciphered: add *Beside the cup on the dash, a second one. Still warm.*
  - The action stays "Walk the ridge again".
- Caught card defaults stay as they are.

## Her lines

`assets/audio/voice/lines.json`: every entry is `{"text": ..., "mood": ...}`. A plain string still loads with the mood `steady`.

```json
{
  "pages":      { "<title>": {"text", "mood"} },
  "deciphered": { "<title>": {"text", "mood"} },
  "places":     { "<place>": {"text", "mood"} },
  "revisits":   { "<place>": {"text", "mood"} },
  "bored":      { "hope": [...], "doubt": [...], "resolve": [...] },
  "calls":      { "hope": [...], "doubt": [...], "resolve": [...] },
  "misread":    [ ... ]
}
```

Moods: `steady`, `warm`, `hushed`, `shaken`, `breaking`, `resolve`, `calling`.

**Stage** comes from `Game.notes_found`: 0–1 is **hope**, 2–3 is **doubt**, 4 or more (or `read_last_page`) is **resolve**.

### Page reactions (on first reading)

| Page | Line | Mood |
|---|---|---|
| by the bed | "Stay in." She's the one out there, and she's telling me to stay in. | shaken |
| from the pack | Two cups. She packed for both of us. She knew I'd come. | breaking |
| on the post | Then I heard it again, from the trees. Okay. I won't answer. I won't. | hushed |
| torn page | Prints that just stop. She's describing mine. I haven't been to the pines yet. Have I? | shaken |
| the handwriting changes | That's my handwriting. That's how I make my M's. | hushed |
| don't turn around | Don't turn around. Fine. I won't. Just be at the lights. | resolve |
| intake | One cup. Just one. I'm not lifting that sheet. I'm not. | breaking |

### Deciphered (on solving a page's last smudge)

| Page | Line | Mood |
|---|---|---|
| by the bed | She left the door open for me. Or for herself. She never could decide which of us needed rescuing. | warm |
| from the pack | One cup. The intake said one cup. I'm not counting again. I'm not. | breaking |
| on the post | It knew my name. It used my name on her. | shaken |
| torn page | Smaller than mine. Then not. Like the prints were growing into me. | hushed |
| the handwriting changes | Same hand, both pages. I'd know it anywhere. That's what scares me. | hushed |
| don't turn around | The sheet is not her. The sheet is not her. I'll say it all the way to the road. | resolve |
| intake | Just an M. It could be either of us. It could be both. | breaking |

### First visits

| Place | Line | Mood |
|---|---|---|
| bedroom | Her side of the bed is still warm. She can't be far. | warm |
| hall | Her boots are gone. The door isn't even latched. | shaken |
| living | Two chairs pulled out. She sat up with that candle until it went out. | hushed |
| backhall | Mathilda? She wouldn't go down there. She hates the cellar. | hushed |
| stair | If she's down here, she's been quiet a long time. | hushed |
| landing | No wind down here. Just my heart, and I wish it would slow down. | hushed |
| corridor | Why does a cabin need a hallway this long under the ground? | hushed |
| janitor | Someone keeps this place clean. Someone expects to use it. | shaken |
| morgue | No. She wouldn't be here. She's out in the snow. She has to be. | breaking |
| snow | Her prints are already filling in. I have to be faster than the snow. | resolve |
| lights | Headlights. Someone's waiting. Please let it be her. | breaking |

### Revisits

Each plays once: on the first return to the place in the doubt or resolve stage, at least 60 s after the first visit there.

| Place | Line | Mood |
|---|---|---|
| bedroom | The lantern's still lit. Nobody's been here. Or I have, and I don't remember. | shaken |
| hall | I latched it behind me. I know I did. | shaken |
| living | Still two chairs. I keep thinking one of them will be pushed in. | hushed |
| morgue | I said I wouldn't come back down here. I keep coming back down here. | breaking |
| snow | Every set of prints out here could be mine. | hushed |

### Idle mutters (six per stage, in order, each once)

Lines from an earlier stage that were never spoken are dropped once she moves on.

Hope:
- She knows this field better than I do. She'll have found shelter. (steady)
- Ten minutes, she said. Ten minutes, and then the snow came in sideways. (shaken)
- When I find her I'm going to be so angry. And then I'm not letting go. (warm)
- She always leaves something behind so I can find her. Always. (steady)
- Every white shape is her coat, until it isn't. (hushed)
- She'll be cold. She never wears the hat. I should've made her wear the hat. (warm)

Doubt:
- Her prints stop. Mine don't. What does that make me? (shaken)
- I've said her name so many times it's just a sound now. (hushed)
- What if she's back at the cabin, by the lantern, writing to me? (shaken)
- I can't remember which of us said we'd stay. (breaking)
- I keep turning to tell her something. There's nobody to tell. (breaking)
- The light hasn't moved. She was right. It's the same afternoon. (hushed)

Resolve:
- Don't turn around. I can do that. I can do that much. (resolve)
- If she's behind me, she can see me. That has to be enough. (breaking)
- The engine's running. Someone kept it warm for one of us. (hushed)
- Whatever's at the lights, I'm walking up to it. I'm not stopping now. (resolve)
- I'll find you. Or you'll find me. One of us gets to go home. (breaking)
- I'm not cold any more. That's bad, isn't it. Keep walking. (hushed)

### Calls

Outdoors only, during `PLAYING`, never while she is speaking. The first call comes `Tune.CALL_FIRST` (20–30 s) after she first steps into the snow, then every `Tune.CALL_EVERY` (45–80 s, random). Calls cycle within the current stage and may repeat. Each shows as a subtitle and records `event:call`.

- Hope: "Mathilda!" (calling); "Mathilda! Can you hear me?" (calling); "Mathilda! Over here!" (calling)
- Doubt: "Mathilda! Answer me!" (calling); "Mathilda… where are you?" (breaking); "Mathilda! Say something!" (calling)
- Resolve: "Mathilda! I'm coming!" (calling); "Mathilda… please." (breaking); "I'm going to the lights, Mathilda! Meet me there!" (calling)

**Echo.** Once she has read *on the post*, the first call in the doubt or resolve stage is answered 1.6–2.4 s later by the same clip, from the nearest pine 25–60 m away (`Flora.tree_positions()`), on the Dread bus, low-passed and `Tune.ECHO_DROP_DB` (14 dB) quieter. This happens at most `Tune.ECHO_MAX` (2) times per run, never indoors, and with no subtitle. The first echo records `event:echo`.

### Misreads (wrong reading in the journal; may repeat, at most one per 8 s)

- No. That's not it. (hushed)
- That doesn't fit. (steady)
- She'd never write that. (shaken)
- Wrong. Look again. (hushed)
- I want it to say that. It doesn't. (breaking)

Totals: 7 pages, 7 deciphered, 11 places, 5 revisits, 18 idle, 9 calls, 5 misreads, for **62 lines**.

Fallbacks in `voice.gd` change to fit: the missing-page line becomes "She wrote this for me. I have to keep going.", and `_stock_place` lines lose the old story. The `PLACES` descriptions, which only feed the drafter, are rewritten.

### Priority and interruption

Each line has a priority:

| Priority | Lines |
|---|---|
| 3 | page reactions, deciphered |
| 2 | first visits, revisits |
| 1 | idle mutters, calls, misreads |

A line may interrupt a playing line of **lower** priority. A misread may also interrupt another misread. Otherwise it waits, or is skipped if it is a call or a misread.

**Interrupted as if never played.** When a line is cut off:

- its speaker stops at once
- its subtitle is cleared (not faded) if it is still the current murmur
- it is removed from `_spoken_once`, and from whichever of `_heard_pages`, `_seen`, the deciphered set or the revisit set marked it
- an idle line moves `_bored_at` back to it

Nothing records that it started, so it plays whole at its next natural chance: the next idle pause, the next time she is in that place, or the next time the journal is opened on that page. Page reactions and deciphered lines are re-queued directly and play after the interrupting line ends and `VOICE_GAP` / 2 has passed. The same rule covers a line stopped by an ending, so a line cut by the end card doesn't count as heard.

## Voice baking on the GPU

`tools/bake_speech.py` is rewritten around **Qwen3-TTS** (Qwen, Apache-2.0) on CUDA, from Hugging Face:

- **`Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign`** speaks each line from a natural-language instruction, so each mood becomes a direction, not a slider.
- **`Qwen/Qwen3-TTS-12Hz-1.7B-Base`** (3-second voice clone) is the fallback when a take drifts from her voice.

They run in their own environment at `build/voice/gpu-venv`: Python 3.12 via `py -3.12` or `uv`, CUDA torch, and `qwen-tts`. The system Python is 3.14 with CPU-only torch. Models download into `build/voice/hf/` with `huggingface-cli`. Kokoro remains available as `--engine kokoro`.

**Her voice description** (the identity, sent with every line):

> A woman around thirty. A low, soft alto with a little breath in it, plain North American accent. She is cold, tired, and talking quietly to herself in an empty place; never theatrical, never narrating.

**Mood directions** (appended to the description):

| Mood | Direction | Level (loudest 50 ms) |
|---|---|---|
| steady | Calm and even, trying to reassure herself. | −12 dBFS |
| warm | Tender and fond, almost smiling, a catch at the end. | −12 |
| hushed | Barely above a whisper, close and careful, as if something might hear. | −18 |
| shaken | Unsteady, breath short, words coming a little too fast. | −12 |
| breaking | On the edge of tears, voice cracking, pauses where it gives out. | −13 |
| resolve | Low and determined, jaw set, each word placed. | −12 |
| calling | Shouting as loud as she can into a strong wind, straining, desperate. | −10 |

**Anchor.** Before the first bake, the script renders `build/voice/ref/anchor.wav` from the description alone, with the steady direction. You listen to it and can keep it or re-roll it with `--new-anchor`. Every take is compared to it.

**Takes and selection.** Four takes per line. Each is:

1. transcribed with `faster-whisper` (`large-v3-turbo`, CUDA) and scored by word error rate against the text
2. compared to the anchor with an ECAPA speaker embedding (`speechbrain/spkrec-ecapa-voxceleb`, Apache-2.0), scored by cosine similarity

Takes above 15% WER are discarded. Of the rest, the highest similarity wins. If no take reaches 0.60 similarity, the line is re-rendered with the Base model cloned from the anchor (it loses the mood direction but keeps the voice) and flagged in the report. A line with no acceptable take stops the bake unless `--accept-bad`. Leading and trailing silence is trimmed to 60 ms. `--only "<text>"` re-bakes one line.

**Names and manifest.** Clips are named by the SHA-256 of `text + "|" + mood`; `voice.gd` computes the same key. `manifest.json` records text, mood, priority category, file, seconds, WER, similarity, engine and model. The game still never runs a model, and clips are imported and packed as before.

## Code changes

- `scripts/notes/note_entry.gd`: `smudges`, `between`.
- `scripts/notes/note_catalog.gd`: the new text and titles; parse `{…}` into smudges; keys and betweens.
- `scripts/game/game.gd`:
  - `Phase.JOURNAL`, `open_journal()` / `close_journal()`, `locks_movement` / `locks_look`
  - `visited`, `heard_events`, `deciphered`, with `visit()`, `heard()`, `known(key)`, `decipher(title, index, reading) -> bool` and `page_solved(title)`
  - all of it cleared in `reset()`
  - bind `journal`
- `scripts/game/settings.gd`: `journal` in `ACTIONS`.
- `scripts/ui/journal.gd` (new), created by `scripts/ui/hud.gd`.
- `scripts/ui/hud.gd`: remove the objective and pips; add the *Added to the journal* plate; new intro line.
- `scripts/ui/note_reader.gd`: the smudge renderer, no random corruption, the journal key row.
- `scripts/ui/chrome.gd`: a shared `smudge_text(entry, solved) -> String` BBCode helper used by both readers.
- `scripts/ui/end_card.gd`: the escape body and its variants.
- `scripts/player/voice.gd`:
  - parse entries as strings or dicts and key clips by text and mood
  - stages; revisits; priorities and the never-played interruption
  - the call player at `Tune.CALL_SPL` and the echo player
  - `deciphered(title)` and `misread()` entry points; report places to `Game.visit()`
- `scripts/tune.gd`: `CALL_SPL := 82.0`, `CALL_EVERY := Vector2(45, 80)`, `CALL_FIRST := Vector2(20, 30)`, `ECHO_DROP_DB := 14.0`, `ECHO_MAX := 2`, `REVISIT_AFTER := 60.0`, `MISREAD_GAP := 8.0`, `JOURNAL_TOAST := 3.0`.
- `tools/bake_speech.py`: Qwen3-TTS, directions, takes, WER and similarity selection.
- Docs: `docs/VOICE.md`; the Voice and UI paragraphs and the new action in `CLAUDE.md` and `AGENTS.md`; a pointer in `docs/DIRECTION.md`.

Two things are deliberately left alone. `tools/bake_voice.py` (the Qwen drafter) would overwrite these lines and doesn't know the format; VOICE.md says so. The old `hunt_started` logic stays in `Game` as the threat interface; only the HUD stops showing it.

## Testing

- `tools/voice_probe.tscn` (extended):
  - every line loads with a mood and has a clip under its text-and-mood hash
  - stage selection gives hope, doubt and resolve at 0, 2 and 4 notes
  - calls never trigger indoors
  - the echo needs *on the post* and stops after two
  - an interrupted line is absent from every "spoken" set and plays again on the next chance; a lower priority never interrupts a higher one
- `tools/journal_probe.tscn` (new):
  - every catalog page parses with the expected smudge count
  - all smudge keys resolve to a real page, place or event
  - a locked smudge refuses; an unlocked one accepts only its first reading
  - solving the last smudge exposes `between` and calls `Voice.deciphered`
  - the `event:echo` fallback works
  - `reset()` clears everything
  - with all keys known, every page can be finished
- `godot --headless --path . --import` is clean.
- Screenshot smoke tests: the intro card, the reader with blots, and the journal with a half-solved page (`RUN_JOURNAL=<title>` with `RUN_CAPTURE`).
- The bake report lists WER and similarity per line. A listening pass (you) is the real check for "alive".

## Out of scope

- Mathilda's model, decimation, rigging, and her appearing in the world (piece 3).
- New threats; the caught ending text.
- The Qwen drafter.
- Any change to the house, trail or editable level structure.

## Risks

- **Qwen3-TTS on Windows.** `qwen-tts` may expect Linux-only extras (flash-attention). Fall back to the SDPA attention path. If the package won't run, use the Base and VoiceDesign checkpoints through `transformers` directly.
- **Voice drift.** VoiceDesign may give a different-sounding woman on emotional lines. The anchor similarity check and the Base-clone fallback catch that. The listening pass decides whether the directions need softening.
- **Whisper on short emotional lines.** Lines like "Mathilda… please." may trip the WER check. `--accept-bad` per line after listening.
- **Journal readability.** Blots must read as *damaged handwriting*, not a UI bug. Check this in the smudge screenshot before wiring the voice.
