extends Node

# Resolution scaling manager
var base_resolution = Vector2(375, 667)
var current_scale_factor = 1.0

# User preference scaling (can be changed via settings)
@export var user_font_scale: float = 1.0  # 1.0 = normal, 1.2 = 20% bigger, 0.8 = 20% smaller

@export var phone_ui_root: Control
@export var desktop_ui_root: Control
@export var game_scene: Control
@export var portrait_game_parent: Control
@export var wide_game_parent: Control
@export var base_theme: Theme

# Wide layout containers
@export var wide_left: Control
@export var wide_right: Control
@export var wide_full: Control

# Panel references for wide layout
@export_group("Panels")
@export var character_panel: Control
@export var talents_panel: Control
@export var avatar_panel: Control
@export var rankings_panel: Control
@export var enemy_panel: Control

@export var vendor_panel: Control
@export var blacksmith_panel: Control
@export var trainer_panel: Control
@export var church_panel: Control
@export var alchemist_panel: Control
@export var enchanter_panel: Control



# Aspect ratio thresholds for portrait phone mode
# 21:9 portrait = 9/21 = 0.4286 (base, tallest)
# 16:9 portrait = 9/16 = 0.5625 (widest portrait before switching to wide)
const ASPECT_21_9 = 0.4286  # Base aspect ratio (tallest portrait)
const ASPECT_16_9 = 0.5625  # Threshold to switch to wide mode

# Base resolutions for each mode
const PORTRAIT_BASE = Vector2i(405, 900)  # 21:9 aspect ratio base
const WIDE_BASE = Vector2i(1600, 900)  # GameScene 4:3 (1200x900) + Sidebar 1/3 width (400)

# Wide layout panel mapping: panel -> target container
var wide_panel_layout = {}

# Store current layout as direct reference to the active UI root
var current_layout: Control = null
var last_aspect_ratio: float = 0.0
var last_window_size: Vector2i = Vector2i.ZERO

# Store portrait container reference for switching back from wide
var portrait_container: Control = null

signal user_font_scale_changed(new_scale)
signal layout_changed(new_layout)

func _ready():
	# Build wide panel layout mapping
	_build_wide_layout_map()
	
	current_layout = null  # Start as null so first calculate_layout triggers switch
	calculate_layout()

func _build_wide_layout_map():
	"""Build the mapping of which panels go to which wide containers"""
	wide_panel_layout.clear()
	
	# Left side panels
	if character_panel:
		wide_panel_layout[character_panel] = "left"
	if rankings_panel:
		wide_panel_layout[rankings_panel] = "left"
	
	# Right side panels
	if talents_panel:
		wide_panel_layout[talents_panel] = "right"
	if avatar_panel:
		wide_panel_layout[avatar_panel] = "right"
	if enemy_panel:
		wide_panel_layout[enemy_panel] = "right"
	
	# Utility panels on right side
	if vendor_panel:
		wide_panel_layout[vendor_panel] = "right"
	if blacksmith_panel:
		wide_panel_layout[blacksmith_panel] = "right"
	if trainer_panel:
		wide_panel_layout[trainer_panel] = "right"
	if church_panel:
		wide_panel_layout[church_panel] = "right"
	if alchemist_panel:
		wide_panel_layout[alchemist_panel] = "right"
	if enchanter_panel:
		wide_panel_layout[enchanter_panel] = "right"
	
	print("Wide layout map built: ", wide_panel_layout.size(), " panels mapped")

func _process(_delta):
	var current_size = DisplayServer.window_get_size()
	if current_size != last_window_size:
		last_window_size = current_size
		calculate_layout()

func calculate_layout():
	var window_size = DisplayServer.window_get_size()
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	
	print("=== Resolution Manager ===")
	print("Window size: ", window_size, " | Aspect: %.4f" % aspect_ratio)
	print("21:9 threshold: %.4f | 16:9 threshold: %.4f" % [ASPECT_21_9, ASPECT_16_9])
	
	# Determine layout based on aspect ratio
	var new_layout: Control
	var target_base_resolution: Vector2i
	
	if aspect_ratio >= ASPECT_16_9:
		# Wide mode: aspect ratio is 16:9 or wider (more landscape)
		new_layout = desktop_ui_root
		target_base_resolution = WIDE_BASE
		print("Mode: WIDE (aspect >= 16:9)")
	else:
		# Portrait mode: aspect ratio is between narrowest phone and 16:9
		new_layout = phone_ui_root
		
		if aspect_ratio < ASPECT_21_9:
			# Narrower than 21:9: shrink height to maintain 21:9 minimum
			# Calculate what height would give us 21:9 ratio with current width
			var adjusted_height = int(window_size.x / ASPECT_21_9)
			target_base_resolution = Vector2i(PORTRAIT_BASE.x, adjusted_height)
			print("Mode: PORTRAIT (narrower than 21:9) - Adjusted height: ", adjusted_height)
		else:
			# Between 21:9 and 16:9: use base 21:9 resolution
			target_base_resolution = PORTRAIT_BASE
			print("Mode: PORTRAIT (21:9 to 16:9 range)")
	
	print("Selected layout: ", new_layout.name, " | Base resolution: ", target_base_resolution)
	
	if new_layout != current_layout:
		var old_layout = current_layout
		switch_layout(new_layout, target_base_resolution, old_layout)
	else:
		# Same layout but potentially different base resolution (for narrow phones)
		update_content_scale(target_base_resolution)


