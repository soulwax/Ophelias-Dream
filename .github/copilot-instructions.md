# Ophelia's Dream: Copilot instructions

## Project and source of truth

Ophelia's Dream is a Godot 4.7 third-person winter-horror game written in
typed GDScript. It uses Forward+ rendering and Jolt physics. When documents
disagree with runtime code, trust the code. `docs/PLAN.md` and several older
design documents describe superseded gameplay.

Read [README.md](../README.md), [AGENTS.md](../AGENTS.md), and
[CLAUDE.md](../CLAUDE.md) before work that affects the areas they cover.
`README.md` is the current onboarding and authoring entry point; `AGENTS.md`
and `CLAUDE.md` contain the detailed runtime, asset, and release constraints.

## Commands and verification

Run commands from the repository root with Godot 4.7 on `PATH`. There is no
general unit-test runner, lint task, formatter, or coverage gate. Each
`tools/*_probe.tscn` scene is an independently runnable, focused test; use the
smallest probe that exercises the changed system.

```powershell
# Run the game or open it in the editor.
godot --path .
godot --path . -e

# Required after adding a class_name script or importing an asset.
godot --headless --path . --import

# Focused story and voice tests.
godot --headless --path . tools/journal_probe.tscn
godot --headless --path . tools/voice_probe.tscn
$env:PROBE_CLIPS = "1"; godot --headless --path . tools/voice_probe.tscn; Remove-Item Env:PROBE_CLIPS

# Focused dialogue and Mathilda-chapter tests.
python tools/bake_meeting.py --check
python tools/bake_meeting.py --paths
godot --headless --path . tools/meeting_probe.tscn
godot --headless --path . tools/mathilda_probe.tscn

# Focused movement and level tests.
godot --headless --path . -s tools/leap_math_probe.gd
godot --headless --path . tools/leap_probe.tscn
godot --headless --path . tools/traversal_probe.tscn
godot --headless --path . tools/note_access_probe.tscn
godot --headless --path . tools/house_space_probe.tscn
godot --headless --path . tools/terrain_probe.tscn

# Rendered smoke capture.
$env:RUN_CAPTURE = "1"; $env:RUN_SHOT = "$PWD\shot.png"; godot --path .; Remove-Item Env:RUN_CAPTURE, Env:RUN_SHOT

# Crash-safe runtime logging.
.\tools\run_blackbox.ps1

# Windows release; synchronizes version metadata and handles encrypted export.
.\tools\export_release.ps1
```

Set `RUN_GRAPHICS=lean` for constrained GPUs. Use `RUN_MENU=<page>`,
`RUN_JOURNAL=<title>`, or `RUN_ENDING=road|prints` with `RUN_CAPTURE` for
targeted UI captures. `RUN_MATHILDA=1` starts Mathilda's optional chapter; use
`RUN_MEETING=1|open` to start it at, or directly open, the doorstep meeting.

## Architecture

### Runtime composition and global state

