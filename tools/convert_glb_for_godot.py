"""Re-export a self-contained GLB with Blender's glTF importer/exporter.

Use when a valid source GLB uses an extension unsupported by the project's
Godot importer. Blender is supplied by the asset workstation, not bundled in
the game. Textures and scene transforms are embedded in the output GLB.

Run from Blender:
  blender --background --python tools/convert_glb_for_godot.py -- input.glb output.glb
"""

from __future__ import annotations

import sys

import bpy


def main() -> None:
	arguments = sys.argv[sys.argv.index("--") + 1 :]
	if len(arguments) != 2:
		raise SystemExit("Expected input and output GLB paths after --")

	source_path, output_path = arguments
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.object.delete(use_global=False)
	bpy.ops.import_scene.gltf(filepath=source_path)
	bpy.ops.object.select_all(action="SELECT")
	bpy.ops.export_scene.gltf(
		filepath=output_path,
		export_format="GLB",
		use_selection=True,
		export_apply=True,
		export_yup=True,
		export_image_format="AUTO",
	)


if __name__ == "__main__":
	main()
