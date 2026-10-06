# Character creator assets

Modular assets derived from Styloo's CC0 elf; preserve [original provenance and license](../styloo_elf/README.md). New garment/trim meshes are project-authored.

Outfits:

- **Wayfarer:** fitted winter bodysuit with dark flank panels and a close collar.
- **Nocturne:** high-neck catsuit with a contrasting centre panel and waist/collar piping.
- **Trailwarden:** fitted ranger suit with leather panels, a shaped waist and a slim belt.

The original elf outfit is also available. All four hair modules can be combined with every outfit. Original skeleton/bind transforms are retained; hair meshes bind to the assembled character's skeleton. The fitted suits reuse actual body contours and weights, with a shaped waist bridge over the vendor model's missing abdomen and fitted sleeves/collars. The original dress, bracers, strap and quiver are removed; boots are retained. Transfer references are excluded from exports.

New outfit meshes have basic UVs and cloth/trim/leather regions. Smooth shader masks place contrasting fitted panels without coarse polygon boundaries; Nocturne uses a softer satin finish. Colour controls use independent overrides, while a geometry-derived atlas mask isolates hair and irises. These are stylized outfit studies, without cloth simulation or hair dynamics. Motion preview uses raw imported clips rather than gameplay's procedural layers.

Editable outfit `.blend` files are in `sources/`, excluded from Godot scanning. Generate all creator assets:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/create_creator_assets.py
godot --headless --path . --import
```

Use `-- --outfits-only` after the Python script to rebuild just outfit assets. Rebuilding replaces derived sources/GLBs. Hair geometry comes from the existing hairstyle studies, including their source limitations.

The studio saves named configurations as JSON under Godot's `user://characters/`, loads them into the collection on startup, and keeps the existing gameplay character separate. Save files describe component IDs and colour values; they are not standalone mesh exports. Feminine preview clips retain their CC BY-NC licensing constraints.
