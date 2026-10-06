# Biome World Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A seed-generated world about 1.1 km across: a snowy story core (200–250 m round the story), biome-math green patches beyond (greener NE and NW, partly SE), natural thaw bands, mountains anywhere outside the route valley, a mountain wall at the edge, and green woods from the user's Sketchfab forest pack.

**Architecture:**
- `Ground` owns the world geometry and the shared snow weight `snow_at(x, z)`, and builds chunked, distance-LOD terrain from one height function. That function is the existing layered core plus mountains and an edge ring.
- `Flora` plants woods by biome as chunked MultiMeshes, with trunk collision straight on `PhysicsServer3D`.
- The ground shader blends snow, thaw, green and rock by a vertex snow weight.
- `Player` footsteps, prints and powder, and `Weather` snowfall all read the snow weight.
- `main.gd` keeps the new land over older snapshots (`TERRAIN_REVISION` 3).

**Tech Stack:** Godot 4.7.2 (`godot-mono`), GDScript, FastNoiseLite, ArrayMesh, MultiMesh, PhysicsServer3D, Python for asset fetching.

**Spec:** `docs/superpowers/specs/2026-10-06-biome-world-design.md`

## Continuation checkpoint — 2026-10-06

This section is the execution order for continuing the partially implemented plan below. Read the original task named in each packet for its algorithms and acceptance values; do not repeat completed asset import. The user requested a plan first and small subagent handoffs. No implementation has been performed during this checkpoint.

### Baseline and decisions

- Clean working tree at inspection, branch `mathilda-story`, baseline `1ee9181`. Recheck before every dispatch because a separate session may work on this branch.
- `forest_pack_probe` passes: all ten split meshes are available.
- `biome_probe` fails: thaw widths pass in only 8/14 crossings; measured widths are 39, 42, 70, 42, 45, 77, 23, 4, 8, 43, 58, 49, 40, 63 m. Ground build 1493 ms; story snow, core coverage (96%), directional green, seam heights (0.007 m worst) and east boundary pass.
- Startup has a runtime error: `main.gd` calls the absent `Trail.settle_house()`.
- `terrain_probe` fails: old 1500 ms budget (1523 ms measured) and typed-array assignment at line 60 stop complete route verification. Do not count its route checks as passing.
- Ruling: retain 1080 × 1080 m bounds and 60 m chunks instead of nominal 1100/64. They meet the approximate size and divide exactly at 1.5/3/6 m cells. Changing this later requires rebuilding chunk geometry and retesting seams.
- Ruling: keep existing edge stitching if collision, normal and visual checks pass; adding skirts alone would conceal rather than repair a collision seam.
- Ruling: the enlarged-world ground budget is 3500 ms, replacing the superseded 1500 ms budget in the terrain probe; retain its route grade/slope checks unchanged.
- Preserve terrain revision 3 for this unfinished generation. Do not regenerate or repack the editable level, commit or push.

### Worker protocol and ownership

Use one bounded implementer at a time, then a fresh reviewer of its diff and test evidence. Each worker reads its packet plus Global Constraints and the relevant original task, writes a report under ignored `build/biome-continuation/`, and returns status, files changed, command/results and unresolved concerns. Workers do not spawn agents. The controller owns the progress ledger, integration and final probe execution. Use file-backed briefs so workers do not need the entire conversation.

Run with `godot-mono` (Godot 4.7.2 on this machine). `python` is not currently on PATH: locate an existing Python interpreter before texture/audio fetches; do not install one implicitly. No simultaneous `--import` processes or edits to the same file. Existing `grow` and zero-argument `tree_positions` callers must continue to work.

### Packet A: Restore normal startup and snapshot safety

**Original task:** 3. **Owner files:** `scripts/world/trail.gd`, `scripts/main.gd`, `scripts/ui/hud.gd`, new `tools/biome_snapshot_probe.gd` and `.tscn`.

**Interfaces:** add `Trail.settle_house() -> void`; retain `route_derived() -> Array[Node]`. Preserve edited house X/Z and yaw; settle only Y to ground plus `House.PLINTH`. Retain the generated terrain/Flora/landmarks and empty Fence when saved terrain revision differs.

