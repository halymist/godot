extends TextureRect

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

func _ready():
	visible = false
	visibility_changed.connect(_on_visibility_changed)
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
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

	texture = current_expedition.map_texture
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

	var quest_log = GameInfo.current_player.quest_log if GameInfo.current_player else []
	var completed_ids = current_expedition.get_completed_node_ids_from_quest_log(quest_log)
	var available_ids = current_expedition.get_available_node_ids(quest_log)

	_draw_edges(available_ids, completed_ids)
	for node in current_expedition.nodes:
		if node.node_id in available_ids:
			_add_node_button(node, node.node_id in completed_ids)

func _clear_graph():
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
	button.custom_minimum_size = Vector2(42, 42)
	button.size = Vector2(42, 42)
	button.text = "✓" if completed else (node.label if node.label != "" else str(node.node_id))
	button.tooltip_text = _get_node_tooltip(node, completed)
	button.disabled = completed
	button.modulate = Color(0.75, 0.95, 0.65, 1.0) if completed else Color(1.0, 0.86, 0.45, 1.0)
	button.pressed.connect(_on_node_pressed.bind(node))
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
	var pos = Vector2(node.pos_x, node.pos_y)
	if node.pos_x >= 0.0 and node.pos_x <= 1.0 and node.pos_y >= 0.0 and node.pos_y <= 1.0:
		return Vector2(size.x * node.pos_x, size.y * node.pos_y)

	var image_size = Vector2.ZERO
	if texture:
		image_size = texture.get_size()
	if image_size.x <= 0.0 or image_size.y <= 0.0:
		return pos
	return Vector2((pos.x / image_size.x) * size.x, (pos.y / image_size.y) * size.y)

func _notification(what):
	if what == NOTIFICATION_RESIZED and current_expedition:
		for node_id in node_buttons.keys():
			var node = current_expedition.get_node(int(node_id))
			if node:
				_position_node_button(node_buttons[node_id], node)
		queue_redraw()

func _on_node_pressed(node: Resource):
	if pending_node_id > 0:
		return
	if not UIManager.instance or not UIManager.instance.quest or not Websocket:
		return

	pending_node_id = int(node.node_id)
	var button = node_buttons.get(pending_node_id, null)
	if button:
		button.disabled = true

	print("ExpeditionPanel: Requesting node start from server: node=", pending_node_id)
	Websocket.start_expedition_node(pending_node_id)

func handle_node_start_response(success: bool, node_id: int, quest_id: int, arrival_timestamp: String = "", message: String = ""):

	if node_id <= 0:
		node_id = pending_node_id

	if pending_node_id == node_id:
		pending_node_id = 0

	var button = node_buttons.get(node_id, null)
	if button:
		button.disabled = false

	if not success:
		if expedition_text:
			expedition_text.text = message if message != "" else "Unable to start this node."
		print("ExpeditionPanel: Node start failed for node ", node_id, ": ", message)
		return

	if quest_id <= 0:
		if expedition_text:
			expedition_text.text = "Server returned invalid quest for this node."
		print("ExpeditionPanel: Invalid quest_id from server for node ", node_id)
		return

	if expedition_text:
		expedition_text.text = ""

	if UIManager.instance and UIManager.instance.map_panel and UIManager.instance.map_panel.has_method("start_expedition_node_travel"):
		UIManager.instance.map_panel.start_expedition_node_travel(current_expedition_id, node_id, quest_id, arrival_timestamp)
	else:
		# Fallback to old behavior if map travel method is unavailable.
		UIManager.instance.quest.load_expedition_node(current_expedition_id, node_id, quest_id)

func handle_expedition_failed(message: String):
	if expedition_text:
		expedition_text.text = message if message != "" else "Expedition ended. Return home."
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
	if GameInfo.current_player:
		GameInfo.current_player.expedition = []
	_clear_graph()
	print("Expedition ended")

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
