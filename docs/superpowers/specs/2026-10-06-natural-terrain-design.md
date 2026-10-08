# Natural terrain, forests and cliffs: design

Date: 2026-10-06. Status: approved in conversation, awaiting review of this document.

## Goal

The field should read as natural winter land: no tiled look, landforms with rising banks, ridges and hollows, rock cliffs, a ravine, and real forest patches with great old pines. All of it is generated from the level seed. The route stays walkable from start to exit.

## Agreed choices

- **Cliffs:** frame parts of the field's edges and some hillsides beside the route, and one stretch of the route runs through a ravine between cliffs. Never on the path.
- **Great trees:** about 15% of forest trees are the premium pines scaled to roughly 25–35 m, plus six to eight lone giants in the open as landmarks.
- **Density:** dense forest (several hundred trees) that stays playable on the Iris Xe laptop in lean graphics.
- **Approach A:** a layered, intentionally shaped height function on a finer grid, a fixed snow shader, and rock meshes dressing steep faces. Not a shader-only fix, not the Terrain3D add-on.

## What is wrong now

- **The tiles.** Up close the snow is a grid of roughly 3 m squares, each shaded a little differently (seen in `build/terrain/near.png`). Two things line up with it: the terrain mesh is a 3 m grid (`Tune.GROUND_CELL`), and the snow shader's drift term is value noise on a 3.2 m lattice (`vnoise(world_pos.xz * 0.31)`). The shader's normal detail is also lattice-aligned value noise. Both are fixed; an A/B render confirms which carried the visible seams.
- **The landform.** One noise blend (broad, detail, ridged) flattened near two points gives a single smooth dome (`build/terrain/high.png`).
- **The trees.** At most 64 pines, placed on a 9 m grid wherever a noise exceeds 0.18. That reads as a thin scatter, not forest.

## 1. Terrain (`Ground`)

The height function is rebuilt in layers. The seed, `height_at()`, pads and cuts keep their meaning.

1. **Hills.** Domain-warped noise (simplex, about 120 m wavelength, warp about 25 m), about 9 m of relief, plus a light detail octave.
2. **Route valley.**
   - Within `VALLEY_HALF` (about 8 m) of the route, the height eases toward a smoothed profile of the hills along the route, so she walks a gentle floor. The along-route grade is capped near 8%.
   - Beyond that the banks rise at `VALLEY_BANK` over the hills.
   - Distance to the route comes from a coarse precomputed distance grid (about 6 m cells, bilinear), not per-vertex curve queries, so generation stays fast.
3. **Cliff bands.**
   - Where a low-frequency "cliff" noise crosses a threshold, the ground steps up `CLIFF_RISE` (6–12 m, varied) over `CLIFF_WIDTH` (2–3 m). Cliff lines follow the noise contours, so they wind naturally.
   - A mask allows cliffs only near the field edges (but at least 6 m inside the fence line) and on hillsides at least `CLIFF_CLEAR` (20 m) from the route, never at a pad.
4. **Ravine.**
   - Over one stretch of the route, about 30–40 m long and centred near the middle (`RAVINE_FROM` / `RAVINE_TO` as route fractions), walls rise `RAVINE_RISE` (about 10 m), starting 6–9 m to either side of the path.
   - They fade in and out at the ends of the stretch. The path between them is the valley floor.
5. **Kept:** the house pad (flat, blended out), the flattening at the start and the exit, and a rim that rises beyond the fence.

**Mesh and normals.** `GROUND_CELL` becomes 1.5 m (about 55k vertices). Normals come from the height function's slope (central differences), not from summed face normals, so shading is smooth across cells. Clockwise winding, the snow depth skirt and the cut walls are unchanged.

**Collision.** The trimesh stays (about 110k triangles). If startup cost is too high, the plan may switch the collision to a heightmap shape, provided the stair-well cut still works.

## 2. Snow shader (`shaders/snow_ground.gdshader`)

