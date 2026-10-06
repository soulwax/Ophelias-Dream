# Looking for Mathilda: story and voice

Date: 2026-10-06. Pieces 1 and 2 of three. Piece 3, bringing Mathilda's model into the world hidden and later rigged to the elf skeleton, gets its own spec.

## Intent

The game had lost its story when the figure and the Listener were removed. The pages and her lines still talk about Mara, a skier, a figure in the tree line and three knocks, and none of that exists any more. The new story gives the snowfield a reason to cross: **she is looking for Mathilda in a snowstorm, and the question is where Mathilda could be.**

Her voice should sound alive. Each line is acted with its own emotion, she calls Mathilda's name into the storm, and what she says changes as she learns more.

Success:

- A first-time player understands within a minute that Mathilda is missing and that she is searching for her.
- The pages can be read in any order, and each one changes the question rather than answering it.
- The relationship and the final answer stay open: who went out, who is searching, who is under the sheet.
- No two consecutive lines sound like the same reading.

## The story

Two women share the surname **Aune**. The strap stamp *M. Aune* fits either of them, and the text never says what Mathilda is to her. The protagonist is never named.

She wakes in the cabin during the storm. The lantern is lit and Mathilda is gone. Three threads run through everything:

- **A, the trail of her.** Pages and places are traces of Mathilda, and each points further on: the bed, the pack, the post, the pines, the lights.
- **B, two voices.** The pages are Mathilda writing to "you". The player hears the protagonist out loud and Mathilda only on paper.
- **C, the doubt.** Mathilda's letters say *she* is the one searching for *you*. The prints she describes stop at the pines and fit the reader. Her handwriting turns into the reader's. The intake record could be either of them.

Nothing resolves C. Both endings are compatible with every reading.

## Pages

`NoteCatalog` keeps its shape: five trail pages in route order, then `bedside()` and `intake()`. Corruption values stay in the same ranges. `LAST_TITLE` becomes `"don't turn around"`. Lowercase text is the corrupted hand, as before.

**by the bed** (`bedside()`, does not count, 0.10)

> I lit the lantern so you would see it from the field. Leave it burning.
>
> If you are reading this, you came back and I did not. Stay in. I mean it this time. Do not do what you always do, which is come after me.
>
> Put your coat on before you argue with me.
>
> — M.

**from the pack** (trail 1, 0.0)

> Packed for two: two cups, one candle (we share), the map. Lookout circled. That is where the road comes up. If the storm closes, go there. Someone always comes up the road.
>
> *(a later line, pressed hard)* Left the pack here. Too heavy to run with. You will know it is mine. Follow the posts, not the prints. The prints lie in this wind.

**on the post** (trail 2, 0.10)

> It is the same afternoon it was. The light has not moved since I left the cabin.
>
> I called your name until I could not hear it over the wind. Then I heard it again, from the trees, in my own voice.
>
> I did not answer it. If you hear me from the trees, do not answer either.

**torn page** (trail 3, 0.28)

> —your prints from the step. I followed them as far as the pines. They do not go on and they do not come back. They stop, both feet together, as if you stood there and the snow decided you had never been here.
>
> i stood in them. they fit me.
>
> I am going on to the lights. If you are behind me, you will find this. If I am behind you, I already did.

**the handwriting changes** (trail 4, 0.48)

> I keep writing to you because writing is the only thing that stays where I put it. The snow does not. The prints do not. the cabin does not. i have passed it twice and it was lit both times and i never went back in.
>
> my letters are going wrong. they lean the way yours lean. i know your hand better than mine. i read every list you ever left me. this is your hand now and i am still writing.
>
> if you are reading this, which of us is holding the pen.

**don't turn around** (trail 5, `LAST_TITLE`, 0.72)

> stop looking for me.
>
> go to the lights. the engine has been running since before the snow. someone kept it warm for one of us. i will be there or i will not, but you will.
>
> i am right behind you. i always was. do not turn around until you reach the road.
>
> — m

**intake** (`intake()`, does not count, 0.06)

> Brought in from the step during the storm. Length under the sheet: 1.6 m. Strap stamped M. Aune. Given name, as copied: M— (left unfinished). Personal effects: one cup. Next of kin: out searching. Not yet notified.

## Frame text

- Intro card, under **RUN AWAY**: *Mathilda went out into the storm.* The Esc line stays.
- HUD objective: **Find Mathilda.** After the last page: **Go to the lights.** This replaces the `hunt_started` text ("Reach the lookout." / "Keep moving."), which nothing triggers any more.
- Escape card: title **The road**, body *The engine is running. The driver's door is open, the seat still warm.* If `read_last_page`, add *You didn't turn around.* The action stays "Walk the ridge again".
- Caught card defaults stay as they are; no threat currently uses them.

