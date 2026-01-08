extends Panel

# Arena slideshow for enemy cards
@export var slide_duration: float = 0.3

var current_index: int = 0
var cards: Array[Control] = []
var card_container: Control
var prev_button: Button
var next_button: Button
var fight_button: Button

# For slide animations
var is_animating: bool = false

func _ready():
	# Get references to scene nodes
	card_container = $CardContainer
	prev_button = $PrevButton
	next_button = $NextButton
	fight_button = $FightButton
	
	# Get the arena opponent cards from the scene
	cards = [
		$CardContainer/ArenaOpponent1,
		$CardContainer/ArenaOpponent2,
		$CardContainer/ArenaOpponent3
	]
	
	# Set up enemy data from GameInfo
	_load_opponent_data()
	
	# Connect button signals
	prev_button.pressed.connect(_on_prev_pressed)
	next_button.pressed.connect(_on_next_pressed)
	fight_button.pressed.connect(_on_fight_pressed)
	
	# Style buttons
	_style_buttons()
	
	# Show first card
	_update_display()

func _load_opponent_data():
	# Look up arena opponents by name from mock data
	if GameInfo.arena_opponents.size() > 0 and GameInfo.enemy_players.size() > 0:
		for i in range(min(cards.size(), GameInfo.arena_opponents.size())):
			var card = cards[i]
			var opponent_name = GameInfo.arena_opponents[i]
			
			# Find opponent by name in enemy_players
			var opponent = null
			for player in GameInfo.enemy_players:
				if player.name == opponent_name:
					opponent = player
					break
			
			if opponent:
				# Get total stats (base + equipment + perks)
				var total_stats = opponent.get_total_stats()
				
				# Set the enemy data with calculated total stats
				card.set_enemy_data(i + 1, opponent.name, total_stats.strength, total_stats.stamina, total_stats.agility, total_stats.luck, total_stats.armor)
				
				# Pass the full opponent data for perks display
				card.set_opponent_data(opponent)
			else:
				print("Warning: Could not find opponent '", opponent_name, "' in enemy_players")
	else:
		print("Warning: No arena opponents data available")

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
	
	# Fight button gets a special red style
	var fight_style = button_style.duplicate()
	fight_style.bg_color = Color(0.6, 0.2, 0.2, 0.9)
	fight_style.border_color = Color(1.0, 0.4, 0.4, 1.0)
	fight_button.add_theme_stylebox_override("normal", fight_style)
	
	var fight_hover_style = fight_style.duplicate()
	fight_hover_style.bg_color = Color(0.8, 0.3, 0.3, 1.0)
	fight_hover_style.border_color = Color(1.0, 0.6, 0.6, 1.0)
	fight_button.add_theme_stylebox_override("hover", fight_hover_style)

func _on_fight_pressed():
	if GameInfo.arena_opponents.size() > current_index:
		var opponent_name = GameInfo.arena_opponents[current_index]
		GameInfo.set_arena_opponent(opponent_name)
		print("Fighting enemy: ", opponent_name)
		# TODO: Implement fight logic
	else:
		print("No opponent data available")

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
	
	# Wait one frame to ensure container size is properly calculated
	await get_tree().process_frame
	
	# Use a more reliable width calculation
	var card_width = max(card_container.size.x, 400)  # Fallback minimum width
	var start_x = card_width * 1.2 if not sliding_left else -card_width * 1.2  # Go further offscreen
	
	# Position the new card offscreen first, THEN make it visible
	new_card.position.x = start_x
	new_card.visible = true
	
	# Create tweens for smooth sliding
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Slide current card out
	var end_x = -card_width * 1.2 if not sliding_left else card_width * 1.2
	tween.tween_property(current_card, "position:x", end_x, slide_duration)
	
	# Slide new card in from offscreen to center
	tween.tween_property(new_card, "position:x", 0, slide_duration)
	
	# Set easing for smoother animation
	tween.set_trans(Tween.TRANS_QUART)
	tween.set_ease(Tween.EASE_OUT)
	
	# When animation completes
	await tween.finished
	
	# Hide the old card and reset its position
	current_card.visible = false
	current_card.position.x = 0
	
	current_index = new_index
	is_animating = false
	
	_update_button_states()

func _update_display():
	# Hide all cards except current and reset their positions
	for i in range(cards.size()):
		if i == current_index:
			cards[i].visible = true
			cards[i].position = Vector2.ZERO
		else:
			cards[i].visible = false
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