func switch_layout(new_layout: Control, base_resolution: Vector2i, old_layout: Control = null):
	if not new_layout:
		print("Error: new_layout is null")
		return
	
	# Determine layout switch direction
	var switching_to_wide = (new_layout == desktop_ui_root)
	var switching_from_wide = (old_layout == desktop_ui_root)
		
	if current_layout:
		print("Switching layout from ", current_layout.name, " to ", new_layout.name)
		current_layout.visible = false
		current_layout.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		print("Switching to initial layout: ", new_layout.name)

	current_layout = new_layout
	current_layout.visible = true
	current_layout.process_mode = Node.PROCESS_MODE_INHERIT
	
	print("Current layout after switch - Name:", current_layout.name, " Visible:", current_layout.visible, " Size:", current_layout.size, " Position:", current_layout.position)
	
	# Update content scale with the calculated base resolution
	update_content_scale(base_resolution)
	
	# Handle panel reparenting based on layout switch
	if switching_to_wide and not switching_from_wide:
		print("Reparenting panels to wide layout")
		reparent_to_wide()
		
		# Auto-show companion panels when switching to wide
		var current_panel = GameInfo.get_current_panel()
		var utility_panels = [vendor_panel, blacksmith_panel, trainer_panel, church_panel, alchemist_panel, enchanter_panel]
		
		# If a utility panel is active as current panel, show character panel on left
		if current_panel and current_panel in utility_panels:
			print("Wide mode: Utility panel active, showing character panel on left")
			if character_panel:
				character_panel.visible = true
		
		# If character panel is current, show talents on right
		elif current_panel == character_panel:
			print("Wide mode: Character panel active, showing talents on right")
			if talents_panel:
				talents_panel.visible = true
	
	elif switching_from_wide and not switching_to_wide:
		print("Reparenting panels to portrait layout")
		reparent_to_portrait()
	
	layout_changed.emit(current_layout)

