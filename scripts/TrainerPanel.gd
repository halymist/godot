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

var utility_background: UtilityBackground  # Found from loaded utility scene

func _ready():
	# Don't load location content yet - wait for character selection
	# Connect button signals
	talent_points_button.pressed.connect(_on_talent_points_plus_pressed)
	strength_button.pressed.connect(_on_strength_plus_pressed)
	stamina_button.pressed.connect(_on_stamina_plus_pressed)
	agility_button.pressed.connect(_on_agility_plus_pressed)
	luck_button.pressed.connect(_on_luck_plus_pressed)
	
	# Connect to character changed signal
	GameInfo.character_changed.connect(_on_character_changed)
	
	# Update stats display when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)

func _on_character_changed():
	_load_location_content()
	update_stats_display()
	update_button_states()

func _on_visibility_changed():
	if visible:
		update_stats_display()
		update_button_states()
		# Show entered greeting when panel becomes visible
		if utility_background:
			utility_background.show_entered_greeting()

func _load_location_content():
	if not GameInfo.current_player:
		return
		
	var location_data = GameInfo.get_location_data(GameInfo.current_player.location)
	
	# Clear existing children from container
	if utility_background_container:
		for child in utility_background_container.get_children():
			child.queue_free()
	
	# Instantiate and add the utility scene
	if location_data.trainer_utility_scene:
		var utility_instance = location_data.trainer_utility_scene.instantiate()
		utility_background_container.add_child(utility_instance)
		
		# Set to full rect (anchors 0,0 to 1,1 with zero offsets)
		if utility_instance is Control:
			utility_instance.set_anchors_preset(Control.PRESET_FULL_RECT)
			utility_instance.offset_left = 0
			utility_instance.offset_top = 0
			utility_instance.offset_right = 0
			utility_instance.offset_bottom = 0
		
		# Get reference to the utility background script
		if utility_instance is UtilityBackground:
			utility_background = utility_instance
		else:
			utility_background = null

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
		# Show action greeting after training
		if utility_background:
			utility_background.show_action_greeting()

func _on_strength_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.strength += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Strength - cost: ", STAT_COST, " gold")
		# Show action greeting after training
		if utility_background:
			utility_background.show_action_greeting()

func _on_stamina_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.stamina += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Stamina - cost: ", STAT_COST, " gold")
		# Show action greeting after training
		if utility_background:
			utility_background.show_action_greeting()

func _on_agility_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.agility += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Agility - cost: ", STAT_COST, " gold")
		# Show action greeting after training
		if utility_background:
			utility_background.show_action_greeting()

func _on_luck_plus_pressed():
	if GameInfo.current_player.silver >= STAT_COST:
		UIManager.instance.update_silver(-STAT_COST)
		GameInfo.current_player.luck += 1
		UIManager.instance.refresh_stats()
		update_stats_display()
		print("Trained Luck - cost: ", STAT_COST, " gold")
		# Show action greeting after training
		if utility_background:
			utility_background.show_action_greeting()
