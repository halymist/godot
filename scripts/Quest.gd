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
	
	# Wait for game_ready before setup
	if UIManager.instance.game_is_ready:
		_setup()
	else:
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
	
	# Reset clicked options tracking for new quest
	clicked_option_ids.clear()
	
	# Restore quest state from quest_log if exists
	var last_node_text: String = ""
	if GameInfo.current_player:
		for quest_log_entry in GameInfo.current_player.quest_log:
			if quest_log_entry.get("quest_id", 0) == quest_id:
				var clicked_options = quest_log_entry.get("clicked_options", [])
				if clicked_options.size() > 0:
					print("Restoring quest state with clicked_options: ", clicked_options)
					for option_id in clicked_options:
						clicked_option_ids.append(option_id)
					# Find the last clicked option's node_text
					var last_clicked_id = clicked_options[clicked_options.size() - 1]
					for option in current_quest.options:
						if option.option_id == last_clicked_id and option.node_text != "":
							last_node_text = option.node_text
				break
	
	# Compute visible options based on requirements tree
	visible_option_ids = _compute_visible_options()
	
	# Display quest with the correct text
	if last_node_text != "":
		display_quest_with_text(last_node_text)
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
			if option and visible_option_ids.has(option.option_id):
				add_option(option.option_text, _on_quest_option_pressed.bind(option), option)
	else:
		print("WARNING: current_quest.options is null or empty")

func _compute_visible_options() -> Array[int]:
	"""Compute which options are visible based on the requirements tree.
	An option is visible if:
	  - It's a start option (is_start == true) and hasn't been clicked, OR
	  - ANY of its requirements are in clicked_option_ids and it hasn't been clicked
	"""
	var result: Array[int] = []
	for option in current_quest.options:
		# Skip already clicked options
		if option.option_id in clicked_option_ids:
			continue
		# Start options are always visible
		if option.is_start:
			result.append(option.option_id)
			continue
		# Check if any requirement has been clicked (OR logic)
		if option.requirements.size() > 0:
			for req_id in option.requirements:
				if req_id in clicked_option_ids:
					result.append(option.option_id)
					break
	return result

