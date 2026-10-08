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
	assert(menu._buttons.size() == 5, "the main menu should offer three modes, credits, and quit")
	assert((menu._buttons[0] as Button).text.replace(" ", "") == "DREAM", "the dream must be the first mode")
	menu._stop_music()
	menu.queue_free()
	Game.dream_mode = true
	Game.dream_memory = story["branches"][0]["id"]
	experience._show_standalone_waking()
	var waking_box := experience._choice_panel.get_child(0) as VBoxContainer
	assert(waking_box.get_child_count() == 4, "standalone dream should show both echoes and a return action")
	assert((waking_box.get_child(1) as Label).text.ends_with(story["branches"][0]["ophelia"]), "standalone dream should show Ophelia's echo")
	assert((waking_box.get_child(2) as Label).text.ends_with(story["branches"][0]["mathilda"]), "standalone dream should show Mathilda's echo")
	assert(Game.phase == Game.Phase.DIALOGUE, "the waking card should lock dream movement")
	Game.dream_mode = false
	Game.dream_memory = ""
	Game.set_phase(Game.Phase.BOOT)
	await get_tree().process_frame
	print("Dream story data and runtime branches checked")
	experience.free()
	reflection.free()
	get_tree().quit()
