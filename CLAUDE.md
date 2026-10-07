# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

"Ophelia's Dream" â€” a short third-person winter horror game in **Godot 4.7** (Forward+, Jolt physics, D3D12 on Windows), written entirely in GDScript. The `godot` binary on PATH (scoop shim) is 4.7.2; on the RTX 3070 Ti desktop it is `godot-mono` (4.7.2 mono build), and every `godot` command below works with it. There is no test suite and no linter; verification is done by running the game, capturing a screenshot, or running a probe (below).

`docs/PLAN.md` is the original design doc (night ridge, the hunter that follows the trail by offset). The game has since become a daylight world about 1.1 km across: a snowy story core inside green, wooded, mountainous land (see *World*). The figure in the tree line and the Listener were removed on 2026-10-05; new threats are being chosen from `docs/THREATS.md`. Older docs (`GDD.md`, `NARRATIVE_INTENT.md`, `TODO.md`, parts of `docs/EDITOR.md`) still describe them. `docs/DIRECTION.md` is the current direction and validation record, and `CHANGELOG.md` tracks releases. Where any doc and the code disagree, trust the code. `AGENTS.md` is a shorter copy of these instructions for other agents; keep it consistent when conventions change.

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

# Journal and voice rules (PROBE_CLIPS=1 also checks baked clips)
godot --headless --path . tools/journal_probe.tscn
godot --headless --path . tools/voice_probe.tscn

# Mathilda's doorway meeting with Ophelia: coherence check, every path as a transcript, the real scene
# (docs/DIALOGUE.md, docs/MEETING_VOICE.md; RUN_MATHILDA=1 RUN_MEETING=1|open starts at the door)
python tools/bake_meeting.py --check
python tools/bake_meeting.py --paths
godot --headless --path . tools/meeting_probe.tscn

# Probe mesh bounds / animation names from the asset packs
godot --headless --path . -s tools/probe.gd

# Rebuild the elf's movement library from the shared Quaternius animation source
godot --headless --path . -s tools/retarget_elf.gd

# Rebuild her walk and jog from the Bandai Namco feminine-style takes (CC BY-NC 4.0)
python tools/fetch_motion.py
godot --headless --path . -s tools/retarget_bvh.gd

# Contact sheets of her clips (needs a window), into build/gait/
godot --path . -s tools/gait_sheet.gd

# Release build: encrypted PCK -> build/windows/Ophelia's Dream.exe. Keeps godot.gdkey (gitignored,
# never commit or print it), builds/caches a custom encryption template in build/templates/
# with SCons, and syncs the version in project.godot + export_presets.cfg.
./tools/export_release.ps1 [-Version 0.0.17] [-Unencrypted] [-RotateKey]
# Plain unencrypted export (needs matching export templates)
godot --headless --path . --export-release "Windows Desktop" "build/windows/Ophelia's Dream.exe"

# Scene probes (tools/*_probe.tscn) run the real systems, autoload included, and print results
godot --headless --path . tools/traversal_probe.tscn    # steer the player along the saved trail
godot --headless --path . tools/note_access_probe.tscn  # page reach against real walls/terrain
godot --headless --path . tools/house_space_probe.tscn  # checks the saved editable house
godot --headless --path . tools/checkpoint_probe.tscn   # the lookout checkpoint: keep, resume, forget
godot --path . tools/lake_view.tscn                      # shots of the lookout, posts and lake into build/lake/
godot --path . tools/return_evidence_probe.tscn         # renders the doorway clue (needs a window)

# Crash-safe logging run (game + disk-flushing hardware monitor, logs in build/blackbox/)
./tools/run_blackbox.ps1

# The world: terrain and route, biome snow weight, snapshot handling, ground material,
# woods (run lean and with RUN_GRAPHICS=full), biome footsteps and snowfall, the forest pack
godot --headless --path . tools/terrain_probe.tscn
godot --headless --path . tools/biome_probe.tscn
godot --headless --path . tools/biome_snapshot_probe.tscn
godot --headless --path . tools/ground_material_probe.tscn
godot --headless --path . tools/flora_probe.tscn
godot --headless --path . tools/biome_effects_probe.tscn
godot --headless --path . -s tools/forest_pack_probe.gd
godot --headless --path . -s tools/import_forest_pack.gd   # re-split the pack's meshes
# Overview shots and FPS (needs a window; RUN_GRAPHICS=full|lean, RUN_VIEW_TAG names the set) -> build/terrain/
godot --path . tools/terrain_view.tscn

# Running leap: pure math; physics and animation on the real player (with a window it
# also saves build/leap/leap_flight.png); a side-on contact sheet (needs a window)
godot --headless --path . -s tools/leap_math_probe.gd
godot --headless --path . tools/leap_probe.tscn
godot --path . -s tools/leap_sheet.gd                    # build/leap/leap_sheet.png
godot --headless --path . -s tools/leap_phase_probe.gd   # re-measure Stride.*_PHASES after changing a running clip

