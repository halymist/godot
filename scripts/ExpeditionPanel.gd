extends TextureRect

const UI_UTILS = preload("res://scripts/utils/UIUtils.gd")

const EXPEDITION_QUEST_START_COST: int = 0
const EXPEDITION_MIN_HEALTH_RATIO: float = 0.20
const EXPEDITION_LOW_HEALTH_MESSAGE: String = "You need at least 20% health to start an expedition quest."
const NODE_BUTTON_SIZE: Vector2 = Vector2(32, 32)
const CAMERA_MOVE_DURATION: float = 0.28
const EMBARK_ACTION_TEXT: String = "Embark"
const NODE_BORDER_WIDTH: int = 1
const NODE_AVAILABLE_FILL: Color = Color(0.42, 0.30, 0.14, 0.96)
const NODE_AVAILABLE_BORDER: Color = Color(0.95, 0.75, 0.38, 1.0)
const NODE_COMPLETED_FILL: Color = Color(0.18, 0.22, 0.24, 0.94)
const NODE_COMPLETED_BORDER: Color = Color(0.55, 0.58, 0.54, 0.9)
const NODE_SELECTED_BORDER: Color = Color(1.0, 0.92, 0.62, 1.0)
const BOTTOM_UI_MARGIN: float = 104.0
const MAP_WHEEL_PAN_STEP: float = 64.0

@export var health_bar: TextureProgressBar
@export var map_area: Control
@export var node_overlay_panel: Control
@export var node_description_label: Label
@export var node_action_button: Button

@export var currency_check_icon: Texture2D

var current_expedition_id: int = 0
var current_expedition: ExpeditionData = null
var node_buttons: Dictionary = {}
var pending_node_id: int = 0
var pending_node_start_cost: int = 0
var map_content: Control = null
var map_view: TextureRect = null
var map_image_size: Vector2 = Vector2.ZERO
var map_base_scale: float = 1.0
var map_view_offset: Vector2 = Vector2.ZERO
var map_tween: Tween = null
var map_dragging: bool = false
var selected_node_id: int = 0
var selected_node_completed: bool = false

func _ready():
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_ensure_map_view()
	_setup_node_overlay()

func _on_visibility_changed():
	if not visible:
		return

	_update_health_bar()
	if GameInfo.current_player and GameInfo.current_player.expedition and GameInfo.current_player.expedition.size() > 0:
		var expedition_id = int(GameInfo.current_player.expedition[0])
		if current_expedition_id != expedition_id:
			start_expedition(expedition_id)
		else:
			_preserve_current_graph_state()

func start_expedition(expedition_id: int, force_refresh: bool = false):
	var is_same_expedition = current_expedition != null and current_expedition_id == expedition_id
	current_expedition_id = expedition_id
	current_expedition = GameInfo.expeditions_db.get_expedition(expedition_id) if GameInfo.expeditions_db else null
	if not current_expedition:
		var db_count = GameInfo.expeditions_db.expeditions.size() if GameInfo.expeditions_db else 0
		print("[expedition:panel] missing expedition id=", expedition_id, " db_count=", db_count)
		return
	print("[expedition:panel] open id=", expedition_id, " settlement=", current_expedition.settlement_id, " nodes=", current_expedition.nodes.size(), " edges=", current_expedition.edges.size())

	if GameInfo.current_player:
		GameInfo.current_player.expedition = [expedition_id]

	_ensure_map_view()
	_setup_node_overlay()
	texture = null
	if is_same_expedition and not force_refresh:
		visible = true
		_preserve_current_graph_state()
		return

	if not is_same_expedition:
		_reset_map_view_offset()
	_update_map_view_transform()
	if not is_same_expedition:
		selected_node_id = 0
		selected_node_completed = false
	_set_node_overlay_text("Select a node to inspect it.")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
	visible = true
	refresh_graph()

