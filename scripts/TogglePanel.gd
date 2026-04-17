extends Control
class_name UIManager

static var instance: UIManager

# ============================================================================
# PANEL CATEGORIES
# ============================================================================
# Main Panels: home, arena, quest, expedition, character, rankings, map, combat
# Overlays: settings, payment, enemy, details, talents, upgrade_talent, perk_screen, 
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
@export var details_panel: Control
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
	print("[UIManager] 5 min inactivity — returning to lobby")
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
	for btn in [back_button, chat_button, arena_button, rankings_button, map_button, home_button, settings_button]:
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
	print("UIManager: Starter panel determined: ", starter_panel.name)
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
	
	print("=== STARTUP QUEST STATE DEBUG ===")
	print("destination: ", destination, " (type: ", typeof(destination), ")")
	print("traveling: ", traveling, " (type: ", typeof(traveling), ")")
	print("expedition: ", expedition)
	print("arrival_ts: ", arrival_ts, " now: ", now, " (diff: ", arrival_ts - now, ")")
	print("================================")
	
	# If arrival time is in the future, show map (traveling)
	if arrival_ts > now:
		print("-> Traveling, showing map panel")
		return map_panel

	# Arrived: show quest or expedition if active
	if destination != null:
		print("-> Arrived at quest, showing quest panel")
		call_deferred("_load_quest_on_startup", destination)
		return quest
	if expedition and expedition.size() > 0:
		print("-> Arrived at expedition, showing expedition panel")
		call_deferred("_load_expedition_on_startup", expedition[0])
		return expedition_panel
	else:
		# No quest active - show home panel
		print("-> No quest active, showing home panel")
		return home_panel

func is_on_active_quest() -> bool:
	"""Check if player is on an active quest (arrived at destination, not traveling)"""
	if not GameInfo.current_player:
		return false
	
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	var arrival_ts = float(traveling) if traveling != null else 0.0
	
	# Player is on active quest if: destination exists AND not currently traveling
	return destination != null and arrival_ts <= Time.get_unix_time_from_system()

func is_on_expedition() -> bool:
	"""Check if player is currently on an expedition"""
	if not GameInfo.current_player:
		return false
	
	var expedition = GameInfo.current_player.expedition
	return expedition and expedition.size() > 0

func is_traveling() -> bool:
	"""Check if player is currently traveling (quest or expedition timer running)"""
	if not GameInfo.current_player:
		return false
	
	# Check quest travel
	var traveling = GameInfo.current_player.traveling
	var arrival_ts = float(traveling) if traveling != null else 0.0
	if arrival_ts > Time.get_unix_time_from_system():
		return true
	
	# Check expedition travel (timer running on map panel)
	if map_panel and map_panel.is_expedition_travel:
		return true
	
	return false

func is_navigation_blocked() -> bool:
	"""Check if navigation to other panels is blocked (quest, expedition, traveling, or arrived)"""
	# Block if arrived on map but not yet entered
	if map_panel.has_arrived or map_panel.is_expedition_travel:
		return true
	return is_on_active_quest() or is_on_expedition() or is_traveling()

func _load_expedition_on_startup(slide_id: int):
	"""Load expedition panel on game startup"""
	if expedition_panel and expedition_panel.has_method("start_expedition"):
		# For now, use expedition ID 1 (the only one we have)
		expedition_panel.start_expedition(1, slide_id)

func show_enemy_panel(enemy_name: String):
	"""Show enemy panel with the specified enemy's data"""
	print("UIManager: Showing enemy panel for: ", enemy_name)
	print("UIManager: enemy_character_display = ", enemy_character_display)
	print("UIManager: enemy_panel = ", enemy_panel)
	
	enemy_character_display.display_enemy(enemy_name)
	show_overlay(enemy_panel)

func show_details_panel(character: GameInfo.GamePlayer):
	"""Show details panel for any character (player or enemy)"""
	print("UIManager: Showing details for: ", character.name)
	if details_panel:
		details_panel.display_effects(character)
		show_overlay(details_panel)  # Push onto stack
	else:
		print("ERROR: details_panel not assigned in UIManager")

func show_talents_panel(character: GameInfo.GamePlayer, read_only: bool = false):
	"""Show talents panel for any character (player or enemy)"""
	print("UIManager: Showing talents for: ", character.name, " read_only=", read_only)
	if talents_panel:
		var set_talents = talents_panel.get_node("GridContainer")
		if set_talents and set_talents.has_method("display_character"):
			if read_only:
				set_talents.display_character(character, true)
			else:
				set_talents.display_player()
			show_overlay(talents_panel)  # Push onto stack
		else:
			print("ERROR: GridContainer node not found or missing methods in talents_panel")
	else:
		print("ERROR: talents_panel not assigned in UIManager")

