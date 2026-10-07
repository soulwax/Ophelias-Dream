# Repository Guidelines

## Project Structure & Module Organization

Ophelia's Dream is a third-person winter horror game using Godot 4.7, Forward+ rendering, and Jolt physics.

- `scenes/main.tscn` is the entry scene; `scripts/main.gd` constructs gameplay systems in code.
- `scripts/` groups GDScript by responsibility: `player/`, `world/`, `house/`, `weather/`, `audio/`, `notes/`, `npc/` and `ui/`. Performance-critical code is C# (`OpheliasDream.csproj`; so far `scripts/npc/Wanderer.cs`): use the `godot-mono` build and run `dotnet build OpheliasDream.csproj` first. There are no threats in the field at the moment; candidates are in `docs/THREATS.md`.
- `assets/characters/styloo_elf/` contains the player model, textures, baked animations, and CC0 license; her walk and jog in `feminine/` are CC BY-NC 4.0, so the game is non-commercial. `addons/quaternius_ik_rigged/` supplies the shared animation source. `shaders/` holds GPU shaders.
- `Hud` creates `Journal` alongside the reader and menus. The HUD has no objective; `show_journal_toast` controls its journal notice. The rebindable `journal` action uses J/Tab and pad Y. `NoteCatalog` parses `{word}` smudges, unlocked through `Game.known` and solved through `Game.decipher`. `Phase.JOURNAL` locks her controls while `Game.awake()` keeps the world running.
- The lookout at the end of the drawn route is a checkpoint and a false lead (two lanterns, no car); posts lead on to the frozen lake (`Lake`, `scripts/world/lake.gd`), where the run ends. `Game.restart(true)` resumes from the lookout. The lake needs three journal pages; a whole in-game day (40 minutes) without an attempt ends on "Mathilda is gone"; with every trail page read, the last deciphered and no turning around, Mathilda waits on the ice for a conversation (`docs/LAKE_MEETING.md`, `assets/dialogue/lake.json`) that ends "Together" or "On the shore".
- `Voice` plays 182 lines in 14 moods from `docs/MATHILDA_STORY.md`, the script of record; `tools/script_to_lines.py` writes `lines.json` from it.
  - Groups: pages, places, stages (with `after` once she turns around), memories, calls, breath, cold, falls, spoken endings.
  - Priorities with forget-on-interrupt.
  - The trees answer in Ophelia’s own voice; Mathilda speaks in Ophelia’s chapter only on the ice and when they pass each other. The optional first-person Mathilda chapter (`scripts/player/mathilda_pov.gd`, `docs/MATHILDA_POV.md`) has 69 separate lines and clips under `assets/audio/voice/mathilda/`.
  - Whoever is played, the other woman wanders her own afternoon (`Encounters` + `Wanderer`, docs/MATHILDA_STORY.md *When they pass each other*): at most three rare, unfinished passings per run, remembered by both meetings. The main menu offers OPHELIA and MATHILDA side by side and opens on either at random.
  - Baking: Qwen3-TTS renders one impression per mood (`build/voice/gpu-venv`, `--impressions`). `--unify` gives each one steady's voice. Chatterbox (`build/voice/cb-venv`) then clones each line from its mood's reference and writes `build/voice/review.html`.
  - Reproducibility: the references, raw picks, `voice_lock.json` and frozen requirements are committed in `tools/voice/` (Godot-ignored); refresh them with `--lock`.
  - Clip names: SHA-256 of `text|mood`. Clips are never deleted, only moved to `build/voice/archive/`.
  - See `docs/VOICE.md`; do not run the obsolete `tools/bake_voice.py`.
- `Camp` (`scripts/world/camp.gd`) builds Mathilda's camp: a canvas tent, a shader-driven campfire whose melted ring grows slowly, smoke, a woodpile, stool, crate table and lantern. Her chapter starts `Atmosphere.start_clock(Tune.MATHILDA_DUSK)`: early dusk, a whole day every `Tune.DAY_MINUTES` minutes; Ophelia's afternoon never moves.
- After the last page, holding glance-back outdoors turns her around (`Game.turn_around()`); the escape card then reads "One set of prints".
- `tools/` contains probes, asset generators, and diagnostic scripts. `docs/PLAN.md` records the original design; prefer current code when it disagrees.

