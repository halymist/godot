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
@export var tooltip_label: Label

var opponent_data = null

func _ready():
	# Manually assign UI elements
	name_label = $EnemyName
	image_label = $AspectRatioContainer/ImagePanel/ImageLabel
	strength_label = $StatsContainer/StrengthLabel
	constitution_label = $StatsContainer/ConstitutionLabel
	dexterity_label = $StatsContainer/DexterityLabel
	luck_label = $StatsContainer/LuckLabel
	armor_label = $StatsContainer/ArmorLabel
	perks_container = $PerksContainer
	tooltip_panel = $PerkTooltip
	tooltip_label = $PerkTooltip/TooltipLabel
	
	_update_display()

func _update_display():
	if name_label:
		name_label.text = enemy_name.to_upper()
	
	if image_label:
		image_label.text = "Enemy\nImage\n" + str(enemy_id)
	
	if strength_label:
		strength_label.text = "STR: " + str(enemy_strength)
	
	if constitution_label:
		constitution_label.text = "CON: " + str(enemy_constitution)
	
	if dexterity_label:
		dexterity_label.text = "DEX: " + str(enemy_dexterity)
	
	if luck_label:
		luck_label.text = "LCK: " + str(enemy_luck)
	
	if armor_label:
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
				
				# Enable mouse detection for hover (like character screen)
				perk_icon.mouse_filter = Control.MOUSE_FILTER_PASS
				
				# Connect hover signals for tooltip functionality
				perk_icon.mouse_entered.connect(_on_perk_hover_start.bind(perk_icon))
				perk_icon.mouse_exited.connect(_on_perk_hover_end)
				
				perks_container.add_child(perk_icon)

func _on_perk_hover_start(perk_icon):
	var perk_data = perk_icon.get_meta("perk_data")
	if perk_data and tooltip_label and tooltip_panel:
		tooltip_label.text = perk_data.perk_name + "\n\n" + perk_data.description
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

func _set_perk_texture_by_asset_id(texture_rect: TextureRect, _asset_id: int):
	# This could be expanded to load actual perk textures based on asset_id
	# For now, just set a placeholder
	if texture_rect:
		# Could load specific textures here based on asset_id
		# texture_rect.texture = load("res://assets/perks/perk_" + str(asset_id) + ".png")
		pass
