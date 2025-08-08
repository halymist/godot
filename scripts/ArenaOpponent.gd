extends Panel

@export var perk_mini_scene: PackedScene
@export var enemy_id: int = 1
@export var enemy_name: String = "Enemy"
@export var enemy_hp: int = 100
@export var enemy_attack: int = 25
@export var enemy_defense: int = 15

@onready var name_label: Label = $EnemyName
@onready var image_label: Label = $ImagePanel/ImageLabel
@onready var stats_label: Label = $StatsLabel
@onready var perks_container: HBoxContainer = $PerksContainer

var opponent_data = null

func _ready():
	# Load perk_mini scene if not set
	if not perk_mini_scene:
		perk_mini_scene = load("res://Scenes/perk_mini.tscn")
	_update_display()

func _update_display():
	if name_label:
		name_label.text = enemy_name.to_upper()
	
	if image_label:
		image_label.text = "Enemy\nImage\n" + str(enemy_id)
	
	if stats_label:
		stats_label.text = "HP: " + str(enemy_hp) + "\nATK: " + str(enemy_attack) + "\nDEF: " + str(enemy_defense)
	
	_update_perks_display()

func set_enemy_data(id: int, enemy_name_text: String, hp: int, attack: int, defense: int):
	enemy_id = id
	enemy_name = enemy_name_text
	enemy_hp = hp
	enemy_attack = attack
	enemy_defense = defense
	_update_display()

func set_opponent_data(opponent):
	opponent_data = opponent
	if opponent:
		set_enemy_data(enemy_id, opponent.name, enemy_hp, enemy_attack, enemy_defense)

func _update_perks_display():
	if not perks_container or not opponent_data:
		return
	
	# Clear existing perk icons
	for child in perks_container.get_children():
		child.queue_free()
	
	# Use the inherited get_active_perks method
	if opponent_data:
		var active_perks = opponent_data.get_active_perks()
		
		# Display up to 5 perks (to fit in the container)
		for i in range(min(active_perks.size(), 5)):
			var perk = active_perks[i]
			if perk_mini_scene:
				var perk_icon = perk_mini_scene.instantiate()
				
				# Store perk data for tooltip
				perk_icon.set_meta("perk_data", perk)
				
				# Set perk texture if available
				var texture_rect = perk_icon.get_node("TextureRect")
				if texture_rect:
					# Use asset_id if available, otherwise use default
					var asset_id = perk.asset_id if perk.asset_id else 1
					_set_perk_texture_by_asset_id(texture_rect, asset_id)
				
				perks_container.add_child(perk_icon)

func _set_perk_texture_by_asset_id(texture_rect: TextureRect, _asset_id: int):
	# This could be expanded to load actual perk textures based on asset_id
	# For now, just set a placeholder
	if texture_rect:
		# Could load specific textures here based on asset_id
		# texture_rect.texture = load("res://assets/perks/perk_" + str(asset_id) + ".png")
		pass
