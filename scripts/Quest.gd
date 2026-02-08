extends TextureRect

# Eldrum-style scrolling quest display
@export var text_container: Node  # Center container for quest text
@export var options_container: VBoxContainer  # Buttons below text
@export var reward_label: Label  # Label to display quest rewards
@export var quest_text: Label
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

# Quest state
var current_quest_id: int = 0
var current_quest: QuestData = null
var visible_option_ids: Array[int] = []  # Currently visible option IDs
var clicked_option_ids: Array[int] = []  # Track which options were clicked during quest
var pending_combat_option: QuestOption = null  # Store option for after combat

# Reference to portrait for navigation
@export var portrait: Control

# Stat maps for unified handling
const STAT_REQUIREMENT_MAP = {
	QuestOption.RequirementType.STRENGTH: "strength",
	QuestOption.RequirementType.STAMINA: "stamina",
	QuestOption.RequirementType.AGILITY: "agility",
	QuestOption.RequirementType.LUCK: "luck",
	QuestOption.RequirementType.ARMOR: "armor"
}

const STAT_REWARD_MAP = {
	QuestOption.RewardType.STRENGTH: {"property": "strength", "name": "strength"},
	QuestOption.RewardType.STAMINA: {"property": "stamina", "name": "stamina"},
	QuestOption.RewardType.AGILITY: {"property": "agility", "name": "agility"},
	QuestOption.RewardType.LUCK: {"property": "luck", "name": "luck"},
	QuestOption.RewardType.ARMOR: {"property": "armor", "name": "armor"},
	QuestOption.RewardType.MIN_DAMAGE: {"property": "damage_min", "name": "minimum damage"},
	QuestOption.RewardType.MAX_DAMAGE: {"property": "damage_max", "name": "maximum damage"}
}

const STAT_ICON_MAP = {
	QuestOption.RequirementType.STRENGTH: "strength_icon",
	QuestOption.RequirementType.STAMINA: "stamina_icon",
	QuestOption.RequirementType.AGILITY: "agility_icon",
	QuestOption.RequirementType.LUCK: "luck_icon",
	QuestOption.RequirementType.ARMOR: "armor_icon"
}

func _ready():
	# Always connect to visibility changes
	visibility_changed.connect(_on_visibility_changed)
	
	# Check if we're the starter panel
	if UIManager.instance.starter_panel == self:
		print("DynamicOptionsPanel: I am the starter panel")
		_setup()
		UIManager.instance.game_is_ready = true
		UIManager.instance.game_ready.emit()
		print("DynamicOptionsPanel: Emitted game_ready signal")
	else:
		print("DynamicOptionsPanel: Waiting for game_ready signal")
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	print("DynamicOptionsPanel: Setup complete")

func _on_visibility_changed():
	"""Load quest when panel becomes visible"""
	if not visible:
		return

	_update_health_bar()
	
	# Check if we're returning from combat
	if pending_combat_option != null:
		print("Returning from combat, handling result")
		handle_combat_result()
		return
	
	print("Quest panel is now visible")
	var destination = GameInfo.current_player.traveling_destination
	# Only load if there's a destination and it's not already loaded
	if destination != null and current_quest_id != destination:
		print("Quest panel became visible, loading quest ", destination)
		load_quest(destination)