`scenes/main.tscn` is intentionally minimal. `scripts/main.gd` builds the
runtime graph in code: atmosphere, trail, player, weather, wildlife,
soundscape, voice (or Mathilda's POV voice), dialogue UI, and HUD.

`Game` (`scripts/game/game.gd`) is the autoload hub. It owns the phase machine
(`BOOT`, `INTRO`, `PLAYING`, `READING`, `PAUSED`, `CAUGHT`, `ESCAPED`,
`JOURNAL`, `DIALOGUE`), gameplay-wide references, journal state, endings, and
signals. Systems register themselves on `Game` during `_ready()` and collaborate
through those references and signals rather than node paths. Do not bypass the
phase API: `locks_movement()`, `locks_look()`, and `awake()` preserve the
different rules for reading, journaling, pausing, and dialogue.

Input actions are created in `Game._ready()`, not in `project.godot`.
Rebindable actions must also be added to `Settings.ACTIONS` in
`scripts/game/settings.gd`; the menu persists them in `user://settings.cfg`.
Use `Game.settings` for user-configurable behavior. Audio players must be
assigned to the established `Ambience`, `Effects`, or `Dread` buses.

### World, house, and authored snapshots

`Trail` constructs terrain, route, fences, field notes, flora, landmarks, and
the house. Place world content through the trail/ground helpers rather than
hard-coded Y coordinates. `House` constructs the cabin, cellar, interactables,
lighting, and haunting systems.

The live world is built in code, but `scenes/editable_level.scn` and
`scenes/generated/` are editable snapshots. At startup,
`EditableLevel.apply()` reapplies authored scene properties to matching
generated nodes. Preserve this correspondence:

- Build new runtime nodes with the repository's `_ready()` / `_build_*()`
  pattern; do not move regular gameplay construction into editor-authored
  scenes.
- Read `docs/EDITOR.md` before touching the saved level.
- Changes to `scripts/world/` or `scripts/house/` node structure require a
  snapshot rebuild through Main's **Randomize / rebuild editable level** tool.
  Rebuilding replaces the saved snapshots and hand edits; ask before doing it.
- Keep sound-only nodes outside editable trees, or append them last. Keep
  authoring marker groups at the end of their parent trees.

### Story, voice, and dialogue

The journal is data-driven by `NoteCatalog` in
`scripts/notes/note_catalog.gd`. A `{word}` in page text has an ordered smudge
definition: the first reading is correct and its `page:`, `place:`, or
`event:` key determines when it unlocks. `Game.known()` and `Game.decipher()`
implement those rules. Changing page titles, key names, page counts, or smudge
counts requires updating the matching voice entries and relevant probe
assertions.

`docs/MATHILDA_STORY.md` is the script of record for Ophelia's spoken lines.
Do not hand-maintain `assets/audio/voice/lines.json`; regenerate and verify it:

```powershell
python tools/script_to_lines.py
python tools/script_to_lines.py --check
```

`Voice` loads those clips, stages them by discovery/turn state, and uses
priority plus forget-on-interrupt semantics. Clip paths are SHA-256 hashes of
the exact UTF-8 `text|mood`; a text or mood change needs a new clip. Follow
`docs/VOICE.md` for the Qwen impression and Chatterbox bake flow. No model runs
in the game. Never run the obsolete `tools/bake_voice.py`.

The optional first-person Mathilda chapter is implemented by
`scripts/player/mathilda_pov.gd` and has separate source clips under
`assets/audio/voice/mathilda/`. The doorstep conversation joins
`docs/MATHILDA_MEETING.md` (spoken script) with
`assets/dialogue/meeting.json` (branch tree). Run
`python tools/bake_meeting.py --check` after either changes; it validates line
coverage, answer links, intensity transitions, overlaps, and generated timing.

## Project-specific conventions

- Use UTF-8, tabs, typed GDScript declarations and return types,
  `snake_case` files/functions, `PascalCase` classes, and `UPPER_SNAKE_CASE`
  constants. Reusable scripts declare `class_name` and are referenced by that
  class name rather than `preload`.
- Keep balance values in `scripts/tune.gd`; do not scatter gameplay constants.
- Construct UI and nodes in code with the established `_ready()` / `_build_*()`
  style. A full-screen `Control` also needs
  `set_anchors_and_offsets_preset`, not only anchors.
- Teleports must call `reset_physics_interpolation()`. Disable interpolation for
  pooled effects that jump locations and nodes moved in `_process`.
- Implement interactables using the repository contract: join the
  `interactables` group and expose `interact_label()`, `interact_point()`,
  `interact()`, and `aim_box()`. Let `Player.aim` choose the target.
- Prefer `Game.*` registrations and signals over scene paths or duplicated
  state. Preserve phase behavior when adding UI, voice, or player controls.
- `scenes/main.tscn` is the entry scene, but generated files are not disposable
  build output: preserve authored snapshot edits unless an explicit rebuild is
  approved.
- Keep `project.godot` `config/version` synchronized with
  `export_presets.cfg` product/file versions. Use `tools/export_release.ps1`
  for release exports rather than editing encryption settings manually.
- Preserve asset provenance and licensing. The feminine walk/jog source is
  CC BY-NC 4.0, so the game is non-commercial. Do not commit `.godot/`,
  `build/`, scratch captures, local voice environments/models, or
  `godot.gdkey`.
