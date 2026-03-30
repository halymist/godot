class_name QuestData
extends Resource

@export var quest_id: int = 0
@export var quest_name: String = ""
@export var background_texture: Texture2D = null
@export var travel_text: String = ""
@export var settlement_id: int = 0  # Which settlement this quest belongs to
@export var asset_id: int = 0  # Background image asset
@export var ending: bool = false  # Is this an ending quest (legacy)
@export var failure_text: String = ""  # Text shown when quest fails

# Flat quest structure
@export_multiline var initial_text: String = ""  # Starting text (start_text from server)
@export var options: Array[QuestOption] = []  # ALL options for this quest
@export var initially_visible_options: Array[int] = []  # Which options show at start (default_entry)