func load_quest(quest_id: int):
	"""Load a quest and display initial state"""
	print("Loading quest ", quest_id)
	UIManager.instance.show_panel(self)
	
	if current_quest_id != quest_id:
		# Set quest background
		var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id) if GameInfo.quests_db else null
		if quest_data:
			texture = quest_data.background_texture
			current_quest = quest_data
	
	current_quest_id = quest_id
	
	# Initialize visible_option_ids from initially_visible_options
	if current_quest.initially_visible_options.size() > 0:
		visible_option_ids = current_quest.initially_visible_options.duplicate()
	else:
		# Default to all options visible if not specified
		visible_option_ids = []
		for i in range(current_quest.options.size()):
			visible_option_ids.append(current_quest.options[i].option_index)
	
	# Reset clicked options tracking for new quest
	clicked_option_ids.clear()
	
	# Restore quest state from quest_log if exists
	var last_response_text: String = ""
	if GameInfo.current_player:
		for quest_log_entry in GameInfo.current_player.quest_log:
			if quest_log_entry.get("quest_id", 0) == quest_id:
				var clicked_options = quest_log_entry.get("clicked_options", [])
				if clicked_options.size() > 0:
					print("Restoring quest state with clicked_options: ", clicked_options)
					# Replay clicked options to restore state
					for option_id in clicked_options:
						clicked_option_ids.append(option_id)
						# Hide the clicked option
						if option_id in visible_option_ids:
							visible_option_ids.erase(option_id)
						# Show options that were revealed by this choice
						for option in current_quest.options:
							if option.option_index == option_id:
								# Store the response text from the last clicked option
								last_response_text = option.response_text
								# Show options revealed by this choice
								for show_id in option.shows_option_ids:
									if not show_id in visible_option_ids:
										visible_option_ids.append(show_id)
								# Hide options hidden by this choice
								for hide_id in option.hides_option_ids:
									if hide_id in visible_option_ids:
										visible_option_ids.erase(hide_id)
				break
	
	# Display quest with the correct text
	if last_response_text != "":
		# Show the last clicked option's response text instead of initial text
		display_quest_with_text(last_response_text)
	else:
		display_quest(current_quest)

func display_quest(quest_data: QuestData):
	"""Display quest text and options"""
	display_quest_with_text(quest_data.initial_text)

func animate_quest_text(text: String):
	"""Animate quest text with fade and slide effect"""
	quest_text.text = text
	quest_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quest_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_text.modulate.a = 0
	var tween = create_tween()
	tween.tween_property(quest_text, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)

func display_quest_with_text(text: String):
	"""Display quest with custom text and current visible options"""
	animate_quest_text(text)
	_update_health_bar()
	
	clear_options()
	if current_quest.options:
		for option in current_quest.options:
			if option and visible_option_ids.has(option.option_index):
				add_option(option.text, _on_quest_option_pressed.bind(option), option)
	else:
		print("WARNING: current_quest.options is null or empty")

