extends Control
class_name UIManager

static var instance: UIManager

# ============================================================================
# PANEL CATEGORIES
# ============================================================================
# Main Panels: home, arena, quest, expedition, character, rankings, map, combat
# Overlays: settings, payment, enemy, talents, upgrade_talent, perk_screen, 
#           cancel_quest, quest_panel, logout, avatar_panel
# Chat: Independent toggle, always on top
# ============================================================================

# Starter panel tracking
var starter_panel: Control = null
var game_is_ready: bool = false
signal game_ready

# ============================================================================
# PANEL EXPORTS - Main Panels
# ============================================================================
@export var home_panel: Control
@export var arena_panel: Control
@export var character_panel: Control
@export var quest: Control              # Quest main panel
@export var expedition_panel: Control
@export var rankings_panel: Control
@export var map_panel: Control
@export var combat_panel: Control

# ============================================================================
# BUTTON EXPORTS
# ============================================================================
@export var home_button: Button
@export var arena_button: Button
@export var character_button: Button
@export var map_button: Button
@export var rankings_button: Button
@export var settings_button: Button
@export var chat_button: Button
@export var payment_button: Button
@export var back_button: Button
@export var fight_button: Button

# ============================================================================
# OVERLAY EXPORTS
# ============================================================================
@export var settings_panel: Control
@export var payment: Control
@export var talents_panel: Control
@export var upgrade_talent: Control
@export var perk_screen: Control
@export var cancel_quest: Control
@export var enemy_panel: Control
@export var logout_panel: Control
@export var avatar_panel: Control

# ============================================================================
# BUILDING PANELS (Shop overlays from home interior)
# ============================================================================
@export var vendor_panel: Control
@export var blacksmith_panel: Control
@export var trainer_panel: Control
@export var church_panel: Control
@export var alchemist_panel: Control
@export var enchanter_panel: Control

# ============================================================================
# SPECIAL CONTROLS
# ============================================================================
@export var chat_panel: Control         # ChatOverlay with ChatPanel.gd script
@export var enemy: Array[Button] = []

# ============================================================================
# UI DATA REFERENCES
# ============================================================================
@export var silver_labels: Array[Label] = []
@export var mushrooms_labels: Array[Label] = []
@export var bag_views: Array[Node] = []
@export var character_display: CharacterDisplay
@export var enemy_character_display: CharacterDisplay
@export var active_effects: Node
@export var avatars: Array[Node] = []
@export var top_ui: Control

# ============================================================================
# STATE TRACKING
# ============================================================================
var current_panel: Control = null
var current_panel_overlay: Control = null
var chat_overlay_active: bool = false
var overlay_stack: Array[Control] = []
var is_new_day_transitioning: bool = false
var _new_day_transition_started_at_ms: int = 0
const NEW_DAY_MIN_TRANSITION_SECONDS: float = 1.5
const BASE_Z_INDEX: int = 200
const Z_INDEX_INCREMENT: int = 10

# Inactivity timeout (returns to lobby after 5 minutes of no input)
const INACTIVITY_TIMEOUT: float = 300.0
var inactivity_timer: Timer

# ============================================================================
# INITIALIZATION
# ============================================================================

func _enter_tree():
	instance = self

func _ready():
	_connect_buttons()
	update_display()
	_initialize_starter_panel()
	if GameInfo.current_player:
		refresh_stats()
	# Inactivity timer
	inactivity_timer = Timer.new()
	inactivity_timer.wait_time = INACTIVITY_TIMEOUT
	inactivity_timer.one_shot = true
	inactivity_timer.timeout.connect(_on_inactivity_timeout)
	add_child(inactivity_timer)
	inactivity_timer.start()

func _input(_event: InputEvent):
	# Reset inactivity timer on any input
	if inactivity_timer:
		inactivity_timer.start()

func _on_inactivity_timeout():
	GameInfo.sync_current_player_to_lobby()
	GameInfo.current_player = null
	GameInfo.current_character_id = 0
	SceneTransition.change_scene_to_file("res://Scenes/login.tscn")

