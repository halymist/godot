extends TextureRect

# Expedition panel - similar to Quest.gd but for expedition content
@export var text_container: Node  # Center container for expedition text
@export var options_container: VBoxContainer  # Buttons below text
@export var reward_label: Label  # Label to display rewards
@export var expedition_text: Label
@export var health_bar: TextureProgressBar
@export var effects_container: Control

# Icon textures for different option types
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

# Reference to portrait for navigation
@export var portrait: Control

# Expedition state
var current_slide_id: int = 0

# Preloaded option scene (reuse quest_option.tscn)
const OptionScene = preload("res://Scenes/quest_option.tscn")

# Stat type string -> icon mapping (server sends stat_type as string)
var STAT_ICON_MAP = {
	"strength": "strength_icon",
	"stamina": "stamina_icon",
	"agility": "agility_icon",
	"luck": "luck_icon",
	"armor": "armor_icon"
}

func _ready():
	visible = false
	visibility_changed.connect(_on_visibility_changed)

	# Wait for game_ready before setup
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	print("ExpeditionPanel: Setup complete")

func _on_visibility_changed():
	"""Auto-load expedition slide when panel becomes visible"""
	if visible:
		_update_health_bar()
		var expedition = GameInfo.current_player.expedition
		if expedition and expedition.size() > 0:
			var slide_id = expedition[0]
			# Only load if we're not already showing this slide
			if current_slide_id != slide_id:
				print("ExpeditionPanel: Auto-loading slide ", slide_id)
				start_expedition(1, slide_id)

func start_expedition(_expedition_id: int, slide_id: int):
	"""Start or resume an expedition at a specific slide"""
	# expedition_id is ignored - we just use slides directly from database
	current_slide_id = slide_id
	show_slide(slide_id)
	visible = true

func show_slide(slide_id: int):
	"""Display a specific slide and apply its rewards"""
	var slide = GameInfo.expeditions_db.get_slide(slide_id)
	if not slide:
		print("Error: Slide not found: ", slide_id)
		return
	
	current_slide_id = slide_id
	
	# Update text
	_animate_expedition_text(slide.slide_text)
	_update_health_bar()
	
	# Update background if slide has texture
	if slide.texture:
		texture = slide.texture

	
	# Clear existing options
	_clear_options()
	
	# Clear reward label
	if reward_label:
		reward_label.text = ""
	
	# Apply slide rewards
	_apply_slide_rewards(slide)

	# Add options
	for option in slide.options:
		_add_option_button(option)

func _add_option_button(option: Resource):
	"""Create and add an option button"""
	var option_button = OptionScene.instantiate()
	options_container.add_child(option_button)
	
	# Set text
	var label = option_button.get_node_or_null("Label")
	if label:
		label.text = option.option_text
	
	# Set icon based on requirement type
	var icon = option_button.get_node_or_null("Icon")
	if icon:
		icon.texture = _get_option_icon(option)
	
	# Check if player meets requirements
	var can_select = _check_requirements(option)
	option_button.disabled = not can_select
	option_button.modulate.a = 1.0 if can_select else 0.5
	
	# Connect signal
	option_button.pressed.connect(_on_option_selected.bind(option))

func _get_option_icon(option: Resource) -> Texture2D:
	"""Get the appropriate icon for an option based on its stat_type or enemy_id"""
	# Combat option (has enemy)
	if option.enemy_id > 0:
		return combat_icon
	
	# Stat check option
	var stat = option.stat_type
	match stat:
		"strength":
			return strength_icon
		"stamina":
			return stamina_icon
		"agility":
			return agility_icon
		"luck":
			return luck_icon
		"armor":
			return armor_icon
		_:
			# Default dialogue icon
			return dialogue_icon

func _check_requirements(option: Resource) -> bool:
	"""Check if player meets the requirements for an option"""
	# No stat requirement
	if option.stat_type == "" and option.stat_required <= 0:
		return true
	
	var player = GameInfo.current_player
	if not player:
		return false
	
	var stats = player.get_total_stats()
	
	# Check stat requirement
	var stat_type = option.stat_type
	if stat_type != "" and option.stat_required > 0:
		var stat_value = stats.get(stat_type, 0)
		return stat_value >= option.stat_required
	
	return true

func _on_option_selected(option: Resource):
	"""Handle option selection"""
	print("Expedition option selected: ", option.option_id)
	
	# Send to server - server will respond with next slide
	Websocket.expedition_option(option.option_id)