func apply_option_reward(option: QuestOption):
	"""Apply reward from a quest option to the player"""
	if option.reward_type == QuestOption.RewardType.NONE or option.reward_amount == 0:
		reward_label.text = ""
		return
	
	if not GameInfo.current_player:
		return
	
	var server_day = GameInfo.current_player.server_day
	var scaled_amount = option.reward_amount
	var reward_text = ""
	
	match option.reward_type:
		QuestOption.RewardType.SILVER:
			UIManager.instance.update_silver(option.reward_amount)
			GameInfo.current_player.silver += option.reward_amount
			reward_text = "You receive " + str(option.reward_amount) + " silver."
			print("REWARD: Awarded ", option.reward_amount, " silver")
		
		QuestOption.RewardType.ITEM:
			var added = GameInfo.current_player.add_item_to_bag(option.reward_amount)
			if added:
				var item_resource = GameInfo.items_db.get_item_by_id(option.reward_amount)
				reward_text = "You receive " + item_resource.item_name + "."
				print("REWARD: Added Item ID ", option.reward_amount, " to bag")
				UIManager.instance.refresh_bags()
			else:
				reward_text = "Your bag is full!"
				print("REWARD: No empty bag slot for item")
		
		QuestOption.RewardType.PERK:
			var added = GameInfo.current_player.add_perk_if_new(option.reward_amount)
			var perk_resource = GameInfo.perks_db.get_perk_by_id(option.reward_amount) if GameInfo.perks_db else null
			if added:
				reward_text = "You receive the perk: " + perk_resource.perk_name + "."
				print("REWARD: Perk added to inactive perks")
				UIManager.instance.refresh_perks()
			else:
				reward_text = "You already have this perk (" + perk_resource.perk_name + ")."
				print("REWARD: Perk already owned, skipping")
		
		QuestOption.RewardType.TALENT_POINT:
			GameInfo.current_player.talent_points += option.reward_amount
			reward_text = "You receive " + str(option.reward_amount) + " talent point" + ("s" if option.reward_amount > 1 else "") + "."
			print("REWARD: Awarded ", option.reward_amount, " Talent Points")
			UIManager.instance.refresh_stats()
		
		QuestOption.RewardType.POTION:
			GameInfo.current_player.potion = option.reward_amount
			var item_resource = GameInfo.items_db.get_item_by_id(option.reward_amount)
			reward_text = "You receive a potion: " + item_resource.item_name + "."
			print("REWARD: Equipped Potion ID ", option.reward_amount)
			UIManager.instance.refresh_active_effects()
		
		QuestOption.RewardType.BLESSING:
			GameInfo.current_player.blessing = option.reward_amount
			var perk_resource = GameInfo.perks_db.get_perk_by_id(option.reward_amount) if GameInfo.perks_db else null
			reward_text = "You receive a blessing: " + perk_resource.perk_name + "."
			print("REWARD: Equipped Blessing ID ", option.reward_amount)
			UIManager.instance.refresh_active_effects()
		
		_:
			# Handle all stat rewards using the map
			if option.reward_type in STAT_REWARD_MAP:
				var stat_data = STAT_REWARD_MAP[option.reward_type]
				scaled_amount = int(option.reward_amount * pow(1.02, server_day - 1))
				GameInfo.current_player.set(stat_data.property, GameInfo.current_player.get(stat_data.property) + scaled_amount)
				reward_text = "You receive " + str(scaled_amount) + " " + stat_data.name + "."
				print("REWARD: Awarded ", scaled_amount, " ", stat_data.name)
				UIManager.instance.refresh_stats()
	
	# Display reward text
	if reward_text != "":
		reward_label.text = reward_text
	else:
		reward_label.text = ""

	_update_health_bar()

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

