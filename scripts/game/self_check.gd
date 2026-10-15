class_name SelfCheck
extends Node

## RUN_SELFCHECK=1 (with RUN_PLAY=1): once Ophelia's chapter is playing, report
## what an exported build actually has (where vendor assets resolve, which
## vendor models the woods placed, whether any model fell back to a box, and
## whether every runtime data file loads), then quit 0 if nothing is missing.
## Exported templates refuse a scene on the command line, so the probes cannot
## run there; this is the packaged counterpart (MASTERPLAN W04, W17, W18).

const DATA := [
	"res://assets/dialogue/dream.json",
	"res://assets/dialogue/lake.json",
	"res://assets/dialogue/meeting.json",
	"res://assets/errands/errands.json",
	"res://assets/audio/voice/lines.json",
	"res://assets/audio/voice/mathilda/lines.json",
	"res://assets/audio/voice/meeting/lines.json",
	"res://assets/audio/voice/meeting/timing.json",
	"res://assets/audio/voice/lake/lines.json",
]

var _frames := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_frames += 1
	var ready := Game.phase == Game.Phase.PLAYING and Game.trail != null and Game.trail.flora != null
	if not ready and _frames < 3000:
		return
	set_process(false)
	var failures := 0
	print("SELFCHECK exported=%s version=%s" % [OS.has_feature("template"), ProjectSettings.get_setting("application/config/version", "")])
	print("SELFCHECK vendor root: %s" % (VendorLoader.root() if not VendorLoader.root().is_empty() else "off"))
	for kind: String in VendorLoader.NATURE_MESHES:
		print("SELFCHECK vendor %s: %s" % [kind, "present" if VendorLoader.available(VendorLoader.nature_mesh(kind)) else "absent (fallback)"])
	if not ready:
		print("SELFCHECK FAIL the chapter never reached PLAYING")
		get_tree().quit(1)
		return
	var parts: Dictionary = Game.trail.flora.get("_parts")
	var vendor_models: PackedStringArray = []
	var boxes: PackedStringArray = []
	for model: String in parts:
		if VendorLoader.NATURE_MESHES.has(model):
			vendor_models.append(model)
		for part: Array in parts[model]:
			if part[0] is BoxMesh:
				boxes.append(model.get_file())
	print("SELFCHECK woods vendor models: %s" % (", ".join(vendor_models) if not vendor_models.is_empty() else "none"))
	if not boxes.is_empty():
		failures += 1
		print("SELFCHECK FAIL box fallbacks: %s" % ", ".join(boxes))
	for path: String in DATA:
		var text := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
		var parsed: Variant = JSON.parse_string(text) if not text.is_empty() else null
		if parsed == null:
			failures += 1
			print("SELFCHECK FAIL data missing or unreadable: %s" % path)
		else:
			print("SELFCHECK data ok: %s" % path)
	print("SELFCHECK %s (%d)" % ["PASS" if failures == 0 else "FAIL", failures])
	get_tree().quit(0 if failures == 0 else 1)