func _preserve_current_graph_state():
	_update_health_bar()
	_update_map_view_transform()
	_refresh_node_positions()
	if selected_node_id <= 0:
		return

	var completed_ids = _get_completed_node_ids()
	_show_current_selection(completed_ids)

func refresh_graph():
	if not current_expedition:
		return

	_update_health_bar()
	_clear_graph()

	_set_node_overlay_text("Loading...")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)

	var completed_ids = _get_completed_node_ids()
	var available_ids = _get_available_node_ids(completed_ids)

	_update_map_view_transform()
	_log_graph_state(available_ids, completed_ids)
	_draw_edges(available_ids, completed_ids)
	for node in current_expedition.nodes:
		if node.node_id in available_ids:
			_add_node_button(node, node.node_id in completed_ids)

	_refresh_node_positions()
	if selected_node_id > 0:
		_show_current_selection(completed_ids)
	elif available_ids.size() > 0:
		_select_initial_node(available_ids, completed_ids)
	else:
		_set_node_overlay_text("Select a node to inspect it." if available_ids.size() > 0 else "No nodes available.")
		_set_action_button_state(EMBARK_ACTION_TEXT, false, true)

func _clear_graph():
	for button in node_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	node_buttons.clear()
	pending_node_id = 0
	queue_redraw()

func _draw_edges(_available_ids: Array, _completed_ids: Array):
	queue_redraw()

func _has_server_progress() -> bool:
	if not GameInfo.current_player:
		return false
	if int(GameInfo.current_player.expedition_progress_id) != current_expedition_id:
		return false
	var has_completed = GameInfo.current_player.expedition_completed_node_ids.size() > 0
	var has_unlocked = GameInfo.current_player.expedition_unlocked_node_ids.size() > 0
	var has_active = GameInfo.current_player.expedition_active_node_id > 0
	return has_completed or has_unlocked or has_active

func _get_completed_node_ids() -> Array[int]:
	if _has_server_progress():
		return GameInfo.current_player.expedition_completed_node_ids.duplicate()
	var quest_log = GameInfo.current_player.quest_log if GameInfo.current_player else []
	return current_expedition.get_completed_node_ids_from_quest_log(quest_log) if current_expedition else []

func _get_available_node_ids(completed_ids: Array) -> Array[int]:
	if _has_server_progress():
		var available_ids: Array[int] = []
		for node_id in completed_ids:
			if node_id not in available_ids:
				available_ids.append(int(node_id))
		for node_id in GameInfo.current_player.expedition_unlocked_node_ids:
			if node_id not in available_ids:
				available_ids.append(int(node_id))
		var active_node_id = int(GameInfo.current_player.expedition_active_node_id)
		if active_node_id > 0 and active_node_id not in available_ids:
			available_ids.append(active_node_id)
		return available_ids
	var quest_log = GameInfo.current_player.quest_log if GameInfo.current_player else []
	var available_ids: Array[int] = []
	if current_expedition:
		available_ids = current_expedition.get_available_node_ids(quest_log)
	if available_ids.is_empty() and current_expedition:
		for node in current_expedition.get_start_nodes():
			if node.node_id not in available_ids:
				available_ids.append(int(node.node_id))
	return available_ids

func _log_graph_state(available_ids: Array, completed_ids: Array):
	if not current_expedition:
		return
	var start_ids: Array[int] = []
	for node in current_expedition.get_start_nodes():
		start_ids.append(int(node.node_id))
	var progress_id := 0
	var unlocked_count := 0
	var active_node_id := 0
	if GameInfo.current_player:
		progress_id = int(GameInfo.current_player.expedition_progress_id)
		unlocked_count = GameInfo.current_player.expedition_unlocked_node_ids.size()
		active_node_id = int(GameInfo.current_player.expedition_active_node_id)
	print(
		"[expedition:graph] id=", current_expedition_id,
		" nodes=", current_expedition.nodes.size(),
		" starts=", start_ids,
		" available=", available_ids,
		" completed=", completed_ids,
		" progress_id=", progress_id,
		" unlocked_count=", unlocked_count,
		" active=", active_node_id,
		" viewport=", _map_viewport_size(),
		" image=", map_image_size,
		" scale=", map_base_scale,
		" offset=", map_view_offset
	)