func add_option(text: String, callback: Callable, option_data: QuestOption = null) -> Control:
	"""Add an option to the container using quest_option.tscn"""
	if not options_container:
		return null
	
	var option_scene = load("res://Scenes/quest_option.tscn")
	var option_button = option_scene.instantiate()  # This is now a TextureButton
	
	var label_text = text
	var meets_requirement = true
	var scaled_requirement = 0
	
	# Check unified requirement
	if option_data and option_data.required_type != QuestOption.RequirementType.NONE and GameInfo.current_player:
		var req_type = option_data.required_type
		var req_amount = option_data.required_amount
		
		# Determine if requirement needs day scaling (only stats scale, effects/silver/factions don't)
		var needs_scaling = req_type >= QuestOption.RequirementType.STRENGTH and req_type <= QuestOption.RequirementType.ARMOR
		
		if needs_scaling:
			var server_day = GameInfo.current_player.server_day
			scaled_requirement = int(req_amount * pow(1.02, server_day - 1))
		else:
			scaled_requirement = req_amount
		
		# Check requirement based on type
		match req_type:
			QuestOption.RequirementType.SILVER:
				meets_requirement = GameInfo.current_player.silver >= scaled_requirement
			QuestOption.RequirementType.ORDER:
				meets_requirement = GameInfo.current_player.faction == 1
			QuestOption.RequirementType.GUILD:
				meets_requirement = GameInfo.current_player.faction == 2
			QuestOption.RequirementType.COMPANIONS:
				meets_requirement = GameInfo.current_player.faction == 3
			_:
				# Check if it's a stat requirement using the map
				if req_type in STAT_REQUIREMENT_MAP:
					var total_stats = GameInfo.current_player.get_total_stats()
					var stat_name = STAT_REQUIREMENT_MAP[req_type]
					var player_value = total_stats.get(stat_name)
					meets_requirement = player_value >= scaled_requirement
				# Effect requirements (EFFECT_1 through EFFECT_20)
				elif req_type >= QuestOption.RequirementType.EFFECT_1 and req_type <= QuestOption.RequirementType.EFFECT_20:
					var effect_id = req_type - QuestOption.RequirementType.EFFECT_1 + 1
					var total_effects = GameInfo.current_player.get_total_effects()
					var player_effect = total_effects.get(effect_id, 0.0)
					meets_requirement = player_effect >= scaled_requirement
		
		# Add requirement to label if not faction check and not combat
		if req_type != QuestOption.RequirementType.COMBAT and (req_type < QuestOption.RequirementType.ORDER or req_type > QuestOption.RequirementType.COMPANIONS):
			label_text = "(" + str(scaled_requirement) + ") " + label_text
	
	# Set icon based on requirement type and option type
	var icon_texture = dialogue_icon  # Default icon
	if option_data:
		if option_data.required_type == QuestOption.RequirementType.COMBAT:
			icon_texture = combat_icon
		elif option_data.required_type in STAT_ICON_MAP:
			icon_texture = get(STAT_ICON_MAP[option_data.required_type])
		elif option_data.required_type != QuestOption.RequirementType.NONE:
			match option_data.required_type:
				QuestOption.RequirementType.SILVER:
					icon_texture = currency_check_icon
				QuestOption.RequirementType.ORDER:
					icon_texture = order_icon
				QuestOption.RequirementType.GUILD:
					icon_texture = guild_icon
				QuestOption.RequirementType.COMPANIONS:
					icon_texture = companions_icon
		elif option_data.ends_quest:
			icon_texture = end_icon
	
	# Set button properties (TextureButton with children)
	var label = option_button.get_node("Label")
	var icon = option_button.get_node("Icon")
	
	label.text = label_text
	icon.texture = icon_texture
	
	option_button.disabled = not meets_requirement
	if not meets_requirement:
		option_button.modulate = Color(0.5, 0.5, 0.5, 0.7)
	option_button.pressed.connect(callback)
	
	options_container.add_child(option_button)
	return option_button

func clear_options():
	"""Remove all option buttons"""
	if not options_container:
		return
	
	for child in options_container.get_children():
		child.queue_free()

func refresh_quest_options_internal():
	"""Refresh quest options when stats/requirements change"""
	print("refresh_quest_options_internal called. current_quest_id: ", current_quest_id)
	if current_quest_id == 0:
		print("No quest loaded, returning")
		return
	
	# Rebuild options with current visible_option_ids
	print("Clearing options...")
	clear_options()
	if current_quest and current_quest.options:
		print("Rebuilding ", current_quest.options.size(), " options")
		for option in current_quest.options:
			if option and visible_option_ids.has(option.option_index):
				add_option(option.text, _on_quest_option_pressed.bind(option), option)

