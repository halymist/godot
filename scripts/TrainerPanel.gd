extends TextureRect

const UI_UTILS = preload("res://scripts/utils/UIUtils.gd")
const SETTLEMENT_UTILS = preload("res://scripts/utils/SettlementPanelUtils.gd")

# Training costs
const TALENT_POINT_COST = 100
const STAT_COST = 10

@export var chat_bubble: ChatBubble
@export var image_area: TextureRect
@export var talent_points_label: Label
@export var strength_label : Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
# Stat row buttons
@export var talent_points_button: Button
@export var strength_button: Button
@export var stamina_button: Button
@export var agility_button: Button
@export var luck_button: Button

var on_entered_greetings: Array[String] = []
var on_placed_greetings: Array[String] = []
var on_action_greetings: Array[String] = []

func _ready():
	talent_points_button.pressed.connect(_on_stat_row_pressed.bind("talent_points", TALENT_POINT_COST))
	strength_button.pressed.connect(_on_stat_row_pressed.bind("strength", STAT_COST))
	stamina_button.pressed.connect(_on_stat_row_pressed.bind("stamina", STAT_COST))
	agility_button.pressed.connect(_on_stat_row_pressed.bind("agility", STAT_COST))
	luck_button.pressed.connect(_on_stat_row_pressed.bind("luck", STAT_COST))
	visibility_changed.connect(_on_visibility_changed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_location_content()
	update_stats_display()
	update_button_states()

func _on_visibility_changed():
	if visible:
		_load_location_content()
		update_stats_display()
		update_button_states()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var content = SETTLEMENT_UTILS.load_utility_content(self, image_area, chat_bubble)
	if content.is_empty():
		return
	on_entered_greetings = content.get("entered", [])
	on_placed_greetings = content.get("placed", [])
	on_action_greetings = content.get("action", [])

func _show_greeting(greetings: Array[String]):
	SETTLEMENT_UTILS.show_greeting(chat_bubble, greetings)

func update_stats_display():
	talent_points_label.text = "Talents: " + str(GameInfo.current_player.talent_points)
	strength_label.text = "Strength: " + str(GameInfo.current_player.strength)
	stamina_label.text = "Stamina: " + str(GameInfo.current_player.stamina)
	agility_label.text = "Agility: " + str(GameInfo.current_player.agility)
	luck_label.text = "Luck: " + str(GameInfo.current_player.luck)

func update_button_states():
	var silver = GameInfo.current_player.silver
	
	talent_points_button.disabled = silver < TALENT_POINT_COST
	strength_button.disabled = silver < STAT_COST
	stamina_button.disabled = silver < STAT_COST
	agility_button.disabled = silver < STAT_COST
	luck_button.disabled = silver < STAT_COST
	_set_cost_label_color(talent_points_button, silver >= TALENT_POINT_COST)
	_set_cost_label_color(strength_button, silver >= STAT_COST)
	_set_cost_label_color(stamina_button, silver >= STAT_COST)
	_set_cost_label_color(agility_button, silver >= STAT_COST)
	_set_cost_label_color(luck_button, silver >= STAT_COST)

func _set_cost_label_color(button: Button, can_afford: bool):
	var cost_label = button.get_node_or_null("Content/Cost/CostLabel") as Label
	UI_UTILS.set_afford_label_color(cost_label, can_afford)

func _on_stat_row_pressed(stat_name: String, cost: int):
	# Check if we have enough silver
	if GameInfo.current_player.silver < cost:
		return
	
	# Map stat names to stat IDs (1=strength, 2=stamina, 3=agility, 4=luck, 5=talent_points)
	var stat_id_map = {
		"strength": 1,
		"stamina": 2,
		"agility": 3,
		"luck": 4,
		"talent_points": 5
	}
	
	Websocket.train_stat(stat_id_map[stat_name])
	UIManager.instance.update_silver(-cost)
	
	match stat_name:
		"strength":
			GameInfo.current_player.strength += 1
		"stamina":
			GameInfo.current_player.stamina += 1
		"agility":
			GameInfo.current_player.agility += 1
		"luck":
			GameInfo.current_player.luck += 1
		"talent_points":
			GameInfo.current_player.talent_points += 1
	
	UIManager.instance.refresh_stats()
	update_stats_display()
	update_button_states()
	_show_greeting(on_action_greetings)
