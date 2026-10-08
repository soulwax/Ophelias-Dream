# Story Studio: masterplan

A local, GUI-first workbench for writing *Ophelia's Dream*: its lines, branches and pages, and the voices that speak them. Every step of baking is wired in, so you can write a line, hear it, change it, bake it properly and walk into the game to hear it in place, without opening a terminal.

Status: the first slice is built (2026-10-08):
- **Phase 0 is done.** `tools/studio/model.py` and `python tools/voice_status.py` give every line's state and the owed list; they match `PROBE_CLIPS=1 voice_probe` text for text.
- **Read-only parts of phase 1.** `python tools/studio/server.py` opens the studio with the lines table, filters and search, chapter/group navigation with open counts, the owed views, and clip playback.
- **First pieces of phase 4.** The voice lab's Kokoro *Try* (a warm worker, scratch takes in `build/studio/scratch/`), and the bake & check queue with every CPU-side command from section 6 plus import and probes. Desktop jobs are greyed out where their venv is missing.
- **Deep links.** `/#line=<uid>` opens a line in the lab.
- **Phase 2's core.** In the lab, edit a line's text or mood, see the exact diff and warnings live (its clip will stop playing; doorway lines whose *Answers* quote words you removed), save it into its script, and undo.
  - Doorway lines now expose their speaker, action/reaction, answer target and quoted words, intensity, pause, overlap and intentional-break marker in the lab. Local checks reject invalid ranges and answer quotes that are not present in the chosen line; the meeting's full `--check` still runs on save.
  - `tools/studio/writers.py` changes only that line's rows and keeps the file's line endings.
  - `python tools/studio/test_writers.py` round-trips every line of all four scripts byte for byte.
  - Saving regenerates the chapter's table (`bake_mathilda.py` gained `--write` for this) and runs its `--check`.
  - Still to do in phase 2: adding and removing lines, editing the trees, probe counts derived from the model.
- **Listening and baking from the lab.**
  - One small player plays everything. Every play button shows ▶ or ❚❚, a pill in the top bar shows what's playing, and Space toggles it.
  - *Bake this line* runs the chapter's own bake tool (it renders only what's missing) and then imports into Godot, as a queued job. It covers Mathilda's chapter and her lake lines with Kokoro finals, and doorway drafts. Ophelia's lines and doorway finals say they need the desktop.
  - *Hear it in the game* (optional) launches the windowed game at the line's scene through the dev hooks. Places and chores spawn her in the room. Passings use `RUN_WANDER=now`. The lake spawns her there. Mathilda's lines run her chapter, and the doorway runs `RUN_MATHILDA=1 RUN_MEETING=open`. `RUN_PLAY=1` (new) skips the menu and intro in Ophelia's chapter.
- **Voice model constellation.** The Voice models view queues curated Hugging Face downloads for Qwen3-TTS VoiceDesign 1.7B, CustomVoice 1.7B, and CustomVoice 0.6B. Weights stay under ignored `build/voice/hf/`; Qwen previews appear in the lab's engine selector after download. Preview takes stay under ignored `build/studio/scratch/` and never update voice locks or game clips.
  - VoiceDesign supports natural-language voice and performance direction; 1.7B CustomVoice retains a built-in timbre and accepts delivery instructions. The smaller 0.6B CustomVoice model is for timbre comparison and has no instruction control. The model cards link to the official Hugging Face pages and show upstream license and approximate download size.
  - Choosing a line seeds its mood-specific performance direction (editable before preview); changing the lab mood refreshes that direction unless it has been manually rewritten.
  - Qwen inference needs the NVIDIA CUDA `build/voice/gpu-venv`. The catalog can stage weights without it; the current machine reports whether it has the runtime. A Qwen take's **Match Ophelia** action runs Chatterbox voice conversion to the approved steady identity when the Chatterbox CUDA runtime and reference are available. Both versions remain scratch previews. The normal bake path runs the existing Whisper transcript and ECAPA speaker checks before a clip is used in the game.
  - The contextual chain editor arranges two to eight existing lines or experimental turns, assigns each character a mood direction and (for CustomVoice) a timbre, and generates one to three seeded conversational variants. Seed and sampling temperature are adjustable for repeatable A/B comparisons and fresh variation. Each response receives the scene summary, speaker profile, and preceding text as context. Named chains persist in the browser's local storage; generated utterances remain individual scratch clips.
  - `python tools/studio/test_chains.py` checks chain limits, supported speakers, and contextual prompt assembly without downloading or loading models.
  - The catalog is deliberately curated; API callers can only request these fixed repository IDs and destinations, never arbitrary Hugging Face repos or filesystem paths. Model weights are ignored by git.
