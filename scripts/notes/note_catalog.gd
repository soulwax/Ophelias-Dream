class_name NoteCatalog
extends RefCounted

# The page that asks her to finish. Opening it is what the endings remember.
const LAST_TITLE := "don't"

static func all() -> Array[NoteEntry]:
	var notes: Array[NoteEntry] = [
		_make(
			"Field Note — Day 3",
			"Ridge still open if we are down before the light goes. Mara is ahead of me. She stopped at the first pines and lifted her hand. I told her it was a skier. It was not wearing skis. She says it lifted its hand after she did. I was looking at her, not at the gap.\n\nThe cabin had a lantern lit when I woke. I do not remember lighting it. Day 3 is what I am calling this morning. Mara says it is later than that.",
			0.0
		),
		_make(
			"from the pack",
			"Strap stamped M. Aune. Inside: wool, a cup, half a candle, the map with the ridge folded under. The candle has not been burned.\n\nSnow pressed flat around the pack, as if it had been set down to pick up again. I counted the prints toward the cabin. Then I counted them from the step. The second count had one more, and it stopped where the mat is. The mat was straight.\n\nNone of them lead back to the pack.",
			0.08
		),
		_make(
			"torn page",
			"—not into the gaps. it stands where the snow will not settle on the branches. i looked and the branches were bare in a shape. when i looked again the shape was only branches.\n\ni held my breath as far as the lantern at the camp. the lantern did not care. something else might have. i did not turn my head to see.\n\nthe lights were already on at the end when we started. mara said a car. the road is closed in this. i wrote that on day 3. this is not that page.",
			0.28
		),
		_make(
			"the handwriting changes",
			"day 3. mara is ahead. she did not lift her hand. i lifted mine. the gap lifted it back. the letters are wrong because the hand is wrong. i am writing with the hand that waved.\n\ni put my mouth close to the paper to see the line. the line did not fog. the cold took it. if you are reading this the fog was here and then it was not.\n\nthe cabin lantern is out if you have walked away from it. it is lit if you go back. i have gone back. the mat is still straight.",
			0.48
		),
		_make(
			LAST_TITLE,
			"stay until the end of the line.\n\ni am the one who stamped the strap. i am not the one who waved. if you hear three strikes on the door you are counting for whatever is on the step. finish this first.\n\nthe lights have been on longer than the snow. do not go to them until you have finished. i need you to finish.\n\nit is behind you.",
			0.72
		),
	]
	return notes


## Left on the nightstand. It knows the bed. It does not know who is reading.
static func bedside() -> NoteEntry:
	var entry := _make(
		"by the bed",
		"The lantern was already burning. I did not light it. The candle on this stand is burned to the tin. I left it that way so I would know if I had been here before.\n\nThe wool is still warm. It is not from me. I do not know your name. I am writing this before I go out to the step.",
		0.12
	)
	entry.counts = false
	return entry


## On the mortuary desk. The height matches neither sheet in the Listener's file.
static func intake() -> NoteEntry:
	var entry := _make(
		"intake",
		"Length under the sheet: 1.6 m. Brought down from the step. Initial, as copied from the strap: R. The rest of the name was not taken down. A second stroke was started and left.",
		0.06
	)
	entry.counts = false
	return entry


static func _make(title: String, body: String, corruption: float) -> NoteEntry:
	var entry := NoteEntry.new()
	entry.title = title
	entry.body = body
	entry.corruption = corruption
	return entry
