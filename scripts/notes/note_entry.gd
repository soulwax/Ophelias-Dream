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
