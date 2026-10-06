extends SceneTree

# The forest pack's split pieces: each mesh exists, stands on its base at the
# origin, and its card surfaces are alpha-cut and double-sided.
#   godot-mono --headless --path . -s tools/forest_pack_probe.gd
# Exits 1 on any failure.

const DIR := "res://assets/vendor/sketchfab_forest/meshes/"
const PIECES := ["spruce_a", "spruce_b", "spruce_c", "spruce_d", "spruce_e",
	"card_tree_a", "card_tree_b", "card_fir", "card_bush", "grass_card"]

var _failed := 0


func _initialize() -> void:
	for piece: String in PIECES:
		var path := DIR + piece + ".res"
		var mesh := load(path) as Mesh if ResourceLoader.exists(path) else null
		_check(mesh != null, "%s exists" % piece)
		if mesh == null:
			continue
		var box := mesh.get_aabb()
		_check(absf(box.position.y) < 0.05, "%s stands on its base (bottom %.2f m)" % [piece, box.position.y])
		var centre := box.get_center()
		_check(Vector2(centre.x, centre.z).length() < 0.3, "%s is centred (%.2f m off)" % [piece, Vector2(centre.x, centre.z).length()])
		var cards := 0
		for surface in mesh.get_surface_count():
			var material := mesh.surface_get_material(surface) as BaseMaterial3D
			if material and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				cards += 1
				_check(material.cull_mode == BaseMaterial3D.CULL_DISABLED, "%s surface %d is double-sided" % [piece, surface])
		_check(cards > 0, "%s has alpha-cut card surfaces (%d)" % [piece, cards])
	print("Forest pack probe: %s" % ("PASS" if _failed == 0 else "%d FAILED" % _failed))
	quit(1 if _failed > 0 else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		print("  FAIL " + label)
		_failed += 1
