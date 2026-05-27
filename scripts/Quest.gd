extends TextureRect

# Eldrum-style scrolling quest display
@export var text_container: Node  # Center container for quest text
@export var options_container: VBoxContainer  # Buttons below text
@export var reward_label: RichTextLabel  # Label to display quest rewards
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
var is_expedition_node: bool = false
var expedition_context_id: int = 0
var expedition_context_node_id: int = 0
var completed_quest_from_expedition: bool = false
var completed_quest_expedition_id: int = 0
var completed_quest_node_id: int = 0

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

const POTION_REWARD_DURATION_SECONDS: float = 48.0 * 60.0 * 60.0
const COLOR_PRICE_NORMAL: Color = Color(0.85, 0.8, 0.7, 1.0)
const COLOR_PRICE_MISSING: Color = Color(1.0, 0.25, 0.2, 1.0)
const REWARD_HIGHLIGHT_COLOR := "#e6b366"

func _ready():
	# Always connect to visibility changes
	visibility_changed.connect(_on_visibility_changed)
	
	# Wait for game_ready before setup
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	pass

func _on_visibility_changed():
	"""Load quest when panel becomes visible"""
	if not visible:
		return

	_update_health_bar()
	_update_effects_bar_visibility()

	# Quest combat loss flow takes precedence over normal resume.
	if GameInfo.pending_quest_failure_message != "":
		var failure_text = GameInfo.pending_quest_failure_message
		GameInfo.pending_quest_failure_message = ""
		show_quest_failure(failure_text)
		return
	
	# Check if we're returning from combat
	if pending_combat_option != null:
		handle_combat_result()
		return
	
	var destination = GameInfo.current_player.traveling_destination
	# Always reload from authoritative quest_log when quest panel becomes visible.
	# This guarantees resume state is reapplied after login/startup transitions.
	if destination != null:
		load_quest(int(destination))

func load_quest(quest_id: int):
	"""Load a quest and display initial state"""
	
	# Capture whether this is a new quest before setting the guard
	var is_new_quest = current_quest_id != quest_id
	# Set ID early to prevent recursive re-entry from _on_visibility_changed
	current_quest_id = quest_id
	
	# Only switch panels if we're not already the active panel
	if UIManager.instance.current_panel != self:
		UIManager.instance.show_panel(self)

	# Always resolve current quest data for the requested id.
	var quest_data = GameInfo.quests_db.get_quest_by_id(quest_id) if GameInfo.quests_db else null
	if not quest_data:
		current_quest = null
		visible_option_ids.clear()
		clear_options()
		if quest_text:
			quest_text.text = "Quest data missing (ID %d)." % quest_id
		return

	current_quest = quest_data
	var background_texture = DataManager.get_quest_background_texture(quest_data)
	if is_new_quest and background_texture:
		texture = background_texture
	if reward_label:
		reward_label.text = ""
	
	# Reset clicked options tracking for new quest
	clicked_option_ids.clear()
	
	# Restore quest state from quest_log if exists
	var last_node_text: String = ""
	var clicked_options = GameInfo.get_quest_clicked_options(quest_id)
	var last_clicked_id = GameInfo.get_last_quest_option_id(quest_id)
	if clicked_options.size() > 0:
		for option_id in clicked_options:
			clicked_option_ids.append(option_id)
		if last_clicked_id <= 0:
			last_clicked_id = clicked_options[clicked_options.size() - 1]
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
	if current_quest and current_quest.options:
		for option in current_quest.options:
			if option and visible_option_ids.has(option.option_id):
				add_option(option.option_text, _on_quest_option_pressed.bind(option), option)
	else:
		pass

func load_expedition_node(expedition_id: int, node_id: int, quest_id: int):
	"""Load a quest launched from an expedition graph node."""
	is_expedition_node = true
	expedition_context_id = expedition_id
	expedition_context_node_id = node_id
	load_quest(quest_id)

func show_quest_failure(failure_text: String):
	"""Show quest failure text with a single Continue action back home."""
	if UIManager.instance and UIManager.instance.current_panel != self:
		UIManager.instance.show_panel(self)

	pending_combat_option = null
	reward_label.text = ""

	var text_to_show = failure_text if failure_text != "" else "Combat lost."
	animate_quest_text(text_to_show)

	clear_options()
	add_option("Continue", _on_quest_failure_continue_pressed)