func apply_option_reward(option: QuestOption):
	"""Apply reward from a quest option to the player"""
	if not GameInfo.current_player:
		return
	
	var reward_text = ""
	var server_day = GameInfo.current_player.server_day
	
	# New server format: individual reward fields
	if option.reward_silver > 0:
		UIManager.instance.update_silver(option.reward_silver)
		GameInfo.current_player.silver += option.reward_silver
		reward_text = "You receive " + str(option.reward_silver) + " silver."
		print("REWARD: Awarded ", option.reward_silver, " silver")
	
	if option.reward_stat_type > 0 and option.reward_stat_amount > 0:
		var stat_name = _get_stat_name_from_type(option.reward_stat_type)
		if stat_name != "":
			var scaled_amount = int(option.reward_stat_amount * pow(1.02, server_day - 1))
			GameInfo.current_player.set(stat_name, GameInfo.current_player.get(stat_name) + scaled_amount)
			reward_text = "You receive " + str(scaled_amount) + " " + stat_name + "."
			print("REWARD: Awarded ", scaled_amount, " ", stat_name)
			UIManager.instance.refresh_stats()
	
	if option.reward_talent > 0:
		GameInfo.current_player.talent_points += option.reward_talent
		reward_text = "You receive " + str(option.reward_talent) + " talent point" + ("s" if option.reward_talent > 1 else "") + "."
		print("REWARD: Awarded ", option.reward_talent, " Talent Points")
		UIManager.instance.refresh_stats()
	
	if option.reward_item > 0:
		var added = GameInfo.current_player.add_item_to_bag(option.reward_item)
		if added:
			var item_resource = GameInfo.items_db.get_item_by_id(option.reward_item)
			reward_text = "You receive " + item_resource.item_name + "."
			print("REWARD: Added Item ID ", option.reward_item, " to bag")
			UIManager.instance.refresh_bags()
		else:
			reward_text = "Your bag is full!"
	
	if option.reward_perk > 0:
		var added = GameInfo.current_player.add_perk_if_new(option.reward_perk)
		var perk_resource = GameInfo.perks_db.get_perk_by_id(option.reward_perk) if GameInfo.perks_db else null
		if added:
			reward_text = "You receive the perk: " + perk_resource.perk_name + "."
			UIManager.instance.refresh_perks()
		else:
			reward_text = "You already have this perk (" + perk_resource.perk_name + ")."
	
	if option.reward_blessing > 0:
		GameInfo.current_player.blessing = option.reward_blessing
		var perk_resource = GameInfo.perks_db.get_perk_by_id(option.reward_blessing) if GameInfo.perks_db else null
		reward_text = "You receive a blessing: " + perk_resource.perk_name + "."
		UIManager.instance.refresh_active_effects()
	
	if option.reward_potion > 0:
		GameInfo.current_player.potion = option.reward_potion
		var item_resource = GameInfo.items_db.get_item_by_id(option.reward_potion)
		reward_text = "You receive a potion: " + item_resource.item_name + "."
		UIManager.instance.refresh_active_effects()
	
	# Fallback: Legacy enum-based reward system
	if reward_text == "" and option.reward_type != QuestOption.RewardType.NONE and option.reward_amount != 0:
		var scaled_amount = option.reward_amount
		
		match option.reward_type:
			QuestOption.RewardType.SILVER:
				UIManager.instance.update_silver(option.reward_amount)
				GameInfo.current_player.silver += option.reward_amount
				reward_text = "You receive " + str(option.reward_amount) + " silver."
			
			QuestOption.RewardType.ITEM:
				var added = GameInfo.current_player.add_item_to_bag(option.reward_amount)
				if added:
					var item_resource = GameInfo.items_db.get_item_by_id(option.reward_amount)
					reward_text = "You receive " + item_resource.item_name + "."
					UIManager.instance.refresh_bags()
				else:
					reward_text = "Your bag is full!"
			
			QuestOption.RewardType.PERK:
				var added = GameInfo.current_player.add_perk_if_new(option.reward_amount)
				var perk_resource = GameInfo.perks_db.get_perk_by_id(option.reward_amount) if GameInfo.perks_db else null
				if added:
					reward_text = "You receive the perk: " + perk_resource.perk_name + "."
					UIManager.instance.refresh_perks()
				else:
					reward_text = "You already have this perk (" + perk_resource.perk_name + ")."
			
			QuestOption.RewardType.TALENT_POINT:
				GameInfo.current_player.talent_points += option.reward_amount
				reward_text = "You receive " + str(option.reward_amount) + " talent point" + ("s" if option.reward_amount > 1 else "") + "."
				UIManager.instance.refresh_stats()
			
			QuestOption.RewardType.POTION:
				GameInfo.current_player.potion = option.reward_amount
				var item_resource = GameInfo.items_db.get_item_by_id(option.reward_amount)
				reward_text = "You receive a potion: " + item_resource.item_name + "."
				UIManager.instance.refresh_active_effects()
			
			QuestOption.RewardType.BLESSING:
				GameInfo.current_player.blessing = option.reward_amount
				var perk_resource = GameInfo.perks_db.get_perk_by_id(option.reward_amount) if GameInfo.perks_db else null
				reward_text = "You receive a blessing: " + perk_resource.perk_name + "."
				UIManager.instance.refresh_active_effects()
			
			_:
				if option.reward_type in STAT_REWARD_MAP:
					var stat_data = STAT_REWARD_MAP[option.reward_type]
					scaled_amount = int(option.reward_amount * pow(1.02, server_day - 1))
					GameInfo.current_player.set(stat_data.property, GameInfo.current_player.get(stat_data.property) + scaled_amount)
					reward_text = "You receive " + str(scaled_amount) + " " + stat_data.name + "."
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
	
	# Check new server format fields first (stat_type, silver_required, faction_required, effect_id)
	if option_data and GameInfo.current_player:
		var player = GameInfo.current_player
		var total_stats = player.get_total_stats()
		var server_day = player.server_day
		
		# Stat requirement (stat_type is int: 1=str, 2=sta, 3=agi, 4=luck, 5=armor)
		if option_data.stat_type > 0 and option_data.stat_required > 0:
			scaled_requirement = int(option_data.stat_required * pow(1.02, server_day - 1))
			var stat_name = _get_stat_name_from_type(option_data.stat_type)
			if stat_name != "":
				var player_value = total_stats.get(stat_name, 0)
				meets_requirement = player_value >= scaled_requirement
			label_text = "(" + str(scaled_requirement) + ") " + label_text
		
		# Silver requirement
		if option_data.silver_required > 0:
			meets_requirement = meets_requirement and player.silver >= option_data.silver_required
			label_text = "(" + str(option_data.silver_required) + ") " + label_text
		
		# Faction requirement
		if option_data.faction_required > 0:
			meets_requirement = meets_requirement and player.faction == option_data.faction_required
		
		# Effect requirement
		if option_data.effect_id > 0 and option_data.effect_amount > 0:
			var total_effects = player.get_total_effects()
			var player_effect = total_effects.get(option_data.effect_id, 0.0)
			meets_requirement = meets_requirement and player_effect >= option_data.effect_amount
			label_text = "(" + str(option_data.effect_amount) + ") " + label_text
		
		# Prerequisite options requirement
		if option_data.requirements.size() > 0:
			for req_id in option_data.requirements:
				if not clicked_option_ids.has(req_id):
					meets_requirement = false
					break
	
	# Fallback: Check legacy unified requirement system
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
		# New server format: check individual fields first
		if option_data.enemy_id > 0:
			icon_texture = combat_icon
		elif option_data.stat_type > 0 and option_data.stat_required > 0:
			var stat_icons = {1: strength_icon, 2: stamina_icon, 3: agility_icon, 4: luck_icon, 5: armor_icon}
			icon_texture = stat_icons.get(option_data.stat_type, dialogue_icon)
		elif option_data.silver_required > 0:
			icon_texture = currency_check_icon
		elif option_data.faction_required > 0:
			var faction_icons = {1: order_icon, 2: guild_icon, 3: companions_icon}
			icon_texture = faction_icons.get(option_data.faction_required, dialogue_icon)
		elif option_data.ends_quest:
			icon_texture = end_icon
		# Fallback: Legacy enum-based icons
		elif option_data.required_type == QuestOption.RequirementType.COMBAT:
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
	
	# Recompute and rebuild visible options
	visible_option_ids = _compute_visible_options()
	print("Clearing options...")
	clear_options()
	if current_quest and current_quest.options:
		print("Rebuilding ", current_quest.options.size(), " options")
		for option in current_quest.options:
			if option and visible_option_ids.has(option.option_id):
				add_option(option.option_text, _on_quest_option_pressed.bind(option), option)