func _connect_buttons():
	"""Connect all button signals"""
	home_button.pressed.connect(handle_home_button)
	arena_button.pressed.connect(handle_arena_button)
	character_button.pressed.connect(handle_character_button)
	map_button.pressed.connect(handle_map_button)
	rankings_button.pressed.connect(handle_rankings_button)
	settings_button.pressed.connect(toggle_overlay.bind(settings_panel))
	payment_button.pressed.connect(toggle_overlay.bind(payment))
	chat_button.pressed.connect(toggle_chat)
	chat_panel.pressed.connect(toggle_chat)
	back_button.pressed.connect(go_back)
	
	# Back button hover/click feedback (golden tint like arena buttons)
	var golden = Color(0.9, 0.7, 0.4, 1)
	var default_color = Color(1, 1, 1, 1)
	for btn in [back_button, chat_button, arena_button, rankings_button, map_button, home_button, settings_button, payment_button]:
		btn.mouse_entered.connect(func(): btn.modulate = golden)
		btn.mouse_exited.connect(func(): btn.modulate = default_color)
		btn.button_down.connect(func(): btn.modulate = golden)
		btn.button_up.connect(func(): btn.modulate = default_color)
	
	# Fight button is handled by Arena.gd - it sends request to server, waits for response, then shows combat panel

func _initialize_starter_panel():
	"""Determine and show the initial panel based on player state"""
	var start_panel = _determine_starter_panel()
	starter_panel = start_panel
	show_panel(start_panel)
	if not game_is_ready:
		if start_panel and start_panel.has_method("_setup"):
			start_panel.call("_setup")
		game_is_ready = true
		game_ready.emit()

func _determine_starter_panel() -> Control:
	"""Determine which panel is the starter based on player state"""
	var destination = GameInfo.current_player.traveling_destination
	var traveling = GameInfo.current_player.traveling
	var expedition = GameInfo.current_player.expedition
	var now = Time.get_unix_time_from_system()
	var arrival_ts = float(traveling) if traveling != null else 0.0
	
	# If arrival time is in the future, show map (traveling)
	if arrival_ts > now:
		return map_panel

	# Arrived: show quest or expedition if active
	if destination != null:
		call_deferred("_load_quest_on_startup", destination)
		return quest
	if expedition and expedition.size() > 0:
		call_deferred("_load_expedition_on_startup", int(expedition[0]))
		return expedition_panel
	return home_panel

func is_on_active_quest() -> bool:
	"""Check if player is on an active quest (arrived at destination, not traveling)"""
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	var arrival_ts = float(traveling) if traveling != null else 0.0
	
	# Player is on active quest if: destination exists AND not currently traveling
	return destination != null and arrival_ts <= Time.get_unix_time_from_system()

func is_on_expedition() -> bool:
	"""Check if player is currently on an expedition"""
	return GameInfo.current_player.expedition.size() > 0

func is_traveling() -> bool:
	"""Check if player is currently traveling (quest or expedition timer running)"""
	# Check quest travel
	var traveling = GameInfo.current_player.traveling
	var arrival_ts = float(traveling) if traveling != null else 0.0
	if arrival_ts > Time.get_unix_time_from_system():
		return true
	
	# Check expedition travel (timer running on map panel)
	if map_panel.is_expedition_travel:
		return true
	
	return false

func is_navigation_blocked() -> bool:
	"""Check if navigation to other panels is blocked (quest, expedition, traveling, or arrived)"""
	# Block if arrived on map but not yet entered
	if map_panel.has_arrived or map_panel.is_expedition_travel:
		return true
	return is_on_active_quest() or is_traveling()

func _load_expedition_on_startup(expedition_id: int):
	"""Load expedition panel on game startup"""
	expedition_panel.start_expedition(expedition_id)

func show_enemy_panel(enemy_name: String):
	"""Show enemy panel with the specified enemy's data"""
	enemy_character_display.display_enemy(enemy_name)
	show_overlay(enemy_panel)

func show_talents_panel(character: GameInfo.GamePlayer, read_only: bool = false):
	"""Show talents panel for any character (player or enemy)"""
	var set_talents = talents_panel.get_node("GridContainer")
	if read_only:
		set_talents.display_character(character, true)
	else:
		set_talents.display_player()
	show_overlay(talents_panel)

func toggle_avatar_overlay():
	toggle_overlay(avatar_panel)

func toggle_chat():
	"""Toggle chat overlay - independent of overlay stack"""
	if is_new_day_transitioning:
		return
	chat_overlay_active = not chat_overlay_active
	if chat_overlay_active:
		chat_panel.z_index = 500  # Always above overlay stack (BASE_Z_INDEX=200)
	chat_panel.visible = chat_overlay_active

