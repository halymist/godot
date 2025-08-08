extends Panel

# Arena slideshow for enemy cards
@export var opponent_scene: PackedScene
@export var slide_duration: float = 0.3

var current_index: int = 0
var cards: Array[Control] = []
var card_container: Control
var prev_button: Button
var next_button: Button

# For slide animations
var is_animating: bool = false

# Enemy data
var enemies_data = [
	{"name": "Goblin Warrior", "hp": 100, "attack": 25, "defense": 15},
	{"name": "Orc Berserker", "hp": 200, "attack": 50, "defense": 30},
	{"name": "Dragon Lord", "hp": 300, "attack": 75, "defense": 45}
]

func _ready():
	# Get references to scene nodes
	card_container = $CardContainer
	prev_button = $PrevButton
	next_button = $NextButton
	
	# Load the opponent scene
	if not opponent_scene:
		opponent_scene = load("res://Scenes/arena_opponent.tscn")
	
	# Connect button signals
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	
	# Style buttons
	_style_buttons()
	
	# Create enemy cards
	_create_enemy_cards()
	
	# Show first card
	_update_display()

func _style_buttons():
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.2, 0.3, 0.9)
	button_style.border_color = Color(0.6, 0.6, 0.8, 1.0)
	button_style.border_width_left = 3
	button_style.border_width_right = 3
	button_style.border_width_top = 3
	button_style.border_width_bottom = 3
	button_style.corner_radius_top_left = 10
	button_style.corner_radius_top_right = 10
	button_style.corner_radius_bottom_left = 10
	button_style.corner_radius_bottom_right = 10
	button_style.shadow_color = Color(0, 0, 0, 0.5)
	button_style.shadow_size = 5
	button_style.shadow_offset = Vector2(2, 2)
	
	prev_button.add_theme_stylebox_override("normal", button_style)
	next_button.add_theme_stylebox_override("normal", button_style)
	
	# Hover style
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.3, 0.3, 0.4, 1.0)
	hover_style.border_color = Color(0.8, 0.8, 1.0, 1.0)
	
	prev_button.add_theme_stylebox_override("hover", hover_style)
	next_button.add_theme_stylebox_override("hover", hover_style)

func _create_enemy_cards():
	for i in range(enemies_data.size()):
		var card_instance = opponent_scene.instantiate()
		var enemy_data = enemies_data[i]
		
		# Set enemy data
		card_instance.set_enemy_data(i + 1, enemy_data.name, enemy_data.hp, enemy_data.attack, enemy_data.defense)
		
		# Add to container
		card_container.add_child(card_instance)
		cards.append(card_instance)
		
		# Position cards (all at same spot, only one visible)
		card_instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card_instance.visible = (i == 0)

func _on_prev_pressed():
	if is_animating:
		return
	
	var new_index = current_index - 1
	if new_index < 0:
		new_index = cards.size() - 1
	
	_slide_to_card(new_index, true)

func _on_next_pressed():
	if is_animating:
		return
	
	var new_index = current_index + 1
	if new_index >= cards.size():
		new_index = 0
	
	_slide_to_card(new_index, false)

func _slide_to_card(new_index: int, sliding_left: bool):
	if new_index == current_index or is_animating:
		return
	
	is_animating = true
	
	var current_card = cards[current_index]
	var new_card = cards[new_index]
	
	# Set up new card position (offscreen)
	var card_width = card_container.size.x
	var start_x = card_width if not sliding_left else -card_width
	
	new_card.position.x = start_x
	new_card.visible = true
	
	# Create tweens for smooth sliding
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Slide current card out
	var end_x = -card_width if not sliding_left else card_width
	tween.tween_property(current_card, "position:x", end_x, slide_duration)
	
	# Slide new card in
	tween.tween_property(new_card, "position:x", 0, slide_duration)
	
	# Set easing
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	
	# When animation completes
	await tween.finished
	
	# Hide the old card and reset position
	current_card.visible = false
	current_card.position.x = 0
	
	current_index = new_index
	is_animating = false
	
	_update_button_states()

func _update_display():
	# Hide all cards except current
	for i in range(cards.size()):
		cards[i].visible = (i == current_index)
		cards[i].position = Vector2.ZERO
	
	_update_button_states()

func _update_button_states():
	prev_button.disabled = false
	next_button.disabled = false
	
	var prev_index = (current_index - 1) % cards.size()
	var next_index = (current_index + 1) % cards.size()
	
	prev_button.text = "< PREV (" + str(prev_index + 1) + ")"
	next_button.text = "NEXT (" + str(next_index + 1) + ") >"

func get_current_enemy_index() -> int:
	return current_index

func show_card(index: int, animate: bool = true):
	if index < 0 or index >= cards.size() or index == current_index:
		return
	
	if animate:
		var sliding_left = index < current_index
		_slide_to_card(index, sliding_left)
	else:
		current_index = index
		_update_display()
