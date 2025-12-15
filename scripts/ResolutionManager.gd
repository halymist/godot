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
@export var aspect_ratio_threshold: float = 0.6  # Below this = phone, above = desktop
var min_phone_aspect_ratio: float = 0.4

# Store current layout as direct reference to the active UI root
var current_layout: Control = null

signal user_font_scale_changed(new_scale)
signal layout_changed(new_layout)

func _ready():
	current_layout = null  # Start as null so first calculate_layout triggers switch
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
	if not new_layout:
		print("Error: new_layout is null")
		return
		
	if current_layout:
		print("Switching layout from ", current_layout.name, " to ", new_layout.name)
		current_layout.visible = false
		current_layout.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		print("Switching to initial layout: ", new_layout.name)

	current_layout = new_layout
	current_layout.visible = true
	current_layout.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Reparent GameScene to the appropriate parent
	if game_scene:
		var current_parent = game_scene.get_parent()
		var target_parent = portrait_game_parent if new_layout == phone_ui_root else wide_game_parent
		
		if target_parent and current_parent != target_parent:
			if current_parent:
				current_parent.remove_child(game_scene)
			target_parent.add_child(game_scene)
			game_scene.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	layout_changed.emit(current_layout)

func _process(_delta):
	if current_layout == desktop_ui_root:
		var viewport_size = get_viewport().get_visible_rect().size
		var target_ratio = 4.0 / 3.0
		
		var width_based_height = viewport_size.x / target_ratio
		var height_based_width = viewport_size.y * target_ratio
		
		var final_width: float
		var final_height: float
		
		if width_based_height <= viewport_size.y:
			final_width = viewport_size.x
			final_height = width_based_height
		else:
			final_width = height_based_width
			final_height = viewport_size.y
		
		var x_offset = (viewport_size.x - final_width) / 2.0
		var y_offset = viewport_size.y - final_height
		
		desktop_ui_root.position = Vector2(x_offset, y_offset)
		desktop_ui_root.size = Vector2(final_width, final_height)

# user font scale preference - only scales Label fonts
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
		
	# Scale the Label font size
	var original_size = base_theme.get_meta("original_label_size")
	var scaled_size = int(original_size * user_font_scale)
	base_theme.set_font_size("font_size", "Label", scaled_size)
	
	print("User font scale set to ", user_font_scale, " - Label font: ", original_size, " -> ", scaled_size)
	user_font_scale_changed.emit(new_scale)