func _close_chat_if_open():
	if not chat_overlay_active:
		return
	chat_overlay_active = false
	chat_panel.visible = false

func show_overlay(overlay: Control):
	"""Push an overlay onto the stack"""
	# Hide current top overlay (if any) but keep it in stack
	if overlay_stack.size() > 0:
		var current_top = overlay_stack[-1]
		current_top.visible = false
	
	# Add new overlay to stack
	overlay_stack.push_back(overlay)
	
	# Set z-index based on stack depth
	var overlay_z_index = BASE_Z_INDEX + (overlay_stack.size() - 1) * Z_INDEX_INCREMENT
	overlay.z_index = overlay_z_index
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = true
	
	# Update GameInfo tracking (use top of stack)
	current_panel_overlay = overlay
	
func hide_current_overlay():
	"""Pop the top overlay from the stack"""
	if overlay_stack.size() == 0:
		return
	
	# Remove and hide top overlay
	var top_overlay = overlay_stack.pop_back()
	top_overlay.visible = false
	
	# Show the previous overlay (if any)
	if overlay_stack.size() > 0:
		var previous_overlay = overlay_stack[-1]
		previous_overlay.visible = true
		current_panel_overlay = previous_overlay
	else:
		current_panel_overlay = null

func toggle_overlay(overlay: Control):
	"""Toggle an overlay - if it's on the stack, pop back to it; otherwise push it"""
	if is_new_day_transitioning:
		return
	_close_chat_if_open()
	
	# Check if this overlay is already in the stack
	var index = overlay_stack.find(overlay)
	
	if index >= 0:
		# Overlay is in stack - pop everything above it
		while overlay_stack.size() > index + 1:
			var top = overlay_stack.pop_back()
			top.visible = false
		
		# Now hide this overlay too
		hide_current_overlay()
	else:
		# Overlay not in stack - push it
		show_overlay(overlay)

# ============================================================================
# PANEL NAVIGATION
# ============================================================================

func begin_new_day_transition():
	"""Begin new day transition: close overlays, route to home, and fade to black."""
	if is_new_day_transitioning:
		return

	is_new_day_transitioning = true
	_new_day_transition_started_at_ms = Time.get_ticks_msec()
	_close_chat_if_open()
	_close_sub_overlays()

	while overlay_stack.size() > 0:
		var overlay = overlay_stack.pop_back()
		overlay.visible = false
	current_panel_overlay = null

	if map_panel and map_panel.has_method("reset_expedition_state"):
		map_panel.reset_expedition_state()

	if expedition_panel and expedition_panel.has_method("end_expedition"):
		expedition_panel.end_expedition()

	show_panel(home_panel)
	SceneTransition.fade_out()

func finish_new_day_transition():
	"""Finalize new day transition after GameInfo has been refreshed."""
	if is_new_day_transitioning:
		var elapsed_seconds = float(max(0, Time.get_ticks_msec() - _new_day_transition_started_at_ms)) / 1000.0
		if elapsed_seconds < NEW_DAY_MIN_TRANSITION_SECONDS:
			await get_tree().create_timer(NEW_DAY_MIN_TRANSITION_SECONDS - elapsed_seconds).timeout

	if not GameInfo.current_player:
		SceneTransition.fade_in()
		is_new_day_transitioning = false
		_new_day_transition_started_at_ms = 0
		return

	if map_panel and map_panel.has_method("reset_expedition_state"):
		map_panel.reset_expedition_state()

	if expedition_panel and expedition_panel.has_method("end_expedition"):
		expedition_panel.end_expedition()

	show_panel(home_panel)

	update_display()
	if top_ui and top_ui.has_method("update_display"):
		top_ui.update_display()

	refresh_bags()
	refresh_active_effects()
	refresh_perks()
	refresh_avatars()

	if vendor_panel:
		if vendor_panel.has_method("_setup"):
			vendor_panel._setup()
		elif vendor_panel.has_method("populate_vendor_slots"):
			vendor_panel.populate_vendor_slots()

	if enchanter_panel:
		if enchanter_panel.has_method("_setup"):
			enchanter_panel._setup()
		elif enchanter_panel.has_method("populate_effect_list"):
			enchanter_panel.populate_effect_list()

	SceneTransition.fade_in()
	is_new_day_transitioning = false
	_new_day_transition_started_at_ms = 0