- [ ] Add a snapshot probe loading the real main scene: house Y within 0.05 m of its pad plus plinth; expected chunk count and mesh extent; 24 collision rays within 0.2 m of terrain height outside the stair cut; empty `Fence` node in its existing child position.
- [ ] Exercise missing revision, old revision, same revision and edited route using in-memory snapshot fixtures; never save those fixtures over the editable level.
- [ ] Run the probe to record the missing-method/fence failure before changing product code.
- [ ] Implement house settlement, empty Fence and HUD world-edge cue. Inspect snapshot application so retained server collision can survive the later Flora rewrite.
- [ ] Run snapshot and biome probes; startup must have no script errors. Existing thaw failure belongs to Packet B.

### Packet B: Make terrain and transition checks trustworthy

**Original task:** remaining 2. **Owner files:** `scripts/world/ground.gd`, biome constants in `scripts/tune.gd`, `tools/biome_probe.gd`, `tools/terrain_probe.gd`, snapshot probe only if collision acceptance needs extension.

**Interfaces:** retain `snow_at(x: float, z: float) -> float`, `height_at`, `normal_at`, `slope_at`, `route_distance`, `story_distance`, `story_points` and chunk counts.

- [ ] Repair the terrain probe's typed conditional array and update only its build budget to 3500 ms. Run it to reveal actual grade/slope outcomes.
- [ ] Strengthen thaw measurement: keep the existing 16-ray regression, add local edge-normal spans so oblique rays cannot hide genuinely narrow transitions, and retain at least eight crossings. Record default seed and two additional deterministic seeds; distinguish required acceptance from seed coverage observations.
- [ ] Fix transition width in world metres using the biome-field gradient/distance, including altitude and competing core/patch edges. Preserve the snow invariants and directional coverage; do not simply relax acceptance thresholds.
- [ ] Check collision interpolation and stitched edge normals. If needed, match height sampling to the generated triangle diagonals and recompute normals after stitching. Preserve pad, stair cut, ravine and route.
- [ ] Run biome, terrain and snapshot probes. Measure build time after new field calculations.

### Packet C: Surface materials and overview tool

**Original task:** 4 and overview portion of 7. **Owner files:** `tools/fetch_ground_textures.py`, `shaders/snow_ground.gdshader`, material binding only in `scripts/world/ground.gd`, `assets/vendor/polyhaven/provenance.json`, new `tools/terrain_view.gd` and `.tscn`.

**Interfaces:** consume vertex red snow weight and terrain normals; preserve `ground.snow_material` for the house snow patch. Overview uses actual generated world and explicit full/lean settings.

- [ ] Resolve a Python executable; fetch the three named 1K CC0 textures from Poly Haven official API with checksums and provenance, then import once.
- [ ] Blend snow, wet thaw, grass/forest floor and slope rock; use rotated/warped noise and a lean path without normal blends. House snow patch must remain snow even where vertex colors are absent.
- [ ] Add captures for near, high, eye-level, far-aerial and thaw-close, with a warm-up before FPS sampling and outputs under `build/biome-continuation/`.
- [ ] Inspect all full and lean captures for shader errors, repetitive grids, visible cracks and incorrect house material; rerun biome/terrain probes after binding changes.

### Packet D: Deterministic tree placement and chunk rendering

**Original task:** tree portion of 5. **Owner files:** `scripts/world/flora.gd`, forest constants only in `scripts/tune.gd`, new `tools/flora_probe.gd` and `.tscn`.

**Interfaces:** retain `grow(ground: Ground, curve: Curve3D, reserved: Array[Vector3], seed_value: int = 1701) -> void`; retain `tree_positions() -> PackedVector3Array`, extend with optional centre/radius arguments for nearest-first queries without breaking callers. Expose `build_msec`, `trees: PackedVector3Array`, biome counts and planned/retained ordinary counts for the probe. Keep giant counts separate.

- [ ] Add the tree checks from Task 5 before replacing the old capped generator.
- [ ] Plant full world snow/green trees deterministically, respecting 12 m route, 25 m reserved clearance and 35 degree slope limits. Use imported spruces/cards with premium-pine fallback; snow gets great pines and 6–8 route giants outside the corridor.
- [ ] Build MultiMeshes per mesh and `Tune.CHUNK_SIZE`, with the specified visibility ranges. Lean selects a stable half of ordinary placements rather than advancing a different RNG sequence.
- [ ] Add one server body per chunk with cylinder trunk shapes; own/free all RIDs in `_exit_tree`. Probe cleanup after freeing Flora and verify collision actually blocks a body.
- [ ] Run full/lean flora probes: snow 300–2500, green 1500–12000 in full, clearance/slope/species checks, nearest query correctness, lean 0.5 ± 0.1, tree position count agreement. Record partial build budget before undergrowth.

