extends Panel
@export var name_label: RichTextLabel
@export var price_label: Label
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label
@export var effect: RichTextLabel

# References to the stat containers for hiding/showing
@onready var price_container = price_label.get_parent() if price_label else null
@onready var strength_container = strength.get_parent()
@onready var stamina_container = stamina.get_parent()
@onready var agility_container = agility.get_parent()
@onready var luck_container = luck.get_parent()
@onready var armor_container = armor.get_parent()

func show_description(item_data: GameInfo.Item, mouse_position: Vector2 = Vector2.ZERO):
	if item_data:
		var display_name = item_data.item_name
		if item_data.get("tempered") and item_data.tempered > 0:
			display_name += " +" + str(item_data.tempered)
		name_label.text = "[b]" + display_name + "[/b]"
		
		# Display price if available and > 0
		if price_label and price_container:
			if item_data.price > 0:
				# Check if item is in vendor slots (105-112) - show 2x price for buying
				var display_price = item_data.price
				if item_data.bag_slot_id >= 105 and item_data.bag_slot_id <= 112:
					display_price = item_data.price * 2
				price_label.text = str(display_price) + " gold"
				price_container.visible = true
			else:
				price_container.visible = false
		
		# Check if this is an elixir (ID > 1000)
		var is_elixir = item_data.id > 1000
		
		if is_elixir:
			# Hide all stat containers for elixirs
			strength_container.visible = false
			stamina_container.visible = false
			agility_container.visible = false
			luck_container.visible = false
			armor_container.visible = false
			
			# Decode ingredient IDs from elixir ID using string manipulation
			# Format: 1000000000000 + ingredientID1(3 digits) + ingredientID2(3 digits) + ingredientID3(3 digits)
			var id_str = str(item_data.id)
			var ingredient1_id = int(id_str.substr(4, 3))  # Characters 4-6 (positions 4,5,6)
			var ingredient2_id = int(id_str.substr(7, 3))  # Characters 7-9 (positions 7,8,9)
			var ingredient3_id = int(id_str.substr(10, 3)) # Characters 10-12 (positions 10,11,12)
			
			# Build effect map to combine duplicate effects
			var effect_map = {}  # Map effect_id to total factor
			for ingredient_id in [ingredient1_id, ingredient2_id, ingredient3_id]:
				if ingredient_id > 0:
					var ingredient_resource = GameInfo.items_db.get_item_by_id(ingredient_id)
					if ingredient_resource != null and ingredient_resource.effect_id > 0:
						# Add factor to existing effect or create new entry
						var factor = ingredient_resource.effect_factor
						if effect_map.has(ingredient_resource.effect_id):
							effect_map[ingredient_resource.effect_id] += factor
						else:
							effect_map[ingredient_resource.effect_id] = factor
			
			# Build effect text from combined effects
			var effect_texts = []
			for effect_id in effect_map.keys():
				var effect_data = GameInfo.effects_db.get_effect_by_id(effect_id)
				if effect_data:
					var effect_line = effect_data.description
					if effect_map[effect_id] > 0:
						effect_line += " " + str(effect_map[effect_id])
					effect_texts.append(effect_line)
			
			# Display combined effects
			if effect_texts.size() > 0:
				effect.text = "[i]" + "\n".join(effect_texts) + "[/i]"
				effect.visible = true
			else:
				effect.visible = false
		else:
			# Regular item - show stats normally
			# Handle strength stat - hide if 0
			if item_data.strength != 0:
				strength.text = str(item_data.strength)
				strength_container.visible = true
			else:
				strength_container.visible = false
			
			# Handle stamina stat - hide if 0
			if item_data.stamina != 0:
				stamina.text = str(item_data.stamina)
				stamina_container.visible = true
			else:
				stamina_container.visible = false
			
			# Handle agility stat - hide if 0
			if item_data.agility != 0:
				agility.text = str(item_data.agility)
				agility_container.visible = true
			else:
				agility_container.visible = false
			
			# Handle luck stat - hide if 0
			if item_data.luck != 0:
				luck.text = str(item_data.luck)
				luck_container.visible = true
			else:
				luck_container.visible = false
			
			# Handle armor stat - hide if 0
			if item_data.armor != 0:
				armor.text = str(item_data.armor)
				armor_container.visible = true
			else:
				armor_container.visible = false
			
			# Handle effect description - show enchant_overdrive if present, otherwise show regular effect
			var display_effect_id = item_data.effect_id
			var display_effect_factor = item_data.effect_factor
			
			# If item has enchant_overdrive, use that instead
			if item_data.enchant_overdrive > 0:
				var overdrive_effect = GameInfo.effects_db.get_effect_by_id(item_data.enchant_overdrive)
				if overdrive_effect:
					display_effect_id = item_data.enchant_overdrive
					display_effect_factor = overdrive_effect.factor
			
			# Display effect from database with factor
			if display_effect_id > 0:
				var effect_data = GameInfo.effects_db.get_effect_by_id(display_effect_id)
				if effect_data and effect_data.description != "":
					var effect_text = effect_data.description
					# Append factor to description as integer
					if display_effect_factor != 0.0:
						effect_text += " " + str(int(display_effect_factor))
					
					effect.text = "[i]" + effect_text + "[/i]"
					effect.visible = true
				else:
					effect.visible = false
			else:
				effect.visible = false
		
		# Show first, then fit content size to ensure proper layout calculation
		visible = true
		
		# Use multiple deferred calls to ensure proper sizing
		call_deferred("_fit_content_size")
		
		# Position the panel relative to mouse/hover position if provided
		if mouse_position != Vector2.ZERO:
			call_deferred("position_near_cursor", mouse_position)
	else:
		visible = false

