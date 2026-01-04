extends Panel

# Eldrum-style scrolling quest display
@export var text_container: CenterContainer  # Center container for quest text
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
var current_slide_number: int = 1
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
	print("Quest panel is now visible")
	var destination = GameInfo.current_player.traveling_destination
	# Only load if there's a destination and it's not already loaded
	if destination != null and current_quest_id != destination:
		# Find the current slide from quest log, default to 1 if not found
		var start_slide = 1
		for quest_log_entry in GameInfo.current_player.quest_log:
			if quest_log_entry.quest_id == destination:
				# Get the last slide from the slides array (most recent progress)
				if quest_log_entry.slides.size() > 0:
					start_slide = quest_log_entry.slides[-1]
				break
		
		print("Quest panel became visible, loading quest ", destination, " at slide ", start_slide)
		load_quest(destination, start_slide)

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
			
			# Apply background texture
			background.texture = quest_data.background_texture
	
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
		var is_end = option_data.slide_target < 0
		
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
	
	# Get current slide and rebuild options (same as display_quest_slide)
	var quest_slide = GameInfo.get_quest_slide(current_quest_id, current_slide_number)
	print("Got quest slide: ", quest_slide)
	if quest_slide:
		print("Clearing options...")
		clear_options()
		if quest_slide.options:
			print("Rebuilding ", quest_slide.options.size(), " options")
			for option in quest_slide.options:
				if option:
					add_option(option.text, _on_quest_option_pressed.bind(option), option)

func _on_quest_option_pressed(option: QuestOption):
	"""Handle option click"""
	# Handle currency cost (silver requirement)
	if option.required_type == QuestOption.RequirementType.SILVER and option.required_amount > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.required_amount:
			if UIManager.instance:
				UIManager.instance.update_silver(-option.required_amount)
				print("Deducted ", option.required_amount, " silver")
		else:
			print("Not enough silver for option: ", option.text)
			return
	
	# Determine navigation based on option type
	if option.required_type == QuestOption.RequirementType.COMBAT:
		# Combat option - start combat flow
		pending_combat_option = option
		_start_combat()
	elif option.required_type != QuestOption.RequirementType.NONE and option.required_type != QuestOption.RequirementType.SILVER:
		# Requirement check (stat, effect, or faction - all already validated in add_option)
		# Success: use slide_target
		if option.slide_target > 0:
			load_quest(current_quest_id, option.slide_target)
		elif option.on_lose_slide > 0:
			# Some checks might have alternative failure path
			load_quest(current_quest_id, option.on_lose_slide)
		else:
			print("WARNING: CHECK option missing slide_target")
	elif option.slide_target < 0:
		# End option
		_finish_quest()
	else:
		# Normal dialogue option
		if option.slide_target > 0:
			load_quest(current_quest_id, option.slide_target)
		else:
			print("WARNING: DIALOGUE option has no slide_target: ", option.text)

func _start_combat():
	"""Initialize combat by loading a random mock combat log and showing combat panel"""
	# Pick a random combat log from mock data
	var random_index = randi() % GameInfo.combat_logs.size()
	GameInfo.set_current_combat_log(random_index)
	
	print("Starting combat with log index: ", random_index)
	
	# Get combat result from log
	var combat_log = GameInfo.current_combat_log
	var player_won = combat_log.haswon
	
	print("Combat outcome: Player won = ", player_won)
	
	# Navigate to result slide IMMEDIATELY (before showing combat)
	if player_won:
		# Win: use slide_target
		if pending_combat_option.slide_target > 0:
			load_quest(current_quest_id, pending_combat_option.slide_target)
			pending_combat_option = null
		elif pending_combat_option.slide_target < 0:
			# End quest (slide_target = -1)
			GameInfo.end_quest(current_quest_id)
			if portrait:
				portrait.navigate_to("map")
			pending_combat_option = null
	else:
		# Loss: use on_lose_slide
		if pending_combat_option.on_lose_slide > 0:
			load_quest(current_quest_id, pending_combat_option.on_lose_slide)
			pending_combat_option = null
		elif pending_combat_option.on_lose_slide < 0:
			# End quest on loss (on_lose_slide = -1)
			GameInfo.end_quest(current_quest_id)
			if portrait:
				portrait.navigate_to("map")
			pending_combat_option = null
	
	# Get combat panel and toggle UI through UIManager
	if not UIManager.instance:
		print("ERROR: UIManager not available!")
		return
	
	var active_ui = UIManager.instance.portrait_ui if UIManager.instance.portrait_ui.visible else UIManager.instance.wide_ui
	var combat_panel = active_ui.combat_panel
	
	if not combat_panel:
		print("ERROR: Could not find Combat panel!")
		return
	
	# Show combat panel using TogglePanel's show_panel method
	active_ui.show_panel(combat_panel)
	GameInfo.set_current_panel(combat_panel)

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
