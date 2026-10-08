# Natural Terrain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the tiled dome of snow with natural, seed-generated land: a route valley, winding cliffs dressed with rock, one ravine, and dense forest patches with great pines and lone giants. It must stay walkable and lean-safe.

**Architecture:**
- `Ground` builds a layered height function on a 1.5 m grid. Its route fields (distance, valley floor, ravine weight) sit on a coarse 6 m grid. Normals come from the heights. Rock meshes are placed on steep cells.
- The snow shader loses its lattice-aligned noise and gains triplanar rock.
- `Flora` plants woods from a mask and draws them as chunked `MultiMeshInstance3D`s, with a trunk collider per tree.
- `main.gd` keeps the newly generated terrain when the editable-level snapshot carries an older `terrain_revision`, and settles the house onto the new pad.

**Tech Stack:** Godot 4.7.2 (`godot-mono`), GDScript, FastNoiseLite, ArrayMesh, MultiMesh, Jolt.

**Spec:** `docs/superpowers/specs/2026-10-06-natural-terrain-design.md`

## Global Constraints

- GDScript with tabs and static typing; `class_name` on every script. Everything is built in code; values live in `Tune`.
- After adding a `class_name` script, run `godot-mono --headless --path . --import`.
- `Game`-dependent code is tested with `tools/*_probe.tscn` scene probes that count failures and `quit(1)`; never bare `assert()`.
- Ground triangles stay clockwise seen from above.
- `GROUND_CELL` = 1.5. `TERRAIN_REVISION` starts at 2.
- No cliff (slope over 45°) within 12 m of the route, except the ravine walls, which start 6–9 m out. No trees within `FOREST_CLEAR` (12 m) of the route. The house pad stays flat.
- Lean graphics keeps half the ordinary trees and undergrowth; great trees and giants are always kept.
- Do not run `--repack-editor-level` or rebuild the editable level without the user's go-ahead. Commit only if asked.

## Review Focus

1. **Snapshot overwrite.** The old snapshot's ground mesh, collision or tree nodes must not replace the new ones on a normal play. Pinned in Task 2: raycasts match `height_at`, and the mesh height range matches `_heights`.
2. **Ravine versus the no-cliff rule.** The probe must exempt the ravine stretch only, not weaken the rule elsewhere. Pinned in Task 1.
3. **Lean versus full layouts.** Thinning must keep the same positions; lean is a subset of full. Pinned in Task 4: every lean tree is also a planned full tree, by count arithmetic.
4. **House on the new pad.** An authored house must sit at pad height plus `PLINTH`, or she spawns in the air or in the ground. Pinned in Task 2.
5. **Startup cost.** Four times the vertices plus rocks and forest must not make startup crawl. Pinned in Task 1 (ground under 1500 ms) and Task 4 (flora under 1500 ms).

---

### Task 1: Layered height function on a finer grid

**Files:**
- Modify: `scripts/tune.gd` (`GROUND_CELL`; new `TERRAIN_*`, `VALLEY_*`, `CLIFF_*`, `RAVINE_*` block)
- Modify: `scripts/world/ground.gd` (route fields, layered `_sample`, height normals, `slope_at`, `normal_at`, `route_distance`, revision metadata, `build_msec`, `cliff_cells`)
- Modify: `scripts/world/trail.gd` (hand the route to `Ground`)
- Create: `tools/terrain_probe.gd`, `tools/terrain_probe.tscn`

**Interfaces (produced):**
- `Ground.TERRAIN_REVISION: int = 2` and `Ground.ROUTE_CELL = 6.0`.
- Settable before `_ready`: `Ground.route: Curve3D`, `route_from: float`, `route_to: float`.
- `Ground.slope_at(x, z) -> float` (degrees), `normal_at(x, z) -> Vector3`, `route_distance(x, z) -> float`.
- Stats: `Ground.build_msec: int`, `cliff_cells: int`, `rock_count: int` (0 until Task 3).