## Build, Test, and Development Commands

Run these from the repository root with Godot 4.7 on PATH:

```powershell
godot --path .                  # Run the game
godot --path . -e               # Open the editor
godot --headless --path . --import # Import assets/register new classes
godot --headless --path . tools/journal_probe.tscn # Journal rules and UI
godot --headless --path . tools/voice_probe.tscn # Voice rules; PROBE_CLIPS=1 checks clips
python tools/bake_meeting.py --check               # meeting script coherent, lines/timing current
godot --headless --path . tools/meeting_probe.tscn # Mathilda meets Ophelia at the door (docs/DIALOGUE.md)
godot --headless --path . -s tools/probe.gd # Inspect meshes/animations
godot --headless --path . -s tools/retarget_elf.gd # Rebuild elf movement clips
godot --headless --path . -s tools/leap_math_probe.gd # Running-leap math checks
godot --headless --path . tools/leap_probe.tscn # Running leap on the real player
godot --path . -s tools/leap_sheet.gd # Leap contact sheet (needs a window)
godot --headless --path . tools/biome_probe.tscn # Snow weight, thaw bands, seams, world edge
godot --headless --path . tools/flora_probe.tscn # Woods by biome (also with RUN_GRAPHICS=full)
godot --headless --path . tools/biome_effects_probe.tscn # Grass/thaw steps, prints, snowfall over green
godot --path . tools/terrain_view.tscn # Overview shots + FPS into build/terrain/ (needs a window)
python tools/curate_camp_assets.py   # Camp props from the owner's asset bank (ignored)
godot --path . tools/camp_view.tscn  # Camp shots into build/camp/ (RUN_HOUR=19.5 for night)
./tools/run_blackbox.ps1         # Run with logs in build/blackbox/
```

For a Windows release, install matching export templates, create `build/windows/`, then run:

```powershell
godot --headless --path . --export-release "Windows Desktop" "build/windows/Ophelia's Dream.exe"
```

## Coding Style & Naming Conventions

Use UTF-8, tabs, typed GDScript declarations and returns, `snake_case` filenames/functions, `PascalCase` class names, and `UPPER_SNAKE_CASE` constants. Declare `class_name` for reusable systems. No formatter or linter is configured.

Construct nodes and UI in code following existing `_ready()`/`_build_*()` patterns. Register systems and input actions through the `Game` autoload; keep balance constants in `scripts/tune.gd`. Synchronize application and export versions.

## Testing Guidelines

There is no automated test framework, test naming convention, or coverage threshold. Validate changes through gameplay and relevant `tools/*_probe.gd` diagnostics. Check movement, interactions, and affected phase transitions.

For a screenshot smoke test:

```powershell
$env:RUN_CAPTURE = "1"
$env:RUN_SHOT = "$PWD/shot.png"
godot --path .
Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT
```

This skips the intro, captures frame 150, and exits. `RUN_MENU=<page>` opens the Esc menu; `RUN_JOURNAL=<title>` opens a half-deciphered journal for capture; `RUN_ENDING=road|prints` shows an escape card. Use `RUN_GRAPHICS=lean` on constrained GPUs.

## Commit & Pull Request Guidelines

History uses descriptive prose sentences without Conventional Commit prefixes. Describe the gameplay or asset change clearly. For PRs, include purpose, affected systems, validation commands/results, related issues when applicable, and screenshots for visual changes.

## Asset Hygiene

Preserve vendor provenance and licensing records. Owner-supplied packs without verified redistribution rights stay ignored (`assets/vendor/requested_house/`, `assets/vendor/requested_camp/`) with their manifests in `docs/`, and the game falls back without them; copy them into the export worktree before a release. Exclude `.godot/`, build outputs, and scratch screenshots from commits. `tools/prepare_elf.py <original-elf.glb>` strips bundled weapons before importing the elf; inspect other asset generators' output paths before running them.
