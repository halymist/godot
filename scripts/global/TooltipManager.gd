extends CanvasLayer

var tooltip_panel: Control
var perk_tooltip_panel: Control

const PERK_TOOLTIP_MIN_WIDTH := 220.0
const PERK_TOOLTIP_MAX_WIDTH := 560.0
const PERK_TOOLTIP_WIDTH_RATIO := 0.60

func _ready():
	# Create item tooltip panel
	var tooltip_scene = preload("res://Scenes/item_description.tscn")
	tooltip_panel = tooltip_scene.instantiate()
	add_child(tooltip_panel)
	tooltip_panel.visible = false
	
	# Create perk tooltip panel
	var perk_tooltip_scene = preload("res://Scenes/perk_tooltip.tscn")
	perk_tooltip_panel = perk_tooltip_scene.instantiate()
	add_child(perk_tooltip_panel)
	perk_tooltip_panel.visible = false
	
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

func show_perk_tooltip(tooltip_text: String, slot_node: Control = null):
	if perk_tooltip_panel:
		var tooltip_label := perk_tooltip_panel.get_node("MarginContainer/TooltipLabel") as Label
		if tooltip_label:
			tooltip_label.text = tooltip_text
			tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
			var viewport_width = get_viewport().get_visible_rect().size.x
			var target_width = clamp(viewport_width * PERK_TOOLTIP_WIDTH_RATIO, PERK_TOOLTIP_MIN_WIDTH, PERK_TOOLTIP_MAX_WIDTH)
			tooltip_label.custom_minimum_size.x = target_width
			tooltip_label.reset_size()
			perk_tooltip_panel.reset_size()
		
		perk_tooltip_panel.visible = true
		
		# Position based on slot type
		if slot_node:
			call_deferred("_position_perk_tooltip", slot_node)
		else:
			call_deferred("_center_perk_tooltip")

func hide_perk_tooltip():
	if perk_tooltip_panel:
		perk_tooltip_panel.visible = false

func _position_tooltip(slot_node: Control):
	# Wait for tooltip to resize based on content
	await get_tree().process_frame
	await get_tree().process_frame
	
	var slot_global_pos = slot_node.global_position
	var slot_size = slot_node.size
	var tooltip_size = tooltip_panel.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	
	# Check which container the slot belongs to
	var parent = slot_node.get_parent()
	var _grandparent = parent.get_parent() if parent else null
	
	
	# Determine slot type by checking parent hierarchy
	var is_left_equip = false
	var is_right_equip = false
	var is_bag_slot = false
	
	if parent:
		if parent.name == "Left":
			is_left_equip = true
		elif parent.name == "Right":
			is_right_equip = true
		elif parent.name == "Bag":
			is_bag_slot = true
	
	var final_pos = Vector2.ZERO
	
	if is_left_equip:
		# Position to the right of the slot
		final_pos.x = slot_global_pos.x + slot_size.x + 10  # 10px gap
		final_pos.y = slot_global_pos.y
		
		# Clamp to screen
		if final_pos.x + tooltip_size.x > viewport_size.x:
			final_pos.x = viewport_size.x - tooltip_size.x - 10
		if final_pos.y + tooltip_size.y > viewport_size.y:
			final_pos.y = viewport_size.y - tooltip_size.y - 10
	
	elif is_right_equip:
		# Position to the left of the slot
		final_pos.x = slot_global_pos.x - tooltip_size.x - 10  # 10px gap
		final_pos.y = slot_global_pos.y
		
		# Clamp to screen
		if final_pos.x < 10:
			final_pos.x = 10
		if final_pos.y + tooltip_size.y > viewport_size.y:
			final_pos.y = viewport_size.y - tooltip_size.y - 10
	
	elif is_bag_slot:
		# Position above the slot
		final_pos.x = slot_global_pos.x + (slot_size.x / 2) - (tooltip_size.x / 2)  # Center horizontally
		final_pos.y = slot_global_pos.y - tooltip_size.y - 10  # 10px gap above
		
		# If it goes off the top, show it below instead
		if final_pos.y < 10:
			final_pos.y = slot_global_pos.y + slot_size.y + 10
		
		# Clamp horizontally
		if final_pos.x < 10:
			final_pos.x = 10
		if final_pos.x + tooltip_size.x > viewport_size.x:
			final_pos.x = viewport_size.x - tooltip_size.x - 10
	
	else:
		# Default: position above the slot
		final_pos.x = slot_global_pos.x + (slot_size.x / 2) - (tooltip_size.x / 2)  # Center horizontally
		final_pos.y = slot_global_pos.y - tooltip_size.y - 10  # 10px gap above
		
		# If it goes off the top, show it below instead
		if final_pos.y < 10:
			final_pos.y = slot_global_pos.y + slot_size.y + 10
		
		# Clamp horizontally
		if final_pos.x < 10:
			final_pos.x = 10
		if final_pos.x + tooltip_size.x > viewport_size.x:
			final_pos.x = viewport_size.x - tooltip_size.x - 10
	
	tooltip_panel.global_position = final_pos

func _center_tooltip():
	# Center the tooltip on screen
	tooltip_panel.set_anchors_preset(Control.PRESET_CENTER)
	tooltip_panel.set_offsets_preset(Control.PRESET_CENTER)

func _position_perk_tooltip(slot_node: Control):
	# Wait for tooltip to resize based on content
	await get_tree().process_frame
	await get_tree().process_frame
	
	var slot_global_pos = slot_node.global_position
	var slot_size = slot_node.size
	var tooltip_size = perk_tooltip_panel.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	
	# Position above the slot by default
	var final_pos = Vector2.ZERO
	final_pos.x = slot_global_pos.x + (slot_size.x / 2) - (tooltip_size.x / 2)  # Center horizontally
	final_pos.y = slot_global_pos.y - tooltip_size.y - 10  # 10px gap above
	
	
	# If it goes off the top, show it below instead
	if final_pos.y < 10:
		final_pos.y = slot_global_pos.y + slot_size.y + 10
	
	# Clamp horizontally
	if final_pos.x < 10:
		final_pos.x = 10
	if final_pos.x + tooltip_size.x > viewport_size.x:
		final_pos.x = viewport_size.x - tooltip_size.x - 10

	# Clamp vertically for long wrapped tooltips
	if final_pos.y + tooltip_size.y > viewport_size.y - 10:
		final_pos.y = viewport_size.y - tooltip_size.y - 10
	if final_pos.y < 10:
		final_pos.y = 10
	
	perk_tooltip_panel.global_position = final_pos

func _center_perk_tooltip():
	# Center the perk tooltip on screen
	perk_tooltip_panel.set_anchors_preset(Control.PRESET_CENTER)
	perk_tooltip_panel.set_offsets_preset(Control.PRESET_CENTER)
