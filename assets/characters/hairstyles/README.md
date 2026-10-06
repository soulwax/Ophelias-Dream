# Hairstyle studies

Geometry variants derived from Styloo's CC0 elf. Preserve [original provenance/license](../styloo_elf/README.md). New procedural strand geometry was created for this project.

- Frost Bob: a shortened, gently flared silver bob, using Snowlight's palette.
- Ember Crown: swept-back auburn hair with a compact woven bun, using Ember's palette.
- Midnight Braids: tapered dark twin braids with small gold bindings, using Midnight's palette.

Original bones, hierarchy and rest transforms are preserved. New strands/ties have normalized head-bone weights: they follow head motion but do not simulate flexible hair. Reshaped original hair retains its UVs/materials; added strands use smooth grooved geometry and dedicated materials. Body/outfit geometry is unchanged.

Editable `.blend` sources live in `sources/`, excluded from Godot import by `.gdignore`. Rebuild intentionally replaces generated sources and GLBs:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/create_hair_variants.py
godot --headless --path . --import
```

Wrappers bind existing palette atlases. The gallery previews seven characters with twelve clips, idle defaults and X-only T pose. These are gallery studies; gameplay still uses the base elf.
