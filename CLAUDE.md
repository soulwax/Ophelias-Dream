# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Run Away" — a short third-person winter horror game in **Godot 4.7** (Forward+, Jolt physics, D3D12 on Windows), written entirely in GDScript. The `godot` binary on PATH (scoop shim) is 4.7.2. There is no test suite and no linter; verification is done by running the game or capturing a screenshot.

`docs/PLAN.md` is the original design doc (night ridge, the hunter that follows the trail by offset). The game has since become an open, fenced daylight snowfield, and in it the hunter is not tied to the trail (see below). Where PLAN.md and the code disagree, trust the code.

## Commands

```powershell
# Run the game
godot --path .

# Open the editor
godot --path . -e

# Re-import assets headlessly (after adding FBX/PNG/WAV files)
godot --headless --path . --import

# Screenshot smoke test: skips the intro, renders 150 frames, saves a PNG, quits
$env:RUN_CAPTURE = "1"; $env:RUN_SHOT = "$PWD\shot.png"; godot --path .
# (RUN_SHOT defaults to user://run_shot.png; clear both env vars afterwards)

# Probe mesh bounds / animation names from the asset packs
godot --headless --path . -s tools/probe.gd

# Windows export (preset "Windows Desktop", embedded PCK -> build/windows/Run Away.exe)
godot --headless --path . --export-release "Windows Desktop" "build/windows/Run Away.exe"

# Crash-safe logging run (game + disk-flushing hardware monitor, logs in build/blackbox/)
./tools/run_blackbox.ps1
```

This machine (ThinkPad, Iris Xe) has hard-frozen while running the game. `Game.lean_graphics` is on automatically for non-discrete GPUs (no volumetric fog/FogVolume/SSAO, 2 shadow splits, half the snow); override with `RUN_GRAPHICS=full|lean`. `RUN_BLACKBOX=<path>` makes `Blackbox` stream startup stages, phases and a 0.5 s performance beat to that file; `Game.mark()` adds a line. After adding a new `class_name` script, run `godot --headless --path . --import` or headless runs fail to resolve it.

F3 toggles a debug label (hunter gap and stamina) in debug builds.

`tools/*.py` are one-off asset generators: `make_storm.py` and `make_taps.py` synthesize WAVs into `assets/audio/`, and `paint_coat.py` (needs Pillow) retints the Quaternius body texture into `assets/characters/girl_coat.png`. They write to **hardcoded absolute paths** under `C:\Users\soulwax\Workspace\Godot\run`. `tools/prev_*.png` are scratch previews and are not part of the game.

## Architecture

**Everything is built in code.** `scenes/main.tscn` is just a root `Node3D` with `scripts/main.gd`. `main.gd` instantiates every system with `ClassName.new()` in order: Atmosphere → Trail → Player → Hunter → Weather → Soundscape → Hud. No other `.tscn` files are authored. Nodes, lights, materials, collision and UI are all constructed in `_ready()`/`_build_*()` methods. New features follow this pattern, not editor-authored scenes.

**`Game` autoload (`scripts/game/game.gd`)** is the hub:
- Holds the phase state machine (`BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED`) and emits `phase_changed` / `closeness_changed`. UI and audio subscribe to these signals.
- Each system registers itself on the autoload in its `_ready()` (`Game.player = self`, `Game.trail = self`, `Game.weather = self`, …), and other systems reach each other through `Game.*`, not node paths.
- Registers all input actions in code with `_bind()`. There is no `[input]` section in `project.godot`, so new actions go here.
- `locks_movement()` / `locks_look()` gate player control by phase. `restart()` resets state and reloads the scene.
- `closeness` (0–1) is the single "how near is it" value. The hunter sets it, and the HUD vignette, breath and audio react to it. The UI never shows distances.

**`Tune` (`scripts/tune.gd`)** holds all balance constants: speeds, stamina, catch gap, reveal distances, fence bounds, and collision layers (`LAYER_WORLD=1`, `LAYER_ACTOR=2`). Change feel here, not in the systems.