## Her lines

`assets/audio/voice/lines.json` gets moods and stages. Every entry is `{"text": ..., "mood": ...}`. A plain string still loads, with the mood `steady`, so older files keep working.

```json
{
  "pages":  { "<title>": {"text": "...", "mood": "..."} },
  "places": { "<place>": {"text": "...", "mood": "..."} },
  "bored":  { "hope": [...], "doubt": [...], "resolve": [...] },
  "calls":  { "hope": [...], "doubt": [...], "resolve": [...] }
}
```

Moods: `steady`, `warm`, `hushed`, `shaken`, `breaking`, `resolve`, `calling`.

### Page reactions

| Page | Line | Mood |
|---|---|---|
| by the bed | "Stay in." She's the one out there, and she's telling me to stay in. | shaken |
| from the pack | Two cups. She packed for both of us. She knew I'd come. | breaking |
| on the post | My own voice, from the trees. Then I won't answer it. I won't. | hushed |
| torn page | Prints that just stop. She's describing mine. I haven't been to the pines yet. Have I? | shaken |
| the handwriting changes | That's my handwriting. That's how I make my M's. | hushed |
| don't turn around | Don't turn around. Fine. I won't. Just be at the lights. | resolve |
| intake | One cup. Just one. I'm not lifting that sheet. I'm not. | breaking |

### First visits

| Place | Line | Mood |
|---|---|---|
| bedroom | Her side of the bed is still warm. She can't be far. | warm |
| hall | Her boots are gone. The door isn't even latched. | shaken |
| living | She sat up waiting. The candle burned all the way down. | hushed |
| backhall | Mathilda? She wouldn't go down there. She hates the cellar. | hushed |
| stair | If she's down here, she's been quiet a long time. | hushed |
| landing | No wind down here. I can hear my own heart. | hushed |
| corridor | Why does a cabin need a hallway this long under the ground? | hushed |
| janitor | Someone keeps this place clean. Someone expects to use it. | shaken |
| morgue | No. She wouldn't be here. She's out in the snow. She has to be. | breaking |
| snow | Her prints are already filling in. I have to be faster than the snow. | resolve |
| lights | Headlights. Someone's waiting. Please let it be her. | breaking |

### Idle mutters, by stage

The stage comes from `Game.notes_found`: 0–1 is **hope**, 2–3 is **doubt**, 4 or more (or `read_last_page`) is **resolve**. Lines in an earlier stage that were never spoken are dropped once she moves on.

Hope:
- She knows this field better than I do. She'll have found shelter. (steady)
- Ten minutes, she said. Ten minutes, and then the snow came in sideways. (shaken)
- When I find her I'm going to be so angry. And then I'm not letting go. (warm)
- She always leaves something behind so I can find her. Always. (steady)
- Every white shape is her coat, until it isn't. (hushed)

Doubt:
- Her prints stop. Mine don't. What does that make me? (shaken)
- I've said her name so many times it's just a sound now. (hushed)
- What if she's back at the cabin, by the lantern, writing to me? (shaken)
- I can't remember which of us said we'd stay. (breaking)
- I keep turning to tell her something. There's nobody to tell. (breaking)

Resolve:
- Don't turn around. I can do that. I can do that much. (resolve)
- If she's behind me, she can see me. That has to be enough. (breaking)
- The engine's running. Someone kept it warm for one of us. (hushed)
- Whatever's at the lights, I'm walking up to it. I'm not stopping now. (resolve)
- I'll find you. Or you'll find me. One of us gets to go home. (breaking)

### Calls

Outdoors only, during `PLAYING`, never while she is speaking. The first call comes 20–30 s after she first steps into the snow, then every `Tune.CALL_EVERY` (45–80 s, random). Calls cycle within the current stage and may repeat, unlike the other lines. Each shows as a subtitle.

- Hope: "Mathilda!" (calling); "Mathilda! Can you hear me?" (calling)
- Doubt: "Mathilda! Answer me!" (calling); "Mathilda… where are you?" (breaking)
- Resolve: "Mathilda! I'm coming!" (calling); "Mathilda… please." (breaking)

