extends TextureRect

const UI_UTILS = preload("res://scripts/utils/UIUtils.gd")
const SETTLEMENT_UTILS = preload("res://scripts/utils/SettlementPanelUtils.gd")

const HEAL_COST: int = 30
const CURE_COST: int = 10

@export var heal_button: Button
@export var cure_button: Button
@export var status_label: Label
@export var image_area: TextureRect
@export var chat_bubble: ChatBubble

var on_entered_greetings: Array[String] = []
var on_healed_greetings: Array[String] = []
var on_cured_greetings: Array[String] = []

func _ready():
	if heal_button and not heal_button.pressed.is_connected(_on_heal_pressed):
		heal_button.pressed.connect(_on_heal_pressed)
	if cure_button and not cure_button.pressed.is_connected(_on_cure_pressed):
		cure_button.pressed.connect(_on_cure_pressed)
	visibility_changed.connect(_on_visibility_changed)
	_update_button_states()

func _on_visibility_changed():
	if visible:
		_load_location_content()
		_update_button_states()
		_show_greeting(on_entered_greetings)

func _load_location_content():
	var content = SETTLEMENT_UTILS.load_healer_content(self, image_area, chat_bubble)
	if content.is_empty():
		return
	on_entered_greetings = content.get("entered", [])
	on_healed_greetings = content.get("healed", [])
	on_cured_greetings = content.get("cured", [])

func _show_greeting(greetings: Array[String]):
	SETTLEMENT_UTILS.show_greeting(chat_bubble, greetings)

func _update_button_states():
	if not GameInfo.current_player:
		return
	var has_heal_silver = GameInfo.current_player.silver >= HEAL_COST
	var has_cure_silver = GameInfo.current_player.silver >= CURE_COST
	if heal_button:
		heal_button.disabled = GameInfo.current_player.depleted_health <= 0 or not has_heal_silver
		UI_UTILS.set_button_price_color(heal_button, has_heal_silver)
	if cure_button:
		cure_button.disabled = not _has_curable_effects() or not has_cure_silver
		UI_UTILS.set_button_price_color(cure_button, has_cure_silver)
	_update_status()

func _update_status():
	if not status_label or not GameInfo.current_player:
		return
	if GameInfo.current_player.depleted_health > 0:
		status_label.text = "Recovered health is available."
	elif _has_curable_effects():
		status_label.text = "A cure can clear active expedition effects."
	else:
		status_label.text = "You are already in good shape."

func _has_curable_effects() -> bool:
	if not GameInfo.current_player:
		return false
	return GameInfo.current_player.potion > 0 or GameInfo.current_player.elixir > 0 or GameInfo.current_player.elixir_effects.size() > 0

func _on_heal_pressed():
	if not GameInfo.current_player or GameInfo.current_player.silver < HEAL_COST or GameInfo.current_player.depleted_health <= 0:
		return
	Websocket.heal()
	GameInfo.current_player.depleted_health = 0
	UIManager.instance.update_silver(-HEAL_COST)
	UIManager.instance.refresh_stats()
	_update_button_states()
	_show_greeting(on_healed_greetings)

func _on_cure_pressed():
	if not GameInfo.current_player or GameInfo.current_player.silver < CURE_COST or not _has_curable_effects():
		return
	Websocket.cure()
	GameInfo.current_player.potion = 0
	GameInfo.current_player.potion_until = 0.0
	GameInfo.current_player.elixir = 0
	GameInfo.current_player.elixir_until = 0.0
	GameInfo.current_player.elixir_ingredients.clear()
	GameInfo.current_player.elixir_effects.clear()
	UIManager.instance.update_silver(-CURE_COST)
	UIManager.instance.refresh_stats()
	UIManager.instance.refresh_active_effects()
	_update_button_states()
	_show_greeting(on_cured_greetings)