func toggle_chat():
	"""Toggle chat overlay - independent of overlay stack"""
	if chat_overlay_active:
		# Hide chat
		chat_overlay_active = false
		chat_panel.visible = false
		print("UIManager: Chat hidden")
	else:
		# Show chat above everything
		chat_overlay_active = true
		chat_panel.z_index = 500  # Always above overlay stack (BASE_Z_INDEX=200)
		chat_panel.visible = true
		print("UIManager: Chat shown with z-index 500")

func show_overlay(overlay: Control):
	"""Push an overlay onto the stack"""
	if overlay == null:
		print("ERROR: Attempted to show null overlay")
		return
	
	print("UIManager: Pushing overlay onto stack: ", overlay.name)
	
	# Hide current top overlay (if any) but keep it in stack
	if overlay_stack.size() > 0:
		var current_top = overlay_stack[-1]
		current_top.visible = false
		print("UIManager: Hiding previous overlay: ", current_top.name)
	
	# Add new overlay to stack
	overlay_stack.push_back(overlay)
	
	# Set z-index based on stack depth
	var overlay_z_index = BASE_Z_INDEX + (overlay_stack.size() - 1) * Z_INDEX_INCREMENT
	overlay.z_index = overlay_z_index
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = true
	
	print("UIManager: Overlay stack depth: ", overlay_stack.size(), " z-index: ", overlay_z_index)
	
	# Update GameInfo tracking (use top of stack)
	current_panel_overlay = overlay
	
func hide_current_overlay():
	"""Pop the top overlay from the stack"""
	if overlay_stack.size() == 0:
		print("UIManager: No overlay to hide")
		return
	
	# Remove and hide top overlay
	var top_overlay = overlay_stack.pop_back()
	top_overlay.visible = false
	print("UIManager: Popped overlay: ", top_overlay.name)
	
	# Show the previous overlay (if any)
	if overlay_stack.size() > 0:
		var previous_overlay = overlay_stack[-1]
		previous_overlay.visible = true
		print("UIManager: Showing previous overlay: ", previous_overlay.name)
		current_panel_overlay = previous_overlay
	else:
		print("UIManager: Returned to base panel")
		current_panel_overlay = null
	
	print("UIManager: Overlay stack depth: ", overlay_stack.size())

func hide_overlay(_overlay: Control):
	"""Legacy function - now just calls hide_current_overlay"""
	hide_current_overlay()

func toggle_overlay(overlay: Control):
	"""Toggle an overlay - if it's on the stack, pop back to it; otherwise push it"""
	if overlay == null:
		print("ERROR: Attempted to toggle null overlay")
		return
	
	# Close chat when opening an overlay
	if chat_overlay_active:
		chat_overlay_active = false
		chat_panel.visible = false
	
	# Check if this overlay is already in the stack
	var index = overlay_stack.find(overlay)
	
	if index >= 0:
		print("UIManager: Overlay already in stack at index ", index, ", popping back to it")
		# Overlay is in stack - pop everything above it
		while overlay_stack.size() > index + 1:
			var top = overlay_stack.pop_back()
			top.visible = false
			print("UIManager: Popped overlay while navigating back: ", top.name)
		
		# Now hide this overlay too
		hide_current_overlay()
	else:
		print("UIManager: Overlay not in stack, pushing it")
		# Overlay not in stack - push it
		show_overlay(overlay)

# ============================================================================
# PANEL NAVIGATION
# ============================================================================

func show_panel(panel: Control):
	"""Show main panel - hides chat, all overlays, and current panel"""
	# Close chat when switching panels
	if chat_overlay_active:
		chat_overlay_active = false
		chat_panel.visible = false
	
	# Hide sub-overlays (these sit outside the main stack)
	if upgrade_talent:
		upgrade_talent.visible = false
	if perk_screen:
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
	print("UIManager: Switched to panel: ", panel.name)

# ============================================================================
# BUTTON HANDLERS
# ============================================================================

func handle_home_button():
	"""Navigate to home panel"""
	# Block if traveling/quest/expedition active
	if is_navigation_blocked():
		_go_to_default_panel()
		return
	
	# Reset and show home
	home_panel.handle_back_navigation()
	show_panel(home_panel)

func handle_map_button():
	"""Navigate to map panel"""
	# Block if traveling/quest/expedition active
	if is_navigation_blocked():
		return
	
	# Toggle off if already on map
	if current_panel == map_panel:
		show_panel(home_panel)
		return
	
	show_panel(map_panel)

func handle_arena_button():
	"""Toggle arena panel"""
	# Block if traveling/quest/expedition active
	if is_navigation_blocked():
		return
	
	if current_panel == arena_panel:
		show_panel(home_panel)
	else:
		show_panel(arena_panel)

