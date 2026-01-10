extends Panel

# Eldrum-style scrolling quest display
@export var text_container: Node  # Center container for quest text
@export var options_container: VBoxContainer  # Buttons below text
@export var reward_label: Label  # Label to display quest rewards
@export var background: TextureRect

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

func _ready():
	# Connect to visibility changes to load quest when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed():
	"""Load quest when panel becomes visible"""
	if not visible:
		return
	
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
	
	if current_quest_id != quest_id:
		# Set quest title and background
		var quest_data = GameInfo.get_quest_data(quest_id)
		if quest_data:
			var title_label = get_node_or_null("QuestTitle")
			if title_label:
				title_label.text = quest_data.quest_name
			
			# Apply background texture
			background.texture = quest_data.background_texture
			
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

func display_quest_with_text(text: String):
	"""Display quest with custom text and current visible options"""
	# Clear previous entry from the text container
	for child in text_container.get_children():
		child.queue_free()
	
	# Create and add new entry to text container
	var entry = create_quest_entry(text)
	text_container.add_child(entry)
	
	# Animate entry sliding up from below
	entry.modulate.a = 0
	entry.position.y = 20
	var entry_tween = create_tween()
	entry_tween.set_parallel(true)
	entry_tween.tween_property(entry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(entry, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Display rewards if present
	display_rewards(current_quest)
	
	# Apply rewards to player
	apply_rewards(current_quest)
	
	# Update options based on visible_option_ids
	clear_options()
	if current_quest.options:
		for option in current_quest.options:
			if option and visible_option_ids.has(option.option_index):
				add_option(option.text, _on_quest_option_pressed.bind(option), option)
	else:
		print("WARNING: current_quest.options is null or empty")

func create_quest_entry(text: String) -> Control:
	"""Create a quest entry label"""
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.custom_minimum_size = Vector2(350, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return label

func display_rewards(quest_data: QuestData):
	"""Display rewards in the reward label"""
	if not reward_label or not quest_data or not quest_data.initial_reward:
		if reward_label:
			reward_label.text = ""
		return
	
	var reward = quest_data.initial_reward
	var reward_parts = []
	
	# Check each reward type
	if reward.silver > 0:
		reward_parts.append(str(reward.silver) + " silver")
	
	if reward.item_id > 0:
		var item_resource = GameInfo.items_db.get_item_by_id(reward.item_id)
		if item_resource:
			reward_parts.append(item_resource.item_name + " (item)")
		else:
			reward_parts.append("Item #" + str(reward.item_id) + " (item)")
	
	if reward.perk_id > 0:
		var perk_resource = GameInfo.perks_db.get_perk_by_id(reward.perk_id) if GameInfo.perks_db else null
		if perk_resource:
			reward_parts.append(perk_resource.perk_name + " (perk)")
		else:
			reward_parts.append("Perk #" + str(reward.perk_id) + " (perk)")
	
	# Stat boosts (scaled by 2% per day)
	var server_day = GameInfo.current_player.server_day if GameInfo.current_player else 1
	if reward.strength_boost > 0:
		var scaled = int(reward.strength_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " strength")
	if reward.stamina_boost > 0:
		var scaled = int(reward.stamina_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " stamina")
	if reward.agility_boost > 0:
		var scaled = int(reward.agility_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " agility")
	if reward.luck_boost > 0:
		var scaled = int(reward.luck_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " luck")
	if reward.armor_boost > 0:
		var scaled = int(reward.armor_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " armor")
	
	# Talent points (not scaled)
	if reward.talent_points > 0:
		reward_parts.append(str(reward.talent_points) + " talent point" + ("s" if reward.talent_points > 1 else ""))
	
	# Display rewards
	if reward_parts.size() > 0:
		reward_label.text = "You recieve " + ", ".join(reward_parts) + ".\n"
	else:
		reward_label.text = ""

func apply_rewards(quest_data: QuestData):
	"""Apply rewards to the player"""
	if not quest_data or not quest_data.initial_reward:
		return
	
	var reward = quest_data.initial_reward
	
	# Silver reward
	if reward.silver > 0:
		print("REWARD: Awarding ", reward.silver, " silver")
		if UIManager.instance:
			UIManager.instance.update_silver(reward.silver)
		if GameInfo.current_player:
			GameInfo.current_player.silver += reward.silver
	
	# Stat boosts (scaled by 2% per day)
	if GameInfo.current_player:
		var server_day = GameInfo.current_player.server_day
		if reward.strength_boost > 0:
			var scaled = int(reward.strength_boost * pow(1.02, server_day - 1))
			print("REWARD: Awarding ", scaled, " Strength (base: ", reward.strength_boost, ")")
			GameInfo.current_player.strength += scaled
		if reward.stamina_boost > 0:
			var scaled = int(reward.stamina_boost * pow(1.02, server_day - 1))
			print("REWARD: Awarding ", scaled, " Stamina (base: ", reward.stamina_boost, ")")
			GameInfo.current_player.stamina += scaled
		if reward.agility_boost > 0:
			var scaled = int(reward.agility_boost * pow(1.02, server_day - 1))
			print("REWARD: Awarding ", scaled, " Agility (base: ", reward.agility_boost, ")")
			GameInfo.current_player.agility += scaled
		if reward.luck_boost > 0:
			var scaled = int(reward.luck_boost * pow(1.02, server_day - 1))
			print("REWARD: Awarding ", scaled, " Luck (base: ", reward.luck_boost, ")")
			GameInfo.current_player.luck += scaled
		if reward.armor_boost > 0:
			var scaled = int(reward.armor_boost * pow(1.02, server_day - 1))
			print("REWARD: Awarding ", scaled, " Armor (base: ", reward.armor_boost, ")")
			GameInfo.current_player.armor += scaled
		
		# Talent points (not scaled)
		if reward.talent_points > 0:
			print("REWARD: Awarding ", reward.talent_points, " Talent Points")
			GameInfo.current_player.talent_points += reward.talent_points
		
		# Refresh stats display if any stat was boosted
		if reward.strength_boost > 0 or reward.stamina_boost > 0 or reward.agility_boost > 0 or reward.luck_boost > 0 or reward.armor_boost > 0 or reward.talent_points > 0:
			if UIManager.instance:
				UIManager.instance.refresh_stats()
	
	# Item reward
	if reward.item_id > 0:
		print("REWARD: Attempting to award Item ID: ", reward.item_id)
		# Find empty bag slot (10-14)
		var found_empty_slot = false
		for bag_slot_id in range(10, 15):
			var is_occupied = false
			for existing_item in GameInfo.current_player.bag_slots:
				if existing_item.bag_slot_id == bag_slot_id:
					is_occupied = true
					break
			
			if not is_occupied:
				# Create simplified item (id, bag_slot_id, day)
				var new_item = GameInfo.Item.new({
					"id": reward.item_id,
					"bag_slot_id": bag_slot_id,
					"day": GameInfo.current_player.server_day if GameInfo.current_player else 1
				})
				
				GameInfo.current_player.bag_slots.append(new_item)
				print("REWARD: Item ", new_item.item_name, " added to bag slot ", bag_slot_id)
				found_empty_slot = true
				
				# Refresh bag UI
				if UIManager.instance:
					UIManager.instance.refresh_bags()
				break
		
		if not found_empty_slot:
			print("REWARD: No empty bag slot available for item ", reward.item_id)
	
	# Perk reward
	if reward.perk_id > 0:
		print("REWARD: Attempting to award Perk ID: ", reward.perk_id)
		if GameInfo.current_player:
			# Create new perk and add to perks array as inactive
			var new_perk = GameInfo.Perk.new({
				"id": reward.perk_id,
				"active": false,
				"slot": 0
			})
			GameInfo.current_player.perks.append(new_perk)
			print("REWARD: Perk ", new_perk.perk_name, " added to inactive perks")		# Refresh the perks grid if it's open
		if UIManager.instance:
			UIManager.instance.refresh_perks()
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
			QuestOption.RequirementType.STRENGTH, QuestOption.RequirementType.STAMINA, \
			QuestOption.RequirementType.AGILITY, QuestOption.RequirementType.LUCK, \
			QuestOption.RequirementType.ARMOR:
				var total_stats = GameInfo.get_total_stats()
				var player_value = 0
				match req_type:
					QuestOption.RequirementType.STRENGTH: player_value = total_stats.strength
					QuestOption.RequirementType.STAMINA: player_value = total_stats.stamina
					QuestOption.RequirementType.AGILITY: player_value = total_stats.agility
					QuestOption.RequirementType.LUCK: player_value = total_stats.luck
					QuestOption.RequirementType.ARMOR: player_value = total_stats.armor
				meets_requirement = player_value >= scaled_requirement
			_:
				# Effect requirements (EFFECT_1 through EFFECT_20)
				if req_type >= QuestOption.RequirementType.EFFECT_1 and req_type <= QuestOption.RequirementType.EFFECT_20:
					var effect_id = req_type - QuestOption.RequirementType.EFFECT_1 + 1
					var total_effects = GameInfo.get_total_effects()
					var player_effect = total_effects.get(effect_id, 0.0)
					meets_requirement = player_effect >= scaled_requirement
		
		# Add requirement to label if not faction check and not combat
		if req_type != QuestOption.RequirementType.COMBAT and (req_type < QuestOption.RequirementType.ORDER or req_type > QuestOption.RequirementType.COMPANIONS):
			label_text = "(" + str(scaled_requirement) + ") " + label_text
	
	# Set icon based on requirement type and option type
	var icon_texture = dialogue_icon  # Default icon
	if option_data:
		var is_end = option_data.ends_quest
		
		if option_data.required_type == QuestOption.RequirementType.COMBAT:
			icon_texture = combat_icon
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
				QuestOption.RequirementType.STRENGTH:
					icon_texture = strength_icon
				QuestOption.RequirementType.STAMINA:
					icon_texture = stamina_icon
				QuestOption.RequirementType.AGILITY:
					icon_texture = agility_icon
				QuestOption.RequirementType.LUCK:
					icon_texture = luck_icon
				QuestOption.RequirementType.ARMOR:
					icon_texture = armor_icon
		elif is_end:
			icon_texture = end_icon
	
	# Set button properties (TextureButton with children)
	var label = option_button.get_node("Label")
	var icon = option_button.get_node("Icon")
	
	if label:
		label.text = label_text
	if icon:
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
	"""Handle option click with persistent options system"""
	# Track this clicked option
	if not clicked_option_ids.has(option.option_index):
		clicked_option_ids.append(option.option_index)
		print("Tracked clicked option: ", option.option_index, " Total clicked: ", clicked_option_ids)
	
	# 1. Handle currency cost (silver requirement)
	if option.required_type == QuestOption.RequirementType.SILVER and option.required_amount > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.required_amount:
			if UIManager.instance:
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
		# Clear previous entry and create new one with response text
		for child in text_container.get_children():
			child.queue_free()
		
		var entry = create_quest_entry(option.response_text)
		text_container.add_child(entry)
		
		# Animate entry
		entry.modulate.a = 0
		entry.position.y = 20
		var entry_tween = create_tween()
		entry_tween.set_parallel(true)
		entry_tween.tween_property(entry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		entry_tween.tween_property(entry, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
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
	"""Initialize combat by loading a random mock combat log and showing combat panel"""
	# Pick a random combat log from mock data
	var random_index = randi() % GameInfo.combat_logs.size()
	GameInfo.set_current_combat_log(random_index)
	
	print("Starting combat with log index: ", random_index)
	
	# Get combat panel and toggle UI through UIManager
	if not UIManager.instance:
		print("ERROR: UIManager not available!")
		return
	
	var combat_panel = UIManager.instance.combat_panel
	
	if not combat_panel:
		print("ERROR: Could not find Combat panel!")
		return
	
	# Show combat panel using UIManager's show_panel method
	UIManager.instance.show_panel(combat_panel)
	GameInfo.set_current_panel(combat_panel)

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
			# Replace text with win response
			for child in text_container.get_children():
				child.queue_free()
			
			var entry = create_quest_entry(option.response_text)
			text_container.add_child(entry)
			
			# Animate entry
			entry.modulate.a = 0
			entry.position.y = 20
			var entry_tween = create_tween()
			entry_tween.set_parallel(true)
			entry_tween.tween_property(entry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
			entry_tween.tween_property(entry, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
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
			# Replace text with lose response
			for child in text_container.get_children():
				child.queue_free()
			
			var entry = create_quest_entry(option.on_lose_response_text)
			text_container.add_child(entry)
			
			# Animate entry
			entry.modulate.a = 0
			entry.position.y = 20
			var entry_tween = create_tween()
			entry_tween.set_parallel(true)
			entry_tween.tween_property(entry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
			entry_tween.tween_property(entry, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		
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
