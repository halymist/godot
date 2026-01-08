extends Control
class_name CharacterDisplay

# Button references
@export var talents_button: Button
@export var details_button: Button
@export var avatar_button: Button

# Stats display references (from LabelUpdate.gd)
@export var player_name_label: Label
@export var rank_label: Label
@export var faction_label: Label
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
@export var armor_label: Label
@export var health_bar: TextureProgressBar
@export var damage_spread_label: Label

# Active perks display
@export var active_perks_display: HBoxContainer
@export var perk_mini_scene: PackedScene

func _ready():
	# Connect button signals
	talents_button.pressed.connect(_on_talents_pressed)
	details_button.pressed.connect(_on_details_pressed)
	avatar_button.pressed.connect(_on_avatar_pressed)
	
	# Initial display
	refresh_active_effects()  # This will also call stats_changed internally

# Called when GameInfo current player is updated
func stats_changed(_stats: Dictionary):
	var total_stats = GameInfo.get_total_stats()
	
	player_name_label.text = str(total_stats.name)
	rank_label.text = GameInfo.current_player.get_rank_name() + " (" + str(GameInfo.current_player.rank) + ")"
	faction_label.text = GameInfo.current_player.get_faction_name()

	
	# Display already-calculated stats from GameInfo
	strength_label.text = str(total_stats.strength)
	stamina_label.text = str(total_stats.stamina)
	agility_label.text = str(total_stats.agility)
	luck_label.text = str(total_stats.luck)
	armor_label.text = str(total_stats.armor)	

	
	# Calculate and display health bar (stamina * 10)
	if health_bar:
		var max_health = total_stats.stamina * 10
		health_bar.max_value = max_health
		health_bar.value = max_health
		if health_bar.has_node("HealthLabel"):
			health_bar.get_node("HealthLabel").text = str(max_health)
	
	# Calculate and display damage spread (strength * weapon damage range)
	if damage_spread_label:
		var weapon_item = null
		# Find equipped weapon in slots 0-8
		for item in GameInfo.current_player.bag_slots:
			if item != null and item.bag_slot_id >= 0 and item.bag_slot_id <= 8:
				if item.type == "Weapon":
					weapon_item = item
					break
		
		if weapon_item != null:
			var min_damage = total_stats.strength * weapon_item.damage_min
			var max_damage = total_stats.strength * weapon_item.damage_max
			damage_spread_label.text = str(min_damage) + " - " + str(max_damage)
		else:
			damage_spread_label.text = "0 - 0"