func show_panel(panel: Control):
	"""Show main panel - hides chat, all overlays, and current panel"""
	if is_new_day_transitioning and panel != home_panel:
		return
	_close_chat_if_open()
	
	# Hide sub-overlays (these sit outside the main stack)
	upgrade_talent.visible = false
	perk_screen.visible = false
	
	# Hide current panel
	var old_panel = current_panel
	if old_panel:
		old_panel.visible = false
		
		# Reset home panel to default view when leaving it
		if old_panel == home_panel:
			home_panel.handle_back_navigation()
	
	# Clear entire overlay stack
	while overlay_stack.size() > 0:
		var overlay = overlay_stack.pop_back()
		overlay.visible = false
	
	# Show new panel
	panel.visible = true
	current_panel = panel

	if panel == enchanter_panel:
		if enchanter_panel.has_method("_setup"):
			enchanter_panel._setup()
		elif enchanter_panel.has_method("populate_effect_list"):
			enchanter_panel.populate_effect_list()

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func handle_home_button():
	"""Navigate to home panel"""
	if current_panel == home_panel:
		return
	# Block if traveling/quest/expedition active
	if is_navigation_blocked():
		_go_to_default_panel()
		return
	
	# Reset and show home
	home_panel.handle_back_navigation()
	show_panel(home_panel)

func handle_map_button():
	"""Route map button by state: travel timer, active quest, or expedition graph."""
	if not GameInfo.current_player:
		return

	var now = Time.get_unix_time_from_system()
	var destination = GameInfo.current_player.traveling_destination
	var traveling = GameInfo.current_player.traveling
	var arrival_ts = float(traveling) if traveling != null else 0.0
	var expedition = GameInfo.current_player.expedition

	# Traveling state always opens the timer UI.
	if arrival_ts > now or (map_panel and map_panel.is_expedition_travel):
		if current_panel == map_panel:
			return
		show_panel(map_panel)
		return

	# Active quest state opens quest directly.
	if destination != null:
		if current_panel == quest:
			return
		map_panel.load_arrived_quest()
		return

	# Active expedition state opens the graph directly.
	if expedition and expedition.size() > 0:
		if current_panel == expedition_panel:
			return
		_open_expedition_graph(int(expedition[0]))
		return

	# Idle state opens the expedition graph for current settlement.
	if current_panel == expedition_panel:
		return
	_open_settlement_expedition_graph()

func _open_settlement_expedition_graph():
	var settlement_id = int(GameInfo.current_player.location)
	var expedition_data = GameInfo.expeditions_db.get_expedition_for_settlement(settlement_id) if GameInfo.expeditions_db else null
	if not expedition_data:
		return
	_open_expedition_graph(int(expedition_data.expedition_id))

func _open_expedition_graph(expedition_id: int):
	if expedition_id <= 0:
		return

	map_panel.reset_expedition_state()

	expedition_panel.start_expedition(expedition_id)
	show_panel(expedition_panel)

func handle_arena_button():
	"""Open arena panel"""
	# Block if traveling/quest/expedition active
	if is_navigation_blocked():
		return
	if not _has_available_arena_opponents():
		_show_navigation_warning("No arena opponents yet.")
		return
	if current_panel == arena_panel:
		return
	show_panel(arena_panel)

func _has_available_arena_opponents() -> bool:
	if GameInfo.arena_opponents.is_empty():
		return false
	for opponent_id in GameInfo.arena_opponents:
		for player in GameInfo.enemy_players:
			if int(player.character_id) == int(opponent_id):
				return true
	return false

func _show_navigation_warning(message: String):
	var dialog = AcceptDialog.new()
	dialog.title = "Arena"
	dialog.dialog_text = message
	dialog.exclusive = true
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(260, 110))

func handle_character_button():
	"""Open character panel - always accessible"""
	if current_panel == character_panel:
		_close_overlay_if_present(talents_panel)
		_close_sub_overlays()
		return
	show_panel(character_panel)

func handle_rankings_button():
	"""Open rankings panel - always accessible"""
	if current_panel == rankings_panel:
		return
	show_panel(rankings_panel)

