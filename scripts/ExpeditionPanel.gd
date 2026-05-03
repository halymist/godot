extends TextureRect

const EXPEDITION_QUEST_START_COST: int = 30
const LOW_HEALTH_WARNING_RATIO: float = 0.10
const NODE_BUTTON_SIZE: Vector2 = Vector2(42, 42)
const CAMERA_MOVE_DURATION: float = 0.28
const MAP_PAN_ZOOM: float = 1.12
const EMBARK_ACTION_TEXT: String = "Embark"
const NODE_BORDER_WIDTH: int = 2
const NODE_AVAILABLE_FILL: Color = Color(0.89, 0.70, 0.28, 0.98)
const NODE_AVAILABLE_BORDER: Color = Color(1.00, 0.90, 0.55, 1.0)
const NODE_COMPLETED_FILL: Color = Color(0.34, 0.38, 0.42, 0.98)
const NODE_COMPLETED_BORDER: Color = Color(0.54, 0.58, 0.62, 1.0)
const NODE_SELECTED_BORDER: Color = Color(0.98, 0.98, 0.98, 1.0)

@export var health_bar: TextureProgressBar
@export var node_overlay_panel: Control
@export var node_description_label: Label
@export var node_action_button: Button

@export var currency_check_icon: Texture2D

var current_expedition_id: int = 0
var current_expedition: ExpeditionData = null
var node_buttons: Dictionary = {}
var pending_node_id: int = 0
var pending_node_start_cost: int = 0
var map_view: TextureRect = null
var map_image_size: Vector2 = Vector2.ZERO
var map_base_scale: float = 1.0
var camera_center_px: Vector2 = Vector2.ZERO
var camera_tween: Tween = null
var selected_node_id: int = 0
var selected_node_completed: bool = false
var rng := RandomNumberGenerator.new()

func _ready():
	visible = false
	rng.randomize()
	visibility_changed.connect(_on_visibility_changed)
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_ensure_map_view()
	_setup_node_overlay()
	print("ExpeditionPanel: Graph setup complete")

func _on_visibility_changed():
	if not visible:
		return

	_update_health_bar()
	if GameInfo.current_player and GameInfo.current_player.expedition and GameInfo.current_player.expedition.size() > 0:
		var expedition_id = int(GameInfo.current_player.expedition[0])
		if current_expedition_id != expedition_id:
			start_expedition(expedition_id)
		else:
			refresh_graph()

func start_expedition(expedition_id: int):
	current_expedition_id = expedition_id
	current_expedition = GameInfo.expeditions_db.get_expedition(expedition_id) if GameInfo.expeditions_db else null
	if not current_expedition:
		print("ExpeditionPanel: Expedition not found: ", expedition_id)
		return

	if GameInfo.current_player:
		GameInfo.current_player.expedition = [expedition_id]

	_ensure_map_view()
	_setup_node_overlay()
	texture = null
	_reset_camera_to_map_center()
	_update_map_view_transform()
	selected_node_id = 0
	selected_node_completed = false
	_set_node_overlay_text("Loading...")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
	visible = true
	refresh_graph()

func refresh_graph():
	if not current_expedition:
		return

	_update_health_bar()
	_clear_graph()

	_set_node_overlay_text("Loading...")
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)

	var quest_log = GameInfo.current_player.quest_log if GameInfo.current_player else []
	var completed_ids = current_expedition.get_completed_node_ids_from_quest_log(quest_log)
	var available_ids = current_expedition.get_available_node_ids(quest_log)

	_update_map_view_transform()
	_draw_edges(available_ids, completed_ids)
	for node in current_expedition.nodes:
		if node.node_id in available_ids:
			_add_node_button(node, node.node_id in completed_ids)

	_refresh_node_positions()
	_restore_or_pick_selection(available_ids, completed_ids)

func _clear_graph():
	for button in node_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	node_buttons.clear()
	pending_node_id = 0
	queue_redraw()

func _draw_edges(_available_ids: Array, _completed_ids: Array):
	queue_redraw()

func _draw():
	if not current_expedition or not GameInfo.current_player:
		return

	var quest_log = GameInfo.current_player.quest_log
	var completed_ids = current_expedition.get_completed_node_ids_from_quest_log(quest_log)
	var available_ids = current_expedition.get_available_node_ids(quest_log)
	for edge in current_expedition.edges:
		if edge.node_a not in available_ids or edge.node_b not in available_ids:
			continue
		var node_a = current_expedition.get_node(edge.node_a)
		var node_b = current_expedition.get_node(edge.node_b)
		if not node_a or not node_b:
			continue
		var color = Color(0.88, 0.78, 0.48, 0.9) if edge.node_a in completed_ids and edge.node_b in completed_ids else Color(0.75, 0.75, 0.75, 0.55)
		draw_line(_node_position(node_a), _node_position(node_b), color, 3.0, true)

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
	add_child(button)
	node_buttons[node.node_id] = button
	_position_node_button(button, node)