func _draw():
	if not current_expedition or not GameInfo.current_player:
		return

	var completed_ids = _get_completed_node_ids()
	var available_ids = _get_available_node_ids(completed_ids)
	for edge in current_expedition.edges:
		if edge.node_a not in available_ids or edge.node_b not in available_ids:
			continue
		var node_a = current_expedition.get_node(edge.node_a)
		var node_b = current_expedition.get_node(edge.node_b)
		if not node_a or not node_b:
			continue
		var color = Color(0.74, 0.58, 0.32, 0.78) if edge.node_a in completed_ids and edge.node_b in completed_ids else Color(0.63, 0.58, 0.50, 0.42)
		var from_point = _node_position_on_panel(node_a)
		var to_point = _node_position_on_panel(node_b)
		if not _is_point_inside_map_viewport(from_point) or not _is_point_inside_map_viewport(to_point):
			continue
		draw_line(from_point, to_point, color, 2.0, true)

func _add_node_button(node: Resource, completed: bool):
	var button = Button.new()
	button.custom_minimum_size = NODE_BUTTON_SIZE
	button.size = NODE_BUTTON_SIZE
	button.text = ""
	button.tooltip_text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.set_meta("completed", completed)
	_apply_node_visual(button, completed, false)
	button.pressed.connect(_on_node_pressed.bind(node, completed))
	_get_map_content().add_child(button)
	node_buttons[node.node_id] = button
	_position_node_button(button, node)

func _position_node_button(button: Button, node: Resource):
	var center = _node_position_in_map(node)
	var button_size = button.size if button.size.x > 0.0 and button.size.y > 0.0 else NODE_BUTTON_SIZE
	button.position = center - button_size * 0.5

func _make_node_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.border_width_left = NODE_BORDER_WIDTH
	style.border_width_top = NODE_BORDER_WIDTH
	style.border_width_right = NODE_BORDER_WIDTH
	style.border_width_bottom = NODE_BORDER_WIDTH
	style.corner_radius_top_left = int(NODE_BUTTON_SIZE.x / 2.0)
	style.corner_radius_top_right = int(NODE_BUTTON_SIZE.x / 2.0)
	style.corner_radius_bottom_left = int(NODE_BUTTON_SIZE.x / 2.0)
	style.corner_radius_bottom_right = int(NODE_BUTTON_SIZE.x / 2.0)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 3
	return style

func _apply_node_visual(button: Button, completed: bool, selected: bool):
	if not button:
		return
	var fill = NODE_COMPLETED_FILL if completed else NODE_AVAILABLE_FILL
	var border = NODE_COMPLETED_BORDER if completed else NODE_AVAILABLE_BORDER
	if selected:
		border = NODE_SELECTED_BORDER

	button.add_theme_stylebox_override("normal", _make_node_style(fill, border))
	button.add_theme_stylebox_override("hover", _make_node_style(fill.lightened(0.08), border))
	button.add_theme_stylebox_override("pressed", _make_node_style(fill.darkened(0.08), border))
	button.add_theme_stylebox_override("disabled", _make_node_style(fill.darkened(0.12), border))

func _refresh_node_visual_states():
	for node_id in node_buttons.keys():
		var button = node_buttons.get(node_id, null)
		if not button or not is_instance_valid(button):
			continue
		var completed = bool(button.get_meta("completed", false))
		var is_selected = int(node_id) == selected_node_id
		_apply_node_visual(button, completed, is_selected)

func _node_position_in_map(node: Resource) -> Vector2:
	return _node_rendered_position(node)

func _node_position_on_panel(node: Resource) -> Vector2:
	return _map_origin() + map_view_offset + _node_position_in_map(node)

