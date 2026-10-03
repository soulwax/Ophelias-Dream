# Repository Guidelines

## Project Structure & Module Organization

Run Away is a third-person winter horror game using Godot 4.7, Forward+ rendering, and Jolt physics.

- `scenes/main.tscn` is the entry scene; `scripts/main.gd` constructs gameplay systems in code.
- `scripts/` groups GDScript by responsibility: `player/`, `world/`, `house/`, `hunter/`, `weather/`, `anomalies/`, `audio/`, `notes/`, and `ui/`.
- `assets/characters/styloo_elf/` contains the player model, textures, baked animations, and CC0 license. `addons/quaternius_ik_rigged/` supplies the hunter and shared animation source. `shaders/` holds GPU shaders.
- `tools/` contains probes, asset generators, and diagnostic scripts. `docs/PLAN.md` records the original design; prefer current code when it disagrees.

## Build, Test, and Development Commands

Run these from the repository root with Godot 4.7 on PATH:

```powershell
godot --path .                  # Run the game
godot --path . -e               # Open the editor
godot --headless --path . --import # Import assets/register new classes
godot --headless --path . -s tools/probe.gd # Inspect meshes/animations
godot --headless --path . -s tools/retarget_elf.gd # Rebuild elf movement clips
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

This skips the intro, captures frame 150, and exits. Use `RUN_GRAPHICS=lean` on constrained GPUs.

## Commit & Pull Request Guidelines

History uses descriptive prose sentences without Conventional Commit prefixes. Describe the gameplay or asset change clearly. For PRs, include purpose, affected systems, validation commands/results, related issues when applicable, and screenshots for visual changes.

## Asset Hygiene

Preserve vendor provenance and licensing records. Exclude `.godot/`, build outputs, and scratch screenshots from commits. `tools/prepare_elf.py <original-elf.glb>` strips bundled weapons before importing the elf; inspect other asset generators' output paths before running them.
