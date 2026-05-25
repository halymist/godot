extends Node

# Resolution scaling manager - Portrait phone only (Autoload)
# Clamps the effective content aspect ratio to a reasonable phone range.

var current_scale_factor = 1.0

# User preference scaling (can be changed via settings)
var user_font_scale: float = 1.0  # 1.0 = normal, 1.2 = 20% bigger, 0.8 = 20% smaller

# Set by game scene after loading
var base_theme: Theme = null

# Aspect ratio thresholds for portrait phone mode.
# Taller/narrower than 21:9 gets vertical letterboxing.
# Wider than 16:9 gets side letterboxing.
const MIN_PHONE_ASPECT = 9.0 / 21.0
const MAX_PHONE_ASPECT = 9.0 / 16.0

# Base resolution
const PORTRAIT_BASE = Vector2i(405, 900)  # 21:9 aspect ratio base

var last_window_size: Vector2i = Vector2i.ZERO

signal user_font_scale_changed(new_scale)

func _ready():
	get_tree().root.size_changed.connect(calculate_layout)
	calculate_layout()

func _process(_delta):
	var current_size = DisplayServer.window_get_size()
	if current_size != last_window_size:
		last_window_size = current_size
		calculate_layout()

func calculate_layout():
	var window_size = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		return
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	var clamped_aspect = clampf(aspect_ratio, MIN_PHONE_ASPECT, MAX_PHONE_ASPECT)
	var target_width = int(round(float(PORTRAIT_BASE.y) * clamped_aspect))
	update_content_scale(Vector2i(target_width, PORTRAIT_BASE.y))

func update_content_scale(base_resolution: Vector2i):
	"""Update the window's content scale base resolution with letterboxing outside supported phone ratios."""
	var window = get_tree().root
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_size = base_resolution
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

# user font scale preference - only scales Label fonts
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
		
	# Scale the Label font size
	var original_size = base_theme.get_meta("original_label_size")
	var scaled_size = int(original_size * user_font_scale)
	base_theme.set_font_size("font_size", "Label", scaled_size)
	
	user_font_scale_changed.emit(new_scale)
