extends HBoxContainer

@export var perk_mini_scene: PackedScene

func _ready():
	# Connect to bag_slots_changed to update consumables immediately
	if GameInfo:
		GameInfo.bag_slots_changed.connect(update_active_perks)

func update_active_perks():
	print("ActivePerksDisplay: Updating active perks and effects...")
	
	# Clear existing icons
	for child in get_children():
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
		var blessing_effect = GameInfo.effects_db.get_effect_by_id(GameInfo.current_player.blessing)
		if blessing_effect:
			create_effect_display(blessing_effect)
	
	# Get active perks from GameInfo
	var active_perks = get_active_perks()
	print("ActivePerksDisplay: Found ", active_perks.size(), " active perks")
	
	# Create icon for each active perk
	for perk in active_perks:
		print("ActivePerksDisplay: Creating icon for: ", perk.perk_name)
		
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
			
			add_child(perk_icon)
			print("ActivePerksDisplay: Added perk icon to HBox")
		else:
			print("ERROR: perk_mini_scene is null!")

func create_consumable_display(icon_texture: Texture2D, consumable_type: String, item_id: int):
	"""Create a display for an equipped consumable (potion or elixir)"""
	if perk_mini_scene:
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
		
		add_child(consumable_icon)
		print("ActivePerksDisplay: Added consumable icon to HBox")

func create_effect_display(effect: EffectResource):
	"""Create a display for an active effect (like blessing)"""
	if perk_mini_scene:
		var effect_icon = perk_mini_scene.instantiate()
		# Store effect data in the icon for hover functionality
		effect_icon.set_meta("effect_data", effect)
		
		# Set the effect texture if available
		var texture_rect = effect_icon.get_node("TextureRect")
		if texture_rect and effect.icon:
			texture_rect.texture = effect.icon
		
		# Enable mouse detection for hover
		effect_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		
		# Connect hover signals for effect
		effect_icon.mouse_entered.connect(_on_effect_hover_start.bind(effect_icon))
		effect_icon.mouse_exited.connect(_on_perk_hover_end)
		
		add_child(effect_icon)
		print("ActivePerksDisplay: Added effect icon to HBox")

func _on_perk_hover_start(perk_icon):
	var perk_data = perk_icon.get_meta("perk_data")
	if perk_data:
		# Build tooltip with perk name and effects
		var tooltip_text = perk_data.perk_name
		
		# Add effect 1 if it exists
		if perk_data.effect1_description != "":
			var effect1_text = perk_data.effect1_description
			if perk_data.factor1 != 0.0:
				effect1_text += " " + str(int(perk_data.factor1))
			tooltip_text += "\n" + effect1_text
		
		# Add effect 2 if it exists
		if perk_data.effect2_description != "":
			var effect2_text = perk_data.effect2_description
			if perk_data.factor2 != 0.0:
				effect2_text += " " + str(int(perk_data.factor2))
			tooltip_text += "\n" + effect2_text
		
		TooltipManager.show_perk_tooltip(tooltip_text, perk_icon)

func _on_effect_hover_start(effect_icon):
	"""Show tooltip for active effects"""
	var effect_data = effect_icon.get_meta("effect_data")
	if effect_data:
		# Build tooltip with effect name and description
		var tooltip_text = effect_data.name
		if effect_data.description != "":
			tooltip_text += "\n" + effect_data.description
		
		TooltipManager.show_perk_tooltip(tooltip_text, effect_icon)

func _on_consumable_hover_start(consumable_icon):
	"""Show tooltip for equipped consumables"""
	var consumable_type = consumable_icon.get_meta("consumable_type")
	var item_id = consumable_icon.get_meta("item_id")
	if consumable_type:
		var tooltip_text = ""
		
		if consumable_type == "Elixir":
			# Decode elixir ID and show combined effects
			tooltip_text = "Elixir"
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
						effect_line += " " + str(effect_map[effect_id])
					tooltip_text += "\n" + effect_line
			
		elif consumable_type == "Potion":
			# Show potion name and effect
			var potion_item = GameInfo.items_db.get_item_by_id(item_id)
			if potion_item:
				tooltip_text = potion_item.item_name
				if potion_item.effect_id > 0:
					var effect_data = GameInfo.effects_db.get_effect_by_id(potion_item.effect_id)
					if effect_data:
						var effect_line = effect_data.description
						if potion_item.effect_factor > 0:
							effect_line += " " + str(int(potion_item.effect_factor))
						tooltip_text += "\n" + effect_line
		
		TooltipManager.show_perk_tooltip(tooltip_text, consumable_icon)

func _on_perk_hover_end():
	TooltipManager.hide_perk_tooltip()

func get_active_perks() -> Array:
	# Use the new helper method directly on the player
	return GameInfo.current_player.get_active_perks() if GameInfo.current_player else []
