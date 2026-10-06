# First house asset batch

Imported locally from `C:\Users\soulwax\Downloads\requested_assets_and_more` on 2026-10-06 into the **Run Away** project at `F:\Workspace\run`.

## Used in the house

| Archive | Use | Preparation |
| --- | --- | --- |
| dauntless-flex-burn-wood-stove | Living-room hearth beneath the existing chimney | Preserve detailed iron, handles, logs and fire insert; normalize floor pivot; transparent glass; connect extension to the actual model's flue |
| gas-stove | Cooker in the north-wall kitchen run | Bind supplied base color, metallic, normal and roughness maps; preserve 0.49 Ã— 0.90 Ã— 0.56 m dimensions |
| bathroom-furniture-set-game-ready | Shower, washing machine, shelves and domestic accessories | Remove only the showroom floor surface; bind the two fixture material sets; the remaining assembly is 1.95 Ã— 2.38 Ã— 1.13 m and fits the planned bathroom |
| henrik-wool-rug | Woven mustard/grey accent in the living room | Remove the 4.45 m showroom floor; preserve the actual 2.40 Ã— 1.60 m rug and supplied weave texture |
| curtain | Linen beside the front living-room window | Correct its 33.52-unit export to a 1.62 m curtain height, retaining folds and panel proportions; place inside the wall |
| ikea_cabinet | Bedroom storage against the north wall | Remove the 95 m showroom floor; retain cabinet/shelves at 1.20 Ã— 1.80 Ã— 0.80 m |
| wooden_display_shelves_01 | Storage along the living-room perimeter | Preserve model/PBR textures and natural dimensions; use an independent simple collider |

The caged pendant is inspected and imported but not placed: the current domestic lighting already reads well, and this industrial fixture is a stronger candidate for a later cellar pass. The full-room interiors, painting collections, stylized classroom/Minecraft pieces and 4K grass are not imported into the game. They add unrelated style, large dependencies or duplicate existing scenery. The existing furniture and premium winter flora remain in place.

The compact sink cabinetry, fridge, bathroom basin/toilet and boot bench are original geometry fitted around the imported models. They can be upgraded with suitable later assets without reopening the structural plan. No extra fire recording was supplied; the stove is visually lit, and existing recorded storm/room/haunting audio remains unchanged. A local recorded wood-fire loop is still a useful future addition.

## Structure and integration

The 2.1 Ã— 3.4 m bathroom/laundry bay is implemented at the blueprint coordinates, with its own door and upstairs room volume. The north-wall kitchen, stove, bedroom storage and entry bench avoid the central routes. Door sweep checks exposed a collision with the first basin position; both sanitary fixtures moved deeper into the room to preserve the full leaf sweep.

House layout revision 4 activates the existing migration path so an older editable snapshot cannot restore the old house branch over these fixtures. The cellar geometry, world route, bedside note and storm systems are retained. This does not rewrite/repack the owner's editable scene on disk; subsequent editor repacks use the established project workflow.

Runtime composition is in `scripts/house/domestic.gd`, called by `House.add_authoring()`. The detailed meshes are visual only; simple blockers and tagged floor materials serve player/camera collision and footsteps. Source downloads and derived scene resources are ignored locally, with primitive fallbacks for missing source files.

## Provenance and reproducibility

`requested_assets_manifest.json` inventories all 22 archives, selected models, hashes, imported files and included licenses. Downloads with no license text stay local and have no assumed source-redistribution permission.

Attribution for included CC BY 4.0 models:

- This work is based on [Curtain](https://sketchfab.com/3d-models/curtain-cb07918102ca40f9b0a4cc6eb20a8aa1) by [lizhou ding](https://sketchfab.com/vancchino), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Changes: unit/pivot correction and scene placement.
- This work is based on [Ikea Cabinet](https://sketchfab.com/3d-models/ikea-cabinet-6a3a2a19a048465a90fe97e2556b2996) by [der_typ](https://sketchfab.com/der_typ), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). Changes: remove showroom floor, normalize pivot and tune material tint.

Retain these credits in distributed game credits when shipping those models. Existing Poly Haven licensing/provenance stays intact.

Recreate the local imports from the repository root:

```powershell
python tools/import_requested_house.py
godot-mono --headless --path . --editor --import --quit
godot-mono --headless --path . --script tools/curate_house_assets.gd
```

The importer inspects paths before extraction and records hashes; it never modifies the original ZIPs. Curating preserves source geometry/textures and writes selected derivatives into the ignored house directory.

## Validation

The existing house-space and note-access probes pass after the additions: default spawn, original upstairs doors, kitchen/back-hall connection, cellar descent, bedside note and all five field pages.

`tools/house_domestic_probe.tscn` checks snapshot migration, seven curated visuals, bathroom identification, actual hinged door clearance, player capsule space and camera sphere sweeps. Rendered views of the living room, kitchen, bedroom and bathroom are saved to ignored `build/house-batch1-*.png` during `--capture` runs. Run the final probe again after future model or placement changes.