func _apply_slide_rewards(slide: Resource):
	"""Apply rewards from the slide when it's shown"""
	var player = GameInfo.current_player
	if not player:
		return
	
	var reward_texts = []
	
	# Check each reward type (new individual fields)
	if slide.reward_stat_type > 0 and slide.reward_stat_amount > 0:
		var stat_name = _get_stat_name(slide.reward_stat_type)
		if stat_name != "":
			var current = player.get(stat_name)
			player.set(stat_name, current + slide.reward_stat_amount)
			reward_texts.append("+%d %s" % [slide.reward_stat_amount, stat_name.capitalize()])
	
	if slide.reward_talent > 0:
		player.talent_points += slide.reward_talent
		reward_texts.append("+%d Talent Point(s)" % slide.reward_talent)
	
	if slide.reward_item > 0:
		var added = player.add_item_to_bag(slide.reward_item)
		if added:
			var item_resource = GameInfo.items_db.get_item_by_id(slide.reward_item) if GameInfo.items_db else null
			if item_resource:
				reward_texts.append("You receive " + item_resource.item_name + ".")
			else:
				reward_texts.append("Item received!")
			print("REWARD: Added Item ID ", slide.reward_item, " to bag")
			if UIManager.instance:
				UIManager.instance.refresh_bags()
		else:
			reward_texts.append("Your bag is full!")
	
	if slide.reward_perk > 0:
		var added_perk = player.add_perk_if_new(slide.reward_perk)
		var perk_resource = GameInfo.perks_db.get_perk_by_id(slide.reward_perk) if GameInfo.perks_db else null
		if added_perk:
			reward_texts.append("You receive the perk: " + perk_resource.perk_name + "." if perk_resource else "Perk unlocked!")
		else:
			reward_texts.append("You already have this perk (" + perk_resource.perk_name + ")." if perk_resource else "Perk already owned!")
	
	if slide.reward_blessing > 0:
		player.blessing = slide.reward_blessing
		var blessing_res = GameInfo.perks_db.get_perk_by_id(slide.reward_blessing) if GameInfo.perks_db else null
		reward_texts.append("You receive a blessing: " + blessing_res.perk_name + "." if blessing_res else "+%d Blessing" % slide.reward_blessing)
		if UIManager.instance:
			UIManager.instance.refresh_active_effects()
	
	if slide.reward_potion > 0:
		player.potion = slide.reward_potion
		var potion_res = GameInfo.items_db.get_item_by_id(slide.reward_potion) if GameInfo.items_db else null
		reward_texts.append("You receive a potion: " + potion_res.item_name + "." if potion_res else "+%d Potion" % slide.reward_potion)
		if UIManager.instance:
			UIManager.instance.refresh_active_effects()

	# Apply slide effect (e.g., effect_id 200 = health depletion)
	if slide.effect_id == 200 and slide.effect_factor != 0:
		var percent = abs(float(slide.effect_factor))
		player.depleted_health = clamp(player.depleted_health + percent, 0.0, 100.0)
		reward_texts.append("You lose %d%% of your health." % int(percent))
		if UIManager.instance:
			UIManager.instance.refresh_stats()
	
	# Show combined reward text
	if reward_label and reward_texts.size() > 0:
		reward_label.text = ", ".join(reward_texts)
		print("Applying slide rewards: ", reward_label.text)
	elif reward_label:
		reward_label.text = ""

	_update_health_bar()

func _get_stat_name(stat_type: int) -> String:
	"""Convert stat type int to stat name"""
	match stat_type:
		1: return "strength"
		2: return "stamina"
		3: return "agility"
		4: return "luck"
		5: return "armor"
		_: return ""

func _show_reward_text(_slide: Resource):
	"""Display reward text for the slide - handled in _apply_slide_rewards now"""
	pass

func receive_next_slide(slide_id: int):
	"""Called when server responds with next slide"""
	if slide_id <= 0:
		# Expedition ended
		end_expedition()
	else:
		show_slide(slide_id)
		# Update player's expedition state
		GameInfo.current_player.expedition = [slide_id]

func handle_expedition_failed(message: String):
	"""Handle a failed expedition option by clearing state and showing a placeholder message"""
	current_slide_id = 0
	visible = true

	_clear_options()
	if reward_label:
		reward_label.text = ""

	var placeholder = message if message != "" else "Expedition ended. Return home."
	_animate_expedition_text(placeholder)

	if GameInfo.current_player:
		GameInfo.current_player.expedition = []
		GameInfo.current_player.traveling_destination = null
		GameInfo.current_player.traveling = 0

	if UIManager.instance and UIManager.instance.map_panel:
		UIManager.instance.map_panel.reset_expedition_state()
	_update_health_bar()

func handle_expedition_end(message: String):
	"""Handle a successful expedition end by showing a placeholder while keeping last texture"""
	current_slide_id = 0
	visible = true

	_clear_options()
	if reward_label:
		reward_label.text = ""

	var placeholder = message if message != "" else "Expedition ended. Return home."
	_animate_expedition_text(placeholder)

	if GameInfo.current_player:
		GameInfo.current_player.expedition = []
		GameInfo.current_player.traveling_destination = null
		GameInfo.current_player.traveling = 0

	if UIManager.instance and UIManager.instance.map_panel:
		UIManager.instance.map_panel.reset_expedition_state()
	_update_health_bar()

func end_expedition():
	"""End the current expedition"""
	current_slide_id = 0
	visible = false
	
	# Clear player's expedition state
	GameInfo.current_player.expedition = []
	
	print("Expedition ended")

func is_on_expedition() -> bool:
	"""Check if player is currently on an expedition"""
	return visible and current_slide_id > 0

func _update_health_bar():
	if not health_bar or not GameInfo.current_player:
		return

	var total_stats = GameInfo.current_player.get_total_stats()
	var max_health = total_stats.stamina * 10
	var depleted_percent = GameInfo.current_player.depleted_health
	var current_health = max(0, int(round(max_health * (1.0 - depleted_percent / 100.0))))
	health_bar.max_value = max_health
	health_bar.value = current_health
	if health_bar.has_node("HealthLabel"):
		health_bar.get_node("HealthLabel").text = str(current_health) + " / " + str(max_health)

func _clear_options():
	for child in options_container.get_children():
		child.queue_free()

func _animate_expedition_text(text: String):
	"""Animate expedition text with fade and slide effect (match quest style)"""
	expedition_text.text = text
	expedition_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	expedition_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	expedition_text.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(expedition_text, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