func refresh_active_effects():
	"""Refresh active effects display (blessings, potions, elixirs, perks)"""
		
	print("CharacterDisplay: Updating active perks and effects...")
	
	# Clear existing icons
	for child in active_perks_display.get_children():
		child.queue_free()
	
	# Add equipped elixir first if any
	if GameInfo.current_player and GameInfo.current_player.elixir > 0:
		var elixir_icon_texture = GameInfo.items_db.get_item_by_id(1000)  # Use elixir base icon
		if elixir_icon_texture and elixir_icon_texture.icon:
			create_consumable_display(elixir_icon_texture.icon, "Elixir", GameInfo.current_player.elixir)
	
	# Add equipped potion second if any
	if GameInfo.current_player and GameInfo.current_player.potion > 0:
		var potion_item = GameInfo.items_db.get_item_by_id(GameInfo.current_player.potion)
		if potion_item and potion_item.icon:
			create_consumable_display(potion_item.icon, "Potion", GameInfo.current_player.potion)
	
	# Add active blessing effect third if any
	if GameInfo.current_player and GameInfo.current_player.blessing > 0:
		var blessing_perk = GameInfo.perks_db.get_perk_by_id(GameInfo.current_player.blessing) if GameInfo.perks_db else null
		if blessing_perk:
			# Get the effect referenced by the blessing perk
			var blessing_effect = GameInfo.effects_db.get_effect_by_id(blessing_perk.effect1_id) if GameInfo.effects_db else null
			if blessing_effect:
				create_blessing_display(blessing_perk, blessing_effect)
	
	# Get active perks from GameInfo
	var active_perks = GameInfo.current_player.get_active_perks() if GameInfo.current_player else []
	print("CharacterDisplay: Found ", active_perks.size(), " active perks")
	
	# Create icon for each active perk
	for perk in active_perks:
		print("CharacterDisplay: Creating icon for: ", perk.perk_name)
		
		if perk_mini_scene:
			var perk_icon = perk_mini_scene.instantiate()
			# Store perk data in the icon for hover functionality
			perk_icon.set_meta("perk_data", perk)
			
			# Set the perk texture if available
			var texture_rect = perk_icon.get_node("TextureRect")
			if texture_rect and perk.texture:
				texture_rect.texture = perk.texture
			
			# Enable mouse detection for hover
			perk_icon.mouse_filter = Control.MOUSE_FILTER_PASS
			
			# Connect hover signals
			perk_icon.mouse_entered.connect(_on_perk_hover_start.bind(perk_icon))
			perk_icon.mouse_exited.connect(_on_perk_hover_end)
			
			active_perks_display.add_child(perk_icon)
			print("CharacterDisplay: Added perk icon to HBox")
		else:
			print("ERROR: perk_mini_scene is null!")
	
	# Refresh stats after updating effects
	stats_changed(GameInfo.get_player_stats())

func create_consumable_display(icon_texture: Texture2D, consumable_type: String, item_id: int):
	"""Create a display for an equipped consumable (potion or elixir)"""
	if perk_mini_scene and active_perks_display:
		var consumable_icon = perk_mini_scene.instantiate()
		# Store consumable type and item ID for hover functionality
		consumable_icon.set_meta("consumable_type", consumable_type)
		consumable_icon.set_meta("item_id", item_id)
		
		# Set the consumable texture
		var texture_rect = consumable_icon.get_node("TextureRect")
		if texture_rect:
			texture_rect.texture = icon_texture
		
		# Enable mouse detection for hover
		consumable_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Connect hover signals for consumable
		consumable_icon.mouse_entered.connect(_on_consumable_hover_start.bind(consumable_icon))
		consumable_icon.mouse_exited.connect(_on_perk_hover_end)
		
		active_perks_display.add_child(consumable_icon)
		print("CharacterDisplay: Added consumable icon to HBox")

func create_blessing_display(perk: PerkResource, effect: EffectResource):
	"""Create a display for an active blessing (from perks.tres)"""
	if perk_mini_scene and active_perks_display:
		var blessing_icon = perk_mini_scene.instantiate()
		# Store perk and effect data for hover functionality
		blessing_icon.set_meta("blessing_perk", perk)
		blessing_icon.set_meta("blessing_effect", effect)
		
		# Use the icon from the perk (not the effect)
		var texture_rect = blessing_icon.get_node("TextureRect")
		if texture_rect and perk.icon:
			texture_rect.texture = perk.icon
		
		# Enable mouse detection for hover
		blessing_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Connect hover signals for blessing
		blessing_icon.mouse_entered.connect(_on_blessing_hover_start.bind(blessing_icon))
		blessing_icon.mouse_exited.connect(_on_perk_hover_end)
		
		active_perks_display.add_child(blessing_icon)
		print("CharacterDisplay: Added blessing icon to HBox")

