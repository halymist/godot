extends Panel

# Training costs
const TALENT_POINT_COST = 100
const STAT_COST = 5

@export var utility_background_container: Control
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

var utility_background: UtilityBackground

func _ready():
	talent_points_button.pressed.connect(_on_stat_plus_pressed.bind("talent_points", TALENT_POINT_COST))
	strength_button.pressed.connect(_on_stat_plus_pressed.bind("strength", STAT_COST))
	stamina_button.pressed.connect(_on_stat_plus_pressed.bind("stamina", STAT_COST))
	agility_button.pressed.connect(_on_stat_plus_pressed.bind("agility", STAT_COST))
	luck_button.pressed.connect(_on_stat_plus_pressed.bind("luck", STAT_COST))
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
		update_stats_display()
		update_button_states()
		utility_background.show_entered_greeting()

func _load_location_content():
	var location_data = GameInfo.settlements_db.get_location_by_id(GameInfo.current_player.location)
	
	for child in utility_background_container.get_children():
		child.queue_free()
	
	var utility_instance = location_data.trainer_utility_scene.instantiate()
	utility_background_container.add_child(utility_instance)
	
	utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
	utility_instance.offset_left = 0
	utility_instance.offset_top = 0
	utility_instance.offset_right = 0
	utility_instance.offset_bottom = 0
	
	utility_background = utility_instance

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

func _on_stat_plus_pressed(stat_name: String, cost: int):
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
	print("Trained ", stat_name, " - cost: ", cost, " silver")
	utility_background.show_action_greeting()
