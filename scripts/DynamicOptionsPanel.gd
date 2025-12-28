extends Panel

# Eldrum-style scrolling quest display
@export var quest_scroll: ScrollContainer  # Container for quest entries
@export var quest_entries_container: VBoxContainer  # Stacked quest entries
@export var options_container: VBoxContainer  # Buttons below text

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

# Distance-based modulation settings
const FOCAL_DISTANCE = 150.0  # Distance at which entries are fully faded
const MIN_SCALE = 0.5
const MIN_ALPHA = 0.15

# Reference to portrait for navigation
@export var portrait: Control

# Quest signals
signal quest_arrived()

func _process(_delta):
	"""Update entry modulation based on distance from focal point"""
	if not quest_scroll or not quest_entries_container:
		return
	
	# Focal point in lower third so newest entries are dominant
	var focus_y = quest_scroll.global_position.y + quest_scroll.size.y * 0.65
	
	for entry in quest_entries_container.get_children():
		if not entry is Control:
			continue
		
		var entry_center_y = entry.global_position.y + entry.size.y * 0.5
		var dist = abs(entry_center_y - focus_y)
		var t = clamp(dist / FOCAL_DISTANCE, 0.0, 1.0)
		
		entry.scale = Vector2.ONE * lerp(1.0, MIN_SCALE, t)
		entry.modulate.a = lerp(1.0, MIN_ALPHA, t)

func _ready():
	quest_arrived.connect(_on_quest_arrived)

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
	if not quest_slide:
		print("ERROR: quest_slide is null")
		return
	
	if not quest_entries_container:
		print("ERROR: quest_entries_container not set")
		return
	
	# Create new entry
	var entry = create_quest_entry(quest_slide.text)
	quest_entries_container.add_child(entry)
	
	# Wait for layout to recalculate with new entry
	await get_tree().process_frame
	
	# Recenter scroll after container size changed
	if quest_scroll:
		var vbox_height = quest_entries_container.size.y
		var margin_container = quest_entries_container.get_parent()
		var content_height = margin_container.size.y if margin_container else vbox_height
		var viewport_height = quest_scroll.size.y
		var max_scroll = quest_scroll.get_v_scroll_bar().max_value
		
		# Calculate where entries actually start (accounting for top margin)
		var margin_top = 0
		if margin_container is MarginContainer:
			margin_top = margin_container.get_theme_constant("margin_top")
		
		# Center the entries in the viewport
		# We want: margin_top + (vbox_height / 2) - (viewport_height / 2)
		var center_scroll = margin_top + (vbox_height / 2.0) - (viewport_height / 2.0)
		center_scroll = max(0, center_scroll)  # Don't go negative
		
		print("=== Scroll Centering ===")
		print("VBox height: ", vbox_height)
		print("Margin top: ", margin_top)
		print("Viewport height: ", viewport_height)
		print("Max scroll: ", max_scroll)
		print("Calculated center scroll: ", center_scroll)
		
		quest_scroll.scroll_vertical = int(center_scroll)
		print("Actual scroll after: ", quest_scroll.scroll_vertical)
		print("========================")
	
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
	"""Create a quest entry node"""
	var entry_scene = load("res://Scenes/quest_entry.tscn")
	var entry = entry_scene.instantiate()
	
	# Set text
	var label = entry.get_node("MarginContainer/EntryText")
	if label:
		label.text = text
	
	return entry

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
	var panel = option_instance.get_node("Panel")
	if button:
		# Disable button if can't afford, wrong faction, or doesn't meet stat requirement
		var is_disabled = (has_currency_requirement and not can_afford) or (has_faction_requirement and not is_correct_faction) or (has_stat_requirement and not meets_stat_requirement)
		button.disabled = is_disabled
		# Dim the panel when disabled
		if panel and is_disabled:
			panel.modulate = Color(0.5, 0.5, 0.5, 0.7)
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
