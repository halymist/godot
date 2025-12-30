extends Panel

# Eldrum-style scrolling quest display
@export var text_container: CenterContainer  # Center container for quest text
@export var options_container: VBoxContainer  # Buttons below text
@export var reward_label: Label  # Label to display quest rewards
@export var overlay: ColorRect  # Overlay that can be pressed to hide UI

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
var current_slide_number: int = 1

# Reference to portrait for navigation
@export var portrait: Control

# Quest signals
signal quest_arrived()

func _ready():
	quest_arrived.connect(_on_quest_arrived)
	
	# Set up overlay press-to-hide functionality
	if overlay:
		overlay.gui_input.connect(_on_overlay_input)

func _on_overlay_input(event: InputEvent):
	"""Hide overlay and UI when pressed, show when released"""
	if event is InputEventMouseButton:
		var mouse_event = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				# Fade out overlay smoothly
				var tween = create_tween()
				tween.tween_property(overlay, "modulate:a", 0.0, 0.2).set_ease(Tween.EASE_OUT)
			else:
				# Fade in overlay smoothly
				var tween = create_tween()
				tween.tween_property(overlay, "modulate:a", 1.0, 0.2).set_ease(Tween.EASE_IN)

func _on_quest_arrived():
	"""Quest arrival from travel"""
	var quest_id = GameInfo.current_player.traveling_destination if GameInfo.current_player else null
	if quest_id:
		load_quest(quest_id, 1)

func load_quest(quest_id: int, slide_number: int = 1):
	"""Load a quest and display first slide"""
	print("Loading quest ", quest_id, " slide ", slide_number)
	
	if current_quest_id != quest_id:
		# Set quest title
		var quest_data = GameInfo.get_quest_data(quest_id)
		if quest_data:
			var title_label = get_node_or_null("QuestTitle")
			if title_label:
				title_label.text = quest_data.quest_name
	
	current_quest_id = quest_id
	current_slide_number = slide_number
	
	# Log this slide in the quest log
	GameInfo.log_quest_slide(quest_id, slide_number)
	
	var quest_slide = GameInfo.get_quest_slide(quest_id, slide_number)
	display_quest_slide(quest_slide)

