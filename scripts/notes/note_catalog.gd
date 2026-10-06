class_name NoteCatalog
extends RefCounted

# Mathilda's pages: five on the trail in route order, then the two in the
# house. {word} marks a smudge that stays blotted until it is deciphered in
# the journal. Each smudge lists its readings (the right one first) and the
# key that makes it legible: page:<title> read, place:<Voice place> visited,
# or event:<call|echo> heard. Lowercase text is the hand going wrong.
# Story: docs/MATHILDA_STORY.md

# The page that asks her to stop looking. The road remembers it.
const LAST_TITLE := "don't turn around"
const EVENTS := ["call", "echo"]


static func all() -> Array[NoteEntry]:
	var notes: Array[NoteEntry] = [
		_make(
			"from the pack",
			"Packed for {two}: two cups, one candle (we share), the map, the gloves you knitted me that I never wear. I drew a ring round the lookout three times, until the pencil went through. That is where the road comes up. Everything out here goes round it.\n\nLeft the pack here. Too heavy to carry what you would not carry. Follow the {posts}, not the prints. The prints lie in this wind.",
			0.0,
			[[["two", "one", "three"], "place:living"], [["posts", "lights", "trees"], "page:on the post"]],
			"If you find this pack with one cup in it, do not count them again."
		),
		_make(
			"on the post",
			"It is the same afternoon it was. The light has not moved since I left the cabin. I keep checking my phone anyway. No bars. Same afternoon.\n\nI called your name until I could not hear it over the wind. Then the trees called back, in {your} voice. Everything I shout out here comes back as you.\n\nI did not answer it. If you hear me from the trees, do not {answer} either. It is only what we threw out here, coming home.",
			0.10,
			[[["your", "my", "her"], "event:call"], [["answer", "follow", "listen"], "event:echo"]],
			"It called me by your name. For a second, I answered to it."
		),
		_make(
			"torn page",
			"—your prints from the step. I followed them as far as the pines. They do not go on and they do not come back. They stop, both feet {together}, the way you stood on the lake that winter when the ice started to sing under us and you would not move. As if the snow decided you had never been here.\n\ni stood in them. they {fit} me.\n\nI am going on to the lights. If you are behind me, you will find this. If I am behind you, I already did.",
			0.28,
			[[["together", "bare", "apart"], "place:snow"], [["fit", "followed", "knew"], "page:the handwriting changes"]],
			"The prints were smaller than mine. Then they were not."
		),
		_make(
			"the handwriting changes",
			"I keep writing to you because writing is the only thing that stays where I put it. The snow does not. The prints do not. the cabin does not. i have passed it twice and it was lit both times and i never went back in. i wanted to. you have no idea how much i wanted to.\n\nmy letters are going wrong. they lean the way {yours} lean. i know your hand better than mine. i read every list you ever left on the fridge. milk. candles. fix the latch. tell her. this is your hand now and i am still writing.\n\nif you are reading this, which of us is holding the {pen}.",
			0.48,
			[[["yours", "mine", "hers"], "page:by the bed"], [["pen", "lantern", "sheet"], "page:intake"]],
			"hold this next to the page by the bed. same hand. it was always the same hand."
		),
		_make(
			LAST_TITLE,
			"stop looking for me.\n\ngo to the lights. the engine has been running since before the snow. someone kept it warm for {one} of us. i will be there or i will not, but you will.\n\ni am right {behind} you. i always was. you just never turned around. do not turn around now. if you look at me there will only be one of us, and i do not know which one it will be.\n\ni forgive you for saying go. forgive me for going.\n\n— m",
			0.72,
			[[["one", "both", "neither"], "place:lights"], [["behind", "beside", "ahead of"], "page:on the post"]],
			"the sheet in the cellar is not me. it is the coat. say it back to me. the sheet is the coat."
		),
	]
	return notes


## Every page: the trail's, then the bed's and the intake.
static func everything() -> Array[NoteEntry]:
	var pages := all()
	pages.append(bedside())
	pages.append(intake())
	return pages


static func find(title: String) -> NoteEntry:
	for entry in everything():
		if entry.title == title:
			return entry
	return null


## Left on the nightstand, in Mathilda's hand.
static func bedside() -> NoteEntry:
	var entry := _make(
		"by the bed",
		"I lit the lantern so you would see it from the field. Leave it burning. You were always better at keeping a light than I was.\n\nYou said go, so I am going. You said it like you meant it. I know you didn't. I know you did.\n\nIf you are reading this, you came back and {I} did not. Stay in. Someone has to keep the door, you always say, and someone has to go out, and it was always going to be me.\n\nPut your coat on before you argue with me. Button it all the way up. You look like yourself in it.\n\n— {M.}",
		0.10,
		[[["I", "you", "we"], "page:torn page"], [["M.", "Mum", "Me"], "page:from the pack"]],
		"I left the door unlatched so you could get back in. Or so I could."
	)
	entry.counts = false
	return entry


## On the mortuary desk. It could be either of them.
static func intake() -> NoteEntry:
	var entry := _make(
		"intake",
		"Brought in from the step during the storm. Length under the sheet: 1.6 m. Strap stamped M. Aune. Given name, as copied: {M—}. Personal effects: one coat, buttoned to the throat. One cup. Cause: exposure. Next of kin: {out searching}. Not yet notified.",
		0.06,
		[[["M—", "Mathilda", "nobody"], "page:from the pack"], [["out searching", "notified", "none"], "page:by the bed"]],
		"Note: the coat held its shape after the sheet was lifted."
	)
	entry.counts = false
	return entry


# smudges: one [readings, key] per {word}, in order; readings[0] is the word.
static func _make(title: String, body: String, corruption: float, smudges: Array = [], between := "") -> NoteEntry:
	var entry := NoteEntry.new()
	entry.title = title
	entry.corruption = corruption
	entry.between = between
	var text := ""
	var at := 0
	var index := 0
	while true:
		var open := body.find("{", at)
		if open < 0:
			break
		var close := body.find("}", open)
		var word := body.substr(open + 1, close - open - 1)
		var spec: Array = smudges[index] if index < smudges.size() else [[word], ""]
		var readings: Array = spec[0]
		if str(readings[0]) != word:
			push_error("NoteCatalog: %s smudge %d reads '%s' but its first reading is '%s'" % [title, index, word, readings[0]])
		entry.smudges.append({"readings": readings, "key": str(spec[1])})
		text += body.substr(at, open - at) + "{%d}" % index
		at = close + 1
		index += 1
	text += body.substr(at)
	if index != smudges.size():
		push_error("NoteCatalog: %s has %d smudges in the text and %d listed" % [title, index, smudges.size()])
	entry.body = text
	return entry
