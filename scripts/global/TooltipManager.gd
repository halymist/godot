extends CanvasLayer

var tooltip_panel: Control
var perk_tooltip_panel: Control
var _item_tooltip_request_id: int = 0
var _perk_tooltip_request_id: int = 0

const TOOLTIP_MARGIN := 10.0
const ITEM_TOOLTIP_MAX_WIDTH := 420.0
const ITEM_TOOLTIP_WIDTH_RATIO := 0.72
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
	if not tooltip_panel:
		return

	_item_tooltip_request_id += 1
	var request_id = _item_tooltip_request_id
	tooltip_panel.visible = false
	tooltip_panel.global_position = Vector2(-10000, -10000)
	tooltip_panel.show_description(item, null)
	_prepare_item_tooltip_size()
	tooltip_panel.visible = false

	if slot_node:
		call_deferred("_position_tooltip", slot_node, request_id)
	else:
		call_deferred("_center_tooltip", request_id)

func hide_tooltip():
	_item_tooltip_request_id += 1
	if tooltip_panel:
		tooltip_panel.visible = false

func show_perk_tooltip(tooltip_text: String, slot_node: Control = null):
	if not perk_tooltip_panel:
		return

	_perk_tooltip_request_id += 1
	var request_id = _perk_tooltip_request_id
	perk_tooltip_panel.visible = false
	perk_tooltip_panel.global_position = Vector2(-10000, -10000)

	var tooltip_label := perk_tooltip_panel.get_node("MarginContainer/TooltipLabel") as Label
	if tooltip_label:
		tooltip_label.text = tooltip_text.strip_edges()
		tooltip_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		var viewport_width = get_viewport().get_visible_rect().size.x
		var target_width = _get_label_wrap_width(tooltip_label, min(PERK_TOOLTIP_MAX_WIDTH, viewport_width * PERK_TOOLTIP_WIDTH_RATIO, viewport_width - TOOLTIP_MARGIN * 2.0), 24.0)
		tooltip_label.custom_minimum_size.x = target_width
		tooltip_label.reset_size()
		perk_tooltip_panel.custom_minimum_size.x = target_width
		perk_tooltip_panel.reset_size()

	if slot_node:
		call_deferred("_position_perk_tooltip", slot_node, request_id)
	else:
		call_deferred("_center_perk_tooltip", request_id)

func hide_perk_tooltip():
	_perk_tooltip_request_id += 1
	if perk_tooltip_panel:
		perk_tooltip_panel.visible = false

func _prepare_item_tooltip_size():
	if not tooltip_panel:
		return

	var viewport_width = get_viewport().get_visible_rect().size.x
	var max_width = min(ITEM_TOOLTIP_MAX_WIDTH, viewport_width * ITEM_TOOLTIP_WIDTH_RATIO, viewport_width - TOOLTIP_MARGIN * 2.0)
	var target_width = 0.0

	var measured_labels = [
		tooltip_panel.get("name_label"),
		tooltip_panel.get("effect"),
		tooltip_panel.get("socket_label")
	]
	for measured_label in measured_labels:
		if measured_label and measured_label is Label:
			target_width = max(target_width, _get_label_wrap_width(measured_label, max_width - 24.0, 24.0) + 24.0)

	target_width = min(target_width, max_width)
	tooltip_panel.custom_minimum_size.x = target_width

	var labels = [
		tooltip_panel.get("name_label"),
		tooltip_panel.get("effect"),
		tooltip_panel.get("socket_label")
	]
	for label in labels:
		if label and label is Label:
			label.autowrap_mode = TextServer.AUTOWRAP_WORD
			label.custom_minimum_size.x = max(0.0, target_width - 24.0)
			label.reset_size()

	tooltip_panel.reset_size()

func _get_label_wrap_width(label: Label, max_width: float, padding: float = 0.0) -> float:
	if label.text.is_empty():
		return 0.0
	var font = label.get_theme_font("font")
	var font_size = label.get_theme_font_size("font_size")
	var longest_line_width = 0.0
	for line in label.text.split("\n"):
		longest_line_width = max(longest_line_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	return min(max_width, longest_line_width + padding)

func _position_tooltip(slot_node: Control, request_id: int):
	await get_tree().process_frame
	await get_tree().process_frame
	if request_id != _item_tooltip_request_id:
		return
	if not tooltip_panel or not is_instance_valid(tooltip_panel):
		return
	if not slot_node or not is_instance_valid(slot_node):
		hide_tooltip()
		return
	
	var slot_global_pos = slot_node.global_position
	var slot_size = slot_node.size
	var tooltip_size = tooltip_panel.size
	var viewport_size = get_viewport().get_visible_rect().size

	var final_pos = _get_position_near_slot(slot_global_pos, slot_size, tooltip_size, viewport_size)
	tooltip_panel.global_position = final_pos
	tooltip_panel.visible = true

func _center_tooltip(request_id: int):
	await get_tree().process_frame
	if request_id != _item_tooltip_request_id or not tooltip_panel:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	tooltip_panel.global_position = (viewport_size - tooltip_panel.size) / 2.0
	tooltip_panel.visible = true

func _position_perk_tooltip(slot_node: Control, request_id: int):
	await get_tree().process_frame
	await get_tree().process_frame
	if request_id != _perk_tooltip_request_id:
		return
	if not perk_tooltip_panel or not is_instance_valid(perk_tooltip_panel):
		return
	if not slot_node or not is_instance_valid(slot_node):
		hide_perk_tooltip()
		return
	
	var slot_global_pos = slot_node.global_position
	var slot_size = slot_node.size
	var tooltip_size = perk_tooltip_panel.size
	var viewport_size = get_viewport().get_visible_rect().size
	var final_pos = _get_position_near_slot(slot_global_pos, slot_size, tooltip_size, viewport_size)
	perk_tooltip_panel.global_position = final_pos
	perk_tooltip_panel.visible = true

func _center_perk_tooltip(request_id: int):
	await get_tree().process_frame
	if request_id != _perk_tooltip_request_id or not perk_tooltip_panel:
		return
	var viewport_size = get_viewport().get_visible_rect().size
	perk_tooltip_panel.global_position = (viewport_size - perk_tooltip_panel.size) / 2.0
	perk_tooltip_panel.visible = true

func _get_position_near_slot(slot_global_pos: Vector2, slot_size: Vector2, tooltip_size: Vector2, viewport_size: Vector2) -> Vector2:
	var final_pos = Vector2(
		slot_global_pos.x + slot_size.x / 2.0 - tooltip_size.x / 2.0,
		slot_global_pos.y - tooltip_size.y - TOOLTIP_MARGIN
	)

	if final_pos.y < TOOLTIP_MARGIN:
		final_pos.y = slot_global_pos.y + slot_size.y + TOOLTIP_MARGIN
	if final_pos.y + tooltip_size.y > viewport_size.y - TOOLTIP_MARGIN:
		final_pos.y = viewport_size.y - tooltip_size.y - TOOLTIP_MARGIN
	if final_pos.x < TOOLTIP_MARGIN:
		final_pos.x = TOOLTIP_MARGIN
	if final_pos.x + tooltip_size.x > viewport_size.x - TOOLTIP_MARGIN:
		final_pos.x = viewport_size.x - tooltip_size.x - TOOLTIP_MARGIN

	return final_pos