func toggle_talents_bookmark():
	"""Toggle talents panel overlay (for current player)"""
	var index = overlay_stack.find(talents_panel)
	if index >= 0:
		# Pop back to this overlay (inclusive)
		while overlay_stack.size() > index + 1:
			overlay_stack.pop_back().visible = false
		hide_current_overlay()
	else:
		# Show player talents
		show_talents_panel(GameInfo.current_player, false)

# ============================================================================
# BACK BUTTON - SIMPLIFIED PRIORITY SYSTEM
# ============================================================================
# Priority order:
# 1. Chat (independent, always closeable)
# 2. Sub-overlays (upgrade_talent, perk_screen)
# 3. Overlay stack
# 4. Panel-specific behavior (cancel dialogs, interior navigation)
# 5. Return to default panel (quest/expedition if active, otherwise home)
# ============================================================================

func go_back():
	"""Back button - unified priority system"""
	if is_new_day_transitioning:
		return
	# Priority 1: Close chat
	if chat_overlay_active:
		_close_chat_if_open()
		return
	
	# Priority 2: Close sub-overlays (these sit outside the stack)
	if _close_sub_overlays():
		return
	
	# Priority 3: Pop overlay stack
	if overlay_stack.size() > 0:
		hide_current_overlay()
		return
	
	# Priority 4: Panel-specific behavior
	if _handle_panel_back():
		return
	
	# Priority 5: Return to default panel
	_go_to_default_panel()

func _close_sub_overlays() -> bool:
	"""Close sub-overlays that sit outside the main stack. Returns true if something was closed."""
	if upgrade_talent.visible:
		upgrade_talent.visible = false
		return true
	
	if perk_screen.visible:
		perk_screen.visible = false
		return true
	
	return false

func _handle_panel_back() -> bool:
	"""Handle panel-specific back behavior. Returns true if handled."""
	var panel = current_panel
	
	# Map panel -> show cancel dialog if anything is pending
	if panel == map_panel:
		# Cancel if traveling, arrived, has destination, or expedition pending
		if is_traveling() or map_panel.has_arrived or GameInfo.current_player.traveling_destination != null or map_panel.is_expedition_travel:
			cancel_quest.show_dialog()
			return true
	
	# Quest panel (arrived at destination) -> show cancel dialog
	if panel == quest and is_on_active_quest():
		cancel_quest.show_dialog()
		return true
	
	# Expedition panel -> show cancel dialog
	if panel == expedition_panel:
		_cancel_expedition_without_confirmation()
		return true
	
	# Home panel -> interior navigation or logout
	if panel == home_panel:
		# Interior navigation
		if home_panel.handle_back_navigation():
			return true
		
		# Third: show logout (already at exterior)
		show_overlay(logout_panel)
		return true
	
	# Character/Rankings panels don't need special handling - fall through to default
	return false

func _cancel_expedition_without_confirmation():
	"""Cancel active expedition immediately (legacy confirm dialog removed)."""
	GameInfo.current_player.expedition = []
	map_panel.reset_expedition_state()
	expedition_panel.end_expedition()

	show_panel(home_panel)

func _go_to_default_panel():
	"""Navigate to the appropriate default panel based on player state"""
	# If map panel has pending arrival or expedition travel, stay on map
	if map_panel.has_arrived or map_panel.is_expedition_travel:
		show_panel(map_panel)
	elif is_on_expedition():
		show_panel(expedition_panel)
	elif is_traveling():
		# Currently traveling - go to map panel (where timer is)
		show_panel(map_panel)
	elif is_on_active_quest():
		show_panel(quest)
	else:
		show_panel(home_panel)

func _close_overlay_if_present(overlay: Control) -> bool:
	"""Close the given overlay if present anywhere in the stack."""
	var index := overlay_stack.find(overlay)
	if index < 0:
		return false

	while overlay_stack.size() > index:
		var top_overlay: Control = overlay_stack.pop_back()
		top_overlay.visible = false

	if overlay_stack.size() > 0:
		current_panel_overlay = overlay_stack[-1]
	else:
		current_panel_overlay = null

	return true


func show_combat():
	"""Show combat panel"""
	show_panel(combat_panel)

func handle_quest_completed():
	"""Called when quest is finished - return to home"""
	quest.visible = false
	show_panel(home_panel)

