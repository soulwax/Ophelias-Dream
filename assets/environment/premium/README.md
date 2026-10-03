# Purchased vegetation

Copied from the owner's The-Quarantine-Unity project and purchased Desktop/Assets library with explicit authorization. These are proprietary assets, not CC0; original vendor licensing continues to apply. Do not redistribute this folder as an asset pack.

Packs: Rocket PAD GrassSet (Grass01b, Grass02a, MoorGrass01a, LadyFern01b), MVV BushesSet Bush03_B, and MVV PineTreeSet Pine02/Pine03. `provenance.json` records original absolute paths and SHA-256 hashes. No license documents were present in the selected pack directories.

Only LOD0 geometry and shared 2048-pixel textures are included. Godot generates mesh LODs during FBX import. The base color includes foliage opacity; OpenGL normal and ambient occlusion maps are connected by `scripts/world/premium_flora.gd`. Unreal UCX collision hulls are hidden; gameplay retains existing trunk colliders and route clearances.

Legacy prop names map to these assets at runtime so authored plant transforms remain valid. Saved old mesh/material descendants are ignored for migrated plants. The existing editor snapshot is retained because its outer scenes contain overrides of the old mesh hierarchy. Additional clustered grassland grows beside the route while keeping the path and landmark clearances open.
