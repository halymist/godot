extends Panel

# Training costs
const TALENT_POINT_COST = 100
const STAT_COST = 5

# Reference to Background node with SilverManager
@export var background: Node

# Stat labels
@export var background_rect: TextureRect
@export var description_label: Label
@export var talent_points_label: Label
@export var strength_label : Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
# Plus buttons
@export var talent_points_button: Button
@export var strength_button: Button
@export var stamina_button: Button
@export var agility_button: Button
@export var luck_button: Button

func _ready():
	_load_location_content()
	# Connect button signals
	talent_points_button.pressed.connect(_on_talent_points_plus_pressed)
	strength_button.pressed.connect(_on_strength_plus_pressed)
	stamina_button.pressed.connect(_on_stamina_plus_pressed)
	agility_button.pressed.connect(_on_agility_plus_pressed)
	luck_button.pressed.connect(_on_luck_plus_pressed)
	# Update stats display when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	if visible:
		update_stats_display()
		update_button_states()

func _load_location_content():
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	if background_rect and location_data.trainer_background:
		background_rect.texture = location_data.trainer_background
	if description_label:
		description_label.text = location_data.get_random_trainer_greeting()

func _update_silver():
	"""Update silver display via UIManager"""
	if background:
		var ui_manager = background.get_node_or_null("UIManager")
		if ui_manager and ui_manager.has_method("update_display"):
			ui_manager.update_display()
		update_button_states()

func update_stats_display():
	if not GameInfo.current_player:
		return
	
	talent_points_label.text = "Talents: " + str(GameInfo.current_player.talent_points)
	strength_label.text = "Strength: " + str(GameInfo.current_player.strength)
	stamina_label.text = "Stamina: " + str(GameInfo.current_player.stamina)
	agility_label.text = "Agility: " + str(GameInfo.current_player.agility)
	luck_label.text = "Luck: " + str(GameInfo.current_player.luck)

func update_button_states():
	if not GameInfo.current_player:
		return
	
	var silver = GameInfo.current_player.silver
	
	# Enable/disable buttons based on gold availability
	talent_points_button.disabled = silver < TALENT_POINT_COST
	strength_button.disabled = silver < STAT_COST
	stamina_button.disabled = silver < STAT_COST
	agility_button.disabled = silver < STAT_COST
	luck_button.disabled = silver < STAT_COST

# Training functions
func _on_talent_points_plus_pressed():
	if GameInfo.current_player.silver >= TALENT_POINT_COST:
		UIManager.instance.update_silver(-TALENT_POINT_COST)
		GameInfo.current_player.talent_points += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Talent Points - cost: ", TALENT_POINT_COST, " gold")

func _on_strength_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.strength += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Strength - cost: ", STAT_COST, " gold")

func _on_stamina_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.stamina += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Stamina - cost: ", STAT_COST, " gold")

func _on_agility_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.agility += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Agility - cost: ", STAT_COST, " gold")

func _on_luck_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.luck += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Luck - cost: ", STAT_COST, " gold")
