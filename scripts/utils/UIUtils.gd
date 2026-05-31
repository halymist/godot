class_name UIUtils
extends RefCounted

const GOLDEN := Color(0.9, 0.7, 0.4, 1.0)
const DEFAULT_MODULATE := Color(1.0, 1.0, 1.0, 1.0)
const PRICE_NORMAL := Color(0.85, 0.8, 0.7, 1.0)
const PRICE_MISSING := Color(1.0, 0.25, 0.2, 1.0)

static func apply_golden_button_feedback(button: BaseButton):
	if not button:
		return
	button.mouse_entered.connect(func(): button.modulate = GOLDEN)
	button.mouse_exited.connect(func(): button.modulate = DEFAULT_MODULATE)
	button.button_down.connect(func(): button.modulate = GOLDEN)
	button.button_up.connect(func(): button.modulate = DEFAULT_MODULATE)

static func set_afford_label_color(label: Label, can_afford: bool):
	if label:
		label.add_theme_color_override("font_color", PRICE_NORMAL if can_afford else PRICE_MISSING)

static func set_button_price_color(button: Button, can_afford: bool):
	if not button:
		return
	set_afford_label_color(button.get_node_or_null("Content/PriceLabel") as Label, can_afford)