func _on_quest_failure_continue_pressed():
	var failed_quest_id = current_quest_id
	if failed_quest_id <= 0 and GameInfo.current_player:
		failed_quest_id = int(GameInfo.current_player.traveling_destination)

	if failed_quest_id > 0:
		GameInfo.complete_quest(failed_quest_id, clicked_option_ids, true)

	if GameInfo.current_player:
		GameInfo.current_player.traveling_destination = null
		GameInfo.current_player.traveling = 0

	current_quest_id = 0
	current_quest = null
	clicked_option_ids.clear()
	visible_option_ids.clear()
	pending_combat_option = null
	is_expedition_node = false
	expedition_context_id = 0
	expedition_context_node_id = 0

	if UIManager.instance:
		UIManager.instance.handle_quest_completed()

func _compute_visible_options() -> Array[int]:
	"""Compute which options are visible based on the requirements tree.
	The tree works depth-first: only the children of the LAST clicked option
	are shown. When nothing has been clicked yet, start options are shown.
	An option is visible if:
	  - Nothing clicked yet AND it's a start option (no requirements), OR
	  - Its requirements contain the last clicked option AND it hasn't been clicked
	"""
	var result: Array[int] = []
	if not current_quest:
		return result

	var last_clicked: int = clicked_option_ids[clicked_option_ids.size() - 1] if clicked_option_ids.size() > 0 else -1
	
	for option in current_quest.options:
		# Skip already clicked options
		if option.option_id in clicked_option_ids:
			continue
		
		if last_clicked == -1:
			# Nothing clicked yet - show start options only
			if option.is_start:
				result.append(option.option_id)
		else:
			# Show options whose requirements include the last clicked option
			if last_clicked in option.requirements:
				result.append(option.option_id)
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
		reward_text = "You receive " + str(option.reward_silver) + " silver."
	
	if option.reward_stat_type > 0 and option.reward_stat_amount > 0:
		var stat_name = _get_stat_name_from_type(option.reward_stat_type)
		if stat_name != "":
			var scaled_amount = _scale_stat_reward(option.reward_stat_amount, server_day)
			GameInfo.current_player.set(stat_name, GameInfo.current_player.get(stat_name) + scaled_amount)
			reward_text = "You receive " + str(scaled_amount) + " " + stat_name + "."
			UIManager.instance.refresh_stats()
	
	if option.reward_talent > 0:
		GameInfo.current_player.talent_points += option.reward_talent
		reward_text = "You receive " + str(option.reward_talent) + " talent point" + ("s" if option.reward_talent > 1 else "") + "."
		UIManager.instance.refresh_stats()
	
	if option.reward_item > 0:
		var added = GameInfo.current_player.add_item_to_bag(option.reward_item)
		if added:
			var item_resource = GameInfo.items_db.get_item_by_id(option.reward_item)
			reward_text = "You receive " + item_resource.item_name + "."
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
		GameInfo.current_player.potion_until = Time.get_unix_time_from_system() + POTION_REWARD_DURATION_SECONDS
		GameInfo.current_player.potion_day = 0
		var item_resource = GameInfo.items_db.get_item_by_id(option.reward_potion)
		reward_text = "You receive a potion: " + item_resource.item_name + "."
		UIManager.instance.refresh_active_effects()
	
	# Fallback: Legacy enum-based reward system
	if reward_text == "" and option.reward_type != QuestOption.RewardType.NONE and option.reward_amount != 0:
		var scaled_amount = option.reward_amount
		
		match option.reward_type:
			QuestOption.RewardType.SILVER:
				UIManager.instance.update_silver(option.reward_amount)
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
				GameInfo.current_player.potion_until = Time.get_unix_time_from_system() + POTION_REWARD_DURATION_SECONDS
				GameInfo.current_player.potion_day = 0
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
					scaled_amount = _scale_stat_reward(option.reward_amount, server_day)
					GameInfo.current_player.set(stat_data.property, GameInfo.current_player.get(stat_data.property) + scaled_amount)
					reward_text = "You receive " + str(scaled_amount) + " " + stat_data.name + "."
					UIManager.instance.refresh_stats()
	
	# Display reward text
	if reward_text != "":
		_set_reward_text(reward_text)
	else:
		reward_label.text = ""

	_update_health_bar()
	_update_effects_bar_visibility()

