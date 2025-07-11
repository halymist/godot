extends Node

# Resolution scaling manager
var base_resolution = Vector2(375, 667)
var current_scale_factor = 1.0

# User preference scaling (can be changed via settings)
@export var user_font_scale: float = 1.0  # 1.0 = normal, 1.2 = 20% bigger, 0.8 = 20% smaller

# Layout management based on aspect ratio
@export var phone_ui_root: Control  # Assign in inspector
@export var desktop_ui_root: Control  # Assign in inspector
@export var aspect_ratio_threshold: float = 0.6  # Below this = phone, above = desktop

# Store current layout as direct reference to the active UI root
var current_layout: Control = null

signal resolution_changed(scale_factor)
signal user_font_scale_changed(new_scale)
signal layout_changed(new_layout)

func _ready():
	# Set initial layout after exports are assigned
	current_layout = phone_ui_root if phone_ui_root else null
	# Connect to resolution changes
	get_viewport().size_changed.connect(_on_screen_resized)
	calculate_scale_factor()

func calculate_scale_factor():
	var current_size = get_viewport().get_visible_rect().size
	var scale_y = current_size.y / base_resolution.y  # Use height for font scaling
	
	current_scale_factor = scale_y
	
	# Calculate aspect ratio from viewport size
	var aspect_ratio = float(current_size.x) / float(current_size.y)
	var new_layout = phone_ui_root if aspect_ratio < aspect_ratio_threshold else desktop_ui_root
	
	# Switch layout if needed
	if new_layout != current_layout:
		switch_layout(new_layout)
	
	print("Current aspect ratio: ", aspect_ratio, " - Active layout: ", new_layout.name if new_layout else "none")
	resolution_changed.emit(current_scale_factor)

func _on_screen_resized():
	calculate_scale_factor()
	update_all_font_scaling()

# Layout switching functionality
func switch_layout(new_layout: Control):
	print("Switching layout from ", current_layout.name, " to ", new_layout.name)
	# Turn off current layout
	current_layout.visible = false
	current_layout.process_mode = Node.PROCESS_MODE_DISABLED

	current_layout = new_layout
	current_layout.visible = true
	current_layout.process_mode = Node.PROCESS_MODE_INHERIT
	layout_changed.emit(current_layout)

# Simple approach - return scaled size with user preference
func get_scaled_font_size(base_size: int) -> int:
	return int(base_size * current_scale_factor * user_font_scale)

# Quick apply method using control's existing font size
func apply_scale_to_control(control: Control):
	if control is Label or control is Button:
		# Get the control's original font size (store it if not already stored)
		if not control.has_meta("original_font_size"):
			var current_font_size = control.get_theme_font_size("font_size")
			if current_font_size == null or current_font_size <= 0:
				current_font_size = 20  # Default fallback
			control.set_meta("original_font_size", current_font_size)
		
		var original_size = control.get_meta("original_font_size")
		var scaled_size = get_scaled_font_size(original_size)
		control.add_theme_font_size_override("font_size", scaled_size)

# Automatically scale all text controls in the scene tree
func apply_scaling_to_all_controls(root_node: Node = null):
	if root_node == null:
		root_node = get_tree().current_scene
	
	_scale_controls_recursive(root_node)

func _scale_controls_recursive(node: Node):
	# Check if this node is a text control
	if node is Label or node is Button:
		apply_scale_to_control(node)
	
	# Recursively check all children
	for child in node.get_children():
		_scale_controls_recursive(child)

# Call this when resolution changes to update all controls
func update_all_font_scaling():
	apply_scaling_to_all_controls()

# Function to change user font scale preference
func set_user_font_scale(new_scale: float):
	user_font_scale = new_scale
	user_font_scale_changed.emit(new_scale)
	# Re-apply scaling to all controls with new user preference
	update_all_font_scaling()
