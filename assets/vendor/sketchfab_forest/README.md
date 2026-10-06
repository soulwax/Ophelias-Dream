# Fir forest in the mountains (Sketchfab)

The green biome's trees and undergrowth come from this pack.

| | |
| --- | --- |
| Original title | лес пихты в горах на скетч ("fir forest in the mountains") |
| Source | Sketchfab. **Model page URL: to be filled in** |
| Author | **To be filled in** |
| Licence | Sketchfab Standard licence, free download (<https://sketchfab.com/licenses>) |
| Received | `the-landscape-is-a-forest-in-the-mountains.zip`, 2026-10-06 |

## Licence terms that matter here

- Use in this game, including modified, is allowed, commercial or not.
- No redistribution of the licensed material as stand-alone files. The pieces ship inside the game; the raw files in `source/` and `textures/` should not be offered on their own. If this repository is public, decide whether these files belong in it.
- Credit the provider where other licensed material is credited. The Esc menu's credits carry a line for this pack.

## What is here

- `source/forest_pack.fbx`: the original scene (renamed from `лес пихты в горах на скетч.fbx`). A hand-made diorama about 35 × 24 m with 395 meshes and 19.4k triangles.
- `textures/`: the pack's 14 textures, unchanged.
- `meshes/`: the pieces the game plants, written by `tools/import_forest_pack.gd`.

## Changes made

`tools/import_forest_pack.gd` takes ten meshes out of the scene: five tall spruces (`spruce_a..e`, 4–11 m), two crossed-card trees, two sizes of the small card fir (`card_fir`, `card_bush`) and a grass card. For each it:
- bakes the mesh's place in the scene into its vertices
- moves it so its base sits at the origin
- gives it its own material copies: surfaces with alpha are alpha-cut (0.4) and double-sided, with roughness 0.9 and no metal

The diorama's ground mesh and its baked texture are not used.

Rebuild:

```powershell
godot-mono --headless --path . -s tools/import_forest_pack.gd
godot-mono --headless --path . -s tools/forest_pack_probe.gd
```