func _is_point_inside_map_viewport(point: Vector2) -> bool:
	var map_rect = Rect2(_map_origin(), _map_viewport_size())
	return map_rect.has_point(point)

func _notification(what):
	if what == NOTIFICATION_RESIZED and current_expedition:
		_update_map_view_transform()
		_refresh_node_positions()
		_recenter_selected_node_immediate()
		queue_redraw()

func _on_node_pressed(node: Resource, completed: bool = false):
	_apply_node_selection(node, completed, true)

func _on_embark_button_pressed():
	if selected_node_id <= 0 or selected_node_completed:
		return
	if pending_node_id > 0:
		return
	if not UIManager.instance or not UIManager.instance.quest or not Websocket:
		return
	if not GameInfo.current_player:
		return

	if _is_health_blocked():
		_set_node_overlay_text(EXPEDITION_LOW_HEALTH_MESSAGE)
		_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
		return

	_confirm_node_start(selected_node_id)

func _confirm_node_start(node_id: int):
	if pending_node_id > 0:
		return
	if not GameInfo.current_player or not Websocket:
		return
	if not Websocket.connected:
		_set_node_overlay_text("Connection lost. Please try again.")
		return

	pending_node_id = node_id
	var button = node_buttons.get(pending_node_id, null)
	if button:
		button.disabled = true
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)

	pending_node_start_cost = EXPEDITION_QUEST_START_COST
	if EXPEDITION_QUEST_START_COST > 0:
		UIManager.instance.update_silver(-EXPEDITION_QUEST_START_COST)

	Websocket.start_expedition_node(pending_node_id)

func _refund_pending_node_start_cost():
	if pending_node_start_cost <= 0:
		return
	if UIManager.instance:
		UIManager.instance.update_silver(pending_node_start_cost)
	pending_node_start_cost = 0

func _is_health_blocked() -> bool:
	if not GameInfo.current_player:
		return false
	var total_stats = GameInfo.current_player.get_total_stats()
	var max_health = max(1, int(total_stats.stamina) * 10)
	var current_health = max(0, max_health - int(GameInfo.current_player.depleted_health))
	return float(current_health) / float(max_health) < EXPEDITION_MIN_HEALTH_RATIO

func handle_node_start_response(success: bool, node_id: int, quest_id: int, arrival_timestamp: String = "", message: String = ""):

	if node_id <= 0:
		node_id = pending_node_id

	if pending_node_id == node_id:
		pending_node_id = 0

	var button = node_buttons.get(node_id, null)
	if button:
		button.disabled = false

	if not success:
		_refund_pending_node_start_cost()
		_set_node_overlay_text(message if message != "" else "Unable to start this node.")
		if selected_node_completed:
			_set_completed_node_action_state()
		else:
			_set_action_button_state(EMBARK_ACTION_TEXT, selected_node_id > 0, true)
		return

	if quest_id <= 0:
		_refund_pending_node_start_cost()
		_set_node_overlay_text("Server returned invalid quest for this node.")
		if selected_node_completed:
			_set_completed_node_action_state()
		else:
			_set_action_button_state(EMBARK_ACTION_TEXT, selected_node_id > 0, true)
		return

	pending_node_start_cost = 0

	_set_node_overlay_text("Travel started...")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)

	if UIManager.instance and UIManager.instance.map_panel and UIManager.instance.map_panel.has_method("start_expedition_node_travel"):
		UIManager.instance.map_panel.start_expedition_node_travel(current_expedition_id, node_id, quest_id, arrival_timestamp)
	else:
		# Fallback to old behavior if map travel method is unavailable.
		UIManager.instance.quest.load_expedition_node(current_expedition_id, node_id, quest_id)

