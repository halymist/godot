class_name TalentResource
extends Resource

@export var talent_id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var max_points: int = 0
@export var perk_slot: int = 0  # If > 0, this talent unlocks a perk slot
@export var effect_id: int = 0
@export var factor: float = 0.0
@export var row: int = 0
@export var col: int = 0
