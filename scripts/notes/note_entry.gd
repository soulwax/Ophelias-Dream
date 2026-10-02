class_name NoteEntry
extends Resource

@export var title: String = ""
@export_multiline var body: String = ""
@export_range(0.0, 1.0, 0.01) var corruption: float = 0.0
# Containment records describe an anomaly's rule. They do not count toward
# the hunter's notes; reading one marks that anomaly as understood.
@export var record_of: String = ""
