class_name FloraCache
extends Resource

# Placement data only. Meshes, materials and physics RIDs are rebuilt from
# the current assets; cached tree indices stay aligned with audio queries.
@export var fingerprint := ""
@export var data: Dictionary = {}