- **Dream story.** A separate *Dream story* view edits the playable dream, now the first standalone mode on the main menu. It includes the opening, four paced path beats, arrival, question, and two to eight answer branches. Each branch has its own choice text, in-dream response, and waking echo for Ophelia and Mathilda. The dream returns to the mode menu after showing both echoes; it no longer precedes either woman's campaign. Saving validates `assets/dialogue/dream.json`, guards against stale browser edits, and writes the same data the runtime reads; it does not add these passages to the voiced line catalogue.
  - `python tools/studio/test_dream_story.py` checks the branch schema, round-trip save and stale-edit guard. `godot --headless --path . -s tools/dream_story_probe.gd` checks the game's branch lookup.
- **Review (5.6).** *Review new clips* lists every clip made since the last commit (untracked under `assets/audio/voice`, from `git status`).
  - Each one plays next to the version it replaces, recovered from the line tables at `HEAD`, with the old wording struck through, and next to the mood's reference performance when one exists.
  - *Accept* records the decision in `build/studio/review.json`. *Reject* moves the clip and its `.import` into `build/voice/archive/<date>-rejected/` through `bake_speech.archive()`, so nothing is deleted.
  - *Re-take* rejects and queues another Chatterbox take (`bake_speech.py --only` or `bake_meeting.py --first-seed`) on the desktop. For Kokoro lines it explains that Kokoro reads a line the same way every time.
  - Keyboard: ↑/↓, Space, A, R. `/#review` and `/#bake` open those views.

Deliberate deviation: the server is standard-library `http.server` rather than FastAPI, so it needs no new venv. Swap it when phase 4 needs server-sent events. Everything else below is still plan.

## 1. Why

The spoken story is spread over four scripts of record, written in three Markdown dialects, plus a GDScript catalogue of pages. The optional playable dream is its own branching story, read by the game but kept outside the voice line catalogue. The voice comes from six Python tools, three speech engines, four virtual environments and two machines. It works, but only for someone who remembers the order:

| Today | Source of record | Tool | Engine / machine | Output |
|---|---|---|---|---|
| Ophelia's field lines (182) | `docs/MATHILDA_STORY.md` (keyed `- **id:** [mood] text`, staged lists) | `script_to_lines.py`, then `bake_speech.py` (`--impressions`, `--unify`, `--lock`, bake) | Qwen3-TTS VoiceDesign (`gpu-venv`), Chatterbox VC + TTS (`cb-venv`), Whisper gate; desktop CUDA | `assets/audio/voice/lines.json`, `<sha256(text\|mood)>.wav`, `build/voice/review.html` |
| Mathilda's chapter (69) | `docs/MATHILDA_POV.md` (`### group` + `- [mood] text`, keyed `passing`) | `bake_mathilda.py` | Kokoro `af_bella` 0.94, CPU (`build/voice/venv`) | `assets/audio/voice/mathilda/` |
| The meeting on the ice (43) | `docs/LAKE_MEETING.md` (table) + `assets/dialogue/lake.json` | `bake_lake.py` | Kokoro for Mathilda; Ophelia waits for Chatterbox | `assets/audio/voice/lake/` |
| The meeting at the door (41) | `docs/MATHILDA_MEETING.md` (`### id \| speaker \| mood \| pause` blocks with Action/reaction, Answers, Intensity, Break) + `assets/dialogue/meeting.json` | `bake_meeting.py` (`--write`, `--check`, `--paths`, `--engine kokoro\|chatterbox`), `dialogue_post.py` | Kokoro drafts; Chatterbox finals with a speaker-similarity gate | `assets/audio/voice/meeting/` (+ `draft/`, `timing.json`) |
| Pages | `scripts/notes/note_catalog.gd` (`_make(title, body, corruption, smudges, between)`) | none | none | in code |
| The playable dream (branching, not voiced) | `assets/dialogue/dream.json` | Story Studio's separate Dream story editor | Godot reads the same file | opening, four approach beats, player answers and waking echoes |

