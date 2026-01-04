extends Node

# Resolution scaling manager
var current_scale_factor = 1.0

# User preference scaling (can be changed via settings)
@export var user_font_scale: float = 1.0  # 1.0 = normal, 1.2 = 20% bigger, 0.8 = 20% smaller

# Signal emitted when layout mode changes
signal layout_mode_changed(is_wide: bool)

@export var phone_ui_root: Control
@export var desktop_ui_root: Control
@export var base_theme: Theme

# Aspect ratio thresholds for portrait phone mode
# 21:9 portrait = 9/21 = 0.4286 (base, tallest)
# 16:9 portrait = 9/16 = 0.5625 (widest portrait before switching to wide)
const ASPECT_21_9 = 0.4286  # Base aspect ratio (tallest portrait)
const ASPECT_16_9 = 0.5625  # Threshold to switch to wide mode

# Base resolutions for each mode
const PORTRAIT_BASE = Vector2i(405, 900)  # 21:9 aspect ratio base
const WIDE_BASE = Vector2i(1050, 630) # GameScene 4:3 (1200x900) + Sidebar 1/3 width (400)

# Store current layout as direct reference to the active UI root
var current_layout: Control = null
var last_aspect_ratio: float = 0.0
var last_window_size: Vector2i = Vector2i.ZERO

signal user_font_scale_changed(new_scale)
signal layout_changed(new_layout)

func _ready():
	current_layout = null  # Start as null so first calculate_layout triggers switch
	calculate_layout()

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
	
	# Emit layout mode signals
	if switching_to_wide and not switching_from_wide:
		print("Switching to wide layout")
		layout_mode_changed.emit(true)  # Emit wide mode signal
	elif switching_from_wide and not switching_to_wide:
		print("Switching to portrait layout")
		layout_mode_changed.emit(false)  # Emit portrait mode signal
	
	layout_changed.emit(current_layout)

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