**Echo.** Once she has read *on the post*, the first call in the doubt or resolve stage is answered 1.6–2.4 s later by the same clip, from the nearest pine 25–60 m away (`Flora.tree_positions()`), on the Dread bus, low-passed and about 14 dB quieter. This happens at most twice per run, never indoors, and with no subtitle. She doesn't comment on it; the page already told the player not to answer.

Fallbacks in `voice.gd` change to fit: the missing-page line becomes "She wrote this for me. I have to keep going.", and `_stock_place` lines lose the old story. The `PLACES` descriptions, which only feed the drafter, are rewritten to match.

## Voice baking on the GPU

`tools/bake_speech.py` is rewritten around **Chatterbox** (Resemble AI, MIT) on CUDA, in a separate environment at `build/voice/gpu-venv`: Python 3.11 and CUDA torch, because the system Python is 3.14 with CPU-only torch. Kokoro stays available with `--engine kokoro` as a CPU fallback.

- **Her identity.** Chatterbox clones a reference voice. The default reference is `build/voice/ref/her.wav`, about 12 s of Kokoro `af_sarah` rendered once by the script, so she keeps the voice players have heard. `--ref <wav>` replaces it.
- **Mood to delivery:**

  | Mood | exaggeration | cfg_weight | temperature | level (loudest 50 ms) |
  |---|---|---|---|---|
  | steady | 0.45 | 0.50 | 0.80 | −12 dBFS |
  | warm | 0.50 | 0.50 | 0.80 | −12 |
  | hushed | 0.30 | 0.60 | 0.70 | −18 |
  | shaken | 0.65 | 0.40 | 0.85 | −12 |
  | breaking | 0.80 | 0.35 | 0.90 | −13 |
  | resolve | 0.55 | 0.45 | 0.80 | −12 |
  | calling | 1.00 | 0.30 | 0.85 | −10 |

- **Takes.** Three takes per line, each transcribed with `faster-whisper` (small.en, CUDA). The take with the lowest word error rate against the text wins; ties go to the median duration. A line whose best take is above 15% WER is reported, and the bake stops unless `--accept-bad`. Leading and trailing silence is trimmed to 60 ms.
- **Clip names** stay the SHA-256 of the text. The hash now covers `text + "|" + mood`, so changing a mood re-bakes the line. `voice.gd` computes the same key. `manifest.json` records text, mood, file, seconds, WER, engine and reference.
- The game still never runs a model. Clips are imported and packed as before.

## Code changes

- `scripts/notes/note_catalog.gd`: the new text and titles.
- `scripts/ui/hud.gd`: the intro line and the objective.
- `scripts/ui/end_card.gd`: the escape body.
- `scripts/player/voice.gd`:
  - parse entries as strings or dicts and key clips by text and mood
  - choose idle lines by stage
  - a second `AudioStreamPlayer3D` for calls at `Tune.CALL_SPL`, plus the echo player
  - new fallbacks and `PLACES` descriptions
- `scripts/tune.gd`: `CALL_SPL := 82.0`, `CALL_EVERY := Vector2(45, 80)`, `CALL_FIRST := Vector2(20, 30)`, `ECHO_DROP_DB := 14.0`, `ECHO_MAX := 2`.
- `tools/bake_speech.py`: Chatterbox, moods, takes and the WER pick, as above.
- Docs: `docs/VOICE.md`, plus the Voice paragraph in `CLAUDE.md` and `AGENTS.md`. A one-line pointer to this spec goes in `docs/DIRECTION.md`.

`tools/bake_voice.py` (the Qwen drafter) is not touched. It would overwrite these lines and doesn't know the new format, and VOICE.md will say so.

## Testing

- `tools/voice_probe.tscn` (existing, extended):
  - every line in `lines.json` loads with a mood
  - every line has a clip under its text and mood hash
  - stage selection gives hope, doubt and resolve at 0, 2 and 4 notes
  - calls never trigger indoors
  - the echo needs the *on the post* page and stops after two
- `godot --headless --path . --import` is clean.
- The bake prints each line's WER. A listening pass (you) is the real check for "alive".
- Screenshot smoke test of the intro card and a page in the reader.

## Out of scope

- Mathilda's model, decimation, rigging, and her appearing in the world (piece 3).
- New threats; the caught ending text.
- The Qwen drafter.
- Any change to the house, trail or editable level structure.

## Risks

- **Chatterbox install.** It pins its own torch version. If it won't install for CUDA 12 on this machine, the fallback is to try the next pinned torch build, and failing that, Kokoro with per-mood speed and level only.
- **Whisper misses.** Short emotional lines ("Mathilda… please.") may trip the WER check. Allow `--accept-bad` per line after listening.
