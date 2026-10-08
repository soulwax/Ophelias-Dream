class_name TerrainCache
extends Resource

# Immutable generated data for one fingerprint. No scene scripts are cached.
@export var fingerprint := ""
@export var data: Dictionary = {}
@export var chunks: PackedScene