### Packet E: Undergrowth and cliff dressing

**Original task:** remainder of 5 and retained natural-terrain dressing. **Owner files:** `scripts/world/flora.gd`, undergrowth constants in `scripts/tune.gd`, `tools/flora_probe.gd`.

**Interfaces:** consume Packet D's deterministic placement/batch infrastructure. Expose undergrowth planned/retained counts; combined Flora build remains below 2500 ms.

- [ ] Plant green fir/bush and clearing grass at 2.5 m candidate spacing, sparse mixed thaw and snow mounds/tufts; batch by mesh/chunk with full 90 m and lean 60 m visibility.
- [ ] Restore steep near-route rock dressing without putting trunk colliders in the route or blocking story interactions. Remove old horizon props and unconditional grassland that bypass biome placement.
- [ ] Extend full/lean probe: more than 5000 undergrowth in full, deterministic half in lean, combined time under 2500 ms, and zero leaked physics objects after cleanup.
- [ ] Inspect near/thaw/eye-level captures using the overview tool.

### Packet F: Biome footsteps, prints and weather

**Original task:** 6. **Owner files:** `scripts/player/player.gd`, `scripts/audio/soundscape.gd`, `scripts/weather/weather.gd`, `scripts/world/atmosphere.gd`, `tools/fetch_sounds.py`, `tools/make_soundscape.py` and audio provenance; new `tools/biome_effects_probe.gd` and `.tscn`.

**Interfaces:** consume `Ground.snow_at`; expose smoothed `Weather.snow_scale: float` for diagnostics, leave wind running. Preserve indoor surface classification and existing weather regimes.

- [ ] Probe outdoor grass below 0.35, thaw from 0.35–0.65, snow above; preserve indoor wood/other sounds. Prints/powder use the independent exact threshold S > 0.6.
- [ ] Verify 3–5 CC0 source recordings on their official pages, fetch grass steps and record provenance; add grass playback and thaw snow playback about 4 dB quieter.
- [ ] Smooth camera snow weight into all snowfall layers/spindrift, including Atmosphere's procedural squall snow densities. Test scale below 0.1 after three seconds over green, recovery over snow, and persistent wind/audio.
- [ ] Run effect probe and traversal/leap regressions; do not edit or rebake character voice clips.

### Packet G: Final integration, credits and documentation

**Original task:** 7. **Owner files:** `tools/biome_probe.gd` as coordinator, menu credit location, forest README, `CLAUDE.md` world documentation and this plan's completion checkboxes.

- [ ] Run forest, snapshot, biome, terrain, flora and effects probes in lean and applicable full mode, then traversal, leap, leap-math, journal, voice and meeting coherence/probe checks.
- [ ] Capture and inspect all five views in full and lean; record startup budgets and steady FPS separately. Capture one normal-play lean smoke frame.
- [ ] Add factual pack credit with explicitly pending author/model URL; request those details without blocking generation. Do not invent attribution or licensing evidence.
- [ ] Document current bounds, snow weights, chunks, mountains, edge, forest import, revision and diagnostic commands. Report screenshots, validation failures/limitations and the decisions above.
- [ ] Obtain explicit repack authorization separately if desired; no repack is part of these packets. No commits or push.

### Dependency and shared-file review

| Producer / consumer | Shared contract or file | Required ordering |
| --- | --- | --- |
| A / B | Snapshot probe, Ground collision and settled house | A restores startup, B validates geometry |
| B / C | Ground geometry versus material-only bindings | B finishes before C edits Ground |
| B / D / E | Tune constants and Ground slope/snow sampling | B then D then E; no concurrent Tune edits |
| D / E | Flora batching, deterministic placement, RID ownership | E builds on reviewed D |
| B / F | Snow weight and thresholds | B fixes field before F effects checks |
| C / E / G | Overview tool and visual output | C tool first, E views, G final views |
| A / D / G | Retained Flora and snapshot physics lifetime | Verify again after server-body rewrite |
| All / G | Public interfaces and gameplay | G integrates only reviewed packets |

Every packet has a bounded file set and an independently rejectable probe/review surface. Author/model URL and possible repack are follow-ups, not prerequisites for terrain implementation.