# Mathilda's camp: props from the owner's asset bank into ignored assets/vendor/requested_camp/,
# the synthesized fire crackle, and shots of the camp into build/camp/ (needs a window)
python tools/curate_camp_assets.py ["<bank root>"]
python tools/make_campfire.py
godot --path . tools/camp_view.tscn                       # RUN_HOUR=19.5 for night, RUN_VIEW_TAG names the set
```

This machine (ThinkPad, Iris Xe) has hard-frozen while running the game. `Game.lean_graphics` is on automatically for non-discrete GPUs (no volumetric fog/FogVolume/SSAO, 2 shadow splits, half the snow); override with `RUN_GRAPHICS=full|lean`. `RUN_BLACKBOX=<path>` makes `Blackbox` stream startup stages, phases and a 0.5 s performance beat to that file; `Game.mark()` adds a line. After adding a new `class_name` script, run `godot --headless --path . --import` or headless runs fail to resolve it.

F3 toggles a debug label (weather, threat and stamina) in debug builds.

Recorded sound comes from CC0 sources: BigSoundBank WAV originals and Freesound HQ previews, after the CC0 licence is checked on each page.
- `python tools/fetch_sounds.py` downloads them to `build/sfx_src/`.
- `python tools/make_soundscape.py` (needs ffmpeg) cuts them into `assets/audio/{steps,weather,nature}/` and writes `assets/audio/provenance.json`, which credits every file.
- Steps, calls, creaks and snowfalls are found by onset detection and levelled to a -12 dBFS impact. Loops are made seamless and levelled to -20 dBFS RMS.
- `tools/make_storm.py` only synthesizes the slide hiss. `tools/prepare_elf.py <original-elf.glb>` removes bow and arrow triangles from the Styloo source asset. `tools/prev_*.png` are scratch previews and are not part of the game.

## Architecture

**Everything is built in code.** `scenes/main.tscn` is just a root `Node3D` with `scripts/main.gd`. `main.gd` instantiates every system with `ClassName.new()` in order: Atmosphere â†’ Trail â†’ Player â†’ Weather â†’ Wildlife â†’ Camp â†’ Soundscape â†’ Voice â†’ Hud. Nodes, lights, materials, collision and UI are all constructed in `_ready()`/`_build_*()` methods. New features follow this pattern, not editor-authored scenes. The only other scenes are generated: `scenes/editable_level.scn` and `scenes/generated/` are snapshots of the built level that can be edited by hand and are reapplied at startup (see *Editable level* below and `docs/EDITOR.md`). The `tools/*_probe.tscn` files are test harnesses.

**`Game` autoload (`scripts/game/game.gd`)** is the hub:
- Holds the phase state machine (`BOOT, INTRO, PLAYING, READING, PAUSED, CAUGHT, ESCAPED, JOURNAL`) and emits `phase_changed` / `closeness_changed`. UI and audio subscribe to these signals.
- Each system registers itself on the autoload in its `_ready()` (`Game.player = self`, `Game.trail = self`, `Game.weather = self`, â€¦), and other systems reach each other through `Game.*`, not node paths.
- Registers all input actions in code with `_bind()`. There is no `[input]` section in `project.godot`, so new actions go here.
- `Game.settings` (`Settings`, `scripts/game/settings.gd`) is created right after the default binds and holds everything the Esc menu changes: look, sprint mode, camera, display, audio levels and HUD options, plus key overrides. It saves to `user://settings.cfg` when the menu closes, on restart and on quit. Systems read `Game.settings.*` when they need a value.
 - New rebindable actions go in `Settings.ACTIONS` (two slots each). A key bound to one action is taken from any other.
 - Audio has three buses created at startup: `Ambience` (wind, drone, storm), `Effects` (steps, slide, doors, switches, house) and `Dread` (heartbeat, stings, threat sounds). Give every new player a `bus`.
 - Graphics detail (Auto/Lean/Full) feeds `_wants_lean_graphics()` after `RUN_GRAPHICS`, and applies on the next restart.
- `locks_movement()` / `locks_look()` gate player control by phase. `restart()` resets state and reloads the scene.
- The threat interface: `closeness` (0â€“1) for the one that hunts her, `dread` and `threat_hint` for any other pressure, `threat()` = max of the two, `catch_player(title, body)` for the ending, `something_at_door` (the house knocks hard) and `shown_threat` (a raven scolds beside it). The HUD vignette, heart and warning line react to `threat()`. The UI never shows distances. `hunt_started` turns true after `Tune.HUNT_NOTES` pages or `HUNT_ROUTE_DISTANCE` metres. No threat sets these yet.
- The lookout at `trail.exit_point` is a checkpoint, not an ending: within `EXIT_RADIUS`, `Game.reach_checkpoint()` keeps her pages, journal and places in `Game.checkpoint` (it survives `reset()`). `Game.restart(true)` (the Esc menu's "Back to the lookout", or the button after a catch) rebuilds the run and `main.gd` calls `Game.resume_checkpoint()`, skipping the menu; a plain `restart()` forgets it. `Game` ends the run as `ESCAPED` when she is within `LAKE_ARRIVE` of `trail.lake_hole`, out on the frozen lake.

**`Tune` (`scripts/tune.gd`)** holds all balance constants: speeds, stamina, aim and reach, the world and story-field bounds (`WORLD_*`, `FENCE_*`), the land, biome and forest values (`TERRAIN_*`, `VALLEY_*`, `CLIFF_*`, `RAVINE_*`, `SNOW_*`, `BIOME_*`, `MOUNTAIN_*`, `RING_*`, `CHUNK_*`, `FOREST_*`, `GREEN_*`, `UNDER_*`), and collision layers (`LAYER_WORLD=1`, `LAYER_ACTOR=2`). Change feel here, not in the systems.

**World (`scripts/world/`)**: `Trail` owns a `Curve3D` (fixed seed 1701) and builds `Ground`, an empty `Fence` node (kept only so editable-level snapshots line up child for child), the landmarks, the `FieldNote` pickups and `Flora`. Use `trail.on_ground()` / `ground.height_at()` to place anything on the terrain. `Trail._reserve()` keeps flora away from landmarks. The exit is the lookout (a checkpoint; the run ends at the lake past it, see `Lake`) at `trail.exit_point`. `PropFactory` loads FBX files from `assets/environment/` once, hides LOD1–3 meshes, and overrides every material with a flat winter palette chosen by filename keyword (`_family()`), or with an alpha-scissor material for the foliage textures. A missing mesh falls back to a box. Specs and plans: `docs/superpowers/specs/2026-10-06-biome-world-design.md` and its plan.
- *Ground* (`ground.gd`): one height function over `WORLD_*` (1080 m square), built in layers: warped hills; a gentle valley along the route (floor graded at most `VALLEY_GRADE`, banks rising); cliff bands on hillsides at least `CLIFF_CLEAR` from the route; one ravine over `RAVINE_FROM..TO` of the played route; ridged mountains rising away from the story; a ring of peaks at the edge plus an invisible `WorldEdge` wall; the house pad last. Route and story distances, the valley floor and the ravine weight are coarse fields (`FIELD_CELL` 6 m). Set `route`, `route_from/to` and `story_points` before it enters the tree (`Trail` does).
 - The mesh is `CHUNK_SIZE` squares with cells of 1.5/3/6 m by distance from the story; a fine chunk's edge is stitched onto a coarser neighbour's so heights and collision are continuous. Each chunk is a `MeshInstance3D` with a trimesh `StaticBody3D`. Normals come from height differences. Helpers: `height_at`, `normal_at`, `slope_at`, `route_distance`, `story_distance`, `snow_at`.
 - **Snow weight** `snow_at(x, z)` (0 green .. 1 snow) is shared by every system: always snow within `SNOW_FORCE` of the story, mostly snow within `SNOW_CORE_IN..OUT` (a few green patches past `SNOW_PATCH_CLEAR`), and beyond it a biome noise biased greener north-east and north-west, partly south-east (north is −Z), snowy on peaks above `BIOME_SNOWLINE`. It is stored in vertex `COLOR.r`.
 - `TERRAIN_REVISION` (now 3): bump it whenever the land's shape changes. `main.gd` keeps the newly generated Ground, Flora, landmarks and Fence over a snapshot whose `terrain_revision` differs, and `Trail.settle_house()` sets the house back onto its pad.
- *Ground shader* (`shaders/snow_ground.gdshader`): blends snow, thaw (wet mud with patchy snow), green (CC0 Poly Haven forest floor and grass from `tools/fetch_ground_textures.py`, pushed toward lush green by `lushness`, with moss patches) and banded triplanar rock on slopes, from the vertex snow weight. Snow ripple normals come from an analytic sine-sum slope, not finite differences of lattice noise (that showed faint squares). Lean skips the normal detail.
- *Flora* (`flora.gd`): woods by biome over the whole world. Snow woods are the premium pines with great pines (`FOREST_GREAT_*`) and 6–8 lone giants beside the route; green woods are the Sketchfab forest pack's spruces and card trees, denser, with firs and bushes underneath and grass in clearings; logs, mounds and boulders in the open; `SM_Env_Rock_Cliff_02` faces on steep cliffs near the route. Nothing within `FOREST_CLEAR` of the route or on slopes over `FOREST_SLOPE`. Every candidate draws all its random numbers before deciding, so lean keeps a stable half (`FOREST_LEAN_SHARE`) of exactly what full plants.
 - Drawn as `MultiMeshInstance3D`s per mesh part per chunk with draw distances (`FOREST_DRAW`, `UNDER_DRAW`, lean values). Trunks are cylinders on one `PhysicsServer3D` static body per chunk (no node per tree), freed on predelete.
 - `tree_positions()` lists every trunk; `tree_positions(centre, radius)` and `nearest_indices(from, count, reach)` query a spatial hash. `Wildlife` uses the latter.
- *Forest pack* (`assets/vendor/sketchfab_forest/`, Sketchfab Standard licence; author and page still to be supplied, see its README): `tools/import_forest_pack.gd` splits ten pieces out of the FBX into `meshes/*.res`.
- *Biome effects*: `Player._surface_at` returns `grass` (snow weight under 0.35), `thaw` (to 0.65) or `snow` outdoors; prints and powder only where `_leaves_prints` (snow weight over 0.6). Grass steps are CC0 Freesound recordings cut by `make_soundscape.py`; thaw plays the snow set 4 dB softer. `Weather.snow_scale` (smoothed snow weight under the camera) scales every snow layer and `Atmosphere.snow_cover` the snow veil; the wind keeps blowing over green.

**Threats**: none in the field right now. `docs/THREATS.md` lists the interface above, the `Trail/Threats` marker slot, record pages (`NoteEntry.record_of`, `Game.knows`), and six candidate threats. New threats are original; canon SCP content is CC BY-SA, so do not borrow it. Teleporting ones call `reset_physics_interpolation()` after the move.

**Locomotion (`scripts/player/stride.gd`, `snow_kick.gd`)**:
- `Stride` builds an `AnimationTree` from code. A BlendSpace1D (Idle, Walk, Jog, Sprint) is driven by her ground speed, and a TimeScale sets the playback rate so the planted foot moves at that speed.
- Since commit `c9fb491` she walks and jogs on the Quaternius `Walk_Formal` and `Jog_Fwd`. The Bandai Namco Research Motion Dataset's feminine-style takes are still built into `assets/characters/styloo_elf/feminine/elf_feminine.res` (library `feminine`, CC BY-NC 4.0; credit in the Esc menu and `feminine/README.md`), but `Player` no longer loads that library.
 - `tools/retarget_bvh.gd` reads the BVH directly, poses the elf from joint positions (limb directions; torso frames relative to their cycle average; neck and head follow the chest), cuts one looping in-place cycle, and prints each clip's natural speed for `Tune.STRIDE_*`.
 - The sprint stays the Quaternius clip; their dash is a light run, too slow for `SPRINT_SPEED`. `Grace` draws its wide elbows in.
- The other clips (idle, sprint, jump, land, crouch, stumble) are baked to the elf in `assets/characters/styloo_elf/elf_animations.res`; regenerate with `tools/retarget_elf.gd`.
- A OneShot plays the exhaustion stumble (Hit_Chest).
- Each running gait spans a plateau (two blend points with the same clip), so a steady speed plays one clip. Blending clips whose cycles differ muddles the legs.
 - Each blend point is a small blend tree (clip â†’ TimeSeek), named `<clip>_<index>`, so it can be cued on its own through `parameters/locomotion/<name>/seek/seek_request`. The space uses `sync_mode = SYNC_MODE_INDEPENDENT` (4.7's replacement for `sync = true`).
- *Running leap* (`Player.leaping`, `leap`, `leap_lead_left`; spec and plan in `docs/superpowers/`):
 - A jump at `Tune.LEAP_FROM` (3.2 m/s) or faster is a leap; in practice that means sprinting, since her input speeds are walk and sprint. `leap` (0..1 up to `SPRINT_SPEED`) lowers the arc, adds a little carry (capped at `LEAP_MAX_SPEED`) and cuts air drag.
 - It pushes off the foot she last planted and lands on the other, one footstep at each end (`_footfall`, not `_both_feet`), and keeps her speed. Only a real drop costs any. `_on_planted` ignores the rig's own re-plant of the lead foot for 150 ms.
 - `Stride`'s leap layer plays her jog or sprint from the push-off foot's toe-off to the lead foot's contact (`JOG_PHASES` / `SPRINT_PHASES`, measured by `tools/leap_phase_probe.gd`), slowed over the predicted airtime (`Leap.airtime`). Progress is held at `LEAP_REACH_HOLD` off a ledge until the ground is near (`_drop_below`). On landing, `leap_land` re-cues every running point to the contact frame.
 - `Leap` (`leap.gd`, a SkeletonModifier3D after `Grace`, same local-rotation technique) adds the split, pointed toes, opening arms and a lifted chest, and a spring dip on the lead leg on landing (a two-bone fold, no IK node). Its math is static and covered by `tools/leap_math_probe.gd`.
 - The standing hop and the slide jump are unchanged. Tuning is `Tune.LEAP_*`. The camera opens (`LEAP_FOV`, under speed FOV), stretches the boom, trails her rise and rolls toward the lead foot on landing.
 - `Player.stepped(left)` fires for every sounded footfall; the probes count steps with it.
- `FootLock` (`foot_lock.gd`) watches the elf's animated feet and emits `planted(left, at)` for sound, prints, `SnowKick` powder and camera jolt. The elf has no leg IK; the distance-based trigger in `_steps` is a fallback.
- Per-step dynamics: `_step_surge()` swings speed within each step (`Tune.STEP_SURGE_*`), checking on landing and surging on push-off.
- Jump (Space) and slide (Ctrl/C, from a sprint) are in `Player`.
  - Jumps have coyote time and a jump buffer, variable height, heavier falls, reduced air control, and landings scaled by fall speed.
  - Slides get a speed boost, snow friction, gravity along the slope and limited steering, and you can jump out of one.
  - `Stride` adds layers on top of locomotion: an air pose (Jump_Start, sought by vertical velocity), a slide pose (Crouch_Idle), and a landing one-shot (Jump_Land).
  - `FootLock.suspended` suppresses ground contact in the air and during a slide.
  - Hold breath is on right mouse button or F (defaults; all keys can be rebound in the Esc menu). Sprint can be set to toggle.
  - Alt (held) walks slowly at `WALK_SLOW_SPEED`. Q or the middle mouse button (held) glances back: the camera swings over her right shoulder while she keeps running the way she was going, and `Grace` turns her chest and head with it.
  - Gamepad (bound in `Game._bind_pad`, kept by `Settings._set_events` when keys are rebound): left stick moves with a radial dead zone and a curve, so a part push walks slowly; right stick looks with a ramp when held fully. `Game.rumble()` shakes the pad on landings, stumbles, hard knocks and the catch.
  - Assists: from standing the first tick moves her at once (`START_BURST`); read/open is buffered for `INTERACT_BUFFER`; indoors she slips past the edge of a door frame (`DOOR_ASSIST`); a held jump floats at its apex (`APEX_HANG`); the camera arm pulls in at once and lets back out at `ARM_EXTEND`.
- Dev hooks: `RUN_AUTOPILOT=walk|jog|sprint|jump|slide|glance|leap` (leap jumps every few seconds once she is near full speed) and `RUN_SHOT_FRAME=<n>` (when `RUN_CAPTURE` takes its shot).
- Momentum is in `Player._steer`, which moves speed and heading separately (`Tune.STRIDE_*`, `TURN_*`). At a walk she pivots almost at once; at a sprint she sweeps round at `TURN_RATE_SPRINT`, and hard key turns dip her speed briefly. A reversal at speed plants and brakes first. Letting go skids about 0.5 s, and in the air she keeps her takeoff speed (`AIR_ACCEL`, `AIR_DRAG`). `_slope_factor` slows her uphill.
- Physics interpolation is on (`physics/common/physics_interpolation`).
 - The camera rig (`spring_arm`) is `top_level`, not interpolated, and placed every frame in `Player._process` from `get_global_transform_interpolated()` and the mouse. Look reads `screen_relative`, so window size never changes sensitivity.
 - Anything that teleports must call `reset_physics_interpolation()` after the move (player spawn, any threat that jumps).
 - Pooled effects that jump to new spots (`Footprints`, `SnowKick`) and nodes moved in `_process` (`Weather`) have interpolation off.

**Player** is a `CharacterBody3D` with a spring-arm third-person camera, stamina-gated sprint, wind push from `Game.weather` (only while she moves), and `Footprints` decals.
- The model (`visual`) turns toward the direction she's moving, independent of the camera, and leans into acceleration and turns (`_carry`).
- `_fit_boom_to_ground` shortens the camera boom so the camera never goes under the one-sided terrain. Opening a note enters `READING`, which freezes the player but not the world.
- *Aim* (`aim.gd`, `Player.aim`): worked out once per rendered frame after the camera is placed, so the outline is exactly what a press uses.
 - Pages (`field_notes`), doors and switches (`interactables`) each return `aim_box()`: `[global transform, local AABB]`. The door's box follows its leaf; the switch's is twice the plate.
 - The ray from the screen centre takes the nearest box it enters, unless a world collider (other than the thing's own) comes first. Out of reach, it is shown as "Too far to reach" and nothing else is chosen.
 - Reach is to the nearest point of the box: `INTERACT_REACH` from her chest for doors and switches, `READ_DISTANCE` from her feet for pages (not at a run), with nothing solid in between.
 - With nothing under the reticle, the thing in reach closest to it within `AIM_CONE` is chosen; the current choice holds unless another is `AIM_STICKY` degrees closer.
 - E / pad X use `aim.target`; a left click uses only a target that is directly under the reticle. The HUD reticle shows only when something is picked: bright direct, faint chosen around it, rust out of reach. `nearby_note()` remains for the reachability probes.

**House (`scripts/house/`)**: the cabin she wakes in, built in code by `House`. Its local frame has +Z facing the trail and y 0 at the boards.
- *Layout*:
  - Ground floor: bedroom (the spawn), entry hall, living room and kitchen, and a back hall with the stair well
  - A 19-step flight down 3.4 m
  - Cellar: landing, corridor, janitor room, and `Morgue`, which is ported from the sibling project `merl`'s `prototype_room.gd`
- *Tools*:
  - `HouseKit`: scanned CC0 Poly Haven materials (world triplanar), props, walls with openings, slabs with holes, stairs (visual treads on one walkable ramp), lights
  - `HouseDoor`: E-to-open hinged leaves on merl's `DoorHingeDynamics`, with `DoorAudio` sounds, in plank, steel and chamber styles
  - `WallSwitch`
  - Interactables join the `interactables` group and expose `interact_label()`, `interact_point()`, `interact()` and `aim_box()`. `Player.aim` picks one, and the HUD prompt shows its label.
- *Terrain*: `Trail` gives `Ground` a flat pad (`pads`) around the house and a cut (`cuts`) over the stair well. `House.add_snow_patch` refills the cut's 3 m cells outside the walls with the same snow material. The cellar stays under `SLAB_TOP`, below the snow.
- *Indoors*: `Game.indoors()` / `House.contains()`.
  - The camera boom drops to 1.75 m over the shoulder, and her model hides if the camera is crushed into her.
  - No snowfall; the storm is muffled.
  - Floor-tap footsteps instead of snow, no prints or powder, and `FootLock.floor_at` reports contacts on the boards.
  - `House.doorstep()` is where something outside would wait.
- *Assets*: from `merl`, CC0, under `assets/vendor/polyhaven/` (`provenance.json`) and `assets/derived/doors/audio/`.
- *Dev hook*: `RUN_SPAWN=outside|bedroom|living|stair|cellar|janitor|morgue` (and `lookout|lake`, handled by `Lake`).
- *Darkness*: `Atmosphere.shelter` (eased by `Weather` as the camera goes in or out) drops the daylight ambience to about 7%, so the rooms are only what their lamps make of them. Most lamps are deliberately unlit. Her camera light brightens and widens indoors.
- *Haunting (`haunting.gd`)*: rooms come from `House.room_at()`. Tension rises indoors and drains outside, and events fire at intervals that shorten with it:
  - `flicker`, `creak`, `door`: a visible door drifts on its own via `HouseDoor.drift()`.
  - `knock` (ground floor): becomes `house_knock_hard` when `Game.something_at_door` is set or tension is high.
  - `steps` (cellar): footsteps cross the floor above toward the head of the stair.
  - `chamber` (morgue): a chamber door opens behind her and its tray slides out.
  - `whisper` (high tension only).
  - Persistent: the bedroom lantern goes out when she leaves and relights when she returns; the sheeted body (`Morgue.body`) is laid out after her first visit; taps drip.
  - Dev hook: `RUN_HAUNT=<event>` fires that event every 2 s and prints it.
- *Sounds*: `python tools/make_house_sounds.py` synthesizes all the `house_*.wav` files (knocks, creaks, whisper, drip, tray, thud, steps above) from resonator and noise models. No licensed audio. The cellar's "steps above" now prefer `assets/audio/steps/above_*.wav`: recorded wood steps, low-passed as if heard through the floor.

**Terrain winding**: `Ground` triangles must be clockwise seen from above (Godot's front face). They used to be counter-clockwise, which culled the whole terrain from above; the "snow" was the sky colour.

**Testing**: scripts that reference the `Game` autoload can't be loaded by a `-s` tool script (`extends SceneTree`). Test them with a scene probe instead: a `tools/<name>_probe.tscn` whose root script `extends Node` runs with the autoload. It builds or loads the systems it needs (setting `Game.player` etc. itself, as `voice_probe.gd` does), prints its findings, and quits. Copy an existing probe as the template.

**Voice (`scripts/player/voice.gd`, `docs/VOICE.md`)**:
- **Script:** `docs/MATHILDA_STORY.md` is the script of record. `python tools/script_to_lines.py` writes `assets/audio/voice/lines.json` from it, and `--check` fails if the two have drifted.
- **Lines:** 141, each in one of 14 moods, in these groups:
  - pages, deciphered, places, revisits
  - bored by stage (hope/doubt/resolve, plus `after` once she turns around)
  - memories while walking outdoors, calls
  - spent (`Player.exhausted`), cold, falls (`Player.landed_hard`)
  - turned, misread, and endings spoken over the escape card
- **Playback:** priorities, with forget-on-interrupt.
- **The trees answer in her own voice** (`answers`): "Go, then!" from a pine, "I'm right behind you." from behind her (`Player.facing()`), and "Okay." from the lake ice behind her at the end (its key is still `road`). Mathilda never speaks.
- **Baking:** `tools/bake_speech.py`:
  1. `--impressions` (Qwen3-TTS VoiceDesign, `build/voice/gpu-venv`) renders one reference performance per mood. `--unify` (Chatterbox voice conversion) gives each one steady's voice, and the results go in committed `tools/voice/ref/<mood>.wav` (raw picks in `ref/raw/`). Godot ignores `tools/voice/` via `.gdignore`; `voice_lock.json` and the `requirements-*.txt` there record models, versions, seeds, the mood table and the picks (refresh them with `--lock`).
  2. The bake (Chatterbox, `build/voice/cb-venv`, `HF_HOME=build/voice/hf/cache`) clones every line from its mood's impression: 3 takes, a Whisper WER gate, the take most like the impression wins.
  3. It writes `build/voice/review.html` for listening.
- **Clip names:** SHA-256 of `text|mood`.
- **Nothing is deleted:** `--scrap` and replaced or stale clips move to `build/voice/archive/`.
- **No model runs in the game.** `tools/bake_voice.py` is obsolete and overwrites the script: do not run it.
- **When Voice is inactive:** `RUN_VOICE=0`, capture and headless runs; journal event keys have fallbacks.

**Turning around**: after the last page, holding glance-back for `Tune.TURN_HOLD` outdoors calls `Game.turn_around()`. That sets `Game.turned_around` and emits `turned`. The escape card at the lake then reads "One set of prints" instead of "The lake", and Voice stops calling and answering. `RUN_ENDING=road|prints` with `RUN_CAPTURE` shows either escape card (`road` is the lake ending).

**The lookout and the lake (`scripts/world/lake.gd`)**: the lights at the end of the drawn route are a false lead. `Trail._extend_to_lake()` carries the curve `Tune.LAKE_LEG` metres past the lookout (turned if needed to stay inside the peaks); the valley follows it, `Ground` gets a level pad for the lake, the leg and lake are story points, and trees are kept off the ice. `Route` in the editable level stays the drawn curve (`_drawn_curve`), so the leg is never saved and doubled. `Lake` (added after `Camp`, built deferred) hides Trail's headlight spots, hangs two Poly Haven lanterns on the lookout rail (from the field they read as headlights), plants posts with red rags every `LAKE_POST_SPACING` metres to the shore, and builds the ice (`lake_ice` shader: clear ice, wandering cracks, drifts, the refrozen hole), two sets of prints to the hole and back (decals), and dry reeds. Places `lookout` and `lake` have their own lines. Nodes Camp and Lake hide carry `replaced_by` meta, which `biome_snapshot_probe` skips. Shots: `godot --path . tools/lake_view.tscn` into `build/lake/`.

**Breath**: `hold_breath` (right mouse, F, pad RT) suppresses `Breath.plume`, drains stamina at `Tune.HOLD_DRAIN`, and ends in a gasp. Nothing perceives breath at the moment.

**Player model**: `scripts/player/player.gd` instantiates `assets/characters/styloo_elf/elf.glb` at 0.8 scale, with its original materials. The bundled bow and arrows were removed from the GLB by `tools/prepare_elf.py`. `elf_animations.res` contains eight movement clips retargeted from the hunter's shared animation library by `tools/retarget_elf.gd`; her walk and jog come from `feminine/elf_feminine.res`. `Breath` is attached to `DEF-spine.006` at the mouth; `FootLock` watches `DEF-foot.L/R` for contacts. The skeleton (216 bones) has hair, dress, eyelid, brow, jaw, eye, finger and twist bones, but nothing drives them yet, and the elf has no leg IK; `docs/MOVEMENT.md` plans both.
- `Grace` (`grace.gd`, a SkeletonModifier3D after `FootLock`) layers her carriage over the clips: in the walk, an arm counter-swing read from the thighs, soft elbows, and shoulders turning against the hips with the head held level; a lifted chest; and, after `Tune.TIPTOE_AFTER` seconds standing, a recurring rise onto her toes. Tuning is in `Tune.GRACE_*` / `TIPTOE_*`.
- Inside a modifier, global bone poses go stale once a parent is written, so `Grace` writes local rotations conjugated through each parent's clip pose. For the same reason, bone attachments don't show its children's changes; `godot --path . -s tools/grace_probe.gd` (needs a window) renders side views with it on and off into `build/grace/`.

**Quaternius rig**: `addons/quaternius_ik_rigged/` is now only the animation source for `tools/retarget_elf.gd` (and a body to source from if a threat needs one). Keep the shared `UAL1_Standard.glb` animation source and male meshes when cleaning assets.

**Sound (`scripts/audio/`, `weather/storm_audio.gd`)**
- *Positioning*: everything in the world is a positional `AudioStreamPlayer3D`, heard from `Player.ears`, an `AudioListener3D` at her head facing the camera's yaw, not from the camera. `audio/general/3d_panning_strength` is 0.85, so surround output pans fully.
- *Loudness* (`loudness.gd`): every source has a typical dB SPL at 1 m.
 - `Loudness.voice/place/sound` set inverse-distance attenuation (unit_size 1, so -6 dB per doubling), a reach where it falls below hearing, and air dulling for far sources.
 - `CALIBRATION` maps SPL to volume; it was measured from recorded mixes: calm about -32 LUFS, a gust about -21, nothing clipping.
 - Recordings that were not levelled carry a measured `TRIM`.
 - New sounds get an SPL constant here, not a hand-set volume_db.
- *Steps* (`Soundscape.play_step(at, surface, force)`): play at the foot.
 - `Player._surface_at` raycasts under the foot and reads the collider's `surface` meta. `HouseKit.surface(material, kind)` tags a material, and `solid`/`stair` copy the tag to their bodies.
 - Planks are wood; the porch and cellar are stone. Otherwise it is snow outdoors and wood indoors.
 - Wood occasionally adds a board creak, and prints and powder appear only on snow.
- *Storm* (`StormAudio`):
 - Four storm beds and two breeze beds sit on a world-fixed ring around the ears, unattenuated, so the storm turns with her head. The gust howl sits upwind.
 - Indoors the walls take `Loudness.WALLS` (the cellar more), and the `Outside` bus low-pass closes down.
 - Wind whistles at the windward `House.windows()`.
- *Wildlife* (`wildlife.gd`):
 - The nearest pines (`Flora.tree_positions()`) rustle with the gusts; trunks creak; snow slides off branches.
 - Crows and ravens call from far trees and fall silent under threat. A raven scolds from beside `Game.shown_threat` when it shows.
 - Songbirds (the PAD day-birds from the inventory) sing only in calm.
- *Buses* (Settings):
 - `Ambience` holds `Outside`, which has the walls low-pass, plus the window whistle.
 - `Effects` is steps and the house, with a `Voice` bus under it for her speech; `Room` and `Cellar` are reverbs fed by Area3D zones that `Soundscape` builds from `House.acoustic_zones()`.
 - `Dread` is the heart, drone, sting, and `Soundscape.play_snap` (positional branch snaps a threat can use).
 - A hard limiter sits on Master.
- *Editable level*: `EditableLevel.apply` matches nodes by child order and frees script-less nodes it does not know. Keep sound-only nodes out of the editable trees, or append them last. Set house audio levels at play time (`Loudness.sound`), because the snapshot overwrites stored properties. `House/Authoring` (spawn markers, window markers, the `StepsAbove` path, room and cellar reverb areas, `Rooms` boxes, the `Doorstep` marker) and `Trail/Threats` (the marker slot for threats, empty now; older snapshots call it `Anomalies`, and `main._park_threats` accepts either) plus `Trail/Route` (the path, with `Start` and `Exit`) are appended last and grouped as `level_authoring`, so an older snapshot keeps them until the next repack. She still wakes on the authored Player transform; `RUN_SPAWN` uses the spawn markers. Redrawing `Route` or moving `Start` rebuilds the snow, the pines and the landmarks on the next play; `Exit` only moves where she escapes. House interior edits stay.
 - **Generator changes need a rebuild.** If you change node structure in `scripts/world/` or `scripts/house/`, saved snapshots no longer line up child for child. Rebuild from the editor: select `Main` and use **Randomize / rebuild editable level**; **World Seed** `-1` means a fresh seed. That replaces `scenes/editable_level.scn` and all of `scenes/generated/`, including hand edits, so ask before doing it.

**Mathilda's camp (`scripts/world/camp.gd`)**: `Camp` is added after `Wildlife` and builds deferred, once the snapshot is applied. It hides Trail's stylised tent, campfire and their light and collision rather than removing them, so the editable level still lines up child for child.
- *Pieces*: a canvas ridge tent (`camp_canvas` shader: weave, hem damp, snow on whichever side faces up, warm glow through the cloth), a stone ring of noise-displaced rocks, a coal bed (`camp_embers`), a split-log tepee, shader flames (`camp_flame`: four upright quads turning to the camera, no particles), sparks, smoke (`camp_smoke`: noise puffs that erode with age, lit, soft against geometry), a flickering shadowed fire light, a woodpile with an axe, a stool, an upside-down crate for a table, Poly Haven's `Lantern_01` on a stump, and a looping crackle (`Loudness.CAMPFIRE`, `tools/make_campfire.py`).
- *Melt*: a decal of wet earth, ash and slush grows from `MELT_START` to `MELT_END` over `Tune.CAMP_MELT_SECONDS`.
- *Mathilda's things*: `place_story_prop("cups"|"gloves"|"note")` puts them at `spots`; `mathilda_pov` uses those for its three objects.
- *Assets*: the Leartes Carpenter's Workshop props and the WW2 note scan come from the owner's asset bank (`OneDrive - Biz\Desktop\Assets`) via `tools/curate_camp_assets.py` into ignored `assets/vendor/requested_camp/` (manifest in `docs/camp/`). Without them the camp builds stand-ins. Copy that folder into the export worktree before a release.

**Day clock**: `Atmosphere.start_clock(hours)` runs a 24 h clock (`Tune.DAY_MINUTES` real minutes per day) that lays sun height and colour, a dim moon, sky, fog and ambient over the weather each frame. Only Mathilda's chapter starts it, at `Tune.MATHILDA_DUSK`; Ophelia's afternoon never moves. Dev hook: `RUN_HOUR=<hours>` in her chapter.

**Weather** follows the camera and drives several `SnowLayer` particle layers, `StormAudio`, and `Atmosphere.apply_storm(intensity)` from one gust/intensity model. `scripts/world/snowfall.gd` (`Snowfall`) is the older snow system and nothing instantiates it any more.

**UI (`scripts/ui/`)**: `Hud` creates `NoteReader`, `Journal`, `EndCard` and `PauseMenu`. The HUD has no objective; `show_journal_toast` controls the journal notice. J/Tab or pad Y opens the rebindable `journal` action. Smudges use `NoteCatalog` `{word}` markup, `Game.known` keys and `Game.decipher`; `Game.awake()` keeps the world running during `JOURNAL`. Controls are not shown on screen; the intro card only points to Esc.
- `PauseMenu` (`pause_menu.gd`) is the Esc menu.
 - The sidebar has Resume, Restart and Quit, and five pages: Controls with rebinding, Camera, Display, Audio and Interface.
 - Each page has a reset, and its controls come from `_slider` / `_toggle` / `_choice` / `_binding`.
 - Rebinding listens in `_input` before anything else: Esc cancels and Backspace clears.
 - Dev hooks: `RUN_MENU=<page>`, `RUN_JOURNAL=<title>` and `RUN_ENDING=road|prints` with `RUN_CAPTURE` open the menu, a half-deciphered journal or an escape card for a shot.
- In-world key hints (the prompt, the note reader footer, the end card) read `Game.settings.key_label(action)`, so they follow rebinding.
- Inside `_ready()`, a full-screen Control needs `set_anchors_and_offsets_preset`; anchors alone keep its empty starting rect. Shared styling (plates, paper, key-hint rows, palette constants) lives in the `UiChrome` class (`chrome.gd`). Note text and its corruption level are data in `NoteCatalog`, separate from the world pickup `FieldNote`.

**Shaders** live in `shaders/` and are loaded by path from code (`snow_ground`, `footprint`, `snowflake`, `vignette`).

## Conventions

- GDScript uses tabs and static typing (`:=`, typed returns, `Array[T]`). Every script declares `class_name` and is referenced by that name, not by preload.
- Keep `config/version` in `project.godot` and `file_version`/`product_version` in `export_presets.cfg` in sync.
- Commit messages are a single descriptive sentence in plain prose about what changed in the game (see `git log`), not conventional-commit prefixes.
