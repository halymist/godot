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
		name_label.text = "[b]" + item_data.item_name + "[/b]"
		
		# Handle strength stat - hide if 0
		if item_data.strength != 0:
			strength.text = str(item_data.strength)
			strength_container.visible = true
		else:
			strength_container.visible = false
		
		# Handle stamina stat - hide if 0
		if item_data.constitution != 0:
			stamina.text = str(item_data.constitution)
			stamina_container.visible = true
		else:
			stamina_container.visible = false
		
		# Handle agility stat - hide if 0
		if item_data.dexterity != 0:
			agility.text = str(item_data.dexterity)
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
		if item_data.effect_description != "":
			effect.text = "[i]" + item_data.effect_description + "[/i]"
			effect.visible = true
		else:
			effect.visible = false
		
		# Fit content to actual size
		call_deferred("_fit_content_size")
		
		# Position the panel relative to mouse/hover position if provided
		if mouse_position != Vector2.ZERO:
			call_deferred("position_near_cursor", mouse_position)
		
		visible = true
	else:
		visible = false

func _fit_content_size():
	# Let the layout update first
	await get_tree().process_frame
	
	# Calculate the required size based on visible content
	var content_height = 20  # Base padding
	var content_width = 200  # Minimum width
	
	# Add height for name (larger now)
	content_height += 35
	
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
	
	# Add consistent height for all visible stats
	content_height += visible_stat_count * 22  # 22px per stat line
	
	# Add height for effect if visible
	if effect.visible:
		content_height += effect.get_content_height() + 10
		content_width = max(content_width, effect.get_content_width() + 40)
	
	# Ensure minimum content size
	content_height = max(content_height, 60)  # Minimum height
	content_width = max(content_width, 180)   # Minimum width
	
	# Update panel size
	size = Vector2(content_width, content_height)
	custom_minimum_size = Vector2(content_width, content_height)

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
