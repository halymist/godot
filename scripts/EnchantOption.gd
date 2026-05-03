extends Button
class_name EnchantOption

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")

var effect_id: int = 0
var effect_factor: float = 0.0

func setup(effect: EffectResource):
	effect_id = effect.id
	effect_factor = effect.factor
	text = EFFECT_FORMATTER.format_with_factor(effect.description, effect.factor, true)
	
	# Style the button
	var normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
	normal_style.border_width_left = 2
	normal_style.border_width_right = 2
	normal_style.border_width_top = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color(0.5, 0.5, 0.6, 1)
	add_theme_stylebox_override("normal", normal_style)
	
	var hover_style = StyleBoxFlat.new()
	hover_style.bg_color = Color(0.3, 0.3, 0.35, 0.9)
	hover_style.border_width_left = 2
	hover_style.border_width_right = 2
	hover_style.border_width_top = 2
	hover_style.border_width_bottom = 2
	hover_style.border_color = Color(0.7, 0.7, 0.8, 1)
	add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = StyleBoxFlat.new()
	pressed_style.bg_color = Color(0.4, 0.6, 0.8, 0.9)
	pressed_style.border_width_left = 2
	pressed_style.border_width_right = 2
	pressed_style.border_width_top = 2
	pressed_style.border_width_bottom = 2
	pressed_style.border_color = Color(0.6, 0.8, 1.0, 1)
	add_theme_stylebox_override("pressed", pressed_style)
	
	add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	add_theme_font_size_override("font_size", 12)

func set_selected(is_selected: bool):
	if is_selected:
		var selected_style = StyleBoxFlat.new()
		selected_style.bg_color = Color(0.4, 0.6, 0.8, 0.9)
		selected_style.border_width_left = 2
		selected_style.border_width_right = 2
		selected_style.border_width_top = 2
		selected_style.border_width_bottom = 2
		selected_style.border_color = Color(0.6, 0.8, 1.0, 1)
		add_theme_stylebox_override("normal", selected_style)
	else:
		var normal_style = StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.2, 0.25, 0.8)
		normal_style.border_width_left = 2
		normal_style.border_width_right = 2
		normal_style.border_width_top = 2
		normal_style.border_width_bottom = 2
		normal_style.border_color = Color(0.5, 0.5, 0.6, 1)
		add_theme_stylebox_override("normal", normal_style)