**World (`scripts/world/`)**: `Trail` owns a `Curve3D` (fixed seed 1701) and builds `Ground` (heightfield, `height_at(x,z)`), `Fence`, the landmarks, the `FieldNote` pickups and `Flora`. Use `trail.on_ground()` / `ground.height_at()` to place anything on the terrain. `Trail._reserve()` keeps flora away from landmarks. The exit is the lookout plus headlights at `trail.exit_point`. `PropFactory` loads FBX files from `assets/environment/` once, hides LOD1–3 meshes, and overrides every material with a flat winter palette chosen by filename keyword (`_family()`), or with an alpha-scissor material for the foliage textures. A missing mesh falls back to a box.

**Hunter (`scripts/hunter/hunter.gd`)** has two modes, switched by `Game.notes_found` against `Tune.HUNT_NOTES` (3):
- *Stalk* (before the third note): it appears at a distance off to the side of the camera's view, vanishes if watched, approached or timed out, and reappears sooner as more notes are read.
- *Pursue* (from the third note on): it walks straight at the player, clamped inside the fence bounds, with no navmesh. Speed and reveal scale with `_threat()`, which combines notes read past the threshold with `Game.seconds_hunting()`. It catches when the gap is under `CATCH_GAP`.

The hunter also detects escape: the player within `EXIT_RADIUS` of `trail.exit_point` triggers it.

**Locomotion (`scripts/player/stride.gd`, `snow_kick.gd`)**:
- `Stride` builds an `AnimationTree` from code. A BlendSpace1D (Idle, Walk_Formal, Jog_Fwd, Sprint) is driven by her ground speed, and a TimeScale sets the playback rate so the planted foot moves at that speed.
- Natural clip speeds (`Tune.STRIDE_WALK/JOG/SPRINT`) were measured with `godot --headless --path . -s tools/stride_probe.gd`. The probe has to disable the rig's `TwoBoneIK3D` modifiers and let frames tick, because a bare `seek()` doesn't apply poses there.
- A OneShot plays the exhaustion stumble (Hit_Chest).
- Each running gait spans a plateau (two blend points with the same clip), so a steady speed plays one clip. Blending clips whose cycles differ muddles the legs.
- `FootLock` (`foot_lock.gd`) is a `SkeletonModifier3D` moved in front of the rig's leg `TwoBoneIK3D` nodes, whose influence starts at 0.
  - When the animated foot comes down (judged against its own recent low point, or at the bottom of its swing for brief sprint contacts, and only after it has really swung), it locks that terrain spot. The IK holds the foot there until the animation lifts it or the leg overreaches.
  - It emits `planted(left, at)`, and `Player._on_planted` does all footfall effects: sound, prints, `SnowKick` powder and camera jolt. The distance-based trigger in `_steps` is only a fallback.
- Per-step dynamics: `_step_surge()` swings speed within each step (`Tune.STEP_SURGE_*`), checking on landing and surging on push-off.
- Momentum is in `Player._momentum` (accelerate, coast, or brake on reversal), and `_slope_factor` slows her uphill.
- Dev hook: `RUN_AUTOPILOT=walk|sprint` holds forward, for `RUN_CAPTURE` shots.

**Player** is a `CharacterBody3D` with a spring-arm third-person camera, stamina-gated sprint, wind push from `Game.weather` (only while she moves), and `Footprints` decals.
- The model (`visual`) turns toward the direction she's moving, independent of the camera, and leans into acceleration and turns (`_carry`).
- `_fit_boom_to_ground` shortens the camera boom so the camera never goes under the one-sided terrain. Notes are found via the `field_notes` group, and you can't read a note while moving fast. Opening a note enters `READING`, which freezes the player but not the hunter.

