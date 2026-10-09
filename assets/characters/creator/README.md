# Character creator assets

Modular hair and the original costume derived from Styloo's CC0 elf. Preserve [original provenance and license](../styloo_elf/README.md).

The procedural Wayfarer, Nocturne and Trailwarden outfits have been discarded, together with their sources and generator code. The creator currently supports the original costume, five hairstyles, independent hair/eye/cloth/trim colours, animation preview and local saved designs. Enhanced Snow Bob layers skinned glacial inlays and a small crystal pin onto the Frost Bob while keeping its original palette controls.

Named configurations are saved under Godot's `user://characters/`. Old outfit IDs fall back to the original costume without rewriting saved files. Hair, names and colours are retained. Configurations identify components and colours; they are not standalone mesh exports. Gameplay still uses the original player.

Rebuild masks, modular hair and the original costume:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/create_creator_assets.py
godot --headless --path . --import
```

Use `-- --original-outfit-only` to rebuild the original costume module alone. The generator cannot recreate the discarded garments.

The new tailoring strategy and authoring foundation are documented in [GARMENT_WORKFLOW.md](../../../docs/GARMENT_WORKFLOW.md). The workbench contains the untouched vendor reference and separated working skin/costume/hair; it does not claim the incomplete body has been rebuilt. New garments enter the creator after topology, fit and real-motion review.

Build only the separate Enhanced Snow Bob component and its editable source:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/create_snowbob.py
godot --headless --path . --import
```

The source blend retains an untouched Frost Bob reference collection. The exported module reuses the original elf skeleton and rigid head weights; the Frost Bob asset itself is unchanged.
