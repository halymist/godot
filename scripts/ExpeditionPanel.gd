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

# Requirement types (matching ExpeditionOption enum)
enum RequirementType {
	NONE,
	COMBAT,
	STRENGTH,
	STAMINA,
	AGILITY,
	LUCK,
	ARMOR,
	SILVER,
	ORDER,
	GUILD,
	COMPANIONS
}

# Reward types (matching ExpeditionOption enum)
enum RewardType {
	NONE,
	SILVER,
	ITEM,
	PERK,
	STRENGTH,
	STAMINA,
	AGILITY,
	LUCK,
	ARMOR,
	MIN_DAMAGE,
	MAX_DAMAGE,
	TALENT_POINT,
	POTION,
	BLESSING
}

# Stat maps for unified handling
var STAT_REQUIREMENT_MAP = {
	RequirementType.STRENGTH: "strength",
	RequirementType.STAMINA: "stamina",
	RequirementType.AGILITY: "agility",
	RequirementType.LUCK: "luck",
	RequirementType.ARMOR: "armor"
}

var STAT_REWARD_MAP = {
	RewardType.STRENGTH: {"property": "strength", "name": "strength"},
	RewardType.STAMINA: {"property": "stamina", "name": "stamina"},
	RewardType.AGILITY: {"property": "agility", "name": "agility"},
	RewardType.LUCK: {"property": "luck", "name": "luck"},
	RewardType.ARMOR: {"property": "armor", "name": "armor"},
	RewardType.MIN_DAMAGE: {"property": "damage_min", "name": "min damage"},
	RewardType.MAX_DAMAGE: {"property": "damage_max", "name": "max damage"}
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
	expedition_text.text = slide.text
	
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
		label.text = option.text
	
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
	"""Get the appropriate icon for an option based on its requirement type"""
	var req_type = option.required_type
	match req_type:
		RequirementType.COMBAT:
			return combat_icon
		RequirementType.SILVER:
			return currency_check_icon
		RequirementType.STRENGTH:
			return strength_icon
		RequirementType.STAMINA:
			return stamina_icon
		RequirementType.AGILITY:
			return agility_icon
		RequirementType.LUCK:
			return luck_icon
		RequirementType.ARMOR:
			return armor_icon
		RequirementType.ORDER:
			return order_icon
		RequirementType.GUILD:
			return guild_icon
		RequirementType.COMPANIONS:
			return companions_icon
		_:
			return dialogue_icon

func _check_requirements(option: Resource) -> bool:
	"""Check if player meets the requirements for an option"""
	var req_type = option.required_type
	
	if req_type == RequirementType.NONE:
		return true
	
	var player = GameInfo.current_player
	if not player:
		return false
	
	var stats = player.get_total_stats()
	
	# Check stat requirements
	if req_type in STAT_REQUIREMENT_MAP:
		var stat_name = STAT_REQUIREMENT_MAP[req_type]
		var stat_value = stats.get(stat_name, 0)
		return stat_value >= option.required_amount
	
	# Check silver
	if req_type == RequirementType.SILVER:
		return player.silver >= option.required_amount
	
	# Check faction requirements
	match req_type:
		RequirementType.ORDER:
			return player.faction == 1
		RequirementType.GUILD:
			return player.faction == 2
		RequirementType.COMPANIONS:
			return player.faction == 3
	
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
	
	var reward_type = slide.reward_type
	var reward_amount = slide.reward_amount
	
	if reward_type == RewardType.NONE:
		return
	
	print("Applying slide reward: type=", reward_type, " amount=", reward_amount)
	
	match reward_type:
		RewardType.SILVER:
			player.silver += reward_amount
			UIManager.instance.update_display()
		RewardType.TALENT_POINT:
			player.talent_points += reward_amount
		RewardType.BLESSING:
			player.blessing += reward_amount
		RewardType.POTION:
			player.potion += reward_amount
		_:
			# Handle stat rewards
			if reward_type in STAT_REWARD_MAP:
				var stat_info = STAT_REWARD_MAP[reward_type]
				var current_value = player.get(stat_info.property)
				player.set(stat_info.property, current_value + reward_amount)
	
	# Show reward text in UI
	_show_reward_text(slide)

func _show_reward_text(slide: Resource):
	"""Display reward text for the slide"""
	if not reward_label:
		return
	
	var reward_type = slide.reward_type
	var reward_amount = slide.reward_amount
	var reward_text = ""
	
	if reward_type == RewardType.NONE:
		reward_label.text = ""
		return
	
	match reward_type:
		RewardType.SILVER:
			reward_text = "+" + str(reward_amount) + " Silver"
		RewardType.ITEM:
			reward_text = "Item received!"
		RewardType.PERK:
			reward_text = "New perk unlocked!"
		RewardType.TALENT_POINT:
			reward_text = "+" + str(reward_amount) + " Talent Point(s)"
		RewardType.BLESSING:
			reward_text = "Blessing increased!"
		RewardType.POTION:
			reward_text = "Potion received!"
		_:
			if reward_type in STAT_REWARD_MAP:
				var stat_info = STAT_REWARD_MAP[reward_type]
				reward_text = "+" + str(reward_amount) + " " + stat_info.name
	
	reward_label.text = reward_text

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
