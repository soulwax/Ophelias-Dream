# Mathilda palette studies

Three derived appearance variants of Styloo's prepared CC0 elf. Geometry, UVs, normals, skeleton and weights are reused from `../styloo_elf/elf.glb`; no new outfit geometry or animation is included. Preserve the original [provenance and license](../styloo_elf/README.md).

- **Snowlight:** silver hair, blue eyes, blue clothing, silver-toned trim.
- **Ember:** auburn hair, amber eyes, burgundy clothing, original gold trim.
- **Midnight:** dark hair, violet eyes, teal clothing, original gold trim.

Each wrapper scene duplicates the original surface materials and binds its own two external 2048×2048 atlases. Reimporting the base GLB therefore does not regenerate the variant textures. The skin, pupils, sclera, leather and painted detail are preserved outside the selected masks. Both eyes share the original wrapped UV region.

Rebuild from the repository root with installed Blender and NumPy:

```powershell
blender --background --factory-startup --python-exit-code 1 --python tools/create_character_variants.py
godot --headless --path . --import
```

The generator identifies connected hair components from deformation weights, rasterizes their wrapped UV triangles, and selects coloured iris pixels inside the eye geometry mask. Clothing recolours select the green regions of the clothing-only atlas. It preserves alpha and shading; `palettes.json` records settings and mask counts. Rebuilding intentionally replaces these derived PNGs. Edit the generator's palette values for further studies or retain a new named variant.
