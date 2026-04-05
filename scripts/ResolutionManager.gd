extends Node

# Resolution scaling manager - Portrait only
# Scales content up to 9:16 aspect ratio, then stops scaling width

var current_scale_factor = 1.0

# User preference scaling (can be changed via settings)
@export var user_font_scale: float = 1.0  # 1.0 = normal, 1.2 = 20% bigger, 0.8 = 20% smaller

@export var phone_ui_root: Control
@export var base_theme: Theme

# Aspect ratio thresholds for portrait phone mode
# 21:9 portrait = 9/21 = 0.4286 (base, tallest)
# 16:9 portrait = 9/16 = 0.5625 (max width ratio - don't scale beyond this)
const ASPECT_21_9 = 0.4286  # Base aspect ratio (tallest portrait)
const ASPECT_16_9 = 0.5625  # Maximum aspect ratio (widest portrait)

# Base resolution
const PORTRAIT_BASE = Vector2i(405, 900)  # 21:9 aspect ratio base

var last_window_size: Vector2i = Vector2i.ZERO

signal user_font_scale_changed(new_scale)

func _ready():
	if phone_ui_root:
		phone_ui_root.visible = true
		phone_ui_root.process_mode = Node.PROCESS_MODE_INHERIT
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
	
	var target_base_resolution: Vector2i
	
	if aspect_ratio < ASPECT_21_9:
		# Narrower than 21:9: shrink height to maintain 21:9 minimum
		var adjusted_height = int(window_size.x / ASPECT_21_9)
		target_base_resolution = Vector2i(PORTRAIT_BASE.x, adjusted_height)
		print("Mode: PORTRAIT (narrower than 21:9) - Adjusted height: ", adjusted_height)
		update_content_scale(target_base_resolution, false)
	elif aspect_ratio <= ASPECT_16_9:
		# Between 21:9 and 16:9: use base 21:9 resolution, content scales to fill
		target_base_resolution = PORTRAIT_BASE
		print("Mode: PORTRAIT (21:9 to 16:9 range) - Base resolution")
		update_content_scale(target_base_resolution, false)
	else:
		# Wider than 16:9: cap at 16:9 width, add black bars on sides
		var max_width = int(PORTRAIT_BASE.y * ASPECT_16_9)
		target_base_resolution = Vector2i(max_width, PORTRAIT_BASE.y)
		print("Mode: PORTRAIT (wider than 16:9) - Capped width: ", max_width)
		update_content_scale(target_base_resolution, true)

func update_content_scale(base_resolution: Vector2i, letterbox: bool = false):
	"""Update the window's content scale base resolution.
	letterbox=true uses KEEP aspect to add black bars on wider screens."""
	var window = get_tree().root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	if letterbox:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	else:
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
	window.content_scale_size = base_resolution
	print("Content scale updated: ", base_resolution, " letterbox: ", letterbox)

# user font scale preference - only scales Label fonts
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
		
	# Scale the Label font size
	var original_size = base_theme.get_meta("original_label_size")
	var scaled_size = int(original_size * user_font_scale)
	base_theme.set_font_size("font_size", "Label", scaled_size)
	
	print("User font scale set to ", user_font_scale, " - Label font: ", original_size, " -> ", scaled_size)
	user_font_scale_changed.emit(new_scale)
