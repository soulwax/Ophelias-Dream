# Internal tools: practical guide

Run these commands from the repository root in PowerShell. Use Godot **4.7.2
Mono** with the .NET 8 SDK: the project includes C# and needs the matching
Godot .NET export templates.
On the current workstation:

```powershell
$env:GODOT_BIN = 'C:\Users\soulwax\scoop\apps\godot-mono\current\godot-mono.console.exe'
dotnet build OpheliasDream.csproj
& $env:GODOT_BIN --headless --path . --import
```

The import registers new `class_name` scripts and imports changed assets. Run
it after adding either. Use `& $env:GODOT_BIN --path . -e` to open the editor and
`& $env:GODOT_BIN --path .` to play. `RUN_GRAPHICS=lean` selects the lighter
graphics path on constrained GPUs. Remove temporary environment variables
after a run with `Remove-Item Env:<name>`.

## Story and audio authoring

Start the local browser app with `python tools/studio/server.py`. It opens Story
Studio at `http://127.0.0.1:4317`; use `--no-browser` to open the URL yourself.
The app has these working areas:

| Area | Use it for | Where changes go |
| --- | --- | --- |
| Lines | Find a line, edit words/mood, audition, then save | Script of record and regenerated line data only after **Save to script** |
| Review | Compare new clips with earlier clips; accept, reject, or retake | Review decisions in ignored `build/studio/`; rejected clips are archived |
| Bake & check | Run the visible bake and validation commands | Reviewed audio and generated data where the underlying command writes them |
| Voices | Inspect model readiness, stage curated Qwen weights, compare experimental pipelines and conversation variants | Weights in ignored `build/voice/hf/`; auditions in ignored scratch |
| SFX | Search game WAV/Ogg effects, hear them, inspect script references, replace a file | Same-format CC0 replacement at the existing path; prior file and provenance archived |
| Dream story | Edit the standalone dream's branching subtitles | `assets/dialogue/dream.json` after a validated save |

Open a line in **Lines** to audition Kokoro, Qwen or Chatterbox. Qwen Base and
direct Chatterbox use an approved character recording as their identity
reference; the lab lets you hear it. Qwen expression can be followed by an
Ophelia identity pass, retaining the raw and converted scratch takes for A/B
listening. These are experiments, not production clips: listen and use the
normal bake/review path before a voice enters the game. The app reports missing
weights, CUDA runtimes, and references. See [Story Studio](STORY_STUDIO.md) and
[voice production](VOICE.md) for the full workflows. `tools/bake_voice.py` is
obsolete and must not be used.

For source drift and inventory without opening the app:

```powershell
python tools/script_to_lines.py --check
python tools/voice_status.py
python tools/bake_meeting.py --check
& $env:GODOT_BIN --headless --path . tools/voice_probe.tscn
```

After an approved Ophelia script change, run `python tools/script_to_lines.py`
to regenerate `assets/audio/voice/lines.json`; `--check` only reports drift.
After changing Story Studio itself, run its focused checks directly:

```powershell
python -B tools/studio/test_models.py
python -B tools/studio/test_pipelines.py
python -B tools/studio/test_sfx.py
python -B tools/studio/test_dream_story.py
python -B tools/studio/test_chains.py
python -B tools/studio/test_writers.py
```

These scripts have `main()` entry points rather than a test-runner discovery
suite.

Set `$env:PROBE_CLIPS = '1'` before `voice_probe.tscn` when checking that all
required baked clips load, then remove it. The written story is not a single
JSON file: Ophelia's speech comes from [MATHILDA_STORY.md](MATHILDA_STORY.md),
Mathilda's chapter from [MATHILDA_POV.md](MATHILDA_POV.md), the lake from
[LAKE_MEETING.md](LAKE_MEETING.md), the doorstep from
[MATHILDA_MEETING.md](MATHILDA_MEETING.md), and dream subtitles from
`assets/dialogue/dream.json`. Journal pages live in
`scripts/notes/note_catalog.gd`. Consult the
[story contract](mvp/STORY_CONTRACT.md) before adding or changing approved
dialogue.

## Probes and captures

Run a focused probe after changing the system it exercises. A passing probe
supports that feature; it does not replace a full playthrough or a packaged
build check.

