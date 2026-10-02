class_name NoteCatalog
extends RefCounted

static func all() -> Array[NoteEntry]:
	var notes: Array[NoteEntry] = [
		_make(
			"Field Note — Day 3",
			"The ridge road is still open if we leave before dark. Mara says someone is standing in the tree line. I told her it was a skier. It was not wearing skis.\n\nIf you woke in the cabin, you already waited too long. The road is ahead. Run.",
			0.0
		),
		_make(
			"Field Note — Day 4",
			"We found Mara's pack set down, as if she meant to come back for it. The snow around it is pressed flat. Prints lead toward the cabin. None lead away.\n\nDo not stop to warm your hands. It listens for that.",
			0.08
		),
		_make(
			"torn page",
			"do not look into the gaps between the pines. it stands where the snow will not settle. the lights at the end of the trail are the road. i think they are the road.\n\nkeep your breath quiet. quiet is slower. slower is how it learned my name.",
			0.28
		),
		_make(
			"the handwriting changes",
			"it knows the sound your breath makes when you stop. i stopped to write this. the letters are wrong because my hands are wrong. the campfire was not warm.\n\nthe cabin was not where you woke up. you have been on this trail longer than the snow.",
			0.48
		),
		_make(
			"don't",
			"i wrote this so you would stand still.\n\ni am sorry.\n\nthe road is a mouth and the lights are teeth and i am the one who\n\nstop reading.\n\nit is behind you.",
			0.72
		),
	]
	return notes


static func _make(title: String, body: String, corruption: float) -> NoteEntry:
	var entry := NoteEntry.new()
	entry.title = title
	entry.body = body
	entry.corruption = corruption
	return entry
