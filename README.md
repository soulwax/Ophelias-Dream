# Run Away

Run Away is a short third-person winter-horror game made with Godot 4.7,
Forward+ rendering, and Jolt physics. An unnamed woman wakes in a cabin to find
Mathilda gone into the snow. She searches the house, cellar, and daylight field
for written pages whose damaged words steadily undermine her understanding of
what happened.

There is no objective marker and no active field threat in the current build.
The journal, the pages, the road, and Mathilda's absence carry the experience.
The authoritative story and complete spoken script are in
[docs/MATHILDA_STORY.md](docs/MATHILDA_STORY.md).

## Play

Open the project in Godot 4.7 and run `scenes/main.tscn`, or launch it from the
repository root:

```powershell
godot --path .
```

| Input | Action |
| --- | --- |
| WASD / left stick | Move |
| Mouse / right stick | Look |
| Shift | Sprint |
| Alt | Walk slowly |
| Space | Jump; leap while running |
| Ctrl or C | Slide while sprinting |
| E / pad X | Read or interact |
| F, right mouse, or pad RT | Hold breath |
| Q or middle mouse | Look behind |
| J, Tab, or pad Y | Open the journal |
| Esc | Pause and open settings |
| R | Restart after an ending |

The journal action is rebindable in the Esc menu. Opening it holds the player
still but leaves the world running. Pages use `{word}` smudges: reading pages,
visiting places, and hearing events unlock their possible readings; selecting
the intended reading deciphers the page.

Godot imports the project on its first run. On a constrained GPU, set
`RUN_GRAPHICS=lean` before launching:

```powershell
$env:RUN_GRAPHICS = "lean"
godot --path .
Remove-Item Env:RUN_GRAPHICS
```

## Project layout

| Path | Purpose |
| --- | --- |
| [scenes/main.tscn](scenes/main.tscn) | Entry scene. |
| [scripts/main.gd](scripts/main.gd) | Builds the game systems in code. |
| [scripts/game/](scripts/game/) | Autoload state, settings, phases, input, and shared state. |
| [scripts/player/](scripts/player/) | Player movement, camera, animation, breath, voice, and interaction. |
| [scripts/world/](scripts/world/) | Terrain, trail, snowfield, fences, landmarks, and field pages. |
| [scripts/house/](scripts/house/) | Cabin, cellar, doors, interactables, and haunting. |
| [scripts/notes/](scripts/notes/) | Journal page data and deciphering rules. |
| [scripts/ui/](scripts/ui/) | HUD, reader, journal, ending card, and pause menu. |
| [scripts/audio/](scripts/audio/) | Positional sound, buses, loudness, and soundscape. |
| [assets/audio/voice/](assets/audio/voice/) | Reviewed voice script, generated clips, and bake manifest. |
| [tools/](tools/) | Probes, generators, diagnostics, and release tooling. |
| [docs/](docs/) | Design, narrative, authoring, and implementation references. |

Most gameplay nodes are constructed in code. The editable level snapshots in
[scenes/editable_level.scn](scenes/editable_level.scn) and
[scenes/generated/](scenes/generated/) preserve authored changes; read
[docs/EDITOR.md](docs/EDITOR.md) before editing or rebuilding them.

## Development and verification

Run commands from the repository root with Godot 4.7 on `PATH`.

```powershell
# Run or open the project.
godot --path .
godot --path . -e

# Re-import after adding a script with class_name or adding an asset.
godot --headless --path . --import

# Story, journal, and voice rules. Set PROBE_CLIPS to require every baked clip.
godot --headless --path . tools/journal_probe.tscn
$env:PROBE_CLIPS = "1"
godot --headless --path . tools/voice_probe.tscn
Remove-Item Env:PROBE_CLIPS

# Movement and level checks.
godot --headless --path . -s tools/leap_math_probe.gd
godot --headless --path . tools/leap_probe.tscn
godot --headless --path . tools/traversal_probe.tscn
godot --headless --path . tools/note_access_probe.tscn
godot --headless --path . tools/house_space_probe.tscn

# Capture a startup smoke screenshot.
$env:RUN_CAPTURE = "1"
$env:RUN_SHOT = "$PWD\shot.png"
godot --path .
Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT
```

Use [tools/run_blackbox.ps1](tools/run_blackbox.ps1) for a crash-safe logging
run. For a Windows release, install matching export templates and run:

```powershell
.\tools\export_release.ps1
```

The release tool maintains the synchronized version metadata and encryption
template. Do not commit `build/`, `.godot/`, `godot.gdkey`, scratch captures, or
local voice models.

## Writing the story and voice lines

Read [docs/MATHILDA_STORY.md](docs/MATHILDA_STORY.md) before changing narrative
content. It is the reviewable story reference: the sequence, ambiguity, page
text, smudge answers, ending text, and all 62 spoken lines. The player
character speaks aloud; Mathilda appears only in the written pages. Preserve
that distinction and the unresolved ending unless the story is intentionally
being redesigned.

### Source of truth