**Plan style ruling:** the terrain's look has to be tuned against renders, so this plan fixes interfaces, algorithms, constants and tests, not every line of code. Each task's probe is its contract.

## Global Constraints

- GDScript with tabs, static typing, `class_name`; built in code; values in `Tune`; `--import` after new classes.
- `Game`-dependent code is tested with `tools/*_probe.tscn`; failures are counted and the probe calls `quit(1)`.
- **S invariant:** `snow_at` ≥ 0.95 on the route (start to exit), at the house, the camp, the lookout and every page.
- **Walkable route:** grade at most 12%, slope under the path at most 25°, no slope over 45° beside the path except the ravine walls (6 m and further out).
- **Thaw band:** 30–60 m wide (S from 0.2 to 0.8 along the edge's normal).
- **Budgets:** ground build under 3500 ms and flora under 2500 ms (headless, this machine).
- **Pack files:** stay under `assets/vendor/sketchfab_forest/` with a README covering source, the Sketchfab Standard licence, the credit, and changes made. The user supplies the URL and author.
- **Keep the existing work:** the layered core (valley, ravine, cliffs), the house pad, the stair cut, and clockwise winding.
- No repack or rebuild of the editable level without the user's go-ahead. No commits unless asked; a parallel session commits on `mathilda-story`, so only files this plan touches get edited.

## Review Focus

1. **Snapshot overwrite** of the new ground, woods or rocks on a normal play. Pinned in Task 3: rays, mesh range, chunk count.
2. **A story spot losing its snow** (a page or the camp on green). Pinned in Task 2: S invariant at every epicentre.
3. **Chunk seams:** cracks or steps where cell sizes change. Pinned in Task 2: heights across seams are continuous to 1 cm, plus a visual check in Task 7.
4. **Lean performance on the Iris Xe:** tree and undergrowth counts and draw distances. Pinned in Task 5 (lean halves) and Task 7 (lean FPS recorded).
5. **Walking off the world** or climbing the wall. Pinned in Task 2: a walk-out probe is stopped inside `WORLD_MAX`.

---

### Task 1: Import the forest pack

**Files:**
- Create: `assets/vendor/sketchfab_forest/` (`forest_pack.fbx`, `textures/`, `README.md`)
- Create: `tools/import_forest_pack.gd` (headless; splits pieces into `meshes/*.res`)
- Create: `tools/forest_pack_probe.gd`

**Steps:**
- [ ] Write the probe (`-s`, headless). Each of `spruce_a..e`, `card_tree_a..b`, `card_fir`, `card_bush` and `grass_card` must exist as a `Mesh`; have its AABB base within 0.05 m of y = 0 and its centre within 0.3 m of x, z = 0; and have card surfaces with `transparency == ALPHA_SCISSOR` and `cull_mode == CULL_DISABLED`. Run it → FAIL (missing files).
- [ ] Copy the FBX (renamed `forest_pack.fbx`) and the textures into the folder; write the README; run `--import`.
- [ ] Write the import tool:
  - Load the FBX scene.
  - Pick pieces by node-name prefix: `Cylinder_0xx` for spruces (choose 5 with distinct height and shape: indices 23, 12, 18, 13, 20); the `05ade0e…` card trees (2 different sizes); the `a37081…|cc24eba…` card fir/bush (one); the `3f84aea…` grass card (one).
  - Bake each mesh's global transform into the vertices, recentre so the base sits at the origin, and duplicate the surface materials as `StandardMaterial3D`: cards get alpha scissor 0.4, cull disabled, and their albedo texture kept; trunks stay opaque.
  - Save `meshes/<name>.res`.
- [ ] Run the tool, then the probe → PASS.

### Task 2: World geometry, snow weight and chunked terrain

**Files:**
- Modify: `scripts/tune.gd` (`WORLD_*`, `SNOW_*`, `BIOME_*`, `MOUNTAIN_*`, `CHUNK_*`)
- Modify: `scripts/world/ground.gd`:
  - story points: `set_story(points: PackedVector3Array)`, called before `_ready`
  - `snow_at`
  - mountain and ring layers in `_sample`
  - a chunked LOD build replacing the single grid
  - `height_at` reads the function-backed height cache per chunk
- Modify: `scripts/world/trail.gd` (pass the house, camp, lookout and page positions to `Ground` before `add_child`; compute them before the ground exists, as the landmarks are placed relative to the route frame)
- Create: `tools/biome_probe.gd`, `tools/biome_probe.tscn`

**Algorithms:**
- **`d_story(x, z)`:** distance to the nearest of the route polyline and the story points, on a coarse field: 6 m cells inside the story field, 12 m outside. Built once.
- **`snow_at`:**
  - `core = 1 − smoothstep(SNOW_CORE_IN + n, SNOW_CORE_OUT + n, d_story)`, with `n` ±20 m of low-frequency noise.
  - Core patches: where `d_route_or_house > SNOW_PATCH_CLEAR`, `core *= 1 − 0.8 × patch` (sparse, high-threshold patch noise).
  - Biome beyond: `b = biome_noise × 1.0 + dir_bias(bearing from the story centre) − altitude_term(height)`; `biome_snow = 1 − smoothstep(−w, +w, b)`, with `w` from the thaw-width target and the noise gradient (tuned so the 0.2–0.8 span is 30–60 m on the ground).
  - `S = max(core, biome_snow)`, forced to 1 where `d_route_or_house < 60`.
- **Height:** core layers as now, then `+ mountains(x, z) × ramp(d_route)`, where the ramp runs 0 at 60 m to 1 at 200 m and mountains are ridged FBM with 60–120 m of relief; `+ ring(dist to world edge)` of 120–160 m over the last 80 m; then the pads as now (last, so the house stays flat).
- **Chunks:** 64 m squares over the world. Cell size by the chunk's nearest distance to the route or house: 1.5 m within 100 m, 3 m within 260 m, otherwise 6 m. Each chunk is a `MeshInstance3D` plus a trimesh `StaticBody3D`; the stair cut applies in the chunks it touches; a 2 m skirt runs down each chunk edge. Vertex `COLOR.r` = S. Normals come from height differences at the chunk's cell size.
- **`height_at`:** evaluates the cached chunk grid bilinearly, and keeps the old signature and speed. **`slope_at` and `normal_at`:** from the chunk grids.
- **Boundary:** a `StaticBody3D` with 4 box walls just inside `WORLD_*`.

**Steps:**
- [ ] Write `biome_probe`. Checks:
  - the S invariant at the route, house, camp, lookout and pages
  - the core: at least 85% of 600 sampled points within 200 m have S > 0.8
  - green exists beyond 250 m, with the mean (1 − S) in the NE and NW quadrants above the SW quadrant
  - thaw width: on 16 rays from the story centre, find the first S crossing 0.5 beyond 250 m; the 0.8→0.2 span along the ray is 30–60 m in at least 12 of 16 (rays with no crossing are skipped; at least 8 must cross)
  - the route-walkability checks (from `terrain_probe`)
  - seams: for 40 points on chunk borders, `height_at` just left and right differ by less than 1 cm
  - edge: a body pushed outward stops inside `WORLD_MAX`
  - `ground.build_msec < 3500`
  
  Run → FAIL.
- [ ] Implement `Tune`, `Ground` and `Trail` as above → PASS. Also run `terrain_probe` (walkable route and ravine) → PASS.

### Task 3: Snapshot, fence and edge

**Files:**
- Modify: `scripts/main.gd` (terrain-revision retain; `settle_house`)
- Modify: `scripts/world/trail.gd` (`settle_house()`; the fence becomes an empty `Node3D` named `Fence`)
- Modify: `scripts/ui/hud.gd` (`_against_wire` → near `WORLD_*`)
- Modify: `scripts/world/ground.gd` (`TERRAIN_REVISION = 3`)

**Steps:**
- [ ] Probe checks in `biome_probe`:
  - 24 collision rays match `height_at` within 0.2 m
  - every chunk mesh exists (the count equals the expected chunk count)
  - the house y is within 0.05 of pad height + `PLINTH`
  
  Run → FAIL (the snapshot overwrites or frees them).
- [ ] Implement the retain for a differing `terrain_revision`: `route_derived()` plus the `Fence` node; `trail.settle_house()` after `_settle_route` on both paths. The fence becomes empty. The HUD edge cue uses `WORLD_*` → PASS.

### Task 4: Biome ground shader and green textures

**Files:**
- Create: `tools/fetch_ground_textures.py` (Poly Haven CC0, 1K: `forrest_ground_01`, `aerial_grass_rock`, `brown_mud_leaves_01`, fetched through the API with md5 checks and recorded in `assets/vendor/polyhaven/provenance.json`)
- Modify: `shaders/snow_ground.gdshader`
- Modify: `scripts/world/ground.gd` (`_material` binds the green, mud and normal textures)

**Steps:**
- [ ] Fetch the textures; run `--import`.
- [ ] Shader:
  - `S = COLOR.r` + per-pixel noise (rotated gradient noise) for patchy edges.
  - Snow: the current look with gradient noise in place of `vnoise` (grid-free).
  - Thaw: wet earth (mud texture) with patchy snow where `S + noise > 0.5`.
  - Green: grass and forest-floor textures, blended by noise.
  - Rock: triplanar, by slope.
  - Snow on ledges only where S is high.
- [ ] Render with `tools/terrain_view` (Task 7's tool; build it here) and look at the near, high and thaw shots.

### Task 5: Flora by biome

**Files:**
- Rewrite: `scripts/world/flora.gd`
- Modify: `scripts/tune.gd` (`FOREST_*`, `GREEN_*`)

**Algorithms:**
- **Snow woods:** the superseded spec's design, with mask × S.
- **Green woods:** mask × (1 − S); spacing 4 m; pack spruces at scale 1.0–2.2, plus 15% card trees.
- **Undergrowth on a 2.5 m grid in green:** card fir and bush where the woods mask is high, grass cards in clearings, with mounds and snow-tuft undergrowth in snow.
- No trees within 12 m of the route or 25 m of reserved points, or on slopes over 35°; draws are deterministic so lean is a subset.
- **Batching:** per (mesh, 64 m chunk) a `MultiMeshInstance3D` with `visibility_range_end`: trees 260 m (lean 150 m), undergrowth 90 m (lean 60 m).
- **Trunks:** one `PhysicsServer3D` static body per chunk with cylinder shapes. `tree_positions()` returns the stored positions; the bodies are freed in `_exit_tree`.

**Steps:**
- [ ] Probe checks in `biome_probe`:
  - snow trees in the range 300–2500 and green trees in 1500–12000 (full); undergrowth over 5000 in full
  - none in the corridor, none on steep ground
  - green species only where S < 0.5 and snow species only where S > 0.5, with a 10% tolerance in the thaw
  - lean: ordinary trees and undergrowth at 0.5 ± 0.1 of planned
  - flora under 2500 ms
  - `tree_positions().size() == trees.size()`
  
  Run → FAIL.
- [ ] Implement → PASS (headless lean and `RUN_GRAPHICS=full`).

### Task 6: Footsteps, prints and snowfall by biome

**Files:**
- Modify: `tools/fetch_sounds.py` and `tools/make_soundscape.py` (grass step sources, CC0 verified on each page)
- Modify: `scripts/audio/soundscape.gd` (`grass`, `thaw`)
- Modify: `scripts/player/player.gd` (`_surface_at` uses `snow_at`; prints and powder only on `snow`)
- Modify: `scripts/weather/weather.gd` (layers × S at the camera, smoothed)

**Steps:**
- [ ] Probe checks:
  - `_surface_at` gives `grass` at a green point and `snow` on the route
  - the weather's snow scale is under 0.1 after 3 s with the camera over green
  
  Run → FAIL.
- [ ] Find 3–5 CC0 grass or forest-floor footstep recordings (BigSoundBank or Freesound, CC0 confirmed on each page), add them to `SOURCES`, run fetch and make, and confirm `assets/audio/steps/grass_*.wav` and the provenance entries exist.
- [ ] Implement → PASS. `thaw` plays the snow set about 4 dB quieter.

### Task 7: Overview, credits, regressions and docs

- [ ] `tools/terrain_view.tscn`: near, high, eye-level, far-aerial and thaw-close shots plus the FPS, in full and lean graphics. Look at every shot.
- [ ] Esc-menu credit line for the pack (with placeholders for the URL and author until the user supplies them, marked in the README).
- [ ] Regressions: the traversal, leap, leap-math, terrain, journal and voice probes, plus a lean smoke capture.
- [ ] CLAUDE.md: the World section (biomes, snow weight, chunks, mountains, edge, pack import, snapshot revision 3) and the commands.
- [ ] Report: show the overview shots; list the rulings; ask for the URL and author and the repack go-ahead. No commit unless asked.