func _on_perk_hover_start(perk_icon):
	var perk_data = perk_icon.get_meta("perk_data")
	if perk_data:
		# Build tooltip with perk name and effects
		var tooltip_content = perk_data.perk_name
		
		# Add effect 1 if it exists
		if perk_data.effect1_description != "":
			var effect1_text = perk_data.effect1_description
			if perk_data.factor1 != 0.0:
				effect1_text += " " + str(int(perk_data.factor1)) + "%"
			tooltip_content += "\n" + effect1_text
		
		# Add effect 2 if it exists
		if perk_data.effect2_description != "":
			var effect2_text = perk_data.effect2_description
			if perk_data.factor2 != 0.0:
				effect2_text += " " + str(int(perk_data.factor2)) + "%"
			tooltip_content += "\n" + effect2_text
		
		TooltipManager.show_perk_tooltip(tooltip_content, perk_icon)

func _on_blessing_hover_start(blessing_icon):
	"""Show tooltip for blessings"""
	var perk_data = blessing_icon.get_meta("blessing_perk")
	var effect_data = blessing_icon.get_meta("blessing_effect")
	if perk_data and effect_data:
		# Build tooltip with perk name (not effect name) and effect description with factor
		var tooltip_content = perk_data.perk_name
		if effect_data.description != "":
			tooltip_content += "\n" + effect_data.description
			# Add factor
			if perk_data.factor1 > 0:
				var factor_text = str(int(perk_data.factor1)) if perk_data.factor1 == int(perk_data.factor1) else str(perk_data.factor1)
				tooltip_content += " " + factor_text + "%"
		
		TooltipManager.show_perk_tooltip(tooltip_content, blessing_icon)

func _on_consumable_hover_start(consumable_icon):
	"""Show tooltip for equipped consumables"""
	var consumable_type = consumable_icon.get_meta("consumable_type")
	var item_id = consumable_icon.get_meta("item_id")
	if consumable_type:
		var tooltip_content = ""
		
		if consumable_type == "Elixir":
			# Decode elixir ID and show combined effects
			tooltip_content = "Elixir"
			var id_str = str(item_id)
			var ingredient1_id = int(id_str.substr(4, 3))
			var ingredient2_id = int(id_str.substr(7, 3))
			var ingredient3_id = int(id_str.substr(10, 3))
			
			# Build effect map to combine duplicate effects
			var effect_map = {}  # Map effect_id to total factor
			for ingredient_id in [ingredient1_id, ingredient2_id, ingredient3_id]:
				if ingredient_id > 0:
					var ingredient_resource = GameInfo.items_db.get_item_by_id(ingredient_id)
					if ingredient_resource and ingredient_resource.effect_id > 0:
						if effect_map.has(ingredient_resource.effect_id):
							effect_map[ingredient_resource.effect_id] += ingredient_resource.effect_factor
						else:
							effect_map[ingredient_resource.effect_id] = ingredient_resource.effect_factor
			
			# Build effect text from combined effects
			for effect_id in effect_map.keys():
				var effect_data = GameInfo.effects_db.get_effect_by_id(effect_id)
				if effect_data:
					var effect_line = effect_data.description
					if effect_map[effect_id] > 0:
						effect_line += " " + str(effect_map[effect_id]) + "%"
					tooltip_content += "\n" + effect_line
			
		elif consumable_type == "Potion":
			# Show potion name and effect
			var potion_item = GameInfo.items_db.get_item_by_id(item_id)
			if potion_item:
				tooltip_content = potion_item.item_name
				if potion_item.effect_id > 0:
					var effect_data = GameInfo.effects_db.get_effect_by_id(potion_item.effect_id)
					if effect_data:
						var effect_line = effect_data.description
						if potion_item.effect_factor > 0:
							effect_line += " " + str(int(potion_item.effect_factor)) + "%"
						tooltip_content += "\n" + effect_line
		
		TooltipManager.show_perk_tooltip(tooltip_content, consumable_icon)

func _on_perk_hover_end():
	TooltipManager.hide_perk_tooltip()

func _on_talents_pressed():
	UIManager.instance.toggle_talents_bookmark()

func _on_details_pressed():
	UIManager.instance.toggle_details_bookmark()

func _on_avatar_pressed():
	UIManager.instance.toggle_avatar_overlay()
