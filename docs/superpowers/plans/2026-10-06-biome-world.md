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
