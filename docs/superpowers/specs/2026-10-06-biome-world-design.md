# Biome world: a snowy story core in green, mountainous land

Date: 2026-10-06. Status: approved in conversation, awaiting review of this document.
Supersedes `2026-10-06-natural-terrain-design.md`. Its layered ground (valley, ravine, cliffs, 1.5 m cells, height-derived normals) is already in `scripts/world/ground.gd` (Task 1 of that plan) and is kept as the core of this one. Its forest design applies to the snow biome.

## Goal

A random landscape about 1.1 × 1.1 km, generated from the level seed.
- Snow lies where the story happens: mostly snow within 200–250 m of its epicentres.
- Beyond that, biome rules decide: random lush green patches everywhere, greener to the north-east and north-west, partly to the south-east.
- Natural thaw bands where snow meets green.
- Mountains anywhere outside the walkable route valley, and a mountain wall at the edge.
- Green woods use the user's Sketchfab forest pack.

## Agreed choices

- **World:** about 1.1 × 1.1 km, walkable everywhere up to the mountain wall.
- **Snow core:** mostly snow within 200 m of the story epicentres, fading out by 250 m. Small green patches are allowed in the core only more than 80 m from the route and house.
- **Beyond the core:** biome math (noise, direction and altitude), with random green patches everywhere, greener NE and NW, moderately SE, least SW.
- **Transitions:** a natural, noisy thaw band of 30–60 m wherever snow meets green.
- **Mountains:** can appear anywhere outside the route valley.
- **Approach A:** one biome-aware generator drives terrain, shader, flora, footsteps and weather from one shared snow weight.

## The asset pack

`C:\Users\soulwax\Downloads\the-landscape-is-a-forest-in-the-mountains.zip`: one FBX ("лес пихты в горах на скетч") and 14 textures. It's a hand-made diorama about 35 × 24 m, 19.4k triangles, 395 meshes:
- 14 tall spruces (cylinder trunk plus branch cards, 106 triangles, 5–11 m)
- 8 crossed-card trees (36 triangles)
- about 370 card firs and bushes (45 triangles)
- one 6.6k-triangle ground and mountain mesh with a texture baked to its own UVs (not tileable)

**Licence:** Sketchfab Standard (free), per the user and <https://sketchfab.com/licenses>.
- Use in the game, modified, is allowed, commercial or not.
- No redistribution of the asset as stand-alone files.
- Credit the provider where others are credited.

Recorded in `assets/vendor/sketchfab_forest/README.md`. The model page URL and author still need to come from the user. If the repository is public, committing the raw FBX and PNGs may count as stand-alone redistribution; the user decides whether to keep them out of the public repository.

## 1. World and story geometry

- `Tune.WORLD_MIN_X/MAX_X/MIN_Z/MAX_Z` ≈ ±550 around the story's centre (x −550..550, z −625..475).
- The old `FENCE_*` rectangle becomes the **story field**, where full detail applies.
- **Story epicentres:** the route polyline from start to exit, the house, the camp, the lookout and the five pages. A coarse distance field to the nearest epicentre (6 m cells inside the story field, coarser outside) feeds everything below.
- North is −Z, the direction the route runs toward the exit.

## 2. Snow weight `S(x, z)`

One function on `Ground`, shared by all systems: `snow_at(x, z) -> float`, 0 = green and 1 = snow.

1. **Core:** `core = 1 − smoothstep(200 + n1, 250 + n1, d_story)`, with `n1` a ±20 m low-frequency wobble.
2. **Core patches:** inside the core, beyond 80 m from the route and house, a sparse patch noise can lower S down to about 0.2, in patches 15–40 m across.
3. **Biome math beyond the core:** `b = biome_noise + direction_bias + altitude`.
   - `direction_bias` comes from the bearing from the story centre: NE and NW +0.35, SE +0.15, SW −0.15, interpolated with cosine lobes.
   - `altitude` raises snow above about 70 m of height (snowcaps).
   - Snow where `b < 0`, green where `b > 0`. The thaw band is `smoothstep(−w, +w, b)`, with `w` set so its width on the ground is 30–60 m (noise-varied).
4. `S = max(core-protected snow, biome snow)`, so within 200 m of the route and house it is always at least the core value.

**Invariant:** S ≥ 0.95 on the route, at the house, the camp, the lookout and every page.

## 3. Terrain

- **Within about 60 m of the route:** the existing layered land (valley floor, banks, ravine, cliff bands) unchanged.
- **Further out:** relief ramps from about 9 m to ridged mountains of 60–120 m, with passes and forested slopes, everywhere including inside the snow core.
- **The edge:** a ring of 120–160 m peaks in the last about 80 m before the world edge, steeper than 45° so she cannot climb it, plus an invisible `WorldBoundaryShape`-style wall just inside the edge as a backstop.
- **Mesh:** 64 m chunks, each with a cell size by distance from the route and house: 1.5 m within 100 m, 3 m within 260 m, 6 m beyond. Each chunk has a 2 m skirt to hide seams between resolutions. Height comes from one function, so the seams agree. Total about 120k vertices.
- **Per vertex:** the colour carries `S` (red) and slope; normals come from height differences.
- **Collision:** one trimesh per chunk, with the stair-well cut kept. Rocks dress the steep cliff cells near the route as before.

## 4. Ground shader