| Change area | Representative check |
| --- | --- |
| Journal, pages, voice | `tools/journal_probe.tscn`, `tools/voice_probe.tscn`, `tools/note_access_probe.tscn` |
| Dream branching, flow, pause | `tools/dream_branches_probe.tscn`, `tools/dream_flow_probe.tscn`, `tools/dream_pause_probe.tscn`, `tools/dream_story_probe.tscn` |
| House and optional activities | `tools/house_space_probe.tscn`, `tools/house_domestic_probe.tscn`, `tools/warm_house_probe.tscn`, `tools/cups_probe.tscn`, `tools/errand_probe.tscn` |
| Interaction and movement | `tools/interaction_probe.tscn`, `tools/carry_probe.tscn`, `tools/hold_probe.tscn`, `tools/leap_probe.tscn`, `tools/traversal_probe.tscn` |
| Endings, encounters, conversations | `tools/ending_probe.tscn`, `tools/checkpoint_probe.tscn`, `tools/encounter_probe.tscn`, `tools/meeting_probe.tscn` |
| Terrain, flora, materials, vendor fallback | `tools/biome_probe.tscn`, `tools/flora_probe.tscn`, `tools/ground_material_probe.tscn`, `tools/vendor_probe.tscn` |

For example:

```powershell
& $env:GODOT_BIN --headless --path . tools/cups_probe.tscn
$env:RUN_VENDOR = 'off'
& $env:GODOT_BIN --headless --path . tools/warm_house_probe.tscn
Remove-Item Env:RUN_VENDOR
```

Some save/load probes use the game's real `user://` save path. Back up a
personal run before using them. `RUN_VENDOR=off` checks the asset fallback
without the owner's local pack.

The visual tools open a window and write captures under ignored `build/`:

```powershell
& $env:GODOT_BIN --path . tools/terrain_view.tscn
& $env:GODOT_BIN --path . tools/camp_view.tscn
& $env:GODOT_BIN --path . tools/lake_view.tscn
& $env:GODOT_BIN --path . tools/dream_view.tscn
```

For a startup screenshot:

```powershell
$env:RUN_CAPTURE = '1'
$env:RUN_SHOT = "$PWD\shot.png"
& $env:GODOT_BIN --path .
Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT
```

`RUN_MENU=<page>`,
`RUN_JOURNAL=<title>`, and `RUN_ENDING=road|prints` open targeted captures.
Use `RUN_GRAPHICS=lean` to inspect the reduced path.

`./tools/run_blackbox.ps1` captures durable logs in `build/blackbox/`; that
helper currently launches `godot` by name, so it requires the Mono executable
on `PATH`. For routine checks, invoke `GODOT_BIN` directly as above.

## Character, level, and asset tools

`& $env:GODOT_BIN --path . tools/animation_workbench.tscn` auditions clips
against the game rig. Read [ANIMATION_WORKBENCH.md](ANIMATION_WORKBENCH.md)
for timing and track checks. The character gallery is
`scenes/character_presentation.tscn`; its creator stores local designs under
Godot `user://characters/`. Read [CHARACTER_CUSTOMIZATION.md](CHARACTER_CUSTOMIZATION.md)
for that workflow. Read [EDITOR.md](EDITOR.md) before regenerating
`scenes/generated/`: rebuilding snapshots can overwrite hand placement.

Source optional environment props from the owner's central asset bank at
`C:\Users\soulwax\OneDrive - Biz\Desktop\Assets` first. Use the relevant
`tools/curate_camp_assets.py`, `tools/curate_errand_assets.py`, or
`tools/curate_nature_assets.py` helper; house curation uses
`tools/curate_house_assets.gd`. Check each tool's output paths before running
it. Curated
proprietary assets stay in ignored `build/vendor/requested_<area>/`, with
source paths and hashes recorded in `docs/<area>/` manifests. The runtime
uses `VendorLoader` and a fallback when the pack is absent. Do not put
unverified proprietary assets under tracked `assets/` or commit `build/`.

## Release candidate

Only run release export for a candidate you intend to inspect. First build
C#, import, and run the affected probes and a continuous playthrough. The
export helper synchronizes version fields, adjusts the export preset, creates
local export credentials/key material as needed, and writes a Windows build:

```powershell
dotnet build OpheliasDream.csproj
& $env:GODOT_BIN --headless --path . --import
./tools/export_release.ps1
```

Use `./tools/export_release.ps1 -Version <four-part-version>` only when a
version change is intended. A working Windows package needs both
`build/windows/Ophelia's Dream.exe` and its
`data_OpheliasDream_windows_x86_64` folder. Copy licensed runtime vendor
content into the package layout before final validation; test the package
with and without that pack, and with the source tree unavailable. The
[masterplan's release gates](../MASTERPLAN.md#5-dependency-order-and-gates)
and [asset decision](../MASTERPLAN.md#decisions-and-contradictions-to-close-at-g0)
govern what can be shipped. Never commit `.godot/`, `build/`, `godot.gdkey`,
downloaded models, or local captures.