func handle_expedition_node_completed(expedition_id: int, _node_id: int):
	"""Called when an expedition node quest is finished - return to graph"""
	quest.visible = false
	GameInfo.current_player.expedition = [expedition_id]
	expedition_panel.start_expedition(expedition_id)
	show_panel(expedition_panel)

func handle_quest_arrived():
	"""Called when travel is completed - show quest panel"""
	# Show quest panel - it will automatically load the quest via visibility_changed
	show_panel(quest)

func _load_quest_on_startup(quest_id: int):
	quest.load_quest(quest_id)

func handle_logout():
	GameInfo.sync_current_player_to_lobby()
	
	GameInfo.current_player = null
	GameInfo.current_character_id = 0
	
	SceneTransition.change_scene_to_file("res://Scenes/login.tscn")

# ============================================================================
# UIManager Functions - Currency, Stats, Effects, Bags, Avatars
# ============================================================================

func update_silver(amount: int):
	"""Add or subtract silver and update all displays"""
	GameInfo.current_player.silver += amount
	update_display()
	top_ui.update_display()

func update_mushrooms(amount: int):
	"""Add or subtract mushrooms and update all displays (account-level)"""
	GameInfo.add_lobby_mushrooms(amount)
	update_display()
	top_ui.update_display()

func update_display():
	"""Refresh all silver and mushroom label displays"""
	var silver_text = "0"
	if GameInfo.current_player:
		silver_text = str(GameInfo.current_player.silver)

	for label in silver_labels:
		label.text = silver_text

	# Refresh mushrooms label displays (account-level)
	if GameInfo.lobby_data.has("mushrooms"):
		var mushrooms_text = str(int(GameInfo.lobby_data.mushrooms))
		for m_label in mushrooms_labels:
			m_label.text = mushrooms_text

func refresh_bags():
	"""Ask all registered bag views to refresh from GameInfo state"""
	for view in bag_views:
		view.update_equip_slots()

func refresh_stats():
	"""Recalculate and display stats for current player"""
	
	character_display.stats_changed(GameInfo.current_player.get_player_stats())
	top_ui.update_health_bar()
	
	# Refresh quest options if currently on a quest
	if GameInfo.current_player.traveling_destination:
		quest.refresh_quest_options_internal()

func refresh_active_effects():
	"""Refresh active effects display (blessings, potions, elixirs)"""
	character_display.refresh_active_effects()
	refresh_stats()

func refresh_perks():
	"""Refresh perks grid when new perks are added"""
	perk_screen.refresh_perks()

func refresh_avatars():
	"""Update all avatar displays with current player data"""
	for avatar in avatars:
		avatar.set_avatar_from_player(GameInfo.current_player)

func notify_slot_changed(slot_id: int):
	"""Notify panels when a utility slot changes by calling their update methods directly"""
	match current_panel:
		blacksmith_panel:
			blacksmith_panel.on_slot_changed(slot_id)
		alchemist_panel:
			alchemist_panel.on_slot_changed(slot_id)
		enchanter_panel:
			enchanter_panel.on_slot_changed(slot_id)

func notify_utility_slot_item_placed(slot_id: int, item: GameInfo.Item, source_slot_id: int):
	"""Notify panels when an item is placed in a utility slot (without changing bag_slot_id)"""
	match current_panel:
		blacksmith_panel:
			blacksmith_panel.on_item_placed(item, source_slot_id)
		alchemist_panel:
			alchemist_panel.on_item_placed_in_slot(slot_id, item, source_slot_id)
		enchanter_panel:
			enchanter_panel.on_item_placed(item, source_slot_id)

func notify_utility_slot_item_removed(slot_id: int):
	"""Notify panels when an item is removed from a utility slot"""
	match current_panel:
		blacksmith_panel:
			blacksmith_panel.on_item_removed()
		alchemist_panel:
			alchemist_panel.on_item_removed_from_slot(slot_id)
		enchanter_panel:
			enchanter_panel.on_item_removed()

func get_items_in_utility_slots() -> Array[GameInfo.Item]:
	"""Get all items currently placed in utility slots (to exclude from bag refresh)"""
	var items: Array[GameInfo.Item] = []

	for working_item in [blacksmith_panel.get_working_item(), enchanter_panel.get_working_item()]:
		if working_item:
			items.append(working_item)

	items.append_array(alchemist_panel.get_working_items())
	
	return items
