extends TextureRect

const EXPEDITION_QUEST_START_COST: int = 30
const LOW_HEALTH_WARNING_RATIO: float = 0.10
const NODE_BUTTON_SIZE: Vector2 = Vector2(42, 42)
const NODE_OVERLAY_HEIGHT: float = 120.0

@export var text_container: Node
@export var options_container: VBoxContainer
@export var reward_label: Label
@export var expedition_text: Label
@export var health_bar: TextureProgressBar
@export var effects_container: Control

@export_group("Option Icons")
@export var dialogue_icon: Texture2D
@export var combat_icon: Texture2D
@export var currency_check_icon: Texture2D
@export var end_icon: Texture2D

@export_group("Stat Check Icons")
@export var strength_icon: Texture2D
@export var stamina_icon: Texture2D
@export var agility_icon: Texture2D
@export var luck_icon: Texture2D
@export var armor_icon: Texture2D

@export_group("Faction Check Icons")
@export var order_icon: Texture2D
@export var guild_icon: Texture2D
@export var companions_icon: Texture2D

@export var portrait: Control

var current_expedition_id: int = 0
var current_expedition: ExpeditionData = null
var node_buttons: Dictionary = {}
var pending_node_id: int = 0
var pending_node_start_cost: int = 0
var map_view: TextureRect = null
var map_image_size: Vector2 = Vector2.ZERO
var map_base_scale: float = 1.0
var camera_center_px: Vector2 = Vector2.ZERO
var selected_node_id: int = 0
var selected_node_completed: bool = false
var node_overlay_panel: PanelContainer = null
var node_description_label: Label = null
var embark_button: Button = null

func _ready():
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	var overlay = get_node_or_null("Overlay")
	if overlay and overlay is ColorRect:
		overlay.color = Color(0, 0, 0, 0)
		overlay.z_index = 10

	_ensure_map_view()
	_ensure_node_overlay()

	if text_container:
		text_container.visible = false
	if options_container:
		options_container.visible = false
	if reward_label:
		reward_label.visible = false
	if expedition_text:
		expedition_text.visible = false

	if effects_container:
		effects_container.visible = false
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
	_ensure_node_overlay()
	texture = null
	_reset_camera_to_map_center()
	_update_map_view_transform()
	selected_node_id = 0
	selected_node_completed = false
	_set_node_overlay_text("Select a node to inspect it.")
	_set_embark_button_enabled(false)
	visible = true
	refresh_graph()

func refresh_graph():
	if not current_expedition:
		return

	_update_health_bar()
	_clear_graph()

	if reward_label:
		reward_label.text = ""
	if expedition_text:
		expedition_text.text = ""
	_set_node_overlay_text("Select a node to inspect it.")
	_set_embark_button_enabled(false)

	var quest_log = GameInfo.current_player.quest_log if GameInfo.current_player else []
	var completed_ids = current_expedition.get_completed_node_ids_from_quest_log(quest_log)
	var available_ids = current_expedition.get_available_node_ids(quest_log)

	_update_map_view_transform()
	_draw_edges(available_ids, completed_ids)
	for node in current_expedition.nodes:
		if node.node_id in available_ids:
			_add_node_button(node, node.node_id in completed_ids)

	_refresh_node_positions()

func _clear_graph():
	for button in node_buttons.values():
		if button and is_instance_valid(button):
			button.queue_free()
	node_buttons.clear()
	pending_node_id = 0
	if options_container:
		for child in options_container.get_children():
			child.queue_free()
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
	button.text = "" if completed else (node.label if node.label != "" else str(node.node_id))
	button.tooltip_text = _get_node_tooltip(node, completed)
	button.modulate = Color(0.45, 0.45, 0.45, 0.95) if completed else Color(1.0, 0.86, 0.45, 1.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_node_pressed.bind(node, completed))
	add_child(button)
	node_buttons[node.node_id] = button
	_position_node_button(button, node)

func _get_node_tooltip(node: Resource, completed: bool) -> String:
	if completed:
		return "Completed"
	if int(node.quest_id) > 0:
		var quest = GameInfo.quests_db.get_quest_by_id(node.quest_id) if GameInfo.quests_db else null
		if quest:
			return quest.quest_name
		return "Quest %d" % int(node.quest_id)
	return node.label if node.label != "" else "Unknown node"

func _position_node_button(button: Button, node: Resource):
	var center = _node_position(node)
	button.position = center - button.size * 0.5

func _node_position(node: Resource) -> Vector2:
	return _world_to_screen(_node_world_position(node))

func _notification(what):
	if what == NOTIFICATION_RESIZED and current_expedition:
		_update_map_view_transform()
		_refresh_node_positions()
		queue_redraw()

