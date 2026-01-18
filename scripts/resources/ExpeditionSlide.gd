class_name ExpeditionSlide
extends Resource

const ExpeditionOptionScript = preload("res://scripts/resources/ExpeditionOption.gd")

@export var slide_id: int = 0
@export_multiline var text: String = ""
@export var texture: Texture2D = null
@export var options: Array[Resource] = []  # Array of ExpeditionOption
