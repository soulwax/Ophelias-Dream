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
 assert(chapter._objects.size() == 3)
 assert(not Game.player.visual.visible)
 assert(not AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")))
 for entries in chapter._lines.values():
  for line in entries:
   assert(chapter._clip(line) != null)
 assert(Game.player.global_position.distance_to(chapter._camp) < 8.0)
 for i in 3:
  Game.player.global_position = chapter._objects[i]
  var event := InputEventAction.new()
  event.action = "interact"
  event.pressed = true
  chapter._unhandled_input(event)
 assert(chapter._inspected.size() == 3)
 Game.player.global_position = chapter._camp
 var event := InputEventAction.new()
 event.action = "interact"
 event.pressed = true
 chapter._unhandled_input(event)
 assert(Game.dialogue._active and Game.phase == Game.Phase.DIALOGUE)
 assert(chapter._lines.has("house") and chapter._lines.has("road"))
 print("MATHILDA PASS: spawn, three objects, choice, separate script")
 get_tree().quit()
