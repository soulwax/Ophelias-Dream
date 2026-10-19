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
const EVENTS := ["call", "echo", "cups"]
const CHAPTERS := [
	{"id": "house", "label": "I  ·  The House", "opening": "The house keeps its small arrangements after Mathilda leaves. Each one looks ordinary until I try to decide who made it. I start with the door, because a door is allowed to belong to two rooms at once. The pages lie where a hand might reach for them in the dark: bedside, hearth, hall, then the cold desk where a name ought to be.", "pages": ["by the bed", "the grate", "the photograph", "intake"], "coda_page": "intake", "coda": "No record names a woman it cannot see. Still, I keep asking the form whether Mathilda went out, or whether I did. Perhaps she is the name the clerk left blank; perhaps she is the one who came back to fill it in. The paper keeps the space where a name should be. I press my thumb to the empty line. It warms, briefly, as if someone has just lifted a pen."},
	{"id": "road", "label": "II  ·  The Road Out", "opening": "Her notes lay a route around the places I thought I knew. I follow the handwriting before I trust the prints. The path seems to have been waiting for my feet to remember it. She has packed for two, but the snow keeps trying to reduce the arithmetic to one.", "pages": ["from the pack", "on the post"], "coda_page": "on the post", "coda": "The trees say the voice is mine. Maybe I taught the forest her name. Maybe her name was what my voice sounded like before I learned to stay quiet. If the woods return only what we give them, why does the answer always know where to hurt? I leave the post without calling again. Behind me, the branches settle into the shape of someone listening."},
	{"id": "prints", "label": "III  ·  The Missing Prints", "opening": "At the lake, the snow keeps two accounts of one afternoon. I cannot find the moment one set became two. The page is torn across the place where a witness might have stood.", "pages": ["torn page"], "coda_page": "torn page", "coda": "If two tracks can meet and continue as one, perhaps Mathilda is where my memory crossed itself. Or perhaps the snow is simply a poor witness. I have blamed the weather for less than this. When I lift my boot, the print underneath is already filling with light."},
	{"id": "hand", "label": "IV  ·  The Familiar Hand", "opening": "The letters change their posture halfway across the page. I recognize the hand and distrust the voice. The ink does not pause where the thought changes owners. I read the sentence aloud; the room answers in the voice I meant to use.", "pages": ["the handwriting changes"], "coda_page": "the handwriting changes", "coda": "My hand wrote you. I cannot tell whether it was addressing someone, or trying to become someone who would answer. Mathilda may be the reader I invented to survive the sentence. She may be the only one who ever read it. The last stroke of her name is mine, but I do not remember putting it there."},
	{"id": "last", "label": "V  ·  The Last Instruction", "opening": "The final page does not lead me to her. It leaves me with the direction she chose. I read it once for the road, and once for the person following. There is no map now, only a pronoun with its face turned away.", "pages": [LAST_TITLE], "coda_page": LAST_TITLE, "coda": "If she is the part of me that went, what is the part that stayed waiting? If she is someone else, why do all my memories have only one set of hands? I close the journal. In the dark glass, someone is still standing just behind my shoulder. I turn the lamp toward the window. The reflection does not move; the room feels less empty anyway."},
	{"id": "aside", "label": "Loose Thread", "opening": "A loose thread is a small thing. I follow it because the cold has made every small thing matter.", "pages": ["The thread"]},
]
const READINGS := {
	"by the bed": "I keep trying to divide us into the one who stayed and the one who left. The open door refuses to hold that line. Perhaps she left it for me. Perhaps I left it for the person I was trying to bring home.",
	"the grate": "Someone keeps the fire alive, then calls the work proof that nobody left. I know that trick. I have used it on this house.",
	"the photograph": "Two people remember standing there. The glass gives me one. I cannot tell whether the picture has lost someone, or whether memory has added her back.",
	"intake": "A form can name a coat, a cup, a length. It cannot tell me who was under the sheet. I keep reading the blank where a name should be as if it might answer differently.",
	"from the pack": "Two cups are a small, stubborn future. Mathilda packed as though we would both arrive, even when I had stopped believing in the plural.",
	"on the post": "The forest gives my voice back in her name. If she is only an echo, why does the echo know what I am afraid to hear?",
	"torn page": "The prints stop together. I have been treating that as proof of an ending. It could also be the place where one memory was laid over another.",
	"the handwriting changes": "The hand is mine. The anger may be hers. I do not know whether that makes Mathilda a memory, a witness, or the part of me that learned to say no.",
	"don't turn around": "I read this as a warning not to look because I might lose her. Another reading is harder: perhaps I am being asked to stop making her turn back for me.",
	"The thread": "A path can be marked without becoming a command. I can follow the wool to the glove and still choose what I do with what it tells me.",
}
const LEAD_INS := {
	"by the bed": "At the cabin, I begin with the door she left unlatched. The cold has not yet reached the sheets.",
	"the grate": "The grate was warm before I knew who had banked it. A little ash shifted when I came in, like a breath held too long.",
	"the photograph": "The photograph is the first thing that refuses to stay singular. I carry it down the hall toward the window and watch the glass add a second witness.",
	"intake": "The record speaks in measurements, as though the body were the simplest part. At the bottom, the clerk has left a line for whoever comes to claim the coat.",
	"from the pack": "Her route begins with a pack laid down for two. I find the second cup before I find the road.",
	"on the post": "The trail gives my own voice back in her name. The echo arrives from ahead of me, where no one is standing.",
	"torn page": "The tracks end at the place where neither memory will lead. I kneel there long enough for the snow to soften the edge of my glove.",
	"the handwriting changes": "The letter changes hands without changing ink. Somewhere in the middle of the line, I stop being sure which of us is asking for an answer.",
	"don't turn around": "The last page asks its reader to keep facing forward. The road is plain; it is the pronoun that will not hold still.",
	"The thread": "I follow the thread past what I already knew.",
}


