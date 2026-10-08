class_name NoteEntry
extends Resource

@export var title: String = ""
@export_multiline var body: String = ""
@export_range(0.0, 1.0, 0.01) var corruption: float = 0.0
# Records describe a threat's rule. They do not count toward the pages that
# start the hunt; reading one marks that code as understood (Game.knows).
@export var record_of: String = ""
# Trail notes advance the hunt. Pages in the house do not.
@export var counts: bool = true

# Smudged words in body order: {"readings": [right, wrong, wrong], "key":
# "page:<title>" | "place:<place>" | "event:<call|echo>"}. The body holds
# {0}, {1}, ... where they sit (NoteCatalog._make).
@export var smudges: Array[Dictionary] = []
# The sentence between the lines, legible once every smudge is solved.
@export var between: String = ""
