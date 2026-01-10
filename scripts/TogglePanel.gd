extends Control
class_name UIManager

static var instance: UIManager

# Panel references (from TogglePanel)
@export var home_panel: Control
@export var home_button: Button
@export var arena_panel: Control
@export var arena_button: Button
@export var character_button: Button
@export var character_panel: Control
@export var talents_panel: Control
@export var details_panel: Control
@export var map_button: Button
@export var map_panel: Control
@export var back_button: Button
@export var settings_button: Button
@export var rankings_button: Button
@export var chat_button: Button
@export var chat_panel: Button
@export var combat_panel: Control
@export var settings_panel: Control
@export var rankings_panel: Control
@export var fight_button: Button
@export var interior_view: Control
@export var village_view: Control
@export var quest_panel: Control
@export var quest: Control
@export var cancel_quest: Control
@export var upgrade_talent: Control
@export var perk_screen: Control
@export var vendor_panel: Control
@export var blacksmith_panel: Control
@export var trainer_panel: Control
@export var church_panel: Control
@export var alchemist_panel: Control
@export var enchanter_panel: Control
@export var enemy_panel: Control
@export var enemy: Array[Button] = []
@export var payment: Control
@export var payment_button: Button
@export var avatar_panel: Control

# Additional UI references (from old UIManager)
@export var silver_labels: Array[Label] = []
@export var mushrooms_labels: Array[Label] = []
@export var bag_views: Array[Node] = []
@export var character_display: CharacterDisplay
@export var enemy_character_display: CharacterDisplay
@export var active_effects: Node
@export var avatars: Array[Node] = []
@export var resolution_manager: Node

# Track UI state
var chat_overlay_active: bool = false
var overlay_stack: Array[Control] = []  # Stack of nested overlays
const BASE_Z_INDEX: int = 200
const Z_INDEX_INCREMENT: int = 10

func _enter_tree():
	# Set singleton instance immediately when entering tree, before any _ready() calls
	instance = self

func _ready():
	# Connect to character changed signal
	GameInfo.character_changed.connect(_on_character_changed)
	
	# Initial currency display update
	update_display()
	
	# Check player's quest state at startup
	var start_panel = home_panel
	var destination = GameInfo.current_player.traveling_destination
	var traveling = GameInfo.current_player.traveling
	
	print("=== STARTUP QUEST STATE DEBUG ===")
	print("destination: ", destination, " (type: ", typeof(destination), ")")
	print("traveling: ", traveling, " (type: ", typeof(traveling), ")")
	print("================================")
	
	if destination != null and traveling != null and traveling != 0:
		# Player is currently traveling to a quest - show map panel
		print("-> Traveling to quest, showing map panel")
		start_panel = map_panel
	elif destination != null:
		# Player has arrived at quest - show quest panel and load it directly
		print("-> Arrived at quest, showing quest panel")
		start_panel = quest
		# Load quest directly after panel is set up with clicked_options from quest_log
		call_deferred("_load_quest_on_startup", destination)
	else:
		# No quest active - show home panel
		print("-> No quest active, showing home panel")
	
	# Start with appropriate panel visible
	GameInfo.set_current_panel(start_panel)
	start_panel.visible = true
	
	# Connect button signals
	home_button.pressed.connect(handle_home_button)
	arena_button.pressed.connect(handle_arena_button)
	character_button.pressed.connect(handle_character_button)
	map_button.pressed.connect(handle_map_button)
	rankings_button.pressed.connect(handle_rankings_button)
	settings_button.pressed.connect(toggle_overlay.bind(settings_panel))
	payment_button.pressed.connect(toggle_overlay.bind(payment))
	chat_button.pressed.connect(toggle_chat)
	chat_panel.pressed.connect(toggle_chat)  # Close chat when clicking background
	back_button.pressed.connect(go_back)
	fight_button.pressed.connect(show_combat)
	
	# Enemy button connections removed - now handled by RankingsPanel calling show_enemy_panel()
	
	# Connect cancel quest dialog buttons
	var yes_button = cancel_quest.get_node("DialogPanel/VBoxContainer/HBoxContainer/YesButton")
	var no_button = cancel_quest.get_node("DialogPanel/VBoxContainer/HBoxContainer/NoButton")
	var background_button = cancel_quest.get_node("BackgroundButton")
	yes_button.pressed.connect(_on_cancel_quest_yes)
	no_button.pressed.connect(_on_cancel_quest_no)
	background_button.pressed.connect(_on_cancel_quest_no)