func reparent_to_wide():
	"""Reparent panels from portrait to wide layout based on mapping"""
	if not wide_left or not wide_right or not wide_full:
		print("ERROR: Wide containers not set - left:", wide_left, " right:", wide_right, " full:", wide_full)
		return
	
	# Get portrait container directly from character_panel's parent
	if not character_panel or not is_instance_valid(character_panel):
		print("ERROR: character_panel not set or invalid")
		return
	
	portrait_container = character_panel.get_parent()
	if not portrait_container:
		print("ERROR: Could not get parent from character_panel")
		return
	
	print("=== Reparenting to Wide ===")
	print("Portrait container: ", portrait_container.name, " (from character_panel parent)")
	print("Portrait container has ", portrait_container.get_child_count(), " children")
	print("Wide panel layout has ", wide_panel_layout.size(), " mapped panels")
	
	# Hide all wide containers initially
	wide_left.visible = false
	wide_right.visible = false
	wide_full.visible = false
	
	# Collect all panels to reparent (from portrait container + utility panels)
	var panels_to_process: Array[Control] = []
	
	# Add panels from portrait container
	for child in portrait_container.get_children():
		if child is Control:
			panels_to_process.append(child)
	
	# Add utility panels explicitly (they may be elsewhere in the tree)
	var utility_panels = [vendor_panel, blacksmith_panel, trainer_panel, church_panel, alchemist_panel, enchanter_panel]
	for utility in utility_panels:
		if utility and utility not in panels_to_process:
			panels_to_process.append(utility)
	
	# Reparent all panels
	for panel in panels_to_process:
		var target_side = wide_panel_layout.get(panel, null)
		var was_visible = panel.visible
		
		print("  Processing: ", panel.name, " -> target: ", target_side if target_side else "FULL (unmapped)", " | visible: ", was_visible)
		
		if target_side == "left":
			_move_to_container(panel, wide_left)
			wide_left.visible = true
		elif target_side == "right":
			_move_to_container(panel, wide_right)
			wide_right.visible = true
			# Set high z-index for utility panels to ensure they're on top
			if panel in utility_panels:
				panel.z_index = 20
				panel.mouse_filter = Control.MOUSE_FILTER_STOP
				print("    Set utility panel z_index=20 and mouse_filter=STOP")
		else:
			_move_to_container(panel, wide_full)
			wide_full.visible = true
		
		# Preserve panel visibility after reparenting
		if panel.visible != was_visible:
			print("    WARNING: Panel visibility changed during reparent! Restoring to: ", was_visible)
			panel.visible = was_visible
	
	print("After reparenting - Left:", wide_left.get_child_count(), " Right:", wide_right.get_child_count(), " Full:", wide_full.get_child_count(), " children")
	print("Container visibility - Left:", wide_left.visible, " Right:", wide_right.visible, " Full:", wide_full.visible)
	
	# Debug container layout
	print("Wide Left - Position:", wide_left.position, " Size:", wide_left.size, " Anchors:", wide_left.anchor_left, ",", wide_left.anchor_right)
	print("Wide Right - Position:", wide_right.position, " Size:", wide_right.size, " Anchors:", wide_right.anchor_left, ",", wide_right.anchor_right)
	print("Wide Full - Position:", wide_full.position, " Size:", wide_full.size, " Anchors:", wide_full.anchor_left, ",", wide_full.anchor_right)
	
	# Debug character panel specifically
	if character_panel:
		print("Character panel - Visible:", character_panel.visible, " Parent:", character_panel.get_parent().name, " Position:", character_panel.position, " Size:", character_panel.size)
	
	# Debug wide_game_parent
	if wide_game_parent:
		print("Wide Game Parent - Visible:", wide_game_parent.visible, " Position:", wide_game_parent.position, " Size:", wide_game_parent.size, " Process mode:", wide_game_parent.process_mode)

func reparent_to_portrait():
	"""Reparent all panels back to portrait layout"""
	if not portrait_container:
		print("ERROR: portrait_container not stored from wide switch")
		return
	
	print("=== Reparenting to Portrait ===")
	print("Portrait container: ", portrait_container.name)
	
	# Collect all panels from wide containers
	var all_panels: Array[Control] = []
	if wide_left:
		for child in wide_left.get_children():
			if child is Control:
				all_panels.append(child)
	if wide_right:
		for child in wide_right.get_children():
			if child is Control:
				all_panels.append(child)
	if wide_full:
		for child in wide_full.get_children():
			if child is Control:
				all_panels.append(child)
	
	# Move all panels back to portrait
	for panel in all_panels:
		var was_visible = panel.visible
		print("Moving ", panel.name, " back to portrait | visible: ", was_visible)
		_move_to_container(panel, portrait_container)
		if panel.visible != was_visible:
			print("  WARNING: ", panel.name, " visibility changed during move! Was: ", was_visible, " Now: ", panel.visible)
			panel.visible = was_visible
		
		# Set z_index for overlay panels so they render on top
		if panel == rankings_panel or panel.name in ["Settings", "Payment", "ChatOverlay"]:
			panel.z_index = 10
			print("  Set ", panel.name, " z_index to 10 (overlay)")
		
		# Debug parent visibility
		print("  ", panel.name, " parent after move: ", panel.get_parent().name, " | parent visible: ", panel.get_parent().visible)

func _move_to_container(panel: Control, container: Control):
	"""Move a panel to a container with full rect anchors"""
	if panel.get_parent() != container:
		var old_parent = panel.get_parent()
		if old_parent:
			old_parent.remove_child(panel)
		container.add_child(panel)
	
	# Set to full rect
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = 0
	panel.offset_bottom = 0

func update_content_scale(base_resolution: Vector2i):
	"""Update the window's content scale base resolution"""
	var window = get_tree().root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = base_resolution
	print("Content scale updated: ", base_resolution)

# user font scale preference - only scales Label fonts
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
		
	# Scale the Label font size
	var original_size = base_theme.get_meta("original_label_size")
	var scaled_size = int(original_size * user_font_scale)
	base_theme.set_font_size("font_size", "Label", scaled_size)
	
	print("User font scale set to ", user_font_scale, " - Label font: ", original_size, " -> ", scaled_size)
	user_font_scale_changed.emit(new_scale)