- [ ] **Step 1: Write the failing probe.** `tools/terrain_probe.gd` loads `main.tscn` and checks:
  - **Walkable route.** Sample every 1 m from `player_start_offset` to `exit_offset`. Consecutive `height_at` grade ≤ 0.12, and `slope_at` on the path ≤ 25°.
  - **No cliffs near the path.** For offsets outside the ravine stretch, sample at ±2, ±5, ±8 and ±11 m perpendicular: `slope_at` ≤ 45°. Inside the ravine stretch, check only ±2 and ±5 m.
  - **Ravine.** At the middle offset of the ravine stretch, `height_at` at ±10 m perpendicular ≥ path height + 6.
  - **Cliffs.** `ground.cliff_cells` ≥ 150.
  - **House pad.** `height_at` at `house.to_global(Vector3(x, 0, z))` for x, z in {-6, -3, 0, 3, 6}: spread ≤ 0.05.
  - **Budget and revision.** `ground.build_msec` < 1500, and the ground's `terrain_revision` metadata == `Ground.TERRAIN_REVISION`.

  The ravine stretch is offsets `route_from + span × [RAVINE_FROM, RAVINE_TO]`, with `span = exit_offset − player_start_offset`.

  Use the probe skeleton from `tools/leap_probe.gd` (`_check`, `_finish` → `quit(1 if failed)`). The `.tscn` is the same three-line wrapper as `leap_probe.tscn`.

- [ ] **Step 2: Run it.** `godot-mono --headless --path . tools/terrain_probe.tscn` → FAIL. Expect parse errors on `slope_at` / `route_distance` / `cliff_cells`, or failed checks.

- [ ] **Step 3: Tune.** Set `GROUND_CELL := 1.5`. Add after `SNOW_DEPTH`:

```gdscript
# The land. Warped hills (TERRAIN_HILLS metres of relief, wavelength about
# 1 / TERRAIN_HILL_FREQ), a route valley (the ground eases onto a walking floor
# within VALLEY_HALF of the path, no steeper than VALLEY_GRADE, and rises
# VALLEY_BANK per metre beyond it up to VALLEY_BANK_MAX), a rim of
# TERRAIN_RIM metres beyond the fence.
const TERRAIN_HILLS := 9.0
const TERRAIN_HILL_FREQ := 0.0085
const TERRAIN_WARP := 25.0
const TERRAIN_DETAIL := 1.2
const TERRAIN_RIM := 14.0
const VALLEY_HALF := 8.0
const VALLEY_GRADE := 0.08
const VALLEY_BANK := 0.18
const VALLEY_BANK_MAX := 6.0
# Cliffs: where the cliff noise crosses CLIFF_THRESHOLD the ground steps up
# CLIFF_RISE_MIN..MAX metres over a band CLIFF_SHARPNESS wide in noise units,
# only CLIFF_CLEAR metres or more from the route and CLIFF_FENCE inside the fence.
const CLIFF_FREQ := 0.012
const CLIFF_THRESHOLD := 0.18
const CLIFF_SHARPNESS := 0.05
const CLIFF_RISE_MIN := 6.0
const CLIFF_RISE_MAX := 12.0
const CLIFF_CLEAR := 20.0
const CLIFF_FENCE := 6.0
# The ravine: the stretch of the played route (as fractions from start to
# exit) where walls RAVINE_RISE metres high rise from RAVINE_INNER to RAVINE_OUTER
# metres either side of the path.
const RAVINE_FROM := 0.45
const RAVINE_TO := 0.6
const RAVINE_RISE := 10.0
const RAVINE_INNER := 6.0
const RAVINE_OUTER := 9.0
```