func is_on_active_quest() -> bool:
	"""Check if player is on an active quest (arrived at destination, not traveling)"""
	if not GameInfo.current_player:
		return false
	
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	
	# Player is on active quest if: destination exists AND not currently traveling
	return destination != null and traveling == 0

func show_enemy_panel(enemy_name: String):
	"""Show enemy panel with the specified enemy's data"""
	print("UIManager: Showing enemy panel for: ", enemy_name)
	print("UIManager: enemy_character_display = ", enemy_character_display)
	print("UIManager: enemy_panel = ", enemy_panel)
	
	if enemy_character_display:
		enemy_character_display.display_enemy(enemy_name)
		if enemy_panel:
			print("UIManager: Calling show_overlay for enemy_panel")
			show_overlay(enemy_panel)
		else:
			print("ERROR: enemy_panel not assigned in UIManager")
	else:
		print("ERROR: enemy_character_display not assigned in UIManager")

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
	GameInfo.set_current_panel_overlay(overlay)
	
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
		GameInfo.set_current_panel_overlay(previous_overlay)
	else:
		print("UIManager: Returned to base panel")
		GameInfo.set_current_panel_overlay(null)
	
	print("UIManager: Overlay stack depth: ", overlay_stack.size())

func hide_overlay(_overlay: Control):
	"""Legacy function - now just calls hide_current_overlay"""
	hide_current_overlay()

func toggle_overlay(overlay: Control):
	"""Toggle an overlay - if it's on the stack, pop back to it; otherwise push it"""
	if overlay == null:
		print("ERROR: Attempted to toggle null overlay")
		return
	
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

func show_panel(panel: Control):
	"""Show main panel - hides all overlays and current panel"""	
	# Hide current panel
	var current_panel = GameInfo.get_current_panel()
	if current_panel:
		current_panel.visible = false
		
		# Reset home panel to default view when leaving it
		if current_panel == home_panel:
			home_panel.handle_back_navigation()
			home_panel.center_village_view()
	
	# Clear entire overlay stack
	while overlay_stack.size() > 0:
		var overlay = overlay_stack.pop_back()
		overlay.visible = false
	
	print("UIManager: Cleared overlay stack when switching to panel: ", panel.name)
	
	# Show new panel
	panel.visible = true
	GameInfo.set_current_panel(panel)
	GameInfo.set_current_panel_overlay(null)
	

func handle_home_button():
	"""Navigate to home panel - with custom home panel behavior"""
	# Block navigation if player is on an active quest
	if is_on_active_quest():
		print(" player is on an active quest")
		show_panel(quest)
		return

	# Custom home panel behavior: exit interior and center view
	home_panel.handle_back_navigation()
	home_panel.center_village_view()
	
	# Show home panel
	show_panel(home_panel)

func handle_map_button():
	"""Navigate to map panel - with custom quest logic"""
	# Block navigation if player is on an active quest
	if is_on_active_quest():
		print("Cannot go to map - player is on an active quest")
		return
	
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	var current = GameInfo.get_current_panel()
	
	# Toggle off if already on map
	if current == map_panel:
		show_panel(home_panel)
		return
	
	# Quest states
	if traveling > 0 and destination != null:
		show_panel(map_panel)  # Traveling
	elif traveling == null and destination != null:
		show_panel(quest)  # Quest available
	else:
		show_panel(map_panel)  # Normal map

func handle_arena_button():
	"""Toggle arena panel"""
	# Block navigation if player is on an active quest
	if is_on_active_quest():
		print("Cannot go to arena - player is on an active quest")
		return
	
	if GameInfo.get_current_panel() == arena_panel:
		show_panel(home_panel)
	else:
		show_panel(arena_panel)

func handle_character_button():
	"""Toggle character panel"""
	if GameInfo.get_current_panel() == character_panel:
		# When toggling off, return to quest if on active quest, otherwise home
		if is_on_active_quest():
			show_panel(quest)
		else:
			show_panel(home_panel)
	else:
		show_panel(character_panel)

