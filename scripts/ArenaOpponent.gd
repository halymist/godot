extends Panel

@export var enemy_id: int = 1
@export var enemy_name: String = "Enemy"
@export var enemy_hp: int = 100
@export var enemy_attack: int = 25
@export var enemy_defense: int = 15

@onready var name_label: Label = $EnemyName
@onready var image_label: Label = $ImagePanel/ImageLabel
@onready var stats_label: Label = $StatsLabel

func _ready():
	_update_display()

func _update_display():
	if name_label:
		name_label.text = enemy_name.to_upper()
	
	if image_label:
		image_label.text = "Enemy\nImage\n" + str(enemy_id)
	
	if stats_label:
		stats_label.text = "HP: " + str(enemy_hp) + "\nATK: " + str(enemy_attack) + "\nDEF: " + str(enemy_defense)

func set_enemy_data(id: int, enemy_name_text: String, hp: int, attack: int, defense: int):
	enemy_id = id
	enemy_name = enemy_name_text
	enemy_hp = hp
	enemy_attack = attack
	enemy_defense = defense
	_update_display()
