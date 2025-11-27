extends Panel

@export var perk_mini_scene: PackedScene
@export var enemy_id: int = 1
var enemy_name: String = "Enemy"
var enemy_strength: int = 10
var enemy_constitution: int = 10
var enemy_dexterity: int = 10
var enemy_luck: int = 10
var enemy_armor: int = 0

@export var image_label: Label
@export var name_label: Label
@export var strength_label: Label
@export var constitution_label: Label
@export var dexterity_label: Label
@export var luck_label: Label
@export var armor_label: Label
@export var perks_container: HBoxContainer
@export var tooltip_panel: Panel

var opponent_data = null

func _ready():
	_update_display()

func _update_display():
	name_label.text = enemy_name.to_upper()
	image_label.text = "Enemy\nImage\n" + str(enemy_id)
	strength_label.text = "STR: " + str(enemy_strength)
	constitution_label.text = "CON: " + str(enemy_constitution)
	dexterity_label.text = "DEX: " + str(enemy_dexterity)
	luck_label.text = "LCK: " + str(enemy_luck)
	armor_label.text = "ARM: " + str(enemy_armor)
	
	_update_perks_display()

func set_enemy_data(id: int, enemy_name_text: String, strength: int, stamina: int, agility: int, luck: int, armor: int):
	enemy_id = id
	enemy_name = enemy_name_text
	enemy_strength = strength
	enemy_constitution = stamina  # Map stamina back to constitution for display
	enemy_dexterity = agility     # Map agility back to dexterity for display
	enemy_luck = luck
	enemy_armor = armor
	_update_display()

func set_opponent_data(opponent):
	opponent_data = opponent
	if opponent:
		var total_stats = opponent.get_total_stats()
		set_enemy_data(enemy_id, opponent.name, total_stats.strength, total_stats.stamina, total_stats.agility, total_stats.luck, total_stats.armor)

func _update_perks_display():
	print("DEBUG: _update_perks_display called")
	print("DEBUG: perks_container = ", perks_container)
	print("DEBUG: opponent_data = ", opponent_data)
	
	if not perks_container or not opponent_data:
		print("DEBUG: Early return - missing container or data")
		return
	
	# Clear existing perk icons
	for child in perks_container.get_children():
		child.queue_free()
	
	# Use the inherited get_active_perks method
	if opponent_data:
		var active_perks = opponent_data.get_active_perks()
		print("DEBUG: Found ", active_perks.size(), " active perks")
		
		# Display all active perks (not limited to 5)
		for i in range(active_perks.size()):
			var perk = active_perks[i]
			print("DEBUG: Processing perk ", i, ": ", perk.perk_name)
			
			if perk_mini_scene:
				print("DEBUG: perk_mini_scene is available")
				var perk_icon = perk_mini_scene.instantiate()
				print("DEBUG: Created perk_icon: ", perk_icon)
				
				# Store perk data for tooltip
				perk_icon.set_meta("perk_data", perk)		
				perk_icon.mouse_entered.connect(_on_perk_hover_start.bind(perk_icon))
				perk_icon.mouse_exited.connect(_on_perk_hover_end)
				
				perks_container.add_child(perk_icon)
				print("DEBUG: Added perk_icon to container")
			else:
				print("DEBUG: perk_mini_scene is null!")
	
	print("DEBUG: perks_container now has ", perks_container.get_child_count(), " children")

func _on_perk_hover_start(perk_icon):
	var perk_data = perk_icon.get_meta("perk_data")
	if perk_data and tooltip_panel:
		var tooltip_label = tooltip_panel.get_node("TooltipLabel")
		if tooltip_label:
			# Build tooltip with perk name and effects
			var tooltip_text = perk_data.perk_name
			
			# Add effect 1 if it exists
			if perk_data.effect1_description != "":
				var effect1_text = perk_data.effect1_description
				if perk_data.factor1 != 0.0:
					effect1_text += " " + str(int(perk_data.factor1))
				tooltip_text += "\n\n" + effect1_text
			
			# Add effect 2 if it exists
			if perk_data.effect2_description != "":
				var effect2_text = perk_data.effect2_description
				if perk_data.factor2 != 0.0:
					effect2_text += " " + str(int(perk_data.factor2))
				tooltip_text += "\n" + effect2_text
			
			tooltip_label.text = tooltip_text
			tooltip_panel.visible = true
			
			# Position tooltip above the perk icon
			var icon_global_pos = perk_icon.global_position
			var icon_size = perk_icon.size
			var tooltip_size = tooltip_panel.size
			
			# Position above the icon, centered horizontally
			tooltip_panel.global_position = Vector2(
				icon_global_pos.x - tooltip_size.x / 2 + icon_size.x / 2,  # Center horizontally on icon
				icon_global_pos.y - tooltip_size.y - 10  # Position above icon with 10px gap
			)
			
			# Ensure tooltip stays within screen bounds
			var viewport_size = get_viewport().get_visible_rect().size
			if tooltip_panel.global_position.x < 0:
				tooltip_panel.global_position.x = 0
			elif tooltip_panel.global_position.x + tooltip_size.x > viewport_size.x:
				tooltip_panel.global_position.x = viewport_size.x - tooltip_size.x
			
			if tooltip_panel.global_position.y < 0:
				tooltip_panel.global_position.y = icon_global_pos.y + icon_size.y + 10  # Show below if no space above

func _on_perk_hover_end():
	if tooltip_panel:
		tooltip_panel.visible = false
