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
var min_phone_aspect_ratio: float = 0.4

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
	var aspect_ratio = float(window_size.x) / float(window_size.y)
	var new_layout = phone_ui_root if aspect_ratio < aspect_ratio_threshold else desktop_ui_root

	# Enforce minimum aspect ratio for phone layout
	if new_layout == phone_ui_root:
		var min_aspect = min_phone_aspect_ratio
		var min_width = int(window_size.y * min_aspect)
		if window_size.x < min_width:
			# Can't enforce min width, so enforce min aspect by reducing height
			var enforced_height = int(window_size.x / min_aspect)
			phone_ui_root.custom_minimum_size.x = window_size.x
			phone_ui_root.custom_minimum_size.y = enforced_height
			phone_ui_root.anchor_left = 0
			phone_ui_root.anchor_right = 1
			phone_ui_root.anchor_top = 1.0 - (enforced_height / float(window_size.y))
			phone_ui_root.anchor_bottom = 1.0
		else:
			# Reset to default
			phone_ui_root.custom_minimum_size.x = 0
			phone_ui_root.custom_minimum_size.y = 0
			phone_ui_root.anchor_left = 0
			phone_ui_root.anchor_right = 1
			phone_ui_root.anchor_top = 0
			phone_ui_root.anchor_bottom = 1
	else:
		# Reset phone UI if not active
		phone_ui_root.custom_minimum_size.x = 0
		phone_ui_root.custom_minimum_size.y = 0
		phone_ui_root.anchor_left = 0
		phone_ui_root.anchor_right = 1
		phone_ui_root.anchor_top = 0
		phone_ui_root.anchor_bottom = 1

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

# user font scale preference - only scales Label fonts
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
		
	# Scale the Label font size
	var original_size = base_theme.get_meta("original_label_size")
	var scaled_size = int(original_size * user_font_scale)
	base_theme.set_font_size("font_size", "Label", scaled_size)
	
	print("User font scale set to ", user_font_scale, " - Label font: ", original_size, " -> ", scaled_size)
	user_font_scale_changed.emit(new_scale)
