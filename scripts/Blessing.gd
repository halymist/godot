extends PanelContainer

signal blessing_selected(blessing_id: int)

var effect: EffectResource
var blessing_id: int = 0
var is_active: bool = false
var is_selected: bool = false

@onready var button = $Button
@onready var icon = $Content/IconContainer/Icon
@onready var name_label = $Content/Info/Name
@onready var description_label = $Content/Info/Description

# Style references
var default_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var active_style: StyleBoxFlat

func _ready():
	# Create default style
	default_style = StyleBoxFlat.new()
	default_style.bg_color = Color(0.12, 0.10, 0.08, 0.7)
	default_style.border_color = Color(0.4, 0.35, 0.25, 0.5)
	default_style.border_width_left = 1
	default_style.border_width_top = 1
	default_style.border_width_right = 1
	default_style.border_width_bottom = 1
	default_style.corner_radius_top_left = 4
	default_style.corner_radius_top_right = 4
	default_style.corner_radius_bottom_left = 4
	default_style.corner_radius_bottom_right = 4
	
	# Create selected style (when clicked but not yet active)
	selected_style = StyleBoxFlat.new()
	selected_style.bg_color = Color(0.18, 0.15, 0.10, 0.75)  # Slightly brighter than default
	selected_style.border_color = Color(0.6, 0.5, 0.35, 0.7)  # Lighter border
	selected_style.border_width_left = 1
	selected_style.border_width_top = 1
	selected_style.border_width_right = 1
	selected_style.border_width_bottom = 1
	selected_style.corner_radius_top_left = 4
	selected_style.corner_radius_top_right = 4
	selected_style.corner_radius_bottom_left = 4
	selected_style.corner_radius_bottom_right = 4
	
	# Create active style
	active_style = StyleBoxFlat.new()
	active_style.bg_color = Color(0.25, 0.20, 0.12, 0.85)
	active_style.border_color = Color(0.85, 0.7, 0.3, 0.9)
	active_style.border_width_left = 2
	active_style.border_width_top = 2
	active_style.border_width_right = 2
	active_style.border_width_bottom = 2
	active_style.corner_radius_top_left = 4
	active_style.corner_radius_top_right = 4
	active_style.corner_radius_bottom_left = 4
	active_style.corner_radius_bottom_right = 4
	
	# Connect button
	if button:
		button.pressed.connect(_on_button_pressed)
	
	# Set initial style
	set_active(false)

func setup(blessing_effect: EffectResource):
	effect = blessing_effect
	blessing_id = blessing_effect.id
	
	# Get nodes directly if @onready hasn't run yet
	var icon_node = icon if icon else $Content/IconContainer/Icon
	var name_node = name_label if name_label else $Content/Info/Name
	var desc_node = description_label if description_label else $Content/Info/Description
	
	if icon_node and blessing_effect.icon:
		icon_node.texture = blessing_effect.icon
	
	if name_node:
		name_node.text = blessing_effect.name
	
	if desc_node:
		desc_node.text = blessing_effect.description

func set_active(active: bool):
	is_active = active
	update_style()

func set_selected(selected: bool):
	is_selected = selected
	update_style()

func update_style():
	# Ensure styles are initialized
	if not default_style or not selected_style or not active_style:
		return
		
	if is_active:
		add_theme_stylebox_override("panel", active_style)
	elif is_selected:
		add_theme_stylebox_override("panel", selected_style)
	else:
		add_theme_stylebox_override("panel", default_style)

func _on_button_pressed():
	blessing_selected.emit(blessing_id)
