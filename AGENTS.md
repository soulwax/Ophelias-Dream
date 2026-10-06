# Repository Guidelines

## Project Structure & Module Organization

Run Away is a third-person winter horror game using Godot 4.7, Forward+ rendering, and Jolt physics.

- `scenes/main.tscn` is the entry scene; `scripts/main.gd` constructs gameplay systems in code.
- `scripts/` groups GDScript by responsibility: `player/`, `world/`, `house/`, `weather/`, `audio/`, `notes/`, and `ui/`. There are no threats in the field at the moment; candidates are in `docs/THREATS.md`.
- `assets/characters/styloo_elf/` contains the player model, textures, baked animations, and CC0 license; her walk and jog in `feminine/` are CC BY-NC 4.0, so the game is non-commercial. `addons/quaternius_ik_rigged/` supplies the shared animation source. `shaders/` holds GPU shaders.
- `Hud` creates `Journal` alongside the reader and menus. The HUD has no objective; `show_journal_toast` controls its journal notice. The rebindable `journal` action uses J/Tab and pad Y. `NoteCatalog` parses `{word}` smudges, unlocked through `Game.known` and solved through `Game.decipher`. `Phase.JOURNAL` locks her controls while `Game.awake()` keeps the world running.
- `Voice` plays 137 lines in 14 moods from `docs/MATHILDA_STORY.md`, the script of record; `tools/script_to_lines.py` writes `lines.json` from it.
  - Groups: pages, places, stages (with `after` once she turns around), memories, calls, breath, cold, falls, spoken endings.
  - Priorities with forget-on-interrupt.
  - The trees answer in her own voice; Mathilda never speaks.
  - Baking: Qwen3-TTS renders one impression per mood (`build/voice/gpu-venv`, `--impressions`). `--unify` gives each one steady's voice. Chatterbox (`build/voice/cb-venv`) then clones each line from its mood's reference and writes `build/voice/review.html`.
  - Reproducibility: the references, raw picks, `voice_lock.json` and frozen requirements are committed in `tools/voice/` (Godot-ignored); refresh them with `--lock`.
  - Clip names: SHA-256 of `text|mood`. Clips are never deleted, only moved to `build/voice/archive/`.
  - See `docs/VOICE.md`; do not run the obsolete `tools/bake_voice.py`.
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
godot --headless --path . -s tools/probe.gd # Inspect meshes/animations
godot --headless --path . -s tools/retarget_elf.gd # Rebuild elf movement clips
godot --headless --path . -s tools/leap_math_probe.gd # Running-leap math checks
godot --headless --path . tools/leap_probe.tscn # Running leap on the real player
godot --path . -s tools/leap_sheet.gd # Leap contact sheet (needs a window)
./tools/run_blackbox.ps1         # Run with logs in build/blackbox/
```

For a Windows release, install matching export templates, create `build/windows/`, then run:

```powershell
godot --headless --path . --export-release "Windows Desktop" "build/windows/Run Away.exe"
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

Preserve vendor provenance and licensing records. Exclude `.godot/`, build outputs, and scratch screenshots from commits. `tools/prepare_elf.py <original-elf.glb>` strips bundled weapons before importing the elf; inspect other asset generators' output paths before running them.
