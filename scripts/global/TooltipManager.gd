extends CanvasLayer

var tooltip_panel: Control

func _ready():
	# Create tooltip panel once
	var tooltip_scene = preload("res://Scenes/item_description.tscn")
	tooltip_panel = tooltip_scene.instantiate()
	add_child(tooltip_panel)
	tooltip_panel.visible = false
	
	# Ensure this layer is on top of everything
	layer = 100

func show_tooltip(item: GameInfo.Item, slot_node: Control = null):
	if tooltip_panel:
		tooltip_panel.show_description(item, slot_node)
		tooltip_panel.visible = true
		
		# Position based on slot type
		if slot_node:
			call_deferred("_position_tooltip", slot_node)
		else:
			call_deferred("_center_tooltip")

func hide_tooltip():
	if tooltip_panel:
		tooltip_panel.visible = false

func _position_tooltip(slot_node: Control):
	# Wait for tooltip to resize based on content
	await get_tree().process_frame
	await get_tree().process_frame
	
	var slot_global_pos = slot_node.global_position
	var slot_size = slot_node.size
	var tooltip_size = tooltip_panel.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	print("=== TOOLTIP POSITIONING ===")
	print("Slot global pos: ", slot_global_pos)
	print("Slot size: ", slot_size)
	print("Tooltip size: ", tooltip_size)
	print("Viewport size: ", viewport_size)
	
	# Check which container the slot belongs to
	var parent = slot_node.get_parent()
	var grandparent = parent.get_parent() if parent else null
	
	print("Parent: ", parent.name if parent else "null")
	print("Grandparent: ", grandparent.name if grandparent else "null")
	
	# Determine slot type by checking parent hierarchy
	var is_left_equip = false
	var is_right_equip = false
	var is_bag_slot = false
	
	if parent:
		if parent.name == "Left":
			is_left_equip = true
			print("Detected: LEFT EQUIP")
		elif parent.name == "Right":
			is_right_equip = true
			print("Detected: RIGHT EQUIP")
		elif parent.name == "Bag":
			is_bag_slot = true
			print("Detected: BAG SLOT")
	
	var final_pos = Vector2.ZERO
	
	if is_left_equip:
		# Position to the right of the slot
		final_pos.x = slot_global_pos.x + slot_size.x + 10  # 10px gap
		final_pos.y = slot_global_pos.y
		print("Positioning to RIGHT of slot")
		
		# Clamp to screen
		if final_pos.x + tooltip_size.x > viewport_size.x:
			final_pos.x = viewport_size.x - tooltip_size.x - 10
			print("Clamped horizontally")
		if final_pos.y + tooltip_size.y > viewport_size.y:
			final_pos.y = viewport_size.y - tooltip_size.y - 10
			print("Clamped vertically")
	
	elif is_right_equip:
		# Position to the left of the slot
		final_pos.x = slot_global_pos.x - tooltip_size.x - 10  # 10px gap
		final_pos.y = slot_global_pos.y
		print("Positioning to LEFT of slot")
		
		# Clamp to screen
		if final_pos.x < 10:
			final_pos.x = 10
			print("Clamped to left edge")
		if final_pos.y + tooltip_size.y > viewport_size.y:
			final_pos.y = viewport_size.y - tooltip_size.y - 10
			print("Clamped vertically")
	
	elif is_bag_slot:
		# Position above the slot
		final_pos.x = slot_global_pos.x + (slot_size.x / 2) - (tooltip_size.x / 2)  # Center horizontally
		final_pos.y = slot_global_pos.y - tooltip_size.y - 10  # 10px gap above
		print("Positioning ABOVE slot")
		
		# If it goes off the top, show it below instead
		if final_pos.y < 10:
			final_pos.y = slot_global_pos.y + slot_size.y + 10
			print("Not enough space above, positioning BELOW slot")
		
		# Clamp horizontally
		if final_pos.x < 10:
			final_pos.x = 10
			print("Clamped to left edge")
		if final_pos.x + tooltip_size.x > viewport_size.x:
			final_pos.x = viewport_size.x - tooltip_size.x - 10
			print("Clamped to right edge")
	
	else:
		# Default: center on screen
		print("No specific type detected, using CENTER")
		_center_tooltip()
		return
	
	print("Final position: ", final_pos)
	tooltip_panel.global_position = final_pos

func _center_tooltip():
	print("=== CENTERING TOOLTIP ===")
	# Center the tooltip on screen
	tooltip_panel.set_anchors_preset(Control.PRESET_CENTER)
	tooltip_panel.set_offsets_preset(Control.PRESET_CENTER)