func handle_expedition_failed(message: String):
	_set_node_overlay_text(message if message != "" else "Expedition ended. Return home.")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
	if GameInfo.current_player:
		GameInfo.current_player.expedition = []
		GameInfo.current_player.traveling_destination = null
		GameInfo.current_player.traveling = 0
	if UIManager.instance and UIManager.instance.map_panel:
		UIManager.instance.map_panel.reset_expedition_state()
	_update_health_bar()

func handle_expedition_end(message: String):
	handle_expedition_failed(message)

func end_expedition():
	current_expedition_id = 0
	current_expedition = null
	visible = false
	if map_view:
		map_view.texture = null
	selected_node_id = 0
	selected_node_completed = false
	_set_node_overlay_text("Select a node to inspect it.")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
	if GameInfo.current_player:
		GameInfo.current_player.expedition = []
	_clear_graph()

func _ensure_map_view():
	if map_view and is_instance_valid(map_view):
		return

	var parent = _get_map_parent()
	parent.clip_contents = true
	parent.mouse_filter = Control.MOUSE_FILTER_PASS
	if not parent.gui_input.is_connected(_on_map_area_gui_input):
		parent.gui_input.connect(_on_map_area_gui_input)

	map_content = Control.new()
	map_content.name = "MapContent"
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_content.z_index = 0
	parent.add_child(map_content)

	map_view = TextureRect.new()
	map_view.name = "MapView"
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.stretch_mode = TextureRect.STRETCH_SCALE
	map_view.z_index = 0
	map_content.add_child(map_view)
	parent.move_child(map_content, 0)

func _setup_node_overlay():
	if node_action_button and not node_action_button.pressed.is_connected(_on_embark_button_pressed):
		node_action_button.pressed.connect(_on_embark_button_pressed)
	if node_overlay_panel and is_instance_valid(node_overlay_panel):
		node_overlay_panel.visible = true

func _set_node_overlay_text(text_value: String):
	if node_description_label and is_instance_valid(node_description_label):
		node_description_label.text = text_value

func _set_action_button_state(text_value: String, enabled: bool, show_price: bool):
	if node_action_button and is_instance_valid(node_action_button):
		node_action_button.visible = true
		node_action_button.disabled = not enabled

		var action_label = node_action_button.get_node_or_null("Content/ActionLabel") as Label
		var price_label = node_action_button.get_node_or_null("Content/PriceLabel") as Label
		var currency_icon = node_action_button.get_node_or_null("Content/CurrencyIcon") as TextureRect
		var closing_paren = node_action_button.get_node_or_null("Content/ClosingParen") as Label

		if action_label and price_label and currency_icon and closing_paren:
			node_action_button.text = ""
			node_action_button.icon = null
			action_label.text = text_value
			price_label.text = str(EXPEDITION_QUEST_START_COST)
			price_label.visible = show_price and EXPEDITION_QUEST_START_COST > 0
			price_label.add_theme_color_override("font_color", UI_UTILS.PRICE_NORMAL)
			currency_icon.visible = show_price and EXPEDITION_QUEST_START_COST > 0
			closing_paren.visible = false
		else:
			node_action_button.text = text_value
			node_action_button.icon = currency_check_icon if show_price and EXPEDITION_QUEST_START_COST > 0 else null

func _set_completed_node_action_state():
	if node_action_button and is_instance_valid(node_action_button):
		node_action_button.disabled = true
		node_action_button.visible = false

func _update_selected_node_action_state():
	var can_embark = selected_node_id > 0 and not selected_node_completed and pending_node_id <= 0 and not _is_health_blocked()
	_set_action_button_state(EMBARK_ACTION_TEXT, can_embark, true)

func _build_node_overlay_text(node: Resource, completed: bool) -> String:
	if node.label != "":
		return node.label
	if completed:
		return "Completed node"
	return "Unknown node"

func _show_current_selection(completed_ids: Array):
	if not current_expedition:
		return

	var selected_node = current_expedition.get_node(selected_node_id)
	if selected_node:
		_apply_node_selection(selected_node, selected_node_id in completed_ids, false)

