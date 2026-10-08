# Scandinavian home asset brief

Target project: `F:\Workspace\run`. Requested 2026-10-06.

The game already has scanned Poly Haven furniture, premium pine/ground vegetation, and recorded winter-weather audio. Keep its storm/shelter filtering, window whistles, room/cellar reverb, haunted cellar, bedside page, door dynamics, and third-person camera contract. The earlier isolated house experiment in Darkfloor is not the target game's house and should not replace these systems.

## Download format

Choose **glTF** for Poly Haven models. Keep each `.gltf` together with its `.bin` and the full `textures/` folder. A self-contained `.glb` is equally convenient when another supplier offers it. Zip these files together for transfer; do not provide the model file alone. Prefer 1K textures for small props and 2K for hero furniture/stove/kitchen surfaces. OpenGL normal maps, base color, roughness and metallic or packed ARM/ORM maps are useful. Keep the original filenames, asset URL, author and license.

Godot supports glTF directly; Blender source is optional and useful for later mesh edits, but not required for importing the house. FBX is usable when it is the only supplied format; USD is not the preferred delivery format here. Source: [Godot supported 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html).

## Already available: do not buy duplicates

- Sofa 02, Arm Chair 01, Throw Pillows 01.
- Vintage Day Bed, painted nightstand, wicker basket.
- Wooden dining table/chairs, Round Wooden Table 02, bookshelf, tea set, lantern.
- Weathered timber siding, plaster, floor tiles, roof slate materials.
- Premium pines and winter flora.
- Recorded storm, gusts, window wind, wood/stone/snow steps, house creaks and door audio.

These Poly Haven assets use [CC0](https://polyhaven.com/license); the project's existing provenance records remain authoritative. No new furniture needs to be downloaded merely because it appeared in the earlier Darkfloor preview.

## Priority 1: changes that make it a believable home

| Needed | Specification | Placement / role |
| --- | --- | --- |
| Wood-burning stove | Freestanding Scandinavian black iron/steel stove, glass front, flue; separate door/flame insert ideal; roughly 0.5–0.8 m wide | Warm visual/acoustic anchor in the living room; keep clear of central circulation |
| Kitchen modules | Plain birch/oak or warm-white base cabinets, worktop, sink + tap, hob/oven, fridge; separate modules preferred | Replace the cabinet-like placeholder with a functional cooking zone beside existing dining furniture |
| Bathroom fittings | Compact toilet, basin/vanity, shower tray + glass or curtain, mirror | Give the domestic plan a real washroom without relocating the cellar access |

Start with these three groups. GLB/glTF with PBR textures and sensible human scale is more useful than a large decorative house pack. Avoid models with an entire baked room attached. Keep original pack materials available so finishes can be matched rather than painted over indiscriminately.

## Priority 2: comfort and practical daily life

| Needed | Specification |
| --- | --- |
| Textile rug | Woven wool/flatweave, oat/grey/rust accents, modest Scandinavian pattern; texture set or model |
| Linen curtains | Simple hanging fabric, ideally separate left/right panels and rod; neutral cream |
| Wardrobe and entry storage | Plain wood wardrobe, boot/drying bench, coat hooks; modular pieces |
| Washing machine | One ordinary domestic machine; dryer optional, not necessary |
| Bedding | Natural linen duvet/blanket and pillows for the existing bed; a simple timber double bed only if changing the bedroom to a double |
| Domestic clutter | Boots, wool coats, folded towels, firewood basket/logs, a few books and mugs; restrained rather than cluttering routes |

## Optional material upgrades

- Pale spruce floorboards or birch/oak joinery texture set.
- Dark stained vertical timber cladding.
- Standing-seam metal roofing if replacing the existing slate direction.
- Slate hearth surface and woven wool/linen material sets.

Tileable textures at 2K are sufficient starting points. Existing materials already cover many of these roles, so these are refinements rather than blockers.

## Optional audio

A clean, licensed wood-fire recording: 30–60 seconds, no music/voices, WAV preferred, no baked room reverb, suitable for a seamless local loop. A restrained stove-door or log-loading clip is useful but optional. Keep the existing winter storm; do not purchase another generic rain bed to replace it.

## Integration rules

Blueprint first: the companion `blueprint.svg` records the current upstairs arrangement and the reserved stair corridor, not a new structural implementation. Extend the normalized plan with bathroom/service zoning before adding their walls. Preserve the current footprint and authored world placement unless an expanded domestic plan requires a measured change.

Keep furniture at verified human scale. Check the 0.68 m player capsule, indoor camera arm, door sweeps, bedside note access and descent to the cellar with the existing `house_space_probe` and `note_access_probe`. Fit hero pieces against measured routes and reserve wall-adjacent areas for new fixtures.

Use `HouseKit.prop` and the existing provenance library. Any new hearth audio belongs on the existing house/effects routing, respects mute/phase controls, and remains spatially local. New fixtures must survive editable-level snapshot application/repacking. Do not replace existing storm buses or remove the haunted cellar to make room for a showcase house.
