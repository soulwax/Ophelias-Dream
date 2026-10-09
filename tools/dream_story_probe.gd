extends Node

const STORY := preload("res://scripts/world/dream_story.gd")
const EXPERIENCE := preload("res://scripts/world/dream_experience.gd")
const REFLECTION := preload("res://scripts/ui/dream_reflection.gd")
const MENU := preload("res://scripts/ui/dream_menu.gd")
const DREAM_ROUTE := preload("res://scripts/world/dream_route.gd")


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
	reflection.mathilda = false
	reflection.outcome = "unresolved"
	assert(reflection._reflection_text() == story["unresolved"]["ophelia"], "missing clues should have an unresolved Ophelia waking")
	reflection.mathilda = true
	reflection.outcome = "ruptured"
	assert(reflection._reflection_text() == story["ruptured"]["mathilda"], "a closed conversation should have a distinct Mathilda waking")
	reflection.outcome = "complete"
	assert(EXPERIENCE != null, "the playable dream scene script should parse")
	assert(DREAM_ROUTE != null, "the dream route event hook should parse without scene assets")
	assert(not STORY.has_branch("missing_branch"), "unknown saved choices should be discarded")
	var experience = EXPERIENCE.new()
	add_child(experience)
	experience._build_choices()
	assert(experience._choice_title.text.begins_with("MATHILDA ·"),
		"the in-world choice prompt should make it clear that Mathilda spoke first")
	assert(experience._choice_buttons.size() == story["branches"].size(),
		"the playable dream should create one choice for every authored branch")
	for index in range(story["branches"].size()):
		assert(experience._choice_buttons[index].text.ends_with(story["branches"][index]["label"]),
			"the playable dream should keep each authored response visible")
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
	experience._seen_story_cues = {"window": true, "sisters": true}
	experience._conversation_strain = 0
	assert(experience._ending_text() == story["ending"], "the warm window cue and one other event should complete the warning")
	Game.dream_mode = true
	Game.dream_memory = story["branches"][0]["id"]
	experience._show_standalone_waking()
	assert(experience._speech_sprite.visible, "Mathilda's final words should remain attached to her in the world")
	assert(experience._speaker_label.text == "MATHILDA", "the final warning should retain its speaker")
	assert(experience._caption.text == story["ending"], "standalone dream should hold the final warning")
	assert(experience._choice_title.text.contains("RETURN TO THE THRESHOLD"), "standalone dream should show its return action in the world")
	assert(Game.phase == Game.Phase.DIALOGUE, "the closing card should wait for the player's return")
	experience._seen_story_cues.clear()
	experience._conversation_strain = 0
	assert(experience._ending_text() == story["unresolved"]["response"], "missing the route clues should lead to the unresolved wakeup")
	experience._conversation_strain = 4
	assert(experience._ending_text() == story["ruptured"]["response"], "repeatedly pressing after repair chances should rupture the conversation")
	experience._conversation_strain = 2
	experience._repair_menu_attempts = 0
	experience._repair_menu_active = false
	experience._conversation_round = 1
	experience._answer_open = true
	experience._build_small_talk_choices()
	assert(experience._repair_menu_active and experience._choice_buttons.size() == story["repair"]["choices"].size(), "pressure should open the in-world repair dialogue")
	experience._choose_small_talk(0)
	assert(experience._conversation_strain == 0 and not experience._conversation_choice_advances, "a repair should restore trust and return to the interrupted topic")
	Game.dream_mode = false
	Game.dream_memory = ""
	Game.set_phase(Game.Phase.BOOT)
	await get_tree().process_frame
	print("Dream story data and runtime branches checked")
	experience.free()
	reflection.free()
	get_tree().quit()
