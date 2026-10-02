class_name NoteEntry
extends Resource

@export var title: String = ""
@export_multiline var body: String = ""
@export_range(0.0, 1.0, 0.01) var corruption: float = 0.0
