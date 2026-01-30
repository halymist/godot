extends Panel

# Expedition panel - similar to Quest.gd but for expedition content
@export var text_container: Node  # Center container for expedition text
@export var options_container: VBoxContainer  # Buttons below text
@export var reward_label: Label  # Label to display rewards
@export var background: TextureRect
@export var expedition_text: Label

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

func _on_visibility_changed():
	"""Auto-load expedition slide when panel becomes visible"""
	if visible:
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
	expedition_text.text = slide.slide_text
	
	# Update background if slide has texture
	if slide.texture and background:
		background.texture = slide.texture
	
	# Clear existing options
	for child in options_container.get_children():
		child.queue_free()
	
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
		# Server handles item - just show notification
		reward_texts.append("Item received!")
	
	if slide.reward_perk > 0:
		reward_texts.append("Perk unlocked!")
	
	if slide.reward_blessing > 0:
		player.blessing += slide.reward_blessing
		reward_texts.append("+%d Blessing" % slide.reward_blessing)
	
	if slide.reward_potion > 0:
		player.potion += slide.reward_potion
		reward_texts.append("+%d Potion" % slide.reward_potion)
	
	# Show combined reward text
	if reward_label and reward_texts.size() > 0:
		reward_label.text = ", ".join(reward_texts)
		print("Applying slide rewards: ", reward_label.text)
	elif reward_label:
		reward_label.text = ""

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