static func chapter_for(title: String) -> Dictionary:
	for chapter: Dictionary in CHAPTERS:
		if (chapter.pages as Array).has(title):
			return chapter
	return {"id": "aside", "label": "Loose Thread", "pages": []}


static func reading_for(entry: NoteEntry) -> String:
	return str(READINGS.get(entry.title, ""))


static func lead_in_for(entry: NoteEntry) -> String:
	return str(LEAD_INS.get(entry.title, ""))


static func chapter_opening_for(title: String) -> String:
	return str(chapter_for(title).get("opening", ""))


static func chapter_coda_for(entry: NoteEntry) -> String:
	var chapter := chapter_for(entry.title)
	if str(chapter.get("coda_page", "")) != entry.title:
		return ""
	return str(chapter.get("coda", ""))


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
	# An additional way to understand the pair; the original living-room key
	# remains sufficient, so no optional activity gates the base story.
	notes[0].smudges[0]["also"] = "event:cups"
	return notes


## Every page: the trail's, then the bed's, the grate's and the intake.
static func everything() -> Array[NoteEntry]:
	var pages := all()
	pages.append(bedside())
	pages.append(grate())
	pages.append(photograph())
	pages.append(intake())
	return pages


## A keepsake from the optional red-thread walk, not a lake page.
static func thread() -> NoteEntry:
	var entry := _make("The thread", "Red wool from the window, caught on five things between the house and the birch. I wound it loose and found your glove beneath our initials. The letters are still there.", 0.0)
	entry.counts = false
	entry.lake_counts = false
	return entry


static func find(title: String) -> NoteEntry:
	if title == "The thread":
		return thread()
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


## On the mantel, once the stove is lit. Not required reading.
static func grate() -> NoteEntry:
	var entry := _make(
		"the grate",
		"Someone banked this grate before I woke. Not last night's fire — older. Days, maybe. A house doesn't stay warm by itself, and this one never once goes properly cold.\n\nThe wood is stacked the way {M.} always stacked it, crosswise so it catches first time.\n\nIf you're reading this by firelight, it is already going. {Build} it up anyway. Let it think one of us did.",
		0.14,
		[[["M.", "I", "we"], "page:by the bed"], [["Build", "Leave", "Light"], "place:living"]],
		"I did not light this fire. I am only the one who tends it now."
	)
	entry.counts = false
	return entry

## On the boot bench in the hall. Mathilda has the same photograph, with both of them in it.
static func photograph() -> NoteEntry:
	var entry := _make(
		"the photograph",
		"The winter the ice sang. Two of us on the lake, the old hole behind us, both squinting into the sun.

On the back, in pencil: {M.} and me.

Hold it to the window and there is only one of us on the ice, and she is looking at whoever held the {camera}.",
		0.16,
		[[["M.", "Me", "nobody"], "page:from the pack"], [["camera", "lantern", "door"], "place:lake"]],
		"Neither of us remembers taking it. Both of us remember being in it."
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