What hurts:
- **Silent drift.** A text change makes a new clip key (`sha256(text|mood)`). The old clip is orphaned and the new line plays as a subtitle, and nobody notices until a probe or a playthrough.
- **No ear in the loop.** Choosing a mood, an engine, a speed or a take means editing a file, running a bake, then opening `review.html`. Trying three readings of one line takes three round trips.
- **Two machines.** Kokoro runs on the ThinkPad, Chatterbox only on the desktop. What is still owed to the desktop lives in nobody's head. Today it's "Ophelia's 23 passing and photograph lines, the a17 doorway line, and every Ophelia lake line".
- **Coherence is checked late.** The doorway meeting's rules (an answer must quote a line that is really there, intensity can't jump more than `MAX_JUMP` = 0.4 without a `Break`) only run in `--check`, after the writing.
- **Missing identities.** Mathilda has no Chatterbox reference voices yet (`tools/voice/ref/mathilda/` does not exist), so her doorway lines can only ever be drafts.

## 2. Principles

1. **The Markdown stays the script of record.** The studio reads and writes the existing docs in place, keeping their formatting, so every change is a readable git diff. It never becomes a second source of truth; its own database is a cache it can always rebuild from the files.
2. **Nothing is deleted.** Replaced, rejected and scrapped clips go to `build/voice/archive/`, exactly as the tools do today.
3. **The existing tools are the engine.** The studio calls `script_to_lines.py`, `bake_speech.py`, `bake_mathilda.py`, `bake_lake.py`, `bake_meeting.py` and `dialogue_post.py` (refactored into importable functions where useful) and never reimplements their gates.
4. **No model runs in the game.** The studio produces the same committed assets as today.
5. **Everything is a click, nothing is magic.** Every action shows the exact command it runs and its log, so the terminal path keeps working and stays documented.
6. **Experiment freely, commit deliberately.** Trying a reading writes to a scratch area. Only *Accept* touches `assets/`.

## 3. Shape

A local web app, `tools/studio/`, served at `http://127.0.0.1:4317` and opened in the browser:

```
browser UI (vanilla JS + htmx, wavesurfer.js vendored for waveforms)
        |  HTTP + server-sent events (job logs, progress)
studio server (Python, FastAPI, its own venv: build/voice/studio-venv)
  ├─ model:     parsers/writers for the 4 script formats + NoteCatalog data -> one Line model
  ├─ jobs:      a queue that runs the bake tools in the right venv as subprocesses
  ├─ engines:   kokoro | chatterbox | qwen-voicedesign, each with a capability flag per machine
  ├─ clips:     clip-key index, status, takes, WER, similarity, archive
  └─ godot:     import, probes, and launching the game at a scene with RUN_* hooks
```

Why a browser app rather than a Godot editor plugin: the tools are Python with heavy venvs. Audio review, waveforms, A/B listening and long-running GPU jobs are easier in a browser, and the same app runs on the ThinkPad and the desktop. Godot is driven from it (section 6.8). A thin Godot dock that just opens the studio on the line under the cursor can come later.

## 4. One model of a line

Every spoken thing becomes a `Line`, whatever file it came from:

