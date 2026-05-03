extends TextureRect

# Arena slideshow for enemy cards
@export var slide_duration: float = 0.3
@export var card_container: Control
@export var prev_button: TextureButton
@export var next_button: TextureButton
@export var fight_button: TextureButton
@export var arena_opponent1: Control
@export var arena_opponent2: Control
@export var arena_opponent3: Control

var current_index: int = 0
var cards: Array[Control] = []

# For slide animations
var is_animating: bool = false
var slide_tween: Tween  # Reusable tween for card animations

func _get_available_opponent_count() -> int:
	return min(cards.size(), GameInfo.arena_opponents.size())

func _ready():
	# Build cards array from exports
	cards = [arena_opponent1, arena_opponent2, arena_opponent3]
	
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	visibility_changed.connect(_on_visibility_changed)
	
	# Hover/click feedback for arena buttons
	var golden = Color(0.9, 0.7, 0.4, 1)
	var default_color = Color(1, 1, 1, 1)
	for btn in [prev_button, next_button, fight_button]:
		btn.mouse_entered.connect(func(): btn.modulate = golden)
		btn.mouse_exited.connect(func(): btn.modulate = default_color)
		btn.button_down.connect(func(): btn.modulate = golden)
		btn.button_up.connect(func(): btn.modulate = default_color)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_load_arena_background()
	_update_display()

func _on_visibility_changed():
	if visible:
		_load_opponent_data()

func _load_opponent_data():
	var available_count = _get_available_opponent_count()

	# Hide all cards first so stale/default content is never shown.
	for card in cards:
		card.visible = false

	# Look up arena opponents by character_id
	for i in range(available_count):
		var opponent_id = GameInfo.arena_opponents[i]
		var found_player = null
		
		# Find opponent by character_id in enemy_players
		for player in GameInfo.enemy_players:
			if player.character_id == opponent_id:
				found_player = player
				break

		if found_player:
			cards[i].set_opponent_data(found_player)
			cards[i].visible = true

	# Clamp current index to available cards.
	if available_count <= 0:
		current_index = 0
	elif current_index >= available_count:
		current_index = 0

	_update_display()

func _load_arena_background():
	"""Load arena background texture from settlements database"""
	var settlement_id = GameInfo.current_player.location
	var settlement = GameInfo.settlements_db.get_location_by_id(settlement_id)
	
	if settlement and settlement.arena_background:
		texture = settlement.arena_background
	else:
		pass

func _on_fight_pressed():
	var available_count = _get_available_opponent_count()
	if available_count > current_index:
		var opponent_id = GameInfo.arena_opponents[current_index]
		
		# Show loading state on button
		fight_button.disabled = true
		
		# Send fight request to server - combat result will come via WebSocket response
		Websocket.fight_player(opponent_id)
	else:
		pass

func reset_fight_button():
	"""Reset fight button to normal state (called after combat loads or on error)"""
	fight_button.disabled = false

func _on_prev_pressed():
	if is_animating:
		return
	var available_count = _get_available_opponent_count()
	if available_count <= 1:
		return
	
	var new_index = current_index - 1
	if new_index < 0:
		new_index = available_count - 1
	
	_slide_to_card(new_index, true)

func _on_next_pressed():
	if is_animating:
		return
	var available_count = _get_available_opponent_count()
	if available_count <= 1:
		return
	
	var new_index = current_index + 1
	if new_index >= available_count:
		new_index = 0
	
	_slide_to_card(new_index, false)

func _slide_to_card(new_index: int, sliding_left: bool):
	if new_index == current_index or is_animating:
		return
	
	is_animating = true
	
	var current_card = cards[current_index]
	var new_card = cards[new_index]
	
	# Wait one frame to ensure container size is properly calculated
	await get_tree().process_frame
	
	# Use a more reliable width calculation
	var card_width = max(card_container.size.x, 400)  # Fallback minimum width
	var start_x = card_width * 1.2 if not sliding_left else -card_width * 1.2  # Go further offscreen
	
	# Position the new card offscreen first, THEN make it visible
	new_card.position.x = start_x
	new_card.visible = true
	
	# Stop any existing tween and create new one
	if slide_tween:
		slide_tween.kill()
	slide_tween = create_tween()
	slide_tween.set_parallel(true)
	
	# Slide current card out
	var end_x = -card_width * 1.2 if not sliding_left else card_width * 1.2
	slide_tween.tween_property(current_card, "position:x", end_x, slide_duration)
	
	# Slide new card in from offscreen to center
	slide_tween.tween_property(new_card, "position:x", 0, slide_duration)
	
	# Set easing for smoother animation
	slide_tween.set_trans(Tween.TRANS_QUART)
	slide_tween.set_ease(Tween.EASE_OUT)
	
	# When animation completes
	await slide_tween.finished
	
	# Hide the old card and reset its position
	current_card.visible = false
	current_card.position.x = 0
	
	current_index = new_index
	is_animating = false
	
	_update_button_states()

func _update_display():
	var available_count = _get_available_opponent_count()

	if available_count <= 0:
		for card in cards:
			card.visible = false
			card.position = Vector2.ZERO
		_update_button_states()
		return

	# Hide all cards except current and reset their positions
	for i in range(cards.size()):
		if i < available_count and i == current_index:
			cards[i].visible = true
			cards[i].position = Vector2.ZERO
		else:
			cards[i].visible = false
			cards[i].position = Vector2.ZERO
	
	_update_button_states()

func _update_button_states():
	var available_count = _get_available_opponent_count()
	prev_button.disabled = available_count <= 1
	next_button.disabled = available_count <= 1
	fight_button.disabled = available_count <= 0

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