func handle_rankings_button():
	"""Toggle rankings panel"""
	# Check if rankings is already showing
	var rankings_index = overlay_stack.find(rankings_panel)
	
	if rankings_index >= 0:
		# Rankings is in the stack
		# If rankings is the ONLY thing in stack (top level), toggle it off
		if overlay_stack.size() == 1 and overlay_stack[0] == rankings_panel:
			print("UIManager: Rankings is only overlay, toggling off")
			hide_current_overlay()
			# Stay on current panel
		else:
			# Rankings is in stack but there are nested overlays above it
			# Clear everything and show rankings fresh at base level
			print("UIManager: Rankings in stack with nested overlays, resetting to rankings")
			# Clear all overlays
			while overlay_stack.size() > 0:
				var overlay = overlay_stack.pop_back()
				overlay.visible = false
			
			# Set base panel to home or quest
			var current_panel = GameInfo.get_current_panel()
			var target_panel = home_panel
			if is_on_active_quest():
				target_panel = quest
			
			if current_panel != target_panel:
				if current_panel:
					current_panel.visible = false
				target_panel.visible = true
				GameInfo.set_current_panel(target_panel)
			
			# Show rankings as fresh overlay
			show_overlay(rankings_panel)
	else:
		# Rankings not in stack - show it
		print("UIManager: Showing rankings overlay")
		
		# If there are nested overlays, clear them and ensure we're on home/quest base
		if overlay_stack.size() > 0:
			print("UIManager: Clearing nested overlays before showing rankings")
			# Clear all overlays
			while overlay_stack.size() > 0:
				var overlay = overlay_stack.pop_back()
				overlay.visible = false
			
			# Set base panel to home or quest
			var current_panel = GameInfo.get_current_panel()
			var target_panel = home_panel
			if is_on_active_quest():
				target_panel = quest
			
			if current_panel != target_panel:
				if current_panel:
					current_panel.visible = false
				target_panel.visible = true
				GameInfo.set_current_panel(target_panel)
		
		# Now show rankings as overlay
		show_overlay(rankings_panel)

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


func go_back():
	"""Back button - priority: chat > overlay stack > panel custom behavior > home"""
	var current = GameInfo.get_current_panel()
	
	print("=== BACK BUTTON DEBUG ===")
	print("Current panel: ", current.name if current else "null")
	print("Overlay stack depth: ", overlay_stack.size())
	print("Chat overlay active: ", chat_overlay_active)
	print("========================")
	
	# Priority 0: Close chat overlay if active (highest priority)
	if chat_overlay_active:
		print("-> Closing chat overlay")
		toggle_chat()
		return
	
	# Priority 1: Hide sub-overlays (upgrade/perkscreen on talents)
	if upgrade_talent and upgrade_talent.visible:
		print("-> Hiding upgrade sub-overlay")
		upgrade_talent.visible = false
		return
	
	if perk_screen and perk_screen.visible:
		print("-> Hiding perks sub-overlay")
		perk_screen.visible = false
		return
	
	# Priority 2: Pop from overlay stack
	if overlay_stack.size() > 0:
		print("-> Popping overlay from stack")
		hide_current_overlay()
		return
	
	# Priority 3: Panel-specific custom back behavior
	var traveling = GameInfo.current_player.traveling
	var destination = GameInfo.current_player.traveling_destination
	
	# Map panel: show cancel quest if traveling
	if current == map_panel:
		if traveling > 0 and destination != null:
			print("-> Map panel with active quest, showing cancel dialog")
			show_overlay(cancel_quest)
			return
	
	# Quest panel: show cancel quest if arrived
	if current == quest:
		if traveling == 0 and destination != null:
			print("-> Quest panel with completed travel, showing cancel dialog")
			show_overlay(cancel_quest)
			return
	
	# Home panel: check quest accept panel first, then interior navigation
	if current == home_panel:
		# First priority: hide quest accept panel if visible
		if quest_panel.visible:
			print("-> Hiding quest accept panel")
			quest_panel.visible = false
			return
		
		# Second priority: interior navigation
		print("-> Home panel, checking interior navigation")
		var handled = home_panel.handle_back_navigation()
		if handled:
			print("   -> Handled interior navigation")
			return
		else:
			print("   -> Already in exterior, do nothing")
			return
	
	# Talents/Details bookmarks - handled by overlay system now
	# (removed specific cases since they're overlays)
	
	# Rankings panel: go back to home or quest
	if current == rankings_panel:
		print("-> Rankings panel, going back")
		if is_on_active_quest():
			show_panel(quest)
		else:
			show_panel(home_panel)
		return
	
	# Default: go home, or go to quest panel if on active quest
	if is_on_active_quest():
		print("-> Active quest detected, returning to quest panel")
		show_panel(quest)
	else:
		print("-> Default case, going home")
		show_panel(home_panel)


func show_combat():
	"""Show combat panel"""
	var current_panel = GameInfo.get_current_panel()
	if current_panel:
		current_panel.visible = false
	combat_panel.visible = true
	GameInfo.set_current_panel(combat_panel)

func handle_quest_completed():
	"""Called when quest is finished - return to home"""
	quest.visible = false
	show_panel(home_panel)

