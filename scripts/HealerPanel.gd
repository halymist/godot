extends TextureRect

const HEAL_COST: int = 30
const CURE_COST: int = 10
const COLOR_PRICE_NORMAL := Color(0.85, 0.8, 0.7, 1.0)
const COLOR_PRICE_MISSING := Color(1.0, 0.25, 0.2, 1.0)

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
	var settlement = GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location) if GameInfo.settlements_db and GameInfo.current_player else null
	if not settlement:
		return

	var healer_texture = settlement.get_healer_texture()
	if healer_texture:
		if image_area:
			image_area.texture = healer_texture
			texture = null
		else:
			texture = healer_texture

	on_entered_greetings = settlement.get_healer_on_entered_lines()
	on_healed_greetings = settlement.get_healer_on_healed_lines()
	on_cured_greetings = settlement.get_healer_on_cured_lines()

	if chat_bubble:
		if settlement.has_healer_msg_rect():
			chat_bubble.set_message_bounds(settlement.healer_msg_bottom_left, settlement.healer_msg_bottom_right)
		else:
			chat_bubble.clear_message_bounds()

func _show_greeting(greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	var greeting = greetings[randi() % greetings.size()]
	chat_bubble.show_with_text(greeting, 4.0)

func _update_button_states():
	if not GameInfo.current_player:
		return
	var has_heal_silver = GameInfo.current_player.silver >= HEAL_COST
	var has_cure_silver = GameInfo.current_player.silver >= CURE_COST
	if heal_button:
		heal_button.disabled = GameInfo.current_player.depleted_health <= 0 or not has_heal_silver
		_set_price_label_color(heal_button, has_heal_silver)
	if cure_button:
		cure_button.disabled = not _has_curable_effects() or not has_cure_silver
		_set_price_label_color(cure_button, has_cure_silver)
	_update_status()

func _set_price_label_color(button: Button, can_afford: bool):
	var price_label = button.get_node_or_null("Content/PriceLabel") as Label
	if price_label:
		price_label.add_theme_color_override("font_color", COLOR_PRICE_NORMAL if can_afford else COLOR_PRICE_MISSING)

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