func _on_quest_option_pressed(option: QuestOption):
	reward_label.text = ""
	
	Websocket.quest_option(option.option_id)
	
	if not clicked_option_ids.has(option.option_id):
		clicked_option_ids.append(option.option_id)
		print("Tracked clicked option: ", option.option_id, " Total clicked: ", clicked_option_ids)
	
	# 1. Handle silver cost (new server field)
	if option.silver_required > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.silver_required:
			UIManager.instance.update_silver(-option.silver_required)
			print("Deducted ", option.silver_required, " silver (silver_required)")
		else:
			print("Not enough silver for option: ", option.option_text)
			return
	
	# 1b. Handle legacy currency cost (silver requirement via enum)
	if option.required_type == QuestOption.RequirementType.SILVER and option.required_amount > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.required_amount:
			UIManager.instance.update_silver(-option.required_amount)
			print("Deducted ", option.required_amount, " silver (legacy)")
		else:
			print("Not enough silver for option: ", option.option_text)
			return
	
	# 2. Handle combat requirement (enemy_id or legacy enum)
	if option.enemy_id > 0 or option.required_type == QuestOption.RequirementType.COMBAT:
		pending_combat_option = option
		_start_combat()
		return  # Combat flow will handle the rest
	
	# 3. Show node_text for the clicked option (the tree's dialogue text)
	if option.node_text != "":
		animate_quest_text(option.node_text)
	
	# 3a. Apply effect if this option applies one
	if option.effect_applied > 0 and option.effect_applied_factor != 0.0 and GameInfo.current_player:
		# Effect 200 = health depletion (same convention as expeditions)
		if option.effect_applied == 200:
			var percent = abs(option.effect_applied_factor)
			GameInfo.current_player.depleted_health = clamp(GameInfo.current_player.depleted_health + percent, 0.0, 100.0)
			print("Applied effect 200 (health depletion): ", percent, "%")
			UIManager.instance.refresh_stats()
	
	# 3b. Apply and display reward for this option
	apply_option_reward(option)
	
	# 4. Recompute visible options from requirements tree
	visible_option_ids = _compute_visible_options()
	print("After clicking option ", option.option_id, ", visible_option_ids: ", visible_option_ids)
	
	# 5. Check if quest ends
	if option.ends_quest:
		_finish_quest()
		return
	
	# 6. Refresh displayed options
	clear_options()
	if current_quest.options:
		for quest_option in current_quest.options:
			if quest_option and visible_option_ids.has(quest_option.option_id):
				add_option(quest_option.option_text, _on_quest_option_pressed.bind(quest_option), quest_option)

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
		# Win: show node_text for the clicked option
		if option.node_text != "":
			animate_quest_text(option.node_text)
		
		# Recompute visible options from requirements tree
		visible_option_ids = _compute_visible_options()
		
		# Check if quest ends
		if option.ends_quest:
			_finish_quest()
			return
	else:
		# Loss: remove this option from clicked so it can be retried
		clicked_option_ids.erase(option.option_id)
		visible_option_ids = _compute_visible_options()
	
	# Refresh options
	clear_options()
	if current_quest.options:
		for quest_option in current_quest.options:
			if quest_option and visible_option_ids.has(quest_option.option_id):
				add_option(quest_option.option_text, _on_quest_option_pressed.bind(quest_option), quest_option)

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

func _get_stat_name_from_type(stat_type: int) -> String:
	"""Convert stat type int to property name"""
	match stat_type:
		1: return "strength"
		2: return "stamina"
		3: return "agility"
		4: return "luck"
		5: return "armor"
		_: return ""