func handle_character_button():
	"""Toggle character panel - always accessible"""
	if current_panel == character_panel:
		_go_to_default_panel()
	else:
		show_panel(character_panel)

func handle_rankings_button():
	"""Toggle rankings panel - always accessible"""
	if current_panel == rankings_panel:
		_go_to_default_panel()
	else:
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

func toggle_details_bookmark():
	"""Toggle details panel overlay"""
	toggle_overlay(details_panel)

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
	var panel_name := "null"
	if current_panel:
		panel_name = current_panel.name
	print("=== BACK BUTTON === Panel: ", panel_name, " Overlays: ", overlay_stack.size())
	
	# Priority 1: Close chat
	if chat_overlay_active:
		print("-> Closing chat")
		toggle_chat()
		return
	
	# Priority 2: Close sub-overlays (these sit outside the stack)
	if _close_sub_overlays():
		return
	
	# Priority 3: Pop overlay stack
	if overlay_stack.size() > 0:
		print("-> Popping overlay")
		hide_current_overlay()
		return
	
	# Priority 4: Panel-specific behavior
	if _handle_panel_back():
		return
	
	# Priority 5: Return to default panel
	print("-> Going to default panel")
	_go_to_default_panel()

func _close_sub_overlays() -> bool:
	"""Close sub-overlays that sit outside the main stack. Returns true if something was closed."""
	if upgrade_talent and upgrade_talent.visible:
		print("-> Closing upgrade_talent sub-overlay")
		upgrade_talent.visible = false
		return true
	
	if perk_screen and perk_screen.visible:
		print("-> Closing perk_screen sub-overlay")
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
			print("-> Map: showing cancel dialog")
			cancel_quest.show_dialog()
			return true
	
	# Quest panel (arrived at destination) -> show cancel dialog
	if panel == quest and is_on_active_quest():
		print("-> Quest: showing cancel dialog")
		cancel_quest.show_dialog()
		return true
	
	# Expedition panel -> show cancel dialog
	if panel == expedition_panel:
		print("-> Expedition: showing cancel dialog")
		cancel_quest.show_dialog()
		return true
	
	# Home panel -> interior navigation or logout
	if panel == home_panel:
		# Interior navigation
		if home_panel.handle_back_navigation():
			print("-> Home: exited interior")
			return true
		
		# Third: show logout (already at exterior)
		print("-> Home: showing logout")
		show_overlay(logout_panel)
		return true
	
	# Character/Rankings panels don't need special handling - fall through to default
	return false

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


func show_combat():
	"""Show combat panel"""
	var old_panel = current_panel
	if old_panel:
		old_panel.visible = false
	combat_panel.visible = true
	current_panel = combat_panel

func handle_quest_completed():
	"""Called when quest is finished - return to home"""
	quest.visible = false
	show_panel(home_panel)

func handle_quest_arrived():
	"""Called when travel is completed - show quest panel"""
	# Show quest panel - it will automatically load the quest via visibility_changed
	show_panel(quest)

func _load_quest_on_startup(quest_id: int):
	quest.load_quest(quest_id)

func handle_logout():
	print("Logging out and returning to login scene...")
	
	GameInfo.current_player = null
	GameInfo.current_character_id = 0
	
	SceneTransition.change_scene_to_file("res://Scenes/login.tscn")

# ============================================================================
# UIManager Functions - Currency, Stats, Effects, Bags, Avatars
# ============================================================================

func update_silver(amount: int):
	"""Add or subtract silver and update all displays"""
	var stack = get_stack()
	var caller = stack[1] if stack.size() > 1 else {}
	var caller_info = "%s:%s in %s" % [caller.get("source", "?"), caller.get("line", "?"), caller.get("function", "?")]
	print("[SILVER] %+d | before=%d after=%d | from %s" % [amount, GameInfo.current_player.silver, GameInfo.current_player.silver + amount, caller_info])
	GameInfo.current_player.silver += amount
	update_display()
	if top_ui and top_ui.has_method("update_display"):
		top_ui.update_display()

func update_mushrooms(amount: int):
	"""Add or subtract mushrooms and update all displays (account-level)"""
	print("UIManager.update_mushrooms called with amount: ", amount)
	if GameInfo.lobby_data.has("mushrooms"):
		print("Current mushrooms before: ", GameInfo.lobby_data.mushrooms)
		GameInfo.lobby_data.mushrooms += amount
		print("Current mushrooms after: ", GameInfo.lobby_data.mushrooms)
	update_display()
	if top_ui and top_ui.has_method("update_display"):
		top_ui.update_display()