func _apply_node_selection(node: Resource, completed: bool, center_camera: bool):
	if center_camera:
		_center_map_on_node(node)
	selected_node_id = int(node.node_id)
	selected_node_completed = completed
	if not completed and _is_health_blocked():
		_set_node_overlay_text(EXPEDITION_LOW_HEALTH_MESSAGE)
	else:
		_set_node_overlay_text(_build_node_overlay_text(node, completed))
	_refresh_node_visual_states()

	if completed:
		_set_completed_node_action_state()
		return

	if pending_node_id > 0:
		_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
		return

	_update_selected_node_action_state()

func _select_initial_node(available_ids: Array, completed_ids: Array):
	var node_id := 0
	if GameInfo.current_player and GameInfo.current_player.expedition_active_node_id > 0:
		var active_node_id = int(GameInfo.current_player.expedition_active_node_id)
		if active_node_id in available_ids:
			node_id = active_node_id
	if node_id <= 0:
		for available_id in available_ids:
			if not completed_ids.has(int(available_id)):
				node_id = int(available_id)
				break
	if node_id <= 0 and available_ids.size() > 0:
		node_id = int(available_ids[0])

	var node = current_expedition.get_node(node_id) if current_expedition else null
	if not node:
		_set_node_overlay_text("No visible expedition nodes matched server progress.")
		_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
		return

	_apply_node_selection(node, completed_ids.has(node_id), false)
	_set_map_center_on_node_immediate(node)

func _recenter_selected_node_immediate():
	if not current_expedition or selected_node_id <= 0:
		return
	var node = current_expedition.get_node(selected_node_id)
	if node:
		_set_map_center_on_node_immediate(node)

func _reset_map_view_offset():
	map_view_offset = Vector2.ZERO

func _get_map_image_size() -> Vector2:
	var expedition_map_texture = current_expedition.get_map_texture() if current_expedition else null
	if expedition_map_texture:
		return expedition_map_texture.get_size()
	if map_view and map_view.texture:
		return map_view.texture.get_size()
	return Vector2(max(_map_viewport_size().x, 1.0), max(_map_viewport_size().y, 1.0))

func _map_viewport_size() -> Vector2:
	if map_area and is_instance_valid(map_area):
		return Vector2(max(1.0, map_area.size.x), max(1.0, map_area.size.y))
	var bottom_height = BOTTOM_UI_MARGIN
	if node_overlay_panel and is_instance_valid(node_overlay_panel):
		bottom_height = max(bottom_height, size.y - node_overlay_panel.position.y)
	return Vector2(size.x, max(1.0, size.y - bottom_height))

func _get_map_parent() -> Control:
	return map_area if map_area and is_instance_valid(map_area) else self

func _get_map_content() -> Control:
	if map_content and is_instance_valid(map_content):
		return map_content
	return _get_map_parent()

func _map_origin() -> Vector2:
	return map_area.position if map_area and is_instance_valid(map_area) else Vector2.ZERO

func _update_map_view_transform():
	if not map_view:
		return

	var expedition_map_texture = current_expedition.get_map_texture() if current_expedition else null
	if expedition_map_texture:
		map_view.texture = expedition_map_texture

	map_image_size = _get_map_image_size()
	if map_image_size.x <= 0.0 or map_image_size.y <= 0.0:
		return

	var viewport_size = _map_viewport_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	map_base_scale = max(1.0, viewport_size.y / map_image_size.y)
	if map_base_scale <= 0.0:
		map_base_scale = 1.0

	var rendered_size = map_image_size * map_base_scale
	map_view_offset = _clamp_map_view_offset(map_view_offset, rendered_size, viewport_size)

	_get_map_content().position = map_view_offset
	_get_map_content().size = rendered_size
	map_view.position = Vector2.ZERO
	map_view.size = rendered_size