| Field | Meaning |
|---|---|
| `uid` | stable id: `ophelia/places/hall`, `mathilda/passing/w_go`, `lake/m23`, `meeting/a16` |
| `speaker` | `ophelia` \| `mathilda` |
| `chapter` | `ophelia`, `mathilda`, `lake`, `doorway` |
| `group` | pages, deciphered, chores, encounters, places, revisits, moments, bored/<stage>, memories/<stage>, calls/<stage>, spent, cold, falls, turned, answers, misread, endings; Mathilda's groups; meeting ids |
| `text`, `mood` | the line, and one of the 14 moods |
| `source` | file, line number, and the exact span to rewrite |
| `clip_key` | `sha256(text\|mood)`, so it's always derivable |
| `clip` | `final` (Chatterbox, or Kokoro for Mathilda's chapter), `draft` (Kokoro stand-in), `missing`, `stale` (a clip exists for an older text) |
| `owed_to` | the machine/engine that must still perform it (`desktop:chatterbox`) |
| `takes` | scratch takes with engine, seed, settings, WER, similarity, loudness |
| `meta` | meeting fields (answers, quote, intensity, break, overlap, pause, reaction); bake overrides (e.g. `exaggeration`) |
| `triggers` | where the game plays it, from a table of hooks (e.g. `Voice.place("hall")` first visit, `Encounters` passing 3, `Conversation` node `held`) |

Writers round-trip each format byte for byte when nothing changed (a golden test per doc). Pages move from `note_catalog.gd` into `assets/story/pages.json` (title, body with `{smudge}` markup, corruption, smudges with readings and key, between, counts, record_of). `NoteCatalog` then loads them, so the studio can edit pages too. That move is phase 3 and is guarded by `journal_probe`.

## 5. Screens

### 5.1 Story map
The whole story on one page: chapters as columns (Ophelia's afternoon, Mathilda's camp, the lake, the doorway), places and beats as cards, pages pinned where they are found, the three passings as a thread between the two columns. Each card shows its lines and their clip status (green final, amber draft, grey missing, red stale). Clicking a card opens it in the script editor. This is also where the *layer underneath* table from MATHILDA_STORY.md lives, next to the beats it explains.

### 5.2 Script editor
A table per group: text, mood (14 coloured chips, with the one-line direction from the mood table on hover), speaker, clip status, play button.
- Editing the text shows "new clip needed" at once, offers to keep the old clip as a draft until the new one is baked, and never leaves a silent subtitle without saying so.
- Each line has a ⟳ *Try* button that renders it in the scratch area with the current lab settings (5.4). The result plays inline, with a waveform.
- Filters: "owed to the desktop", "drafts", "missing", "stale", "changed since the last commit".
- Live validation as you type: a mood that isn't one of the 14, a duplicate id, a group count the probes expect (`voice_probe` counts are derived from the model, not hard-coded, once phase 2 lands).

### 5.3 Dialogue editor
The trees (`lake.json`, `meeting.json`) as a node graph. Each node shows its `say` lines, with choices as edges labelled with `requires` / `sets` / `once` / `end`. Plus:
- **Coherence on the fly**: the `bake_meeting.py` rules (Answers must quote the answered line, `MAX_JUMP` between reachable neighbours unless `Break`, no same-speaker overlap, no orphan or missing lines) run as you edit and mark the offending edge.
- **Path walker**: pick flags (`passed`, `pack`, `gloves`…) and step through the conversation as text or as audio, with the authored pauses and overlaps, the way `--paths` prints them.
- **Intensity strip**: a line chart of intensity along the chosen path, with breaks marked.

### 5.4 Voice lab
For experimenting, never for committing.
- **Engines**: Kokoro (any voice, speed), Chatterbox (reference = a mood's impression, exaggeration, cfg weight, seed), Qwen3 VoiceDesign (a mood description, seed, for new impressions). Engines the current machine can't run are greyed out with *Queue for desktop*.
- **A/B/C**: render one line in up to four configurations, listen blind, keep the winner as a take.
- **Moods**: for each of the 14 moods, the reference impression, its raw candidates (`tools/voice/ref/raw/`), the description, and the lock entry. *New impression → unify → audition → lock* is the `--impressions`, `--unify`, `--pick`, `--lock` path from `bake_speech.py`, as one wizard per mood.
- **Speakers**: Ophelia's identity (the 14 refs plus `anchor.wav`) and **Mathilda's, which does not exist yet**. The wizard creates `tools/voice/ref/mathilda/<mood>.wav` the same way, unblocking Chatterbox finals for her doorway and lake lines.
- **Gates visible**: every take shows Whisper's transcript and WER (gate `MAX_WER` 0.15), speaker similarity (gate 0.72 in the meetings), loudness against the -12 / -20 dBFS targets, and duration.

### 5.5 Bake queue
The real bakes, as jobs:
- One job per tool invocation, with the command shown verbatim, live log, progress (lines done / total), and the venv it ran in.
- **Plan before bake**: a dry run lists exactly which clips will be performed, kept, archived. Accepting the plan starts the job.
- **Machine routing**: jobs the ThinkPad can't do become *owed* and are listed in `build/voice/owed.json` (committed as `docs/voice_owed.md` so the desktop sees it after `git pull`). On the desktop, the studio's *Pay what's owed* runs them all.
- **Resumable**: a crash or a closed laptop doesn't lose finished clips (the tools already skip existing clips; the queue records where it stopped).

### 5.6 Review
`review.html`, but interactive: per group, every new clip next to its previous version (from the archive) and its mood impression. *Accept*, *Reject → archive*, or *Re-take (next seed)*, with the WER and similarity beside each. Keyboard-driven (space plays, ←/→ moves, A accepts, R re-takes).

### 5.7 Pages
The page editor once pages are data: the body with smudges highlighted, each smudge's readings (first = intended) and its key picked from a list of valid keys (`page:<title>`, `place:<Voice.PLACES>`, `event:call|echo`), corruption slider with a live preview rendered the way `NoteReader` draws it, the between-the-lines text, and the reaction and deciphered lines from the script editor right beside it.

### 5.8 Play it
Buttons that launch the mono Godot build at the right moment:
- *Hear it in place*: for a place line, `RUN_SPAWN=<room>`; for a passing, `RUN_WANDER=now`; for Mathilda's chapter, `RUN_MATHILDA=1`; for the doorway, `RUN_MATHILDA=1 RUN_MEETING=open`; for an ending card, `RUN_CAPTURE=1 RUN_ENDING=<kind>`.
- *Check it*: runs the probes that cover what changed (`voice`, `journal`, `meeting`, `mathilda`, `encounter` in both chapters, `dialogue`, `ending`), after `godot --import` and `dotnet build OpheliasDream.csproj`, and shows pass/fail per check.
- *Ready to release*: all of the above green, nothing stale, a summary of what's owed. It hands over to the signed-release skill; the studio never commits or pushes.

## 6. The workflow, wired

Every command that exists today maps to one studio action:

| Studio action | Runs today's |
|---|---|
| Save a script edit | writer for that doc, then `script_to_lines.py` / `bake_mathilda.py --check` / `bake_lake.py --write` / `bake_meeting.py --write` |
| Validate | `script_to_lines.py --check`, `bake_mathilda.py --check`, `bake_lake.py --check`, `bake_meeting.py --check`, `dialogue_post.py --check` |
| Transcripts | `bake_meeting.py --paths` |
| Bake Mathilda's chapter | `build/voice/venv/Scripts/python.exe tools/bake_mathilda.py` |
| Bake the lake (Mathilda) | `build/voice/venv/Scripts/python.exe tools/bake_lake.py` |
| Drafts for the doorway | `bake_meeting.py --engine kokoro` |
| Finals for the doorway | `bake_meeting.py --engine chatterbox [--speaker] [--takes] [--first-seed]` (desktop) |
| Ophelia's field lines | `bake_speech.py [--only] [--mood] [--force] [--accept-bad]` (desktop, `cb-venv`) |
| New mood impression | `bake_speech.py --impressions --moods <m> --candidates N` (`gpu-venv`), `--unify`, `--pick`, `--lock` |
| Start over (archived) | `bake_speech.py --scrap` |
| Clean and time | `dialogue_post.py` |
| Import into Godot | `godot-mono --headless --path . --import` |
| Probes | `godot-mono --headless --path . tools/<name>_probe.tscn` |

The dependency chain the studio enforces (and shows as a strip at the top of every screen):

```
edit -> script of record -> lines.json / trees -> validate -> bake (draft | final) -> review/accept -> import -> probes -> release
```

A step that is out of date turns amber, and its button says what it will do ("3 lines need clips, 1 stale clip will be archived").

## 7. Writing support

Help for writing the story, kept light:
- **Beat sheet** per chapter, linked to the lines that carry each beat.
- **Branch and condition view**: which flags exist (`Game.read_pages`, `deciphered`, `turned_around`, `passings`, `meeting_ready()`, the `requires` flags), where each is set and where it is read. You can see at a glance that `passed` is set by `Encounters` and read by the lake (o20) and the doorway (a16).
- **Voice consistency**: Ophelia's lines by mood across the whole game, Mathilda's likewise, so a mood that's over-used or a voice that drifts shows up.
- **Read-aloud pass**: plays a chapter's lines in trigger order, drafts and finals mixed, with a marker on each draft.
- **Search across all four scripts**, with replace-preview that shows which clips each replacement would invalidate.

## 8. Phases

| Phase | Delivers | Done when |
|---|---|---|
| **0. Groundwork** | `bake_*` tools importable (functions behind `main()`); one `voice_status.py` that reports final/draft/missing/stale/owed for every line in every chapter; `build/voice/studio-venv` with FastAPI | `voice_status.py` matches what `PROBE_CLIPS=1 voice_probe` and `mathilda_probe` see, line for line |
| **1. Read-only studio** | Story map, script tables, dialogue graphs, clip playback, status filters, owed list | every line of all four scripts shows with the right status, and clicking plays its clip or says why it can't |
| **2. Editing** | Round-trip writers (golden tests per doc), live validation, meeting coherence in the editor, derived probe counts | editing a line in the UI produces the same diff as editing the Markdown by hand; `--check` on every tool passes after a UI edit |
| **3. Pages as data** | `assets/story/pages.json`, `NoteCatalog` loading it, the page editor | `journal_probe`, `note_access_probe`, `voice_probe` pass unchanged |
| **4. Voice lab + queue** | Try/A-B, takes with gates, bake queue with dry-run plan, logs over SSE, resumable jobs | a Kokoro bake of Mathilda's chapter and a meeting draft bake run from the UI with identical output to the CLI |
| **5. Desktop path** | Engine capability per machine, owed list in git, *Pay what's owed*, Chatterbox finals and impressions wizard, Mathilda's identity | on the desktop, one click bakes every owed Ophelia line and the Mathilda refs exist |
| **6. Review + play** | Interactive review with archive, launch-at-scene buttons, probe runner, release readiness | a line can go from edit to heard-in-game to accepted without a terminal |

Each phase is shippable on its own; nothing in a later phase is needed to use an earlier one.

## 9. Risks

- **Format round-tripping.** Four hand-written Markdown dialects are easy to break. Mitigation: golden tests, and the writer only touches the span of the line it changed.
- **GPU stack fragility.** Chatterbox and Qwen in their venvs are version-sensitive. Mitigation: the studio only shells out to the locked venvs and shows `voice_lock.json` drift as a warning; it never upgrades them.
- **Clip-key churn.** Every typo fix is a new bake. Mitigation: *keep old clip as draft until re-baked*, and a "typo-only" flag that lets a punctuation-only change keep its clip deliberately (recorded in an alias table the game reads, `clip_aliases.json`).
- **Scope creep into a DAW.** No mixing, no music. Waveforms are for listening and trimming only.

## 10. First steps

1. Write `tools/voice_status.py` (phase 0) and run it: the owed list becomes concrete.
2. Pull `parse()`/`write()` out of the four tools into `tools/studio/model.py`, with golden round-trip tests.
3. Stand up the read-only story map against that model.
