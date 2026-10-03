class_name NoteCatalog
extends RefCounted

static func all() -> Array[NoteEntry]:
	var notes: Array[NoteEntry] = [
		_make(
			"Field Note — Day 3",
			"The ridge road is still open if we leave before dark. Mara says someone is standing in the tree line. I told her it was a skier. It was not wearing skis. It does not walk while you are looking. It is there when you turn back to the trail.\n\nIf you woke in the cabin, you already waited too long. The road is ahead. Run.",
			0.0
		),
		_make(
			"Field Note — Day 4",
			"We found Mara's pack set down, as if she meant to come back for it. The snow around it is pressed flat. Prints lead toward the cabin. None lead away.\n\nThe one in the trees will not come through the door. It stands on the step and waits, and the waiting counts. Do not go back in to be warm.",
			0.08
		),
		_make(
			"torn page",
			"do not look into the gaps between the pines. the tall one stands where the snow will not settle. that one wants you still.\n\nthere is another in the field. it does not want you. it wants the cloud that leaves your mouth. the lights at the end of the trail are the road.\n\nkeep moving. quiet is slower. slower is how the tall one learned where i stopped.",
			0.28
		),
		_make(
			"the handwriting changes",
			"the tall one knows the shape of a person who has stopped. i stopped to write this. the letters are wrong because my hands are wrong.\n\nsomething else turns its head only for breath. i breathed on the page. it did not care about the words.\n\nthe cabin is shelter. it is not a way out. you have been on this trail longer than the snow.",
			0.48
		),
		_make(
			"don't",
			"i wrote this so you would stand still.\n\ni am sorry. i thought if the one in the trees took you it would leave the rest of us. it does not leave.\n\nthe road is not a mouth. i needed you to believe the lights were teeth. they are headlights. run to them.\n\nstop reading.\n\nit is behind you.",
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