- The lattice-aligned value noise for drift, clumps, grains and normal detail is replaced by noise that does not line up with the world axes: rotated, domain-warped sampling or a gradient noise. No 3 m period is visible.
- Steep ground: the rock blend uses triplanar projection, so faces are not stretched. Snow stays on flat tops and ledges (by the normal's upward component), and the flecks and crystals stay on snow only.
- The existing parameters (tint, shade, dirt, rock colour, snow depth) are kept.

## 3. Rock dressing (`Ground` or a small `Cliffs` builder)

- After the heights are built, cells steeper than about 55° are grouped into cliff runs.
- `SM_Env_Rock_Cliff_02` (24 × 10 × 12 m) is placed about every 14 m along each run. Each is turned to face outward along the downhill direction, scaled 0.6–1.2, and sunk so most of it sits inside the slope. Boulders (`Rock_01/02/05/08`) are scattered at cliff feet.
- Rock meshes are visual only. The steep ground blocks her, since slopes over `floor_max_angle` (45°) are walls to the character controller, so she cannot climb cliffs or stand inside rock.

## 4. Forest (`Flora`)

- **Mask.**
  - A low-frequency forest noise (about 90 m wavelength) makes woods of 40–70 m with clearings, weighted toward rising banks and cliff tops and feet.
  - It is zero within `FOREST_CLEAR` (about 12 m) of the route, within 25 m of reserved points (house, landmarks), on slopes over 35°, and within 6 m of the fence.
- **Placement.** A jittered grid at about 4.5 m, accepted by mask × density. Minimum spacing is 3.5 m (7 m around great trees).
- **Trees.**
  - The premium pines (`SM_MVV_Pine02`/`03`, 12–14 m tall), scale 0.9–1.4.
  - About 15% are great trees at scale 2.0–2.6.
  - Six to eight lone giants stand in clearings 20–60 m from the route, at least 30 m apart.
  - About 10% of ordinary trees are bare (`SM_Env_Pine_NoLeaves_01`), as now.
- **Drawing.** One `MultiMeshInstance3D` per mesh part per tree model, sharing the trees' transforms, so hundreds of trees cost a few draw calls.
- **Collision.** A trunk `CylinderShape3D` per tree on `StaticBody3D`, radius and height scaled with the tree. `tree_positions()` keeps reading trunk bodies, so the wildlife sounds keep working.
- **Undergrowth.**
  - The current set stays: bushes, grass, moss, boulders, snow mounds, deadfall.
  - It is placed by context: bushes and deadfall along forest edges, grass in clearings, mounds in the open, and none on cliff faces.
  - The horizon trees and mountains beyond the fence stay.
- **Lean graphics.** `Game.lean_graphics` keeps half the forest trees (great trees and giants are always kept) and half the undergrowth.

## 5. The editable-level snapshot

`Trail` generates everything, then `EditableLevel.apply` copies the saved snapshot over it by child order (meshes, collision, transforms), and frees unknown script-less nodes. Without care, the old ground mesh would overwrite the new terrain and the new instanced trees would be freed.

- `Ground.TERRAIN_REVISION` (new constant, starting at 2) is stored as metadata in the bake, like `House.LAYOUT_REVISION`.
- When the snapshot's terrain revision differs, `main.gd` keeps the newly generated route-derived nodes (`Trail.route_derived()`: Ground, Flora, landmarks) and the fence, instead of applying the snapshot to them.
- The house keeps its authored position, rotation and all interior edits; only its height is settled onto the new pad.
- After this lands, the existing non-destructive repack (`--repack-editor-level`) can store the new terrain in the snapshot, so the editor shows it and hand edits to trees persist again. That rewrites `scenes/editable_level.scn` and `scenes/generated/`, so it is run only with the user's go-ahead.
- **Accepted cost:** pines, rocks, landmarks or fence posts hand-moved in the editor are replaced by the new generator.

## 6. Tuning

Values live in `Tune`, grouped under `TERRAIN_*`, `CLIFF_*`, `RAVINE_*` and `FOREST_*`. Among them: `GROUND_CELL` (1.5), the valley half-width and bank rise, cliff rise, width and clearance, the ravine's span and rise, the forest clearance, spacing and density, the great-tree share and scale, the giant count, and the lean share.

## Verification

- **Terrain probe** (`tools/terrain_probe.tscn`, headless, loads `main.tscn`):
  - Walkable route: sampled every metre from start to exit, the along-route grade is at most 12% and the ground slope at the path is at most 25°.
  - No cliff (slope over 45°) within 12 m of the route.
  - The ravine: across its middle, the ground 10 m to each side is at least 6 m above the path.
  - Cliffs exist: at least 150 grid cells over 55° (about 340 m² of rock face), and at least 12 rock-cliff meshes are placed.
  - The house pad is flat (spread within 5 cm under the footprint).
  - Forest: the tree count is in range, there are no trees within `FOREST_CLEAR` of the route, no trees on slopes over 35°, at least the expected great trees, and 6–8 giants.
  - Lean graphics keeps about half the trees.
  - Ground generation takes under 1.5 s on this machine (reported, and checked against a budget).
- **Overview tool** (`tools/terrain_view.tscn`, needs a window): near, high and eye-level shots with a frame-rate reading, in full and lean graphics, into `build/terrain/`. Used for the before/after comparison of the tiles and to show the result.
- **Regressions:** `tools/traversal_probe.tscn` still reaches the exit, `tools/leap_probe.tscn` still passes, and a `RUN_CAPTURE` smoke shot looks normal.

## Risks

- **Generation time.** Four times the vertices, domain warping and rock and forest scans could make startup slow. The coarse distance grid and a time-budget check guard this; noise evaluation can be cached per vertex.
- **Steep collision.** A 10 m rise over 2–3 m on a 1.5 m grid gives long thin triangles. The character controller treats them as walls (good), but camera boom fitting near cliffs needs checking in play.
- **Fence on uneven ground.** The fence follows `height_at`; cliffs stay at least 6 m inside it, and the rim rises outside.
- **Draw distance and fog.** Very tall great trees may poke through the fog in ways that read oddly. The overview shots are where this gets judged.
