extends Node

# Resolution scaling manager
var base_resolution = Vector2(375, 667)
var current_scale_factor = 1.0

# User preference scaling (can be changed via settings)
@export var user_font_scale: float = 1.0  # 1.0 = normal, 1.2 = 20% bigger, 0.8 = 20% smaller

@export var phone_ui_root: Control
@export var desktop_ui_root: Control
@export var base_theme: Theme
@export var aspect_ratio_threshold: float = 0.6  # Below this = phone, above = desktop

# Store current layout as direct reference to the active UI root
var current_layout: Control = null

signal user_font_scale_changed(new_scale)
signal layout_changed(new_layout)

func _ready():
	current_layout = phone_ui_root
	get_viewport().size_changed.connect(calculate_layout)
	calculate_layout()

func calculate_layout():
	var window_size = DisplayServer.window_get_size()
	
	# Calculate aspect ratio for layout switching
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	var new_layout = phone_ui_root if aspect_ratio < aspect_ratio_threshold else desktop_ui_root
	if new_layout != current_layout:
		switch_layout(new_layout)


func switch_layout(new_layout: Control):
	print("Switching layout from ", current_layout.name, " to ", new_layout.name)
	current_layout.visible = false
	current_layout.process_mode = Node.PROCESS_MODE_DISABLED

	current_layout = new_layout
	current_layout.visible = true
	current_layout.process_mode = Node.PROCESS_MODE_INHERIT
	layout_changed.emit(current_layout)

# Simple user font scale preference - only scales Label fonts
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
	
	# Store original Label font size if not already stored
	if not base_theme.has_meta("original_label_size"):
		var original_size = base_theme.get_font_size("font_size", "Label")
		if original_size > 0:
			base_theme.set_meta("original_label_size", original_size)
	
	# Scale the Label font size
	var original_size = base_theme.get_meta("original_label_size")
	var scaled_size = int(original_size * user_font_scale)
	base_theme.set_font_size("font_size", "Label", scaled_size)
	
	print("User font scale set to ", user_font_scale, " - Label font: ", original_size, " -> ", scaled_size)
	user_font_scale_changed.emit(new_scale)
