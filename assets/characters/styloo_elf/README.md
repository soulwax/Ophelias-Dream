# Styloo elf

Source: `thecompanycharactersStyloo/glb/elf.glb` by Styloo ([creator page](https://styloo.itch.io/)). The included `LICENSE.txt` states the pack is CC0.

`elf.glb` is the prepared model. `tools/prepare_elf.py <original-elf.glb>` removes bow and arrow triangles while keeping the elf's clothing, materials, skin, and skeleton. Godot extracts the two material textures beside the GLB on import.

`elf_animations.res` contains movement clips baked onto this skeleton. Rebuild it with `godot --headless --path . -s tools/retarget_elf.gd`; that tool uses the hunter's shared Quaternius animation source. Run `godot --headless --path . --import` after changing the GLB.