func _position_node_button(button: Button, node: Resource):
	var center = _node_position(node)
	button.position = center - button.size * 0.5

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

func _node_position(node: Resource) -> Vector2:
	return _world_to_screen(_node_world_position(node))

func _notification(what):
	if what == NOTIFICATION_RESIZED and current_expedition:
		_update_map_view_transform()
		_refresh_node_positions()
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

	if GameInfo.current_player.silver < EXPEDITION_QUEST_START_COST:
		_set_node_overlay_text("You need %d silver to embark." % EXPEDITION_QUEST_START_COST)
		return

	if _is_low_health_warning_needed():
		if UIManager.instance.cancel_quest and UIManager.instance.cancel_quest.has_method("show_custom_dialog"):
			UIManager.instance.cancel_quest.show_custom_dialog(
				"You are below 10% health. Proceed anyway?",
				Callable(self, "_confirm_node_start").bind(selected_node_id)
			)
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
	if GameInfo.current_player.silver < EXPEDITION_QUEST_START_COST:
		_set_node_overlay_text("You need %d silver to embark." % EXPEDITION_QUEST_START_COST)
		return

	pending_node_id = node_id
	var button = node_buttons.get(pending_node_id, null)
	if button:
		button.disabled = true
	_set_action_button_state(EMBARK_ACTION_TEXT, false, true)

	pending_node_start_cost = EXPEDITION_QUEST_START_COST
	UIManager.instance.update_silver(-EXPEDITION_QUEST_START_COST)

	print("ExpeditionPanel: Requesting node start from server: node=", pending_node_id)
	Websocket.start_expedition_node(pending_node_id)

func _refund_pending_node_start_cost():
	if pending_node_start_cost <= 0:
		return
	if UIManager.instance:
		UIManager.instance.update_silver(pending_node_start_cost)
	pending_node_start_cost = 0

func _is_low_health_warning_needed() -> bool:
	if not GameInfo.current_player:
		return false
	var total_stats = GameInfo.current_player.get_total_stats()
	var max_health = max(1, int(total_stats.stamina) * 10)
	var current_health = max(0, max_health - int(GameInfo.current_player.depleted_health))
	return float(current_health) / float(max_health) < LOW_HEALTH_WARNING_RATIO

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
			_set_action_button_state("Completed", false, false)
		else:
			_set_action_button_state(EMBARK_ACTION_TEXT, selected_node_id > 0, true)
		print("ExpeditionPanel: Node start failed for node ", node_id, ": ", message)
		return

	if quest_id <= 0:
		_refund_pending_node_start_cost()
		_set_node_overlay_text("Server returned invalid quest for this node.")
		if selected_node_completed:
			_set_action_button_state("Completed", false, false)
		else:
			_set_action_button_state(EMBARK_ACTION_TEXT, selected_node_id > 0, true)
		print("ExpeditionPanel: Invalid quest_id from server for node ", node_id)
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
	print("Expedition ended")

func _ensure_map_view():
	if map_view and is_instance_valid(map_view):
		return

	map_view = TextureRect.new()
	map_view.name = "MapView"
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.stretch_mode = TextureRect.STRETCH_SCALE
	map_view.z_index = 0
	add_child(map_view)
	move_child(map_view, 0)
	clip_contents = true

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
		node_action_button.disabled = not enabled

		var action_label = node_action_button.get_node_or_null("Content/ActionLabel") as Label
		var price_label = node_action_button.get_node_or_null("Content/PriceLabel") as Label
		var currency_icon = node_action_button.get_node_or_null("Content/CurrencyIcon") as TextureRect
		var closing_paren = node_action_button.get_node_or_null("Content/ClosingParen") as Label

		if action_label and price_label and currency_icon and closing_paren:
			node_action_button.text = ""
			node_action_button.icon = null
			action_label.text = "%s(" % text_value if show_price else text_value
			price_label.text = str(EXPEDITION_QUEST_START_COST)
			price_label.visible = show_price
			currency_icon.visible = show_price
			closing_paren.visible = show_price
		else:
			node_action_button.text = "%s (%d)" % [text_value, EXPEDITION_QUEST_START_COST] if show_price else text_value
			node_action_button.icon = currency_check_icon if show_price else null

func _build_node_overlay_text(node: Resource, completed: bool) -> String:
	if node.label != "":
		return node.label
	if completed:
		return "Completed node"
	return "Unknown node"