func handle_quest_arrived():
	"""Called when travel is completed - show quest panel"""
	# Show quest panel - it will automatically load the quest via visibility_changed
	show_panel(quest)

# Cancel quest dialog functions
func _on_cancel_quest_yes():
	# Get the quest ID before clearing it
	var quest_id = GameInfo.current_player.traveling_destination
	
	# Mark quest as completed so NPC won't show up again
	if quest_id != null and quest_id is int:
		GameInfo.complete_quest(quest_id)
		print("Quest ", quest_id, " abandoned and marked as completed")
	
	# Cancel the quest
	GameInfo.current_player.traveling = 0
	GameInfo.current_player.traveling_destination = null
	
	# Hide cancel dialog using unified overlay system and return to home
	hide_overlay(cancel_quest)
	show_panel(home_panel)
	print("Quest canceled by user")

func _on_cancel_quest_no():
	# Just hide the dialog using unified overlay system, continue with quest
	hide_overlay(cancel_quest)

func _load_quest_on_startup(quest_id: int):
	"""Helper to load quest on startup after panel is visible"""
	quest.load_quest(quest_id)

# ============================================================================
# UIManager Functions - Currency, Stats, Effects, Bags, Avatars
# ============================================================================

func update_silver(amount: int):
	"""Add or subtract silver and update all displays"""
	print("UIManager.update_silver called with amount: ", amount)
	print("Current silver before: ", GameInfo.current_player.silver)
	GameInfo.current_player.silver += amount
	print("Current silver after: ", GameInfo.current_player.silver)
	update_display()

func update_mushrooms(amount: int):
	"""Add or subtract mushrooms and update all displays"""
	print("UIManager.update_mushrooms called with amount: ", amount)
	print("Current mushrooms before: ", GameInfo.current_player.mushrooms)
	GameInfo.current_player.mushrooms += amount
	print("Current mushrooms after: ", GameInfo.current_player.mushrooms)
	update_display()

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

	# Refresh mushrooms label displays
	print("UIManager.update_display mushrooms_labels count: ", mushrooms_labels.size())
	var mushrooms_text = str(GameInfo.current_player.mushrooms)
	for m_label in mushrooms_labels:
		m_label.text = mushrooms_text

func _on_character_changed():
	"""Called when character switches - refresh all displays"""
	update_display()
	refresh_bags()

func refresh_bags():
	"""Ask all registered bag views to refresh from GameInfo state"""
	print("UIManager.refresh_bags bag_views count: ", bag_views.size())
	for view in bag_views:
		view.update_equip_slots()

func refresh_stats():
	"""Recalculate and display stats for current player"""
	character_display.stats_changed(GameInfo.get_player_stats())
	details_panel.display_effects(GameInfo.current_player)
	
	# Refresh quest options if currently on a quest
	if GameInfo.current_player and GameInfo.current_player.traveling_destination:
		print("UIManager.refresh_stats refreshing quest options")
		quest.refresh_quest_options_internal()

func refresh_active_effects():
	"""Refresh active effects display (blessings, potions, elixirs)"""
	if character_display:
		character_display.refresh_active_effects()

func refresh_perks():
	"""Refresh perks grid when new perks are added"""
	if perk_screen and perk_screen.has_method("refresh_perks"):
		perk_screen.refresh_perks()

func refresh_avatars():
	"""Update all avatar displays with current player data"""
	print("UIManager.refresh_avatars avatars count: ", avatars.size())
	if not GameInfo.current_player:
		return
	
	for avatar in avatars:
		avatar.refresh_avatar(
			GameInfo.current_player.avatar_face,
			GameInfo.current_player.avatar_hair,
			GameInfo.current_player.avatar_eyes,
			GameInfo.current_player.avatar_nose,
			GameInfo.current_player.avatar_mouth
		)

func notify_slot_changed(slot_id: int):
	"""Notify panels when a utility slot changes by calling their update methods directly"""
	var current_panel = GameInfo.get_current_panel()
	if not current_panel:
		return
	
	# Call the appropriate panel's update method
	if current_panel.name == "BlacksmithPanel" and current_panel.has_method("on_slot_changed"):
		current_panel.on_slot_changed(slot_id)
	elif current_panel.name == "AlchemistPanel" and current_panel.has_method("on_slot_changed"):
		current_panel.on_slot_changed(slot_id)
	elif current_panel.name == "EnchanterPanel" and current_panel.has_method("on_slot_changed"):
		current_panel.on_slot_changed(slot_id)