- [ ] **Step 4: Ground.** Replace the noise and sampling parts of `ground.gd`:
  - Add the header comment, `TERRAIN_REVISION`, `ROUTE_CELL`, the route vars, the stats, `_normals`, the noises (`_hills`, `_warp`, `_detail`, `_cliff`, `_cliff_zone`, `_cliff_rise`, `_dirt`), the `_rng`, and the coarse fields (`_field_origin`, `_field_size`, `_route_distance`, `_valley_floor`, `_ravine`).
  - `_ready()` sets the metadata, times the build, and calls `_configure_noise()`, `_build_route_fields()`, `_build()` (and `_dress_cliffs()` from Task 3).
  - `_hills_at(x, z)`: warped simplex hills plus detail.
  - `_valley_profile()`: the hills along the route every 2 m, averaged over ±15 m, then one forward pass clamping each step to `VALLEY_GRADE × 2 m`.
  - `_build_route_fields()`: for each 6 m node, `route.get_closest_offset`, distance, profile height, and ravine weight (`smoothstep` over `RAVINE_FROM`..`+0.05` and `RAVINE_TO−0.05`..`RAVINE_TO` of the played fraction).
  - `_field(values, x, z, fallback)`: bilinear.
  - `_sample(x, z)`: hills + bank, eased onto the valley floor by `1 − smoothstep(0.6 × VALLEY_HALF, 2 × VALLEY_HALF, d)`, + `_cliffs(x, z, d)`, + ravine walls (`ravine weight × smoothstep(INNER, OUTER, d) × (1 − smoothstep(40, 70, d)) × RAVINE_RISE`), + rim (`smoothstep(0, GROUND_PAD, −fence distance) × TERRAIN_RIM`), then the pads as before. The old `_flatten` calls go.
  - `_cliffs(x, z, d)`: the allowed mask (`max(edge zone within 30–60 m of the fence, hillside zone noise)` × `smoothstep(CLIFF_CLEAR, +15, d)` × `smoothstep(CLIFF_FENCE, +4, fence distance)` × away from pads), then `step × rise × allowed`.
  - `_build()`: as before, but heights from `_sample`, and normals by central differences of `_heights` (no face-normal sums), stored in `_normals`. Count `cliff_cells` (normals with y < cos 55°).
  - `normal_at`, `slope_at`, `route_distance` as public helpers.

- [ ] **Step 5: Trail.** Before `add_child(ground)` in `Trail._ready`:

```gdscript
	# The land is shaped around the path: a valley along it, a ravine on one stretch.
	ground.route = curve
	ground.route_from = player_start_offset
	ground.route_to = exit_offset
```

- [ ] **Step 6: Run the probe** → PASS. If a check fails, adjust the shape, not the check. Keep the ravine exemption limited to the ravine stretch. Also run `godot-mono --headless --path . --import`, which must be clean.

---

### Task 2: Keep the new terrain over an older snapshot

**Files:**
- Modify: `scripts/main.gd` (terrain-revision retain; settle the house)
- Modify: `scripts/world/trail.gd` (`settle_house()`)
- Modify: `tools/terrain_probe.gd` (snapshot checks)

**Interfaces:**
- Consumes: `Ground.TERRAIN_REVISION` and the metadata (Task 1).
- Produces: `Trail.settle_house() -> void`.

- [ ] **Step 1: Add the failing checks** to the probe:
  - **Collision matches.** At 24 points inside the fence (a fixed grid, skipping slopes over 20° and the house area), a downward ray on `LAYER_WORLD` from 50 m up hits within 0.2 m of `height_at`.
  - **Mesh matches.** `SnowSurface`'s mesh AABB top (`position.y + size.y`) is within 0.3 m of the maximum of `_heights`.
  - **House on the pad.** `house.global_position.y` is within 0.05 of `height_at(house) + House.PLINTH`.

- [ ] **Step 2: Run.** Expected: FAIL, because the old snapshot's collision and mesh were applied over the new ground.

- [ ] **Step 3: main.gd.** After the house layout-revision block (inside `if use_snapshot:`), add:

```gdscript
		# A snapshot of older land: keep the field, woods, landmarks and fence as
		# generated now. The house keeps its edits; it is set back onto the pad.
		var saved_ground := snapshot.get_node_or_null("Trail/Ground")
		if saved_ground == null or int(saved_ground.get_meta("terrain_revision", 0)) != Ground.TERRAIN_REVISION:
			terrain_changed = true
			var keep: Array[Node] = trail.route_derived()
			var fence := trail.get_node_or_null("Fence")
			if fence:
				keep.append(fence)
			for node in keep:
				if not retain.has(node):
					retain.append(node)
```

Declare `var terrain_changed := false` next to `house_changed`. In both the repack path and the normal path, directly after `_settle_route(...)`, add:

```gdscript
		if terrain_changed:
			trail.settle_house()
```

- [ ] **Step 4: Trail.settle_house.**

```gdscript
# After an older snapshot put the house back at its own height: down onto the pad.
func settle_house() -> void:
	if house and ground:
		var at := house.global_position
		house.global_position = Vector3(at.x, ground.height_at(at.x, at.z) + House.PLINTH, at.z)
```

- [ ] **Step 5: Run the probe** → PASS. Then the leap probe → PASS.