| Content | Authoritative source | Required companion update |
| --- | --- | --- |
| Written page, smudges, unlock conditions, and between-the-lines sentence | [scripts/notes/note_catalog.gd](scripts/notes/note_catalog.gd) | [docs/MATHILDA_STORY.md](docs/MATHILDA_STORY.md), then the journal probe |
| Spoken text, mood, category, and when a line plays | [assets/audio/voice/lines.json](assets/audio/voice/lines.json) | [docs/MATHILDA_STORY.md](docs/MATHILDA_STORY.md), rebaked clip, then voice probe |
| Voice playback stages, priorities, calls, and echoes | [scripts/player/voice.gd](scripts/player/voice.gd) | [docs/VOICE.md](docs/VOICE.md) when behavior changes |
| Generated clip metadata | [assets/audio/voice/manifest.json](assets/audio/voice/manifest.json) | Generated by the baker; do not edit it by hand |

The full voice production reference, including first-time CUDA setup, is
[assets/audio/voice/README.md](assets/audio/voice/README.md). Do **not** run
`tools/bake_voice.py`; it uses an obsolete format and can overwrite the reviewed
script.

### Edit a written page

1. Update the matching `NoteCatalog._make()` entry in
   [scripts/notes/note_catalog.gd](scripts/notes/note_catalog.gd). Keep each
   `{word}` in the body aligned with one smudge specification, in the same
   order. The first reading is the correct one; its `page:`, `place:`, or
   `event:` key controls when it can be solved.
2. Update the page, smudge table, and any affected ending text in
   [docs/MATHILDA_STORY.md](docs/MATHILDA_STORY.md).
3. If changing a page title, update the matching `pages` and `deciphered` keys
   in [assets/audio/voice/lines.json](assets/audio/voice/lines.json). A new
   place key must also exist in `Voice.PLACES`.
4. The current probes intentionally expect seven pages with two smudges each.
   If the story deliberately changes those structural counts, update the
   relevant assertions in [tools/journal_probe.gd](tools/journal_probe.gd) and
   [tools/voice_probe.gd](tools/voice_probe.gd) in the same change.
5. Run the journal probe and the voice probe if titles, clues, or page reactions
   changed.

### Edit or add a spoken line

`lines.json` has four keyed categories (`pages`, `deciphered`, `places`, and
`revisits`), three staged categories (`bored` and `calls` under `hope`, `doubt`,
and `resolve`), and the `misread` array. Every entry needs `text` and one of
these moods:

`steady`, `warm`, `hushed`, `shaken`, `breaking`, `resolve`, or `calling`.

1. Edit the line's exact `text` and optional `mood` in
   [assets/audio/voice/lines.json](assets/audio/voice/lines.json). Changing
   either changes the clip filename, which is the SHA-256 of `text|mood`.
2. Update the matching spoken-script entry in
   [docs/MATHILDA_STORY.md](docs/MATHILDA_STORY.md). Page prose itself remains
   in `NoteCatalog`; changing a reaction does not change the page.
3. Run the baker self-test, then bake the exact edited text. This example reads
   the line directly from JSON so PowerShell preserves its punctuation:

   ```powershell
   python tools/bake_speech.py --self-test
   $line = (Get-Content assets/audio/voice/lines.json -Raw | ConvertFrom-Json).pages.'by the bed'.text
   build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --only $line
   ```

   For an idle thought or a call, select its staged array item instead, for
   example `.calls.hope[0].text`. `--only` is an exact match. A mood-only
   change still requires a re-bake using the unchanged text.
4. Listen to the generated WAV. Import it and require every scripted line to
   load:

   ```powershell
   godot --headless --path . --import
   $env:PROBE_CLIPS = "1"
   godot --headless --path . tools/voice_probe.tscn
   Remove-Item Env:PROBE_CLIPS
   godot --headless --path . tools/journal_probe.tscn
   ```
5. Stage the changed script, story document, generated manifest, WAV, and any
   confirmed-obsolete clip deliberately. A normal full bake removes unreferenced
   WAVs; for a one-line bake, remove an old hash only after confirming that no
   current line uses it.

### Generate or refresh the voice set

Voice clips are generated with Qwen3-TTS on CUDA into
[assets/audio/voice/](assets/audio/voice/). The game ships only the WAVs and
JSON; models, references, and the Python environment stay under the ignored
`build/voice/` directory.

Before a full bake, create and listen to the anchor:

```powershell
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --anchor-only
```

Keep the approved anchor, or deliberately re-roll it with
`--anchor-only --new-anchor --anchor-seed N`. Then generate the reviewed script:

```powershell
# Resume missing clips.
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py

# Recreate every clip only after approving the anchor.
build/voice/gpu-venv/Scripts/python.exe tools/bake_speech.py --force
```

The baker renders directed takes, checks word error rate and anchor similarity,
and checkpoints [manifest.json](assets/audio/voice/manifest.json) after each
accepted line. Scores confirm transcription and voice consistency, not acting
quality: listen to every changed clip. If a line fails, correct or re-bake it;
use `--accept-bad` only as an explicit, reviewed exception.

## Credits and licensing

Asset licences and provenance live beside the relevant assets, including the
[elf](assets/characters/styloo_elf/README.md), environment assets, and
`assets/vendor/` and `assets/audio/` provenance records. Walk and jog motion in
[assets/characters/styloo_elf/feminine/](assets/characters/styloo_elf/feminine/)
is adapted from the Bandai Namco Research Motion Dataset (CC BY-NC 4.0).
Accordingly, Run Away is non-commercial.