func _restore_or_pick_selection(available_ids: Array, completed_ids: Array):
	if not current_expedition:
		return

	if selected_node_id > 0 and selected_node_id in available_ids:
		var selected_node = current_expedition.get_node(selected_node_id)
		if selected_node:
			_apply_node_selection(selected_node, selected_node_id in completed_ids, false)
			return

	var embarkable_ids: Array[int] = []
	for node_id in available_ids:
		if node_id not in completed_ids:
			embarkable_ids.append(int(node_id))

	var pick_id: int = 0
	var pick_completed: bool = false
	if embarkable_ids.size() > 0:
		pick_id = int(embarkable_ids[rng.randi() % embarkable_ids.size()])
	elif completed_ids.size() > 0:
		pick_id = int(completed_ids[rng.randi() % completed_ids.size()])
		pick_completed = true
	elif available_ids.size() > 0:
		pick_id = int(available_ids[rng.randi() % available_ids.size()])

	if pick_id <= 0:
		selected_node_id = 0
		selected_node_completed = false
		_set_node_overlay_text("No nodes available.")
		_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
		return

	var pick_node = current_expedition.get_node(pick_id)
	if pick_node:
		_apply_node_selection(pick_node, pick_completed, true)

func _apply_node_selection(node: Resource, completed: bool, center_camera: bool):
	if center_camera:
		_center_camera_on_node(node)
	selected_node_id = int(node.node_id)
	selected_node_completed = completed
	_set_node_overlay_text(_build_node_overlay_text(node, completed))
	_refresh_node_visual_states()

	if completed:
		_set_action_button_state("Completed", false, false)
		return

	if pending_node_id > 0:
		_set_action_button_state(EMBARK_ACTION_TEXT, false, true)
		return

	_set_action_button_state(EMBARK_ACTION_TEXT, true, true)

func _reset_camera_to_map_center():
	map_image_size = _get_map_image_size()
	if map_image_size.x <= 0.0 or map_image_size.y <= 0.0:
		camera_center_px = size * 0.5
		return
	camera_center_px = map_image_size * 0.5

func _get_map_image_size() -> Vector2:
	if current_expedition and current_expedition.map_texture:
		return current_expedition.map_texture.get_size()
	if map_view and map_view.texture:
		return map_view.texture.get_size()
	return Vector2(max(size.x, 1.0), max(size.y, 1.0))

func _update_map_view_transform():
	if not map_view:
		return

	if current_expedition and current_expedition.map_texture:
		map_view.texture = current_expedition.map_texture

	map_image_size = _get_map_image_size()
	if map_image_size.x <= 0.0 or map_image_size.y <= 0.0:
		return

	var viewport_size = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	map_base_scale = max(viewport_size.x / map_image_size.x, viewport_size.y / map_image_size.y)
	if map_base_scale <= 0.0:
		map_base_scale = 1.0
	map_base_scale *= MAP_PAN_ZOOM

	camera_center_px = _clamp_camera_center(camera_center_px)
	var top_left = viewport_size * 0.5 - camera_center_px * map_base_scale

	map_view.position = top_left
	map_view.size = map_image_size * map_base_scale

func _clamp_camera_center(center_px: Vector2) -> Vector2:
	var viewport_size = size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return center_px

	var safe_scale = max(map_base_scale, 0.0001)
	var half_view_world = viewport_size * 0.5 / safe_scale
	var clamped = center_px

	if map_image_size.x <= half_view_world.x * 2.0:
		clamped.x = map_image_size.x * 0.5
	else:
		clamped.x = clamp(clamped.x, half_view_world.x, map_image_size.x - half_view_world.x)

	if map_image_size.y <= half_view_world.y * 2.0:
		clamped.y = map_image_size.y * 0.5
	else:
		clamped.y = clamp(clamped.y, half_view_world.y, map_image_size.y - half_view_world.y)

	return clamped

func _node_world_position(node: Resource) -> Vector2:
	if map_image_size.x <= 0.0 or map_image_size.y <= 0.0:
		map_image_size = _get_map_image_size()

	if node.pos_x >= 0.0 and node.pos_x <= 1.0 and node.pos_y >= 0.0 and node.pos_y <= 1.0:
		return Vector2(map_image_size.x * node.pos_x, map_image_size.y * node.pos_y)

	return Vector2(node.pos_x, node.pos_y)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	return (world_pos - camera_center_px) * map_base_scale + size * 0.5

func _center_camera_on_node(node: Resource):
	var target_center = _clamp_camera_center(_node_world_position(node))
	if camera_tween:
		camera_tween.kill()
	camera_tween = create_tween()
	camera_tween.set_trans(Tween.TRANS_CUBIC)
	camera_tween.set_ease(Tween.EASE_OUT)
	camera_tween.tween_method(Callable(self, "_set_camera_center_interpolated"), camera_center_px, target_center, CAMERA_MOVE_DURATION)

func _set_camera_center_interpolated(value: Vector2):
	camera_center_px = value
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