- **Snow:** the existing snow look, with grid-free noise (rotated, warped gradient noise; no 3 m lattice).
- **Thaw (S about 0.3–0.7):** patchy snow broken up per pixel over wet, dark earth and flattened grass.
- **Green:** tiling moss, grass and forest-floor albedo and normal maps from CC0 Poly Haven (1K, fetched like `assets/vendor/polyhaven/`), blended by noise.
- **Rock:** triplanar rock on slopes over about 40°, with snow on ledges only where S is high.
- **Lean graphics:** a cheaper path (no normal-map blend).

## 5. Flora by biome

- **Snow:** the forest design from the superseded spec, with mask × S: premium pines, clearings, about 15% great pines at scale 2.0–2.6, and 6–8 lone giants near the route.
- **Green:** lush woods from the pack, mask × (1 − S).
  - The pack's tall spruces, the 4–5 most distinct of the 14, at scale 1.0–2.2.
  - Dense card firs and bushes underneath, grass cards in clearings, and a share of the card trees.
  - Density is higher than in the snow.
- **Thaw band:** sparse, mixed species.
- **Rules everywhere:**
  - No trees within 12 m of the route, within 25 m of reserved points, or on slopes over 35°.
  - Instanced per (model, 64 m chunk) with draw distances: trees 260 m (150 m lean), undergrowth 90 m (60 m lean). Lean keeps half the ordinary trees and undergrowth.
- **Collision:** trunk cylinders through `PhysicsServer3D`, one static body per chunk, no node per tree. `Flora.tree_positions()` returns the stored trunk positions, nearest first within a radius when asked, for `Wildlife`.

## 6. Pack import (`tools/import_forest_pack.gd`)

1. Copy the zip's FBX (renamed `forest_pack.fbx`) and textures into `assets/vendor/sketchfab_forest/`, with a README covering source, licence, credit, and the changes made.
2. A headless tool script loads the FBX and saves each chosen piece as its own mesh resource (`spruce_a..e.res`, `card_tree_a..b.res`, `card_fir.res`, `card_bush.res`, `grass_card.res`) under `meshes/`:
   - recentred so its base sits at the origin, with +Y up
   - card materials set to alpha scissor, double-sided, with the pack's normal maps where they match
3. `Flora` loads these by path. If the folder is missing, the green biome falls back to the premium pines tinted green.

## 7. Systems

- **Footsteps:**
  - `Player._surface_at` returns `"grass"` where S < 0.35 outdoors, and `"thaw"` (snow sound at a lower level) where S is 0.35–0.65.
  - A `grass` step set comes from CC0 sources through `tools/fetch_sounds.py` and `make_soundscape.py`, with provenance recorded in `assets/audio/provenance.json`.
  - Prints and powder appear only where S > 0.6.
- **Snowfall:** `Weather` scales the snow particle layers and the spindrift by S at the camera (smoothed). Over green the air is clear; the wind stays.
- **The fence:** the old 300 m fence is no longer built. An empty `Fence` node stays in `Trail`'s child order for the editable-level snapshot. `Hud._against_wire()` becomes an edge cue at the world boundary.
- **Snapshot:** `Ground.TERRAIN_REVISION = 3`. When a snapshot's revision differs, `main.gd` keeps the newly generated route-derived nodes and the fence node, and `Trail.settle_house()` sets the house onto its pad. The user can repack afterwards (`--repack-editor-level`) only with their go-ahead.

## Tuning

`Tune` gets `WORLD_*`, `SNOW_CORE_IN` (200), `SNOW_CORE_OUT` (250), `SNOW_PATCH_CLEAR` (80), `BIOME_*` (frequency, direction biases, snowline altitude, thaw width), `MOUNTAIN_*` (relief, ring height, ramp distances), `CHUNK_SIZE` (64), `CHUNK_CELL_NEAR/MID/FAR` (1.5/3/6), and green-forest counterparts of the `FOREST_*` values.

## Verification

- **Biome and terrain probe** (`tools/biome_probe.tscn`, headless):
  - The S invariant at the route, house, camp, lookout and pages.
  - At least 85% of samples within 200 m of the story have S > 0.8.
  - Green exists beyond 250 m, with mean (1 − S) higher NE and NW than SW.
  - Thaw-band width: for each of 16 rays crossing a snow-to-green edge, the 0.2–0.8 span is 30–60 m.
  - The route is walkable: grade at most 12%, path slope at most 25°, no cliff beside it except the ravine.
  - The edge blocks her: a probe walking outward is stopped before `WORLD_MAX`.
  - Tree counts per biome are within ranges, with no trees in the route corridor.
  - Lean halves the ordinary trees and undergrowth.
  - Ground under 3.5 s and flora under 2.5 s on this machine.
  - The snapshot: collision rays match `height_at`, the mesh range matches, and the house is on its pad.
  - `_surface_at` returns grass on green and snow on snow; the weather snow scale is near 0 over green.
- **Overview tool:** near, high, eye-level and far-aerial shots plus a frame-rate reading, in full and lean graphics.
- **Regressions:** the traversal, leap, terrain-route, journal and voice probes.

## Risks

- **Startup time and memory** at 1.1 km². Chunked LOD meshes, coarse distance fields and per-chunk physics bodies are the mitigation; the probe enforces budgets.
- **Card trees up close.** The pack is stylised and low-poly; near the route they may read as flat. The design keeps them in the green and away from the route, which mostly sits in snow, and the overview shots judge it.
- **Chunk seams.** Skirts hide cracks; height comes from one function.
- **Licence and redistribution:** see above. The user confirms the model URL and author for the credit.