**Anomalies (`scripts/anomalies/`)** are original, SCP-style entities that run alongside the hunter. They are not canon SCPs; canon SCP content is CC BY-SA, so keep them original.
- *Anomaly*: each subclass follows one strict rule. It exposes `dread` (0..1), a HUD `hint`, and `record()`, a containment record `NoteEntry` with `record_of` set to its code.
- *AnomalyDirector*: picks `Tune.ANOMALIES_PER_RUN` from `roster()` (add new ones there), lays out the records as `FieldNote`s, and writes the strongest dread to `Game.dread` and its hint to `Game.anomaly_hint`.
- *Records*: they don't count toward `notes_found`. Reading one sets `Game.knows(code)`, which upgrades the vague hint to the actual rule.
- *Threat*: the HUD and soundscape use `Game.threat()`, which is max(hunter closeness, dread).
- *Endings*: anomalies end the run with `catch(title, body)`, which gives a custom end card.
- *Dev hooks*: `RUN_ANOMALY=<code>` forces one, and `RUN_ANOMALY_NEAR=1` places it in front of her. Combine with `RUN_CAPTURE` for a screenshot.
- *Testing*: scripts that reference the `Game` autoload can't be loaded by a `-s` tool script, so test them in the game.
- *The Listener (2-117)* perceives only `Breath.plume`. Space (`hold_breath`) suppresses the steam, drains stamina at `Tune.HOLD_DRAIN`, and ends in a gasp.

**Wardrobe (`scripts/player/outfit.gd`, `cloth.gd`, `breath.gd`)**: `Outfit.dress(model)` dresses the walker in code, and every size it uses is measured from the body mesh's rest pose.
- *Skinned shell*: a copy of her body mesh pushed out along the normals per zone, keeping the bone weights (coat bodice and sleeves, belt, jeans, a bare-neck skin layer whose tone is sampled from the face texture, and a scalp layer). It has two surfaces, fabric and skin.
- *Boots*: lofted from measured foot slices and skinned to the Foot, Toes and LowerLeg binds.
- *Cloth*: the coat skirt, hair locks and scarf are `Cloth`, a world-space Verlet grid pinned to a bone. It has a soft pull toward its rest shape, weighted bend links, capsule colliders, and a Catmull-Rom smoothed render. `panel` splits it into strips, and `card_uv`/`card_layers` turn the strips into hair cards.
- *Breath*: `Breath` emits GPU steam at the mouth. `Player.strain` drives its rhythm; strain rises while sprinting and peaks just after a long sprint.

Look at changes with `godot --path . --resolution 800x900 -s tools/outfit_preview.gd -- <out_dir>`, which renders PNGs from fixed angles, including moving shots. Shaders: `wear.gdshader` (dye in vertex colour, roughness in alpha, velvet sheen, lining on back faces) and `hair.gdshader` (alpha-scissor strands, anisotropic highlight). Two gotchas:
- On `CPUParticles3D`/`GPUParticles3D`, never set `lifetime` or `amount` every frame: it restarts the emitter.
- `MeshInstance3D` already has a `layers` property, so don't reuse that name.

**Actors** both use the Quaternius rig in `addons/quaternius_ik_rigged/`: the player is `Female_Rigged.tscn` with the `girl_coat.png` texture, the hunter is `Master_Rigged.tscn` stretched and painted black. Clip names are resolved by suffix match with fallbacks (`Sprint`→`Jog_Fwd`, `Walk_Formal`→`Walk`), because the rig's animation libraries prefix the clip names.

**Weather** follows the camera and drives several `SnowLayer` particle layers, `StormAudio`, and `Atmosphere.apply_storm(intensity)` from one gust/intensity model. `scripts/world/snowfall.gd` (`Snowfall`) is the older snow system and nothing instantiates it any more.

**UI (`scripts/ui/`)**: `Hud` creates `NoteReader` and `EndCard`. Shared styling (plates, paper, key-hint rows, palette constants) lives in the `UiChrome` class (`chrome.gd`). Note text and its corruption level are data in `NoteCatalog`, separate from the world pickup `FieldNote`.

**Shaders** live in `shaders/` and are loaded by path from code (`snow_ground`, `footprint`, `snowflake`, `vignette`).

## Conventions

- GDScript uses tabs and static typing (`:=`, typed returns, `Array[T]`). Every script declares `class_name` and is referenced by that name, not by preload.
- Keep `config/version` in `project.godot` and `file_version`/`product_version` in `export_presets.cfg` in sync.
- Commit messages are a single descriptive sentence in plain prose about what changed in the game (see `git log`), not conventional-commit prefixes.
