extends Node

# MASTERPLAN W04: VendorLoader's one path contract and the fallbacks that rely
# on it. Run twice: as is (the pack present in build/vendor/) and with
# RUN_VENDOR=off (as an exported build without a pack). Quits 1 on any failure.
#   godot --headless --path . tools/vendor_probe.tscn
#   RUN_VENDOR=off godot --headless --path . tools/vendor_probe.tscn

const FLOWERS := "requested_nature/flowers/SM_MVV_Flowers_01_B_c1_LOD0.fbx"
const VENDOR_KINDS := ["flowers", "bush", "grass"]

var _failures := 0


func _ready() -> void:
	OS.set_environment("RUN_PLAY", "1")
	RunSave.set_process(false)
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	print(("PASS " if ok else "FAIL ") + what)
	if not ok:
		_failures += 1


func _run() -> void:
	var off := OS.get_environment("RUN_VENDOR") == "off"
	print("vendor: ", "off" if off else VendorLoader.root())
	_contract(off)
	if not off:
		_loading()
	await _flora(off)
	print("Vendor probe: %s (%d)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)


func _contract(off: bool) -> void:
	if off:
		_check(VendorLoader.root().is_empty() and not VendorLoader.available(FLOWERS), "RUN_VENDOR=off makes nothing available")
		_check(VendorLoader.load_model(FLOWERS) == null and VendorLoader.spawn_nature_prop("flowers") == null, "and loads nothing")
		return
	if OS.has_feature("template"):
		_check(VendorLoader.root() == OS.get_executable_path().get_base_dir().path_join("vendor"), "exported, the root is vendor/ beside the executable")
	else:
		_check(VendorLoader.root() == ProjectSettings.globalize_path("res://build/vendor"), "developing, the root is build/vendor/")
	_check(VendorLoader.resolve("build/vendor/" + FLOWERS) == VendorLoader.resolve(FLOWERS), "the older build/vendor/ prefix resolves the same")
	_check(VendorLoader.available(FLOWERS), "the flowers pack is present for this run")
	_check(not VendorLoader.available("requested_nature/flowers/missing.fbx"), "a missing file is not available")
	_check(VendorLoader.load_model("requested_nature/flowers/missing.fbx") == null, "and loads as null")
	# A malformed file next to the real ones fails safely.
	var bad_dir := VendorLoader.resolve("_probe")
	DirAccess.make_dir_recursive_absolute(bad_dir)
	var bad := FileAccess.open(bad_dir.path_join("broken.fbx"), FileAccess.WRITE)
	bad.store_string("not an fbx")
	bad.close()
	_check(VendorLoader.load_model("_probe/broken.fbx") == null, "a malformed model loads as null")
	DirAccess.remove_absolute(bad_dir.path_join("broken.fbx"))
	DirAccess.remove_absolute(bad_dir)


func _loading() -> void:
	var first := VendorLoader.spawn_nature_prop("flowers")
	var second := VendorLoader.spawn_nature_prop("flowers")
	_check(first != null and second != null, "a nature prop spawns twice from the cache")
	if first == null or second == null:
		return
	var first_mesh := first.find_children("*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool: return (m as MeshInstance3D).visible)
	var second_mesh := second.find_children("*", "MeshInstance3D", true, false).filter(func(m: Node) -> bool: return (m as MeshInstance3D).visible)
	var first_mat := (first_mesh[0] as MeshInstance3D).material_override as ShaderMaterial
	var second_mat := (second_mesh[0] as MeshInstance3D).material_override as ShaderMaterial
	_check(first_mat != null and first_mat != second_mat, "each spawn gets its own material")
	_check((first_mesh[0] as MeshInstance3D).mesh == (second_mesh[0] as MeshInstance3D).mesh, "and shares the mesh")
	var albedo := first_mat.get_shader_parameter("albedo_texture") as ImageTexture
	_check(albedo != null and albedo.get_image().has_mipmaps(), "vendor textures carry mipmaps")
	var box := AABB()
	for index in first_mesh.size():
		var mesh_box := (first_mesh[index] as MeshInstance3D).transform * (first_mesh[index] as MeshInstance3D).get_aabb()
		box = mesh_box if index == 0 else box.merge(mesh_box)
	_check(box.size.x > 0.3 and box.size.x < 5.0 and box.size.y < 3.0, "the flower patch is in metres (%.2f x %.2f x %.2f)" % [box.size.x, box.size.y, box.size.z])
	first.free()
	second.free()
	_check(VendorLoader.spawn_nature_prop("flowers") != null, "the cached model survives its spawns being freed")


func _flora(off: bool) -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(main)
	for frame in 600:
		await get_tree().process_frame
		if Game.trail and Game.trail.get("flora") and Game.phase == Game.Phase.PLAYING:
			break
	var flora: Node = main.find_child("Flora", true, false)
	_check(flora != null, "the woods are built")
	if flora == null:
		return
	# _batches is cleared once drawn; _parts keeps every model that was drawn.
	var parts: Dictionary = flora.get("_parts")
	var vendor_models: PackedStringArray = []
	for model: String in parts:
		if model in VENDOR_KINDS:
			vendor_models.append(model)
	if off:
		_check(vendor_models.is_empty(), "without the pack no vendor model is placed (%s)" % ", ".join(vendor_models))
	else:
		_check(not vendor_models.is_empty(), "with the pack the vendor undergrowth is placed (%s)" % ", ".join(vendor_models))
	var boxes: PackedStringArray = []
	for model: String in parts:
		for part: Array in parts[model]:
			if part[0] is BoxMesh:
				boxes.append(model.get_file())
	_check(boxes.is_empty(), "no placed model falls back to a box" + ("" if boxes.is_empty() else " (%s)" % ", ".join(boxes)))
	print("flora built in %d ms (cache %s)" % [int(flora.get("build_msec")), "hit" if flora.get("cache_hit") else "miss"])
