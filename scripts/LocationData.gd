class_name LocationResource
extends Resource

@export var location_id: int
@export var location_name: String
@export_multiline var description: String = ""

# Village background image for this location (replaces village_scene)
@export var village_texture: Texture2D

# Expedition/Map panel when not traveling
@export var expedition_texture: Texture2D
@export var expedition_text: String = ""

# Utility backgrounds (null = not available at this location)
@export var blacksmith_utility_scene: PackedScene

@export var vendor_utility_scene: PackedScene

@export var alchemist_utility_scene: PackedScene

@export var enchanter_utility_scene: PackedScene

@export var trainer_utility_scene: PackedScene

@export var church_utility_scene: PackedScene

# Three blessing perk IDs available at this location's church
@export var blessings: Array[int] = []

@export var arena_background: Texture

func has_blacksmith() -> bool:
	return blacksmith_utility_scene != null

func has_vendor() -> bool:
	return vendor_utility_scene != null

func has_alchemist() -> bool:
	return alchemist_utility_scene != null

func has_enchanter() -> bool:
	return enchanter_utility_scene != null

func has_trainer() -> bool:
	return trainer_utility_scene != null

func has_church() -> bool:
	return church_utility_scene != null