func _set_reward_text(reward_text: String):
	if not reward_label:
		return
	reward_label.bbcode_enabled = true
	reward_label.text = _highlight_reward_segment(reward_text)

func _highlight_reward_segment(reward_text: String) -> String:
	var highlighted_text = _extract_reward_highlight(reward_text)
	var escaped_text = _escape_bbcode(reward_text)
	if highlighted_text == "":
		return escaped_text
	var escaped_highlight = _escape_bbcode(highlighted_text)
	return escaped_text.replace(escaped_highlight, "[color=%s]%s[/color]" % [REWARD_HIGHLIGHT_COLOR, escaped_highlight])

func _extract_reward_highlight(reward_text: String) -> String:
	var text_value = reward_text.strip_edges()
	if text_value.begins_with("You receive the perk: "):
		return _trim_sentence_end(text_value.trim_prefix("You receive the perk: "))
	if text_value.begins_with("You receive a blessing: "):
		return _trim_sentence_end(text_value.trim_prefix("You receive a blessing: "))
	if text_value.begins_with("You receive a potion: "):
		return _trim_sentence_end(text_value.trim_prefix("You receive a potion: "))
	if text_value.begins_with("You receive "):
		return _trim_sentence_end(text_value.trim_prefix("You receive "))
	if text_value.begins_with("You already have this perk (") and text_value.ends_with(")."):
		return text_value.substr(28, text_value.length() - 31)
	return ""

func _trim_sentence_end(text_value: String) -> String:
	return text_value.left(text_value.length() - 1) if text_value.ends_with(".") else text_value

func _escape_bbcode(text_value: String) -> String:
	return text_value.replace("[", "[lb]").replace("]", "[rb]")

func _update_health_bar():
	if not health_bar or not GameInfo.current_player:
		return

	var total_stats = GameInfo.current_player.get_total_stats()
	var max_health = total_stats.stamina * 10
	var hp_lost = int(GameInfo.current_player.depleted_health)
	var current_health = max(0, max_health - hp_lost)
	health_bar.max_value = max_health
	health_bar.value = current_health
	if health_bar.has_node("HealthLabel"):
		health_bar.get_node("HealthLabel").text = str(current_health) + " / " + str(max_health)

func _update_effects_bar_visibility():
	if not effects_container or not GameInfo.current_player:
		return
	var player = GameInfo.current_player
	effects_container.visible = player.blessing > 0 or player.potion > 0 or player.elixir > 0 or player.get_active_perks().size() > 0

func add_option(text: String, callback: Callable, option_data: QuestOption = null) -> Control:
	"""Add an option to the container using quest_option.tscn"""
	if not options_container:
		return null
	
	var option_scene = load("res://Scenes/quest_option.tscn")
	var option_button = option_scene.instantiate()  # This is now a TextureButton
	
	var label_text = text
	var meets_requirement = true
	var has_missing_price = false
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
			var has_silver = player.silver >= option_data.silver_required
			meets_requirement = meets_requirement and has_silver
			has_missing_price = not has_silver
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
			# Requirements represent parent links in the option graph.
			# The option should be clickable if ANY parent was clicked.
			var has_any_parent_clicked = false
			for req_id in option_data.requirements:
				if clicked_option_ids.has(req_id):
					has_any_parent_clicked = true
					break
			meets_requirement = meets_requirement and has_any_parent_clicked
	
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
				var has_silver = GameInfo.current_player.silver >= scaled_requirement
				meets_requirement = has_silver
				has_missing_price = not has_silver
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
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon.texture = icon_texture
	if has_missing_price:
		label.add_theme_color_override("font_color", COLOR_PRICE_MISSING)
	else:
		label.add_theme_color_override("font_color", COLOR_PRICE_NORMAL)
	
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
	if current_quest_id == 0:
		return
	
	# Recompute and rebuild visible options
	visible_option_ids = _compute_visible_options()
	clear_options()
	if current_quest and current_quest.options:
		for option in current_quest.options:
			if option and visible_option_ids.has(option.option_id):
				add_option(option.option_text, _on_quest_option_pressed.bind(option), option)