---

### Task 3: Shader without tiles, triplanar rock, and rock dressing

**Files:**
- Modify: `shaders/snow_ground.gdshader`
- Modify: `scripts/world/ground.gd` (`_dress_cliffs`)
- Modify: `scripts/tune.gd` (`CLIFF_ROCKS_MAX := 70`, `CLIFF_ROCK_GAP := 12.0`)
- Modify: `tools/terrain_probe.gd` (rock count)
- Create: `tools/terrain_view.gd`, `tools/terrain_view.tscn` (overview shots; promote `build/terrain/view.gd`)

- [ ] **Step 1: Failing check.** Add `ground.rock_count >= 12` to the probe. Run → FAIL (0).

- [ ] **Step 2: Rock dressing** in `Ground`:
  - `_dress_cliffs()` collects the vertices whose normal has y < cos 55°, shuffles them with `_rng`, and greedily places `SM_Env_Rock_Cliff_02.fbx` at least `CLIFF_ROCK_GAP` apart and at least `RAVINE_INNER` from the route, up to `CLIFF_ROCKS_MAX`.
  - Each rock: scale 0.6–1.2, turned so local +Z points along the downhill horizontal of the normal, positioned at `vertex − outward × 2.5 × scale − up × 3 × scale`.
  - One to three boulders (`SM_Env_Rock_01/02/05/08`) go 4–8 m out from the face, at least 5 m from the route, on `height_at − 0.2`.
  - All of it sits under a `Rocks` node. Count `rock_count`.

- [ ] **Step 3: Run the probe** → PASS.

- [ ] **Step 4: The tiles, before and after.** Promote the throwaway overview into `tools/terrain_view.gd` + `.tscn`:
  - It takes near, high and eye-level shots into `build/terrain/`, with a suffix from `RUN_VIEW_TAG`.
  - It prints the average FPS over 60 frames at the eye shot.

  Render with the current shader (`RUN_VIEW_TAG=before_shader`).

- [ ] **Step 5: Shader.**
  - Add gradient noise `gnoise(vec2)` (quintic, hashed gradients), `soft(p) = clamp(0.5 + 0.7 × gnoise(p), 0, 1)`, and two rotation matrices.
  - Drift, clumps, grains and the normal-detail differences use `soft()` on rotated, offset coordinates instead of `vnoise`.
  - Drop the absolute-height `hollow` term, since heights are no longer meaningful as dirt.
  - The rock blend uses triplanar `dirt_tex` (weights `|n|⁴`) for rock variation.

- [ ] **Step 6: Render again** (`RUN_VIEW_TAG=after`). Look at both `near` shots: the 3 m squares must be gone. Note which change removed them.

---

### Task 4: Forest patches, great pines, giants, chunked instancing

**Files:**
- Rewrite: `scripts/world/flora.gd` (keep `_prop`, `_trunk`, `_horizon`, `_off_path`, `_blocked`, `tree_positions`, the grassland, and the undergrowth lists)
- Modify: `scripts/tune.gd` (`FOREST_*`)
- Modify: `tools/terrain_probe.gd` (forest checks)

**Interfaces:**
- Produces:
  - `Flora.trees: Array` of `[Vector3 at, float scale, String kind]` (kinds `tree`, `bare`, `great`, `giant`).
  - `Flora.planned_trees: int` and `planned_ordinary: int`.
  - `Flora.build_msec: int`.
  - `Flora.forest_at(at: Vector3) -> float`.
- Consumes: `Ground.route_distance`, `slope_at`, `height_at`.

- [ ] **Step 1: Failing forest checks** in the probe:
  - `300 ≤ planned_trees ≤ 1500`.
  - Every tree has `route_distance ≥ FOREST_CLEAR − 0.01` and `slope_at ≤ 35.5`.
  - Great trees ≥ 8% of the placed trees; giants between 6 and `FOREST_GIANTS`.
  - Ordinary placed vs planned: in lean, within 0.5 ± 0.1 of `planned_ordinary`; in full, equal.
  - `flora.build_msec < 1500`.
  - `tree_positions().size() == trees.size()`.

  Run → FAIL.

- [ ] **Step 2: Tune.**

