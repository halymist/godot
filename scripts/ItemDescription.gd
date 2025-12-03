extends Panel
@export var name_label: RichTextLabel
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label
@export var effect: RichTextLabel

# References to the stat containers for hiding/showing
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
		
		# Handle effect description - hide if empty
		# Display effect from database with factor from item
		if item_data.effect_id > 0 and item_data.effect_description != "":
			var effect_text = item_data.effect_description
			# Append factor to description as integer
			if item_data.effect_factor != 0.0:
				effect_text += " " + str(int(item_data.effect_factor))
			
			effect.text = "[i]" + effect_text + "[/i]"
			effect.visible = true
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