func _fit_content_size():
	# Force layout update multiple times to ensure consistency
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Reset size first to get accurate content measurements
	custom_minimum_size = Vector2.ZERO
	size = Vector2(200, 60)  # Start with minimum size
	
	# Force another layout pass
	await get_tree().process_frame
	
	# Calculate the required size based on visible content
	var content_height = 25  # Base padding + spacing
	var content_width = 200  # Minimum width
	
	# Add height for name (RichTextLabel needs time to calculate)
	if name_label.visible:
		content_height += max(30, name_label.get_content_height())
	
	# Count visible stats and add consistent spacing
	var visible_stat_count = 0
	if strength_container.visible:
		visible_stat_count += 1
	if stamina_container.visible:
		visible_stat_count += 1
	if agility_container.visible:
		visible_stat_count += 1
	if luck_container.visible:
		visible_stat_count += 1
	if armor_container.visible:
		visible_stat_count += 1
	if price_container and price_container.visible:
		visible_stat_count += 1
	
	# Add consistent height for all visible stats (with spacing)
	if visible_stat_count > 0:
		content_height += visible_stat_count * 25 + 10  # 25px per stat line + spacing
	
	# Add height for effect if visible (RichTextLabel needs proper sizing)
	if effect.visible and effect.text != "":
		# Force effect to calculate its content size
		effect.custom_minimum_size = Vector2.ZERO
		await get_tree().process_frame
		
		var effect_height = max(20, effect.get_content_height())
		content_height += effect_height + 15  # Extra spacing for effect
		
		# Calculate width based on effect content
		var effect_width = max(200, effect.get_content_width() + 40)
		content_width = max(content_width, effect_width)
	
	# Ensure minimum content size with some padding
	content_height = max(content_height, 70)   # Minimum height
	content_width = max(content_width, 200)    # Minimum width
	
	# Apply the calculated size
	var new_size = Vector2(content_width, content_height)
	custom_minimum_size = new_size
	size = new_size
	
	# Force final layout update
	await get_tree().process_frame

func position_near_cursor(cursor_pos: Vector2):
	var viewport_size = get_viewport().get_visible_rect().size
	var panel_size = size
	
	# Default position: to the right and below cursor
	var new_pos = cursor_pos + Vector2(20, 20)
	
	# Check if panel would go off screen on the right
	if new_pos.x + panel_size.x > viewport_size.x:
		new_pos.x = cursor_pos.x - panel_size.x - 20
	
	# Check if panel would go off screen on the bottom
	if new_pos.y + panel_size.y > viewport_size.y:
		new_pos.y = cursor_pos.y - panel_size.y - 20
	
	# Ensure panel doesn't go off screen on the left or top
	new_pos.x = max(10, new_pos.x)
	new_pos.y = max(10, new_pos.y)
	
	position = new_pos

func hide_description():
	visible = false