```gdscript
# Woods: a forest mask (wavelength about 1 / FOREST_FREQ), none within
# FOREST_CLEAR of the route, trees on a FOREST_SPACING jittered grid at least
# FOREST_MIN_GAP apart (FOREST_GREAT_GAP round a great tree), FOREST_GREAT_SHARE
# of them great (scale FOREST_GREAT_MIN..MAX), FOREST_GIANTS lone giants in
# clearings, FOREST_LEAN_SHARE of the ordinary trees and undergrowth kept in
# lean graphics, and woods drawn in FOREST_CHUNK metre blocks out to FOREST_DRAW
# (FOREST_DRAW_LEAN in lean graphics).
const FOREST_FREQ := 0.011
const FOREST_CLEAR := 12.0
const FOREST_SPACING := 4.5
const FOREST_MIN_GAP := 3.5
const FOREST_GREAT_GAP := 7.0
const FOREST_DENSITY := 0.85
const FOREST_TREE_MIN := 0.9
const FOREST_TREE_MAX := 1.4
const FOREST_GREAT_SHARE := 0.15
const FOREST_GREAT_MIN := 2.0
const FOREST_GREAT_MAX := 2.6
const FOREST_GIANTS := 7
const FOREST_GIANT_MIN := 2.4
const FOREST_GIANT_MAX := 2.8
const FOREST_LEAN_SHARE := 0.5
const FOREST_CHUNK := 60.0
const FOREST_DRAW := 230.0
const FOREST_DRAW_LEAN := 130.0
```

- [ ] **Step 3: Flora.** In `grow()`:
  1. Seed `_rng` and a separate `_thin` RNG.
  2. Configure the forest noise.
  3. `_plant_forest()`: a jittered grid; draw every random value for a candidate before deciding, so lean is a subset of full. Accept by `forest_at × FOREST_DENSITY` and `_room()` (spatial hash of 8 m cells). Count `planned_*`; plant if great, or full, or `_thin < LEAN_SHARE`; always occupy.
  4. `_plant_giants()`: candidates on a 6 m grid with route distance 20–60 m, raw woods < 0.2, slope < 20°, not reserved, inside the fence. Shuffle; take up to `FOREST_GIANTS`, at least 30 m apart and `_room(at, 8)`.
  5. `_draw_batches()`: group transforms by (model, chunk). Per visible mesh part of the model (`_parts()`: the spawned model's visible `MeshInstance3D`s, mesh duplicated with override materials baked into surfaces, and the transform relative to the model), one `MultiMeshInstance3D` with `visibility_range_end` = draw distance, shadows on.
  6. `_undergrowth()`: a 7 m jittered grid placed by context (bushes and deadfall at the forest edge, grass and moss in clearings, mounds in the open, sparse boulders), skipping steep, reserved and near-route spots. Caps are scaled by the lean share.
  7. `_horizon()` and the grassland as before.

  Trees use the premium pines (`SM_Env_Pine_02.fbx`, `SM_Env_Pine_03.fbx`, which `PremiumFlora` maps) and `SM_Env_Pine_NoLeaves_01.fbx` for bare trees (10%). Every tree gets `_trunk(at, 0.35 × scale, 3.6 × scale)`.

- [ ] **Step 4: Run the probe** headless (lean) and with `RUN_GRAPHICS=full` → PASS both. Run `--import` if needed.

---

### Task 5: Overview, regressions, docs

- [ ] **Step 1: Overview shots.** Run `tools/terrain_view.tscn` in full and lean graphics (`RUN_GRAPHICS`), and read every image:
  - The near shot has no tiles.
  - The high shot shows valley, cliffs, rock, woods and giants.
  - The eye-level shot is legible.
  - Record the FPS in both modes.
- [ ] **Step 2: Regressions.**
  - `tools/traversal_probe.tscn` → reaches the exit.
  - `tools/leap_probe.tscn` → PASS.
  - The leap math and phase probes → PASS.
  - A lean `RUN_CAPTURE` smoke shot looks normal.
- [ ] **Step 3: Docs.** In CLAUDE.md, update the World section (layered terrain, route fields, cliffs and rocks, ravine, forest batching, `TERRAIN_REVISION` and the snapshot retain) and the commands (terrain probe and view). Note that `--repack-editor-level` stores the new terrain in the snapshot only with the user's go-ahead.
- [ ] **Step 4:** Report to the user. Offer the repack. No commit unless asked.
