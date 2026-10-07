extends Node
var ticks := 0
func _ready() -> void:
 Game.mathilda_pov = true
 add_child(load("res://scenes/main.tscn").instantiate())
func _process(_delta: float) -> void:
 ticks += 1
 if ticks != 10: return
 var chapter = Game.voice
 assert(chapter != null and Game.phase == Game.Phase.PLAYING)
 assert(chapter._objects.size() == 5)
 assert(not Game.player.visual.visible)
 assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
 for entries in chapter._lines.values():
  for line in entries:
   assert(chapter._clip(line) != null)
 assert(Game.player.global_position.distance_to(chapter._camp) < 8.0)
 var camp := get_tree().get_first_node_in_group("camp") as Camp
 assert(camp != null and not camp.tent_mended, "the guy-line starts loose")
 for i in 5:
  Game.player.global_position = chapter._objects[i]
  var event := InputEventAction.new()
  event.action = "interact"
  event.pressed = true
  chapter._unhandled_input(event)
 assert(chapter._inspected.size() == 5, "cups, gloves, note, fire, mend")
 assert(camp.tent_mended, "mending the guy-line actually mends it")
 assert(chapter._found_photo and chapter._mathilda_seen.has("photograph"), "the photograph surfaces once everything else is done")
 Game.player.global_position = chapter._camp
 var event := InputEventAction.new()
 event.action = "interact"
 event.pressed = true
 chapter._unhandled_input(event)
 assert(Game.dialogue._active and Game.phase == Game.Phase.DIALOGUE)
 assert(chapter._lines.has("house") and chapter._lines.has("road"))
 assert(chapter._lines.has("fire") and chapter._lines.has("mend") and chapter._lines.has("photograph"))
 print("MATHILDA PASS: spawn, five tasks, the photograph, choice, separate script")
 get_tree().quit()
