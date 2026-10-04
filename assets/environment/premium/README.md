# Purchased vegetation

Copied from the owner's The-Quarantine-Unity project and purchased Desktop/Assets library with explicit authorization. These are proprietary assets, not CC0; original vendor licensing continues to apply. Do not redistribute this folder as an asset pack.

Packs: Rocket PAD GrassSet (Grass01b, Grass02a, MoorGrass01a, LadyFern01b), MVV BushesSet Bush03_B, and MVV PineTreeSet Pine02/Pine03. `provenance.json` records original absolute paths and SHA-256 hashes. No license documents were present in the selected pack directories.

Trail props also include Rocket MVV LogPile and the `painted_wooden_bench` FBX/PBR textures from the owner's Unity `Art/Sourced` directory. Their original paths and hashes are recorded in the same manifest. Both are reusable Godot scene assets with external material resources, and the corresponding bench and wood-pile instances have been updated in the saved landmark, trail, and level scenes.

Only LOD0 geometry and shared 2048-pixel textures are included. Godot generates mesh LODs during FBX import. Reusable scenes in `scenes/` reference the original FBX imports, with shared Godot materials in `materials/`. The base color includes foliage opacity; OpenGL normal and ambient occlusion maps are connected in those materials. Unreal UCX collision hulls are hidden; gameplay retains existing trunk colliders and route clearances.

The saved editable level contains 257 upgraded vegetation instances and a reusable `grassland.tscn` with 224 saved patch placements. Legacy prop names map to the same scene assets at runtime so authored plant transforms remain valid. Old mesh overrides were removed from the flora, trail, and level snapshots together. Grassland placements and materials are stored as Godot resources, rather than generated during play. Edit the scenes directly in Godot; grassland placements are specific to the current route and terrain and need adjustment if those change.
