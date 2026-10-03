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
- Jump (Space) and slide (Ctrl/C, from a sprint) are in `Player`.
  - Jumps have coyote time and a jump buffer, variable height, heavier falls, reduced air control, and landings scaled by fall speed.
  - Slides get a speed boost, snow friction, gravity along the slope and limited steering, and you can jump out of one.
  - `Stride` adds layers on top of locomotion: an air pose (Jump_Start, sought by vertical velocity), a slide pose (Crouch_Idle), and a landing one-shot (Jump_Land). Clip phases were found with `tools/clip_probe.gd -- <clips>`.
  - `FootLock.suspended` releases the feet in the air and during a slide.
  - Hold breath is on right mouse button or F.
- Dev hooks: `RUN_AUTOPILOT=walk|sprint|jump|slide` and `RUN_SHOT_FRAME=<n>` (when `RUN_CAPTURE` takes its shot).
- Momentum is in `Player._momentum` (accelerate, coast, or brake on reversal), and `_slope_factor` slows her uphill.
- Dev hook: `RUN_AUTOPILOT=walk|sprint` holds forward, for `RUN_CAPTURE` shots.

**Player** is a `CharacterBody3D` with a spring-arm third-person camera, stamina-gated sprint, wind push from `Game.weather` (only while she moves), and `Footprints` decals.
- The model (`visual`) turns toward the direction she's moving, independent of the camera, and leans into acceleration and turns (`_carry`).
- `_fit_boom_to_ground` shortens the camera boom so the camera never goes under the one-sided terrain. Notes are found via the `field_notes` group, and you can't read a note while moving fast. Opening a note enters `READING`, which freezes the player but not the hunter.

**House (`scripts/house/`)**: the cabin she wakes in, built in code by `House`. Its local frame has +Z facing the trail and y 0 at the boards.
- *Layout*:
  - Ground floor: bedroom (the spawn), entry hall, living room and kitchen, and a back hall with the stair well
  - A 19-step flight down 3.4 m
  - Cellar: landing, corridor, janitor room, and `Morgue`, which is ported from the sibling project `merl`'s `prototype_room.gd`
- *Tools*:
  - `HouseKit`: scanned CC0 Poly Haven materials (world triplanar), props, walls with openings, slabs with holes, stairs (visual treads on one walkable ramp), lights
  - `HouseDoor`: E-to-open hinged leaves on merl's `DoorHingeDynamics`, with `DoorAudio` sounds, in plank, steel and chamber styles
  - `WallSwitch`
  - Interactables join the `interactables` group and expose `interact_label()`, `interact_point()` and `interact()`. `Player.nearby_interactable()` picks one, and the HUD prompt shows its label.
- *Terrain*: `Trail` gives `Ground` a flat pad (`pads`) around the house and a cut (`cuts`) over the stair well. `House.add_snow_patch` refills the cut's 3 m cells outside the walls with the same snow material. The cellar stays under `SLAB_TOP`, below the snow.
- *Indoors*: `Game.indoors()` / `House.contains()`.
  - The camera boom drops to 1.75 m over the shoulder, and her model hides if the camera is crushed into her.
  - No snowfall; the storm is muffled.
  - Floor-tap footsteps instead of snow, no prints or powder, and `FootLock.floor_at` plants feet on the boards.
  - The hunter waits at `House.doorstep()` and cannot catch her inside. The Listener cannot perceive breath through walls.
- *Assets*: from `merl`, CC0, under `assets/vendor/polyhaven/` (`provenance.json`) and `assets/derived/doors/audio/`.
- *Dev hook*: `RUN_SPAWN=outside|bedroom|living|stair|cellar|janitor|morgue`.
- *Darkness*: `Atmosphere.shelter` (eased by `Weather` as the camera goes in or out) drops the daylight ambience to about 7%, so the rooms are only what their lamps make of them. Most lamps are deliberately unlit. Her camera light brightens and widens indoors.
- *Haunting (`haunting.gd`)*: rooms come from `House.room_at()`. Tension rises indoors and drains outside, and events fire at intervals that shorten with it:
  - `flicker`, `creak`, `door`: a visible door drifts on its own via `HouseDoor.drift()`.
  - `knock` (ground floor): becomes `house_knock_hard` when the hunter waits at the doorstep.
  - `steps` (cellar): footsteps cross the floor above toward the head of the stair.
  - `chamber` (morgue): a chamber door opens behind her and its tray slides out.
  - `whisper` (high tension only).
  - Persistent: the bedroom lantern goes out when she leaves and relights when she returns; the sheeted body (`Morgue.body`) is laid out after her first visit; taps drip.
  - Dev hook: `RUN_HAUNT=<event>` fires that event every 2 s and prints it.
- *Sounds*: `python tools/make_house_sounds.py` synthesizes all the `house_*.wav` files (knocks, creaks, whisper, drip, tray, thud, steps above) from resonator and noise models. No licensed audio.

**Terrain winding**: `Ground` triangles must be clockwise seen from above (Godot's front face). They used to be counter-clockwise, which culled the whole terrain from above; the "snow" was the sky colour.

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

- *Posture* (`posture.gd`): a `SkeletonModifier3D` placed before `FootLock`. It turns her head and neck toward the camera's look direction (clamped, and forward again when the camera looks behind her), opens the chest and lifts the shoulders with `Breath.fullness()` (scaled by strain), and sways the hips over her planted feet when she stands still.
- *Hair*: two layers.
  - `Outfit._build_crown`: ~150 short rigid cards attached to the Head bone, combed away from the side part. A per-angle hairline keeps them off the face. Their normals point out from the skull centre, so the layer shades as one mass.
  - Long simulated locks, whose three skull rows are rigidly carried (`Cloth.pinned_rows`) so they can't drift from the scalp.
- *Cloth timing*: `Cloth` steps on `Skeleton3D.skeleton_updated`, not in `_process`. Modifier results are discarded after the skeleton update, so reading bones in `_process` misses the head turn, breathing and sway.
- *Skirt fit*: the skirt starts just above the widest point of her hips, from her measured outline there (`Outfit._outline`, a radius per direction), with the top row tucked under the fitted shell. It has stiffer top rows (`Cloth.top_stiffness`), a modest A-line with 7 godet folds, and leg capsules from mid-thigh down. A pelvis capsule, or thigh capsules starting at the hip joints, shove the hip rows out into a shelf.

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