func update_display():
	"""Refresh all silver and mushroom label displays"""
	print("UIManager.update_display called, silver_labels count: ", silver_labels.size())
	var silver_text = str(GameInfo.current_player.silver)
	for label in silver_labels:
		if label:
			print("Updating label to: ", silver_text)
			label.text = silver_text
		else:
			print("Warning: null label in silver_labels array")

	# Refresh mushrooms label displays (account-level)
	print("UIManager.update_display mushrooms_labels count: ", mushrooms_labels.size())
	if GameInfo.lobby_data.has("mushrooms"):
		var mushrooms_text = str(int(GameInfo.lobby_data.mushrooms))
		for m_label in mushrooms_labels:
			m_label.text = mushrooms_text

func refresh_bags():
	"""Ask all registered bag views to refresh from GameInfo state"""
	print("UIManager.refresh_bags bag_views count: ", bag_views.size())
	for view in bag_views:
		view.update_equip_slots()

func refresh_stats():
	"""Recalculate and display stats for current player"""
	
	character_display.stats_changed(GameInfo.current_player.get_player_stats())
	details_panel.display_effects(GameInfo.current_player)
	if top_ui and top_ui.has_method("update_health_bar"):
		top_ui.call("update_health_bar")
	
	# Refresh quest options if currently on a quest
	if GameInfo.current_player and GameInfo.current_player.traveling_destination:
		print("UIManager.refresh_stats refreshing quest options")
		quest.refresh_quest_options_internal()

func refresh_active_effects():
	"""Refresh active effects display (blessings, potions, elixirs)"""
	character_display.refresh_active_effects()
	refresh_stats()

func refresh_perks():
	"""Refresh perks grid when new perks are added"""
	if perk_screen and perk_screen.has_method("refresh_perks"):
		perk_screen.refresh_perks()

func refresh_avatars():
	"""Update all avatar displays with current player data"""
	for avatar in avatars:
		if avatar and avatar.has_method("set_avatar_from_player"):
			avatar.set_avatar_from_player(GameInfo.current_player)

func notify_slot_changed(slot_id: int):
	"""Notify panels when a utility slot changes by calling their update methods directly"""
	var panel = current_panel
	if not panel:
		return
	
	# Call the appropriate panel's update method
	if panel.name == "BlacksmithPanel" and panel.has_method("on_slot_changed"):
		panel.on_slot_changed(slot_id)
	elif panel.name == "AlchemistPanel" and panel.has_method("on_slot_changed"):
		panel.on_slot_changed(slot_id)
	elif panel.name == "EnchanterPanel" and panel.has_method("on_slot_changed"):
		panel.on_slot_changed(slot_id)

func notify_utility_slot_item_placed(slot_id: int, item: GameInfo.Item, source_slot_id: int):
	"""Notify panels when an item is placed in a utility slot (without changing bag_slot_id)"""
	var panel = current_panel
	if not panel:
		return
	
	print("DEBUG notify_utility_slot_item_placed: slot_id=", slot_id, " item=", item.item_name, " source_slot_id=", source_slot_id)
	
	if panel.name == "BlacksmithPanel" and panel.has_method("on_item_placed"):
		panel.on_item_placed(item, source_slot_id)
	elif panel.name == "AlchemistPanel" and panel.has_method("on_item_placed_in_slot"):
		panel.on_item_placed_in_slot(slot_id, item, source_slot_id)
	elif panel.name == "EnchanterPanel" and panel.has_method("on_item_placed"):
		panel.on_item_placed(item, source_slot_id)

func notify_utility_slot_item_removed(slot_id: int):
	"""Notify panels when an item is removed from a utility slot"""
	var panel = current_panel
	if not panel:
		return
	
	print("DEBUG notify_utility_slot_item_removed: slot_id=", slot_id)
	
	if panel.name == "BlacksmithPanel" and panel.has_method("on_item_removed"):
		panel.on_item_removed()
	elif panel.name == "AlchemistPanel" and panel.has_method("on_item_removed_from_slot"):
		panel.on_item_removed_from_slot(slot_id)
	elif panel.name == "EnchanterPanel" and panel.has_method("on_item_removed"):
		panel.on_item_removed()

func get_items_in_utility_slots() -> Array[GameInfo.Item]:
	"""Get all items currently placed in utility slots (to exclude from bag refresh)"""
	var items: Array[GameInfo.Item] = []
	
	# Check BlacksmithPanel
	if blacksmith_panel and blacksmith_panel.has_method("get_working_item"):
		var item = blacksmith_panel.get_working_item()
		if item:
			items.append(item)
	
	# Check EnchanterPanel
	if enchanter_panel and enchanter_panel.has_method("get_working_item"):
		var item = enchanter_panel.get_working_item()
		if item:
			items.append(item)
	
	# Check AlchemistPanel
	if alchemist_panel and alchemist_panel.has_method("get_working_items"):
		var alch_items = alchemist_panel.get_working_items()
		for item in alch_items:
			items.append(item)
	
	return items
