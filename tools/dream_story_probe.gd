extends Node

const STORY := preload("res://scripts/world/dream_story.gd")
const EXPERIENCE := preload("res://scripts/world/dream_experience.gd")
const REFLECTION := preload("res://scripts/ui/dream_reflection.gd")
const MENU := preload("res://scripts/ui/dream_menu.gd")


func _ready() -> void:
	var story := STORY.load_data()
	assert(not story.is_empty(), "dream story data should load")
	assert(story["beats"].size() == 4, "four path beats must keep their movement pacing")
	assert(story["branches"].size() >= 2, "dream must offer a branch")
	var seen := {}
	for branch in story["branches"]:
		assert(not seen.has(branch["id"]), "branch ids must be unique")
		seen[branch["id"]] = true
		assert(STORY.has_branch(branch["id"]), "saved branch ids must be recognized by Game")
		assert(not STORY.branch_for(story, branch["id"])["ophelia"].is_empty(), "Ophelia needs a waking echo")
		assert(not STORY.branch_for(story, branch["id"])["mathilda"].is_empty(), "Mathilda needs a waking echo")
	var reflection = REFLECTION.new()
	reflection.memory = "name"
	assert(reflection._reflection_text() == STORY.branch_for(story, "name")["ophelia"], "Ophelia should wake into her branch text")
	reflection.mathilda = true
	assert(reflection._reflection_text() == STORY.branch_for(story, "name")["mathilda"], "Mathilda should wake into her branch text")
	assert(EXPERIENCE != null, "the playable dream scene script should parse")
	assert(not STORY.has_branch("missing_branch"), "unknown saved choices should be discarded")
	var experience = EXPERIENCE.new()
	add_child(experience)
	experience._build_choices()
	assert(experience._choice_panel.get_child(0).get_child_count() == story["branches"].size() + 1,
		"the playable dream should display every authored branch")
	var menu = MENU.new()
	add_child(menu)
	assert(menu._buttons.size() == 6, "the main menu should offer three modes, settings, credits, and quit")
	assert((menu._buttons[0] as Button).text.ends_with("DREAM"), "the dream must be the first mode")
	assert((menu._buttons[3] as Button).text.ends_with("SETTINGS"), "settings should be part of the title menu")
	var first_cell := (menu._buttons[0] as Button).get_parent() as VBoxContainer
	assert((first_cell.get_child(0) as Label).text == "夢へ入る", "each title action should have its Japanese translation above it")
	(menu._buttons[0] as Button).grab_focus()
	assert((menu._buttons[0] as Button).text.begins_with("[ "), "the selected title action should be bracketed")
	menu._choose("SETTINGS")
	assert(menu._settings_terminal.is_title_settings_open(), "settings should open the terminal without leaving the title phase")
	assert(menu._settings_terminal._crt.z_index < menu._settings_terminal._frame.z_index,
		"the CRT glass should render behind readable settings controls")
	assert(menu._settings_terminal._frame.mouse_filter == Control.MOUSE_FILTER_PASS,
		"the settings frame should pass mouse input to its controls")
	await get_tree().create_timer(0.7).timeout
	assert(is_equal_approx(menu._settings_terminal._frame.scale.y, 1.0), "the terminal should open in ordered stages")
	var invert_y: Button = menu._settings_terminal._fields["invert_y"].focus
	var original_invert_y: bool = Game.settings.invert_y
	invert_y.pressed.emit()
	assert(Game.settings.invert_y != original_invert_y, "title settings should apply a changed value")
	invert_y.pressed.emit()
	assert(Game.settings.invert_y == original_invert_y, "title settings should let the user restore a changed value")
	menu._settings_terminal._title_dirty = false
	var close_started := Time.get_ticks_msec()
	var close_event := InputEventAction.new()
	close_event.action = "pause"
	close_event.pressed = true
	menu._settings_terminal._input(close_event)
	await get_tree().create_timer(0.35).timeout
	assert(Time.get_ticks_msec() - close_started < 1000, "the terminal should deconstruct in under a second")
	assert(not menu._settings_terminal.visible, "the terminal should return to the main menu")
	menu._stop_music()
	menu.free()
	Game.dream_mode = true
	Game.dream_memory = story["branches"][0]["id"]
	experience._show_standalone_waking()
	var waking_box := experience._choice_panel.get_child(0) as VBoxContainer
	assert(waking_box.get_child_count() == 3, "standalone dream should close on one image and a return action")
	assert((waking_box.get_child(0) as Label).text == "THE LIGHT REMAINS", "standalone dream should keep its final image")
	assert((waking_box.get_child(1) as Label).text == story["arrival"], "standalone dream should not reveal future chapter echoes")
	assert((waking_box.get_child(2) as Button).text == "Return to the threshold", "standalone dream should offer a return")
	assert(Game.phase == Game.Phase.DIALOGUE, "the closing card should wait for the player's return")
	Game.dream_mode = false
	Game.dream_memory = ""
	Game.set_phase(Game.Phase.BOOT)
	await get_tree().process_frame
	print("Dream story data and runtime branches checked")
	experience.free()
	reflection.free()
	get_tree().quit()