func _on_quest_option_pressed(option: QuestOption):
	reward_label.text = ""
	
	Websocket.quest_option(option.option_id)
	
	if not clicked_option_ids.has(option.option_id):
		clicked_option_ids.append(option.option_id)
		GameInfo.append_quest_log_action(current_quest_id, option.option_id, false)
	
	# 1. Handle silver cost (new server field)
	if option.silver_required > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.silver_required:
			UIManager.instance.update_silver(-option.silver_required)
		else:
			return
	
	# 1b. Handle legacy currency cost (silver requirement via enum)
	if option.required_type == QuestOption.RequirementType.SILVER and option.required_amount > 0:
		if GameInfo.current_player and GameInfo.current_player.silver >= option.required_amount:
			UIManager.instance.update_silver(-option.required_amount)
		else:
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
		# Effect 200 = health depletion (now as HP lost)
		if option.effect_applied == 200:
			var hp_lost = abs(int(option.effect_applied_factor))
			var max_health = GameInfo.current_player.get_total_stats().stamina * 10
			GameInfo.current_player.depleted_health = clamp(GameInfo.current_player.depleted_health + hp_lost, 0, max_health)
			UIManager.instance.refresh_stats()
			# Block/fail quest if health is depleted
			if GameInfo.current_player.depleted_health >= max_health:
				animate_quest_text("You are too injured to continue this quest!")
				# Optionally, end quest or disable further options here
	
	# 3b. Apply and display reward for this option
	apply_option_reward(option)
	
	# 4. Recompute visible options from requirements tree
	visible_option_ids = _compute_visible_options()
	
	# 5. Check if quest ends
	if option.ends_quest:
		_complete_quest_and_show_home_action()
		return
	
	# 6. Refresh displayed options
	clear_options()
	if current_quest.options:
		for quest_option in current_quest.options:
			if quest_option and visible_option_ids.has(quest_option.option_id):
				add_option(quest_option.option_text, _on_quest_option_pressed.bind(quest_option), quest_option)

func _start_combat():
	"""Initialize combat - combat data will come from server response"""
	# Combat is executed by server during quest_option; wait for questOptionResponse.

func has_pending_combat_option() -> bool:
	return pending_combat_option != null

func handle_combat_result():
	"""Called after combat panel closes to handle quest continuation"""
	if not pending_combat_option:
		return
	
	# Get combat result
	var combat_log = GameInfo.current_combat_log
	var player_won = combat_log != null and combat_log.has_won()
	
	
	var option = pending_combat_option
	pending_combat_option = null
	
	if player_won:
		# Win: show node_text for the clicked option
		if option.node_text != "":
			animate_quest_text(option.node_text)

		# Combat options should still grant their rewards on win.
		apply_option_reward(option)
		
		# Recompute visible options from requirements tree
		visible_option_ids = _compute_visible_options()
		
		# Check if quest ends
		if option.ends_quest:
			_complete_quest_and_show_home_action()
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

func _complete_quest_and_show_home_action():
	"""Finish quest state, keep final text/reward visible, and offer explicit navigation."""
	completed_quest_from_expedition = is_expedition_node
	completed_quest_expedition_id = expedition_context_id
	completed_quest_node_id = expedition_context_node_id

	GameInfo.complete_quest(current_quest_id, clicked_option_ids, not completed_quest_from_expedition)
	GameInfo.current_player.traveling_destination = null
	GameInfo.current_player.traveling = 0
	current_quest_id = 0
	clicked_option_ids.clear()
	visible_option_ids.clear()
	pending_combat_option = null
	is_expedition_node = false
	expedition_context_id = 0
	expedition_context_node_id = 0

	clear_options()
	add_option("Home", _on_completed_quest_home_pressed)

func _on_completed_quest_home_pressed():
	current_quest = null
	if completed_quest_from_expedition:
		UIManager.instance.handle_expedition_node_completed(completed_quest_expedition_id, completed_quest_node_id)
	else:
		UIManager.instance.handle_quest_completed()
	completed_quest_from_expedition = false
	completed_quest_expedition_id = 0
	completed_quest_node_id = 0

func _get_stat_name_from_type(stat_type: int) -> String:
	"""Convert stat type int to property name"""
	match stat_type:
		1: return "strength"
		2: return "stamina"
		3: return "agility"
		4: return "luck"
		5: return "armor"
		_: return ""

func _scale_stat_reward(base_amount: int, server_day: int) -> int:
	return GameInfo.Item.calculate_scaled_value(base_amount, max(0, server_day - 1), 0)