func display_quest_slide(quest_slide: QuestSlide):
	"""Create new quest entry"""
	# Clear previous entry from the text container
	for child in text_container.get_children():
		child.queue_free()
	
	# Create and add new entry to text container
	var entry = create_quest_entry(quest_slide.text)
	text_container.add_child(entry)
	
	# Animate entry sliding up from below
	entry.modulate.a = 0
	entry.position.y = 20
	var entry_tween = create_tween()
	entry_tween.set_parallel(true)
	entry_tween.tween_property(entry, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
	entry_tween.tween_property(entry, "position:y", 0, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	# Display rewards if present
	display_rewards(quest_slide)
	
	# Apply rewards to player
	apply_rewards(quest_slide)
	
	# Update options
	clear_options()
	if quest_slide.options:
		for option in quest_slide.options:
			if option:
				add_option(option.text, _on_quest_option_pressed.bind(option), option)
			else:
				print("WARNING: Null option in quest_slide.options")
	else:
		print("WARNING: quest_slide.options is null or empty")

func create_quest_entry(text: String) -> Control:
	"""Create a quest entry label"""
	var label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.custom_minimum_size = Vector2(350, 0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label

func display_rewards(quest_slide: QuestSlide):
	"""Display rewards in the reward label"""
	if not reward_label or not quest_slide or not quest_slide.reward:
		if reward_label:
			reward_label.text = ""
		return
	
	var reward = quest_slide.reward
	var reward_parts = []
	
	# Check each reward type
	if reward.silver > 0:
		reward_parts.append(str(reward.silver) + " silver")
	
	if reward.item_id > 0:
		var item_resource = GameInfo.items_db.get_item_by_id(reward.item_id)
		if item_resource:
			reward_parts.append(item_resource.item_name)
		else:
			reward_parts.append("Item #" + str(reward.item_id))
	
	if reward.perk_id > 0:
		var perk_data = GameInfo.get_perk(reward.perk_id)
		if perk_data:
			reward_parts.append(perk_data.perk_name)
		else:
			reward_parts.append("Perk #" + str(reward.perk_id))
	
	# Stat boosts (scaled by 2% per day)
	var server_day = GameInfo.current_player.server_day if GameInfo.current_player else 1
	if reward.strength_boost > 0:
		var scaled = int(reward.strength_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " Strength")
	if reward.stamina_boost > 0:
		var scaled = int(reward.stamina_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " Stamina")
	if reward.agility_boost > 0:
		var scaled = int(reward.agility_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " Agility")
	if reward.luck_boost > 0:
		var scaled = int(reward.luck_boost * pow(1.02, server_day - 1))
		reward_parts.append(str(scaled) + " Luck")
	
	# Display rewards
	if reward_parts.size() > 0:
		reward_label.text = "You receive: " + ", ".join(reward_parts)
	else:
		reward_label.text = ""

func apply_rewards(quest_slide: QuestSlide):
	"""Apply rewards to the player"""
	if not quest_slide or not quest_slide.reward:
		return
	
	var reward = quest_slide.reward
	
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
		
		# Refresh stats display if any stat was boosted
		if reward.strength_boost > 0 or reward.stamina_boost > 0 or reward.agility_boost > 0 or reward.luck_boost > 0:
			if UIManager.instance:
				UIManager.instance.refresh_stats()
	
	# Item reward
	if reward.item_id > 0:
		print("REWARD: Attempting to award Item ID: ", reward.item_id)
		# Find empty bag slot (10-14)
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
				
				# Refresh bag UI
			if UIManager.instance:
				UIManager.instance.refresh_bags()
			break
	
	if reward.item_id > 0:
		# Check if we went through the loop without finding empty slot
		var found_slot = false
		for existing_item in GameInfo.current_player.bag_slots:
			if existing_item.id == reward.item_id and existing_item.bag_slot_id >= 10 and existing_item.bag_slot_id <= 14:
				found_slot = true
				break
		
		if not found_slot:
			print("REWARD: No empty bag slot available for item ", reward.item_id)
	
	# Perk reward
	if reward.perk_id > 0:
		print("REWARD: Attempting to award Perk ID: ", reward.perk_id)
		if GameInfo.current_player:
			# Find next available inactive perk slot
			var next_slot = GameInfo.current_player.inactive_perks.size()
			print("REWARD: Assigning perk to inactive slot ", next_slot)
			GameInfo.current_player.inactive_perks.append({
				"perk_id": reward.perk_id,
				"active": false
			})
			# TODO: Refresh perk UI when available

func add_option(text: String, callback: Callable, option_data: QuestOption = null) -> Control:
	"""Add an option to the container using quest_option.tscn"""
	if not options_container:
		return null
	
	var option_scene = load("res://Scenes/quest_option.tscn")
	var option_instance = option_scene.instantiate()
	
	# We'll update label text after checking requirements (to include required values)
	var label = option_instance.get_node("HBoxContainer/Label")
	var label_text = text
	
	# Check if this is a currency check (has required_silver)
	var has_currency_requirement = option_data and option_data.required_silver > 0
	var can_afford = true
	
	if has_currency_requirement and GameInfo.current_player:
		can_afford = GameInfo.current_player.silver >= option_data.required_silver
		# Add required silver to label
		label_text = "(" + str(option_data.required_silver) + ") " + label_text
	
	# Check if this is a faction check (has required_faction)
	var has_faction_requirement = option_data and option_data.required_faction != QuestOption.Faction.NONE
	var is_correct_faction = true
	
	if has_faction_requirement and GameInfo.current_player:
		# Cast enum to int for comparison
		var required_faction_int = int(option_data.required_faction)
		is_correct_faction = GameInfo.current_player.faction == required_faction_int
		print("Faction check: player faction=", GameInfo.current_player.faction, " required=", required_faction_int, " match=", is_correct_faction)
	
	# Check if this is a stat check (has required_stat)
	var has_stat_requirement = option_data and option_data.required_stat != QuestOption.Stat.NONE and option_data.required_amount > 0
	var meets_stat_requirement = true
	
	if has_stat_requirement and GameInfo.current_player:
		# Scale requirement by 20% per day (compounded)
		var server_day = GameInfo.current_player.server_day
		var scaled_requirement = int(option_data.required_amount * pow(1.20, server_day - 1))
		
		# Get player's total stats (includes equipment, perks, etc.)
		var total_stats = GameInfo.get_total_stats()
		var player_stat_value = 0
		match option_data.required_stat:
			QuestOption.Stat.STRENGTH:
				player_stat_value = total_stats.strength
			QuestOption.Stat.STAMINA:
				player_stat_value = total_stats.stamina
			QuestOption.Stat.AGILITY:
				player_stat_value = total_stats.agility
			QuestOption.Stat.LUCK:
				player_stat_value = total_stats.luck
			QuestOption.Stat.ARMOR:
				player_stat_value = total_stats.armor
		
		meets_stat_requirement = player_stat_value >= scaled_requirement
		print("Stat check: player ", option_data.required_stat, "=", player_stat_value, " required=", scaled_requirement, " (base=", option_data.required_amount, " day=", server_day, ") match=", meets_stat_requirement)
		# Add required stat amount to label
		label_text = "(" + str(scaled_requirement) + ") " + label_text
	
	# Infer option type from data
	var is_combat = option_data and option_data.enemy_id > 0
	var is_stat_check = option_data and option_data.required_stat != QuestOption.Stat.NONE
	var is_end = option_data and option_data.slide_target < 0
	
	# Set icon based on inferred type or requirements
	var icon = option_instance.get_node("HBoxContainer/Icon")
	if icon:
		if has_currency_requirement:
			icon.texture = currency_check_icon
		elif has_faction_requirement:
			# Use specific faction icon
			match option_data.required_faction:
				QuestOption.Faction.ORDER:
					icon.texture = order_icon
				QuestOption.Faction.GUILD:
					icon.texture = guild_icon
				QuestOption.Faction.COMPANIONS:
					icon.texture = companions_icon
		elif is_stat_check:
			# Use specific stat icon
			match option_data.required_stat:
				QuestOption.Stat.STRENGTH:
					icon.texture = strength_icon
				QuestOption.Stat.STAMINA:
					icon.texture = stamina_icon
				QuestOption.Stat.AGILITY:
					icon.texture = agility_icon
				QuestOption.Stat.LUCK:
					icon.texture = luck_icon
				QuestOption.Stat.ARMOR:
					icon.texture = armor_icon
		elif is_combat:
			icon.texture = combat_icon
		elif is_end:
			icon.texture = end_icon
		else:
			icon.texture = dialogue_icon
	
	# Set the label text with prefixes
	if label:
		label.text = label_text
	
	# Connect button press and style based on requirements
	var button = option_instance.get_node("Button")
	if button:
		# Disable button if can't afford, wrong faction, or doesn't meet stat requirement
		var is_disabled = (has_currency_requirement and not can_afford) or (has_faction_requirement and not is_correct_faction) or (has_stat_requirement and not meets_stat_requirement)
		button.disabled = is_disabled
		# Dim the entire option when disabled
		if is_disabled:
			option_instance.modulate = Color(0.5, 0.5, 0.5, 0.7)
		button.pressed.connect(callback)
	
	options_container.add_child(option_instance)
	return option_instance

func clear_options():
	"""Remove all option buttons"""
	if not options_container:
		return
	
	for child in options_container.get_children():
		child.queue_free()

func _on_quest_option_pressed(option: QuestOption):
	"""Handle option click"""
	# Handle currency requirement first
	if option.required_silver > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.required_silver:
			# Deduct silver using UIManager
			if UIManager.instance:
				UIManager.instance.update_silver(-option.required_silver)
				print("Deducted ", option.required_silver, " silver")
		else:
			print("Not enough silver for option: ", option.text)
			return
	
	# Infer option type from data
	if option.enemy_id > 0:
		# Combat option
		var won = randf() > 0.5
		if won and option.on_win_slide > 0:
			load_quest(current_quest_id, option.on_win_slide)
		elif not won and option.on_lose_slide > 0:
			load_quest(current_quest_id, option.on_lose_slide)
		else:
			print("WARNING: COMBAT option missing win/lose slides")
	elif option.required_stat != QuestOption.Stat.NONE:
		# Stat check option
		# Scale requirement by 20% per day (compounded)
		var server_day = GameInfo.current_player.server_day
		var scaled_requirement = int(option.required_amount * pow(1.20, server_day - 1))
		
		# Get player's total stats (includes equipment, perks, etc.)
		var total_stats = GameInfo.get_total_stats()
		var player_stat_value = 0
		match option.required_stat:
			QuestOption.Stat.STRENGTH:
				player_stat_value = total_stats.strength
			QuestOption.Stat.STAMINA:
				player_stat_value = total_stats.stamina
			QuestOption.Stat.AGILITY:
				player_stat_value = total_stats.agility
			QuestOption.Stat.LUCK:
				player_stat_value = total_stats.luck
			QuestOption.Stat.ARMOR:
				player_stat_value = total_stats.armor
		
		# Check if stat requirement is met
		if player_stat_value >= scaled_requirement:
			# Success - navigate to target slide
			if option.slide_target > 0:
				load_quest(current_quest_id, option.slide_target)
			else:
				print("WARNING: STAT CHECK option missing slide_target")
		else:
			print("Stat check failed: ", player_stat_value, " < ", scaled_requirement)
	elif option.slide_target < 0:
		# End option
		_finish_quest()
	else:
		# Dialogue option
		if option.slide_target > 0:
			load_quest(current_quest_id, option.slide_target)
		else:
			print("WARNING: DIALOGUE option has no slide_target: ", option.text)

func _finish_quest():
	"""End quest and return home"""
	# Mark quest as completed in quest log
	print("Finishing quest ID: ", current_quest_id)

	GameInfo.complete_quest(current_quest_id)
	GameInfo.current_player.traveling_destination = null
	GameInfo.current_player.traveling = 0
	current_quest_id = 0
	current_slide_number = 1
	
	# Call handle_quest_completed on active toggle panel through UIManager
	# This will hide the panel and navigate home
	print("UIManager exists: ", UIManager.instance != null)
	if UIManager.instance:
		print("Portrait visible: ", UIManager.instance.portrait_ui.visible)
		print("Wide visible: ", UIManager.instance.wide_ui.visible)
		if UIManager.instance.portrait_ui.visible:
			print("Calling handle_quest_completed on portrait_ui")
			UIManager.instance.portrait_ui.handle_quest_completed()
		elif UIManager.instance.wide_ui.visible:
			print("Calling handle_quest_completed on wide_ui")
			UIManager.instance.wide_ui.handle_quest_completed()
		else:
			print("WARNING: Neither portrait nor wide UI is visible!")