func _on_quest_option_pressed(option: QuestOption):
	reward_label.text = ""
	
	Websocket.quest_option(option.option_index)
	
	if not clicked_option_ids.has(option.option_index):
		clicked_option_ids.append(option.option_index)
		print("Tracked clicked option: ", option.option_index, " Total clicked: ", clicked_option_ids)
	
	# 1. Handle currency cost (silver requirement)
	if option.required_type == QuestOption.RequirementType.SILVER and option.required_amount > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.required_amount:
			UIManager.instance.update_silver(-option.required_amount)
			print("Deducted ", option.required_amount, " silver")
		else:
			print("Not enough silver for option: ", option.text)
			return
	
	# 2. Handle combat requirement
	if option.required_type == QuestOption.RequirementType.COMBAT:
		pending_combat_option = option
		_start_combat()
		return  # Combat flow will handle the rest
	
	# 3. Replace text with response_text if provided
	if option.response_text != "":
		animate_quest_text(option.response_text)
	
	# 3b. Apply and display reward for this option
	apply_option_reward(option)
	
	# 4. Always hide clicked option (exhausted)
	visible_option_ids.erase(option.option_index)
	print("After hiding clicked option ", option.option_index, ", visible_option_ids: ", visible_option_ids)
	
	# 5. Show new options
	for show_id in option.shows_option_ids:
		if not visible_option_ids.has(show_id):
			visible_option_ids.append(show_id)
	print("After showing options ", option.shows_option_ids, ", visible_option_ids: ", visible_option_ids)
	
	# 6. Hide other options
	for hide_id in option.hides_option_ids:
		visible_option_ids.erase(hide_id)
	print("After hiding options ", option.hides_option_ids, ", visible_option_ids: ", visible_option_ids)
	
	# 7. Check if quest ends
	if option.ends_quest:
		_finish_quest()
		return
	
	# 8. If staying in quest, refresh options
	print("Refreshing options, current_quest.options.size(): ", current_quest.options.size())
	clear_options()
	if current_quest.options:
		for quest_option in current_quest.options:
			print("Checking option ", quest_option.option_index, " - visible: ", visible_option_ids.has(quest_option.option_index))
			if quest_option and visible_option_ids.has(quest_option.option_index):
				add_option(quest_option.text, _on_quest_option_pressed.bind(quest_option), quest_option)

func _start_combat():
	"""Initialize combat - combat data will come from server response"""
	# Send combat request to server via Websocket
	# Combat result will come via WebSocket response and show combat panel automatically
	print("Starting quest combat - waiting for server response")
	# TODO: Call appropriate Websocket function for quest combat when server implements it
	# For now, this is a placeholder - server will send combatLog which shows the combat panel

func handle_combat_result():
	"""Called after combat panel closes to handle quest continuation"""
	if not pending_combat_option:
		return
	
	# Get combat result
	var combat_log = GameInfo.current_combat_log
	var player_won = combat_log.haswon
	
	print("Handling combat result: Player won = ", player_won)
	
	var option = pending_combat_option
	pending_combat_option = null
	
	if player_won:
		# Win: use regular response_text and shows/hides
		if option.response_text != "":
			animate_quest_text(option.response_text)
		
		# Always hide clicked option
		visible_option_ids.erase(option.option_index)
		
		# Show/hide options
		for show_id in option.shows_option_ids:
			if not visible_option_ids.has(show_id):
				visible_option_ids.append(show_id)
		for hide_id in option.hides_option_ids:
			visible_option_ids.erase(hide_id)
		
		# Check if quest ends
		if option.ends_quest:
			_finish_quest()
			return
	else:
		# Loss: use on_lose_response_text
		if option.on_lose_response_text != "":
			animate_quest_text(option.on_lose_response_text)
		
		# Always hide clicked option
		visible_option_ids.erase(option.option_index)
		
		# Show/hide options for lose scenario
		for show_id in option.on_lose_shows_option_ids:
			if not visible_option_ids.has(show_id):
				visible_option_ids.append(show_id)
		for hide_id in option.on_lose_hides_option_ids:
			visible_option_ids.erase(hide_id)
	
	# Refresh options
	clear_options()
	if current_quest.options:
		for quest_option in current_quest.options:
			if quest_option and visible_option_ids.has(quest_option.option_index):
				add_option(quest_option.text, _on_quest_option_pressed.bind(quest_option), quest_option)

func _finish_quest():
	"""End quest and return home"""
	# Mark quest as completed in quest log
	print("Finishing quest ID: ", current_quest_id)
	print("Clicked options during quest: ", clicked_option_ids)

	GameInfo.complete_quest(current_quest_id, clicked_option_ids)
	GameInfo.current_player.traveling_destination = null
	GameInfo.current_player.traveling = 0
	current_quest_id = 0
	current_quest = null
	clicked_option_ids.clear()
	
	# Call handle_quest_completed on UIManager
	# This will hide the panel and navigate home
	print("UIManager exists: ", UIManager.instance != null)
	UIManager.instance.handle_quest_completed()