func _clamp_map_view_offset(offset: Vector2, rendered_size: Vector2, viewport_size: Vector2) -> Vector2:
	var clamped = offset
	if rendered_size.x > viewport_size.x:
		clamped.x = clamp(clamped.x, viewport_size.x - rendered_size.x, 0.0)
	else:
		clamped.x = (viewport_size.x - rendered_size.x) * 0.5

	if rendered_size.y > viewport_size.y:
		clamped.y = clamp(clamped.y, viewport_size.y - rendered_size.y, 0.0)
	else:
		clamped.y = (viewport_size.y - rendered_size.y) * 0.5

	return clamped

func _node_rendered_position(node: Resource) -> Vector2:
	var rendered_size = map_view.size if map_view and is_instance_valid(map_view) else map_image_size * map_base_scale
	return Vector2(rendered_size.x * node.pos_x, rendered_size.y * node.pos_y)

func _center_map_on_node(node: Resource):
	var viewport_size = _map_viewport_size()
	var target_offset = viewport_size * 0.5 - _node_rendered_position(node)
	target_offset = _clamp_map_view_offset(target_offset, map_view.size, viewport_size)

	if map_tween:
		map_tween.kill()
	map_tween = create_tween()
	map_tween.set_trans(Tween.TRANS_CUBIC)
	map_tween.set_ease(Tween.EASE_OUT)
	map_tween.tween_method(Callable(self, "_set_map_view_offset_interpolated"), map_view_offset, target_offset, CAMERA_MOVE_DURATION)

func _set_map_center_on_node_immediate(node: Resource):
	if not map_view or not is_instance_valid(map_view):
		return
	var viewport_size = _map_viewport_size()
	map_view_offset = _clamp_map_view_offset(viewport_size * 0.5 - _node_rendered_position(node), map_view.size, viewport_size)
	_update_map_view_transform()
	_refresh_node_positions()
	queue_redraw()

func _set_map_view_offset_interpolated(value: Vector2):
	map_view_offset = _clamp_map_view_offset(value, map_view.size, _map_viewport_size())
	_update_map_view_transform()
	_refresh_node_positions()
	queue_redraw()

func _on_map_area_gui_input(event: InputEvent):
	if not current_expedition or not map_view or not is_instance_valid(map_view):
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			map_dragging = event.pressed
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_pan_map(Vector2(0.0, MAP_WHEEL_PAN_STEP))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_pan_map(Vector2(0.0, -MAP_WHEEL_PAN_STEP))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
			_pan_map(Vector2(MAP_WHEEL_PAN_STEP, 0.0))
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
			_pan_map(Vector2(-MAP_WHEEL_PAN_STEP, 0.0))
	elif event is InputEventMouseMotion and map_dragging:
		_pan_map(event.relative)
	elif event is InputEventScreenDrag:
		_pan_map(event.relative)

func _pan_map(delta: Vector2):
	if not map_view or not is_instance_valid(map_view):
		return
	map_view_offset = _clamp_map_view_offset(map_view_offset + delta, map_view.size, _map_viewport_size())
	_update_map_view_transform()
	_refresh_node_positions()
	queue_redraw()

func _refresh_node_positions():
	if not current_expedition:
		return
	for node_id in node_buttons.keys():
		var button = node_buttons.get(node_id, null)
		if not button or not is_instance_valid(button):
			continue
		var node = current_expedition.get_node(int(node_id))
		if node:
			_position_node_button(button, node)

func is_on_expedition() -> bool:
	return visible and current_expedition_id > 0

func _update_health_bar():
	if not health_bar or not GameInfo.current_player:
		return

	var total_stats = GameInfo.current_player.get_total_stats()
	var max_health = total_stats.stamina * 10
	var current_health = max(0, max_health - int(GameInfo.current_player.depleted_health))
	health_bar.max_value = max_health
	health_bar.value = current_health
	if health_bar.has_node("HealthLabel"):
		health_bar.get_node("HealthLabel").text = str(current_health) + " / " + str(max_health)
