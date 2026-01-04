class_name LocationResource
extends Resource

@export var location_id: int
@export var location_name: String

# Village scene for this location
@export var village_scene: PackedScene

# Expedition/Map panel when not traveling
@export var expedition_texture: Texture2D
@export var expedition_text: String = ""

# Utility backgrounds (null = not available at this location)
@export var blacksmith_utility_scene: PackedScene

@export var vendor_background: Texture
@export var vendor_greetings: Array[String] = []

@export var alchemist_utility_scene: PackedScene

@export var enchanter_background: Texture
@export var enchanter_greetings: Array[String] = []

@export var trainer_background: Texture
@export var trainer_greetings: Array[String] = []

@export var church_background: Texture
@export var church_greetings: Array[String] = []

@export var arena_background: Texture

func has_blacksmith() -> bool:
	return blacksmith_utility_scene != null

func has_vendor() -> bool:
	return vendor_background != null

func has_alchemist() -> bool:
	return alchemist_utility_scene != null

func has_enchanter() -> bool:
	return enchanter_background != null

func has_trainer() -> bool:
	return trainer_background != null

func has_church() -> bool:
	return church_background != null

func get_random_vendor_greeting() -> String:
	if vendor_greetings.is_empty():
		return "What can I get you?"
	return vendor_greetings[randi() % vendor_greetings.size()]

func get_random_enchanter_greeting() -> String:
	if enchanter_greetings.is_empty():
		return "I can enhance your equipment."
	return enchanter_greetings[randi() % enchanter_greetings.size()]

func get_random_trainer_greeting() -> String:
	if trainer_greetings.is_empty():
		return "Ready to train?"
	return trainer_greetings[randi() % trainer_greetings.size()]

func get_random_church_greeting() -> String:
	if church_greetings.is_empty():
		return "May the gods bless you."
	return church_greetings[randi() % church_greetings.size()]