func _on_node_pressed(node: Resource, completed: bool = false):
	_center_camera_on_node(node)
	selected_node_id = int(node.node_id)
	selected_node_completed = completed
	_set_node_overlay_text(_build_node_overlay_text(node, completed))

	if completed:
		_set_embark_button_enabled(false)
		return

	if pending_node_id > 0:
		_set_embark_button_enabled(false)
		return

	_set_embark_button_enabled(true)

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
		if expedition_text:
			expedition_text.text = "Connection lost. Please try again."
		return
	if GameInfo.current_player.silver < EXPEDITION_QUEST_START_COST:
		_set_node_overlay_text("You need %d silver to embark." % EXPEDITION_QUEST_START_COST)
		return

	pending_node_id = node_id
	var button = node_buttons.get(pending_node_id, null)
	if button:
		button.disabled = true
	_set_embark_button_enabled(false)

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
		_set_embark_button_enabled(not selected_node_completed and selected_node_id > 0)
		print("ExpeditionPanel: Node start failed for node ", node_id, ": ", message)
		return

	if quest_id <= 0:
		_refund_pending_node_start_cost()
		_set_node_overlay_text("Server returned invalid quest for this node.")
		_set_embark_button_enabled(not selected_node_completed and selected_node_id > 0)
		print("ExpeditionPanel: Invalid quest_id from server for node ", node_id)
		return

	pending_node_start_cost = 0

	_set_node_overlay_text("Travel started...")

	if UIManager.instance and UIManager.instance.map_panel and UIManager.instance.map_panel.has_method("start_expedition_node_travel"):
		UIManager.instance.map_panel.start_expedition_node_travel(current_expedition_id, node_id, quest_id, arrival_timestamp)
	else:
		# Fallback to old behavior if map travel method is unavailable.
		UIManager.instance.quest.load_expedition_node(current_expedition_id, node_id, quest_id)

func handle_expedition_failed(message: String):
	if expedition_text:
		expedition_text.text = message if message != "" else "Expedition ended. Return home."
	_set_node_overlay_text(message if message != "" else "Expedition ended. Return home.")
	_set_embark_button_enabled(false)
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
	_set_embark_button_enabled(false)
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

func _ensure_node_overlay():
	if node_overlay_panel and is_instance_valid(node_overlay_panel):
		return

	var overlay = get_node_or_null("Overlay")
	if not overlay:
		return

	node_overlay_panel = PanelContainer.new()
	node_overlay_panel.name = "NodeOverlay"
	node_overlay_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	node_overlay_panel.anchor_left = 0.04
	node_overlay_panel.anchor_top = 1.0
	node_overlay_panel.anchor_right = 0.96
	node_overlay_panel.anchor_bottom = 1.0
	node_overlay_panel.offset_top = -NODE_OVERLAY_HEIGHT
	node_overlay_panel.offset_bottom = -14.0
	overlay.add_child(node_overlay_panel)

	var inner = MarginContainer.new()
	inner.add_theme_constant_override("margin_left", 12)
	inner.add_theme_constant_override("margin_top", 10)
	inner.add_theme_constant_override("margin_right", 12)
	inner.add_theme_constant_override("margin_bottom", 10)
	node_overlay_panel.add_child(inner)

	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	inner.add_child(row)

	node_description_label = Label.new()
	node_description_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node_description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node_description_label.text = "Select a node to inspect it."
	row.add_child(node_description_label)

	embark_button = Button.new()
	embark_button.custom_minimum_size = Vector2(140, 44)
	embark_button.text = "Embark (30 Silver)"
	embark_button.disabled = true
	embark_button.focus_mode = Control.FOCUS_NONE
	embark_button.pressed.connect(_on_embark_button_pressed)
	row.add_child(embark_button)

func _set_node_overlay_text(text_value: String):
	if node_description_label and is_instance_valid(node_description_label):
		node_description_label.text = text_value

func _set_embark_button_enabled(enabled: bool):
	if embark_button and is_instance_valid(embark_button):
		embark_button.disabled = not enabled

func _build_node_overlay_text(node: Resource, completed: bool) -> String:
	if completed:
		var title = node.label if node.label != "" else ("Node %d" % int(node.node_id))
		return "%s\nCompleted" % title

	var quest_id = int(node.quest_id)
	if quest_id > 0 and GameInfo.quests_db:
		var quest = GameInfo.quests_db.get_quest_by_id(quest_id)
		if quest:
			var title = quest.quest_name if quest.quest_name != "" else ("Quest %d" % quest_id)
			var details = quest.initial_text if quest.initial_text != "" else (quest.travel_text if quest.travel_text != "" else "No description available.")
			return "%s\n%s" % [title, details]

	var node_title = node.label if node.label != "" else ("Node %d" % int(node.node_id))
	return "%s\nEmbark to begin this node quest." % node_title

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
	camera_center_px = _clamp_camera_center(_node_world_position(node))
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
