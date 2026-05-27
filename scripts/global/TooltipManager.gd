extends Node

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")
const SILVER_ICON = preload("res://assets/images/ui/silver.png")
const MAX_TOOLTIP_WIDTH := 260.0
const NAME_COLOR := Color(0.90, 0.70, 0.40, 1.0)
const TEXT_COLOR := Color(0.95, 0.90, 0.82, 1.0)

func _ready():
	_install_tooltip_popup_style()

func make_item_tooltip(item: GameInfo.Item) -> Control:
	return _make_item_tooltip_panel(item)

func make_text_tooltip(tooltip_text: String, bulletize_body: bool = false) -> Control:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_tooltip_style())

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var label = Label.new()
	var content = tooltip_text.strip_edges()
	label.text = _bulletize_body_after_title(content) if bulletize_body else content
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = MAX_TOOLTIP_WIDTH
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	label.add_theme_color_override("font_color", TEXT_COLOR)
	margin.add_child(label)
	return panel

func get_item_tooltip_text(item: GameInfo.Item) -> String:
	if not item:
		return ""
	var lines: Array[String] = [_get_item_display_name(item)]
	var body_text = _build_item_tooltip_text(item)
	if not body_text.is_empty():
		lines.append(body_text)
	if item.price > 0:
		lines.append(str(_get_item_display_price(item)) + " silver")
	return "\n".join(lines)

func _build_item_tooltip_text(item: GameInfo.Item) -> String:
	if not item:
		return ""
	var lines: Array[String] = []
	var gem = item.get_socketed_gem()
	if item.type == "Weapon" and (item.damage_min > 0 or item.damage_max > 0):
		lines.append("Damage: %d - %d" % [item.damage_min, item.damage_max])

	_append_stat_line(lines, "Strength", item.strength, gem.strength if gem else 0)
	_append_stat_line(lines, "Stamina", item.stamina, gem.stamina if gem else 0)
	_append_stat_line(lines, "Agility", item.agility, gem.agility if gem else 0)
	_append_stat_line(lines, "Luck", item.luck, gem.luck if gem else 0)
	_append_stat_line(lines, "Armor", item.armor, gem.armor if gem else 0)

	for effect_line in _get_item_effect_lines(item):
		lines.append(effect_line)

	if item.has_socket:
		if item.socket_id > 0:
			var gem_item = GameInfo.items_db.get_item_by_id(item.socket_id) if GameInfo.items_db else null
			lines.append("Socket: " + (gem_item.item_name if gem_item else "Unknown Gem"))
		else:
			lines.append("Socket: Empty")

	return "\n".join(lines)

func _make_item_tooltip_panel(item: GameInfo.Item) -> Control:
	var panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", _make_tooltip_style())

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)

	var name_label = Label.new()
	name_label.text = _get_item_display_name(item)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.custom_minimum_size.x = MAX_TOOLTIP_WIDTH
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	layout.add_child(name_label)

	var body_text = _build_item_tooltip_text(item)
	if not body_text.is_empty():
		var body_label = Label.new()
		body_label.text = _bulletize_all_lines(body_text) if item.type == "Elixir" else body_text
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.custom_minimum_size.x = MAX_TOOLTIP_WIDTH
		body_label.add_theme_color_override("font_color", TEXT_COLOR)
		layout.add_child(body_label)

	if item and item.price > 0:
		layout.add_child(_make_price_row(_get_item_display_price(item)))

	return panel

func _get_item_display_name(item: GameInfo.Item) -> String:
	if not item:
		return ""
	var display_name = item.item_name
	if item.tempered > 0:
		display_name += " +" + str(item.tempered)
	return display_name

func _get_item_display_price(item: GameInfo.Item) -> int:
	return item.price * 2 if item.bag_slot_id == 20 else item.price

func _make_price_row(price: int) -> Control:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 4)
	var price_label = Label.new()
	price_label.text = str(price)
	price_label.add_theme_color_override("font_color", TEXT_COLOR)
	row.add_child(price_label)
	var icon = TextureRect.new()
	icon.texture = SILVER_ICON
	icon.custom_minimum_size = Vector2(16, 16)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	return row

func _bulletize_body_after_title(text: String) -> String:
	if text.is_empty():
		return ""
	var lines = text.split("\n")
	if lines.size() <= 1:
		return text
	var result: Array[String] = [lines[0]]
	for i in range(1, lines.size()):
		var line = String(lines[i]).strip_edges()
		if line.is_empty():
			continue
		if line.begins_with("["):
			result.append(line)
		else:
			result.append("- " + line)
	return "\n".join(result)

func _bulletize_all_lines(text: String) -> String:
	if text.is_empty():
		return ""
	var result: Array[String] = []
	for raw_line in text.split("\n"):
		var line = String(raw_line).strip_edges()
		if line.is_empty():
			continue
		result.append("- " + line)
	return "\n".join(result)

func _append_stat_line(lines: Array[String], stat_name: String, base_value: int, gem_value: int):
	if base_value == 0 and gem_value == 0:
		return
	if gem_value > 0:
		lines.append("%s: %d + %d" % [stat_name, base_value, gem_value])
	else:
		lines.append("%s: %d" % [stat_name, base_value])

func _get_item_effect_lines(item: GameInfo.Item) -> Array[String]:
	var lines: Array[String] = []
	if item.type == "Elixir" and (item.ingredients.size() > 0 or item.elixir_effects.size() > 0):
		var effect_map = {}
		if item.elixir_effects.size() > 0:
			for entry in item.elixir_effects:
				var effect_id = int(entry.get("effect_id", 0))
				var factor = float(entry.get("factor", 0.0))
				if effect_id > 0:
					effect_map[effect_id] = effect_map.get(effect_id, 0.0) + factor
		else:
			for ingredient_id in item.ingredients:
				var ingredient_resource = GameInfo.items_db.get_item_by_id(ingredient_id) if GameInfo.items_db else null
				if ingredient_resource and ingredient_resource.effect_id > 0:
					effect_map[ingredient_resource.effect_id] = effect_map.get(ingredient_resource.effect_id, 0.0) + ingredient_resource.effect_factor
		for effect_id in effect_map.keys():
			var effect_data = GameInfo.effects_db.get_effect_by_id(effect_id) if GameInfo.effects_db else null
			if effect_data:
				lines.append(EFFECT_FORMATTER.format_with_factor(effect_data.description, float(effect_map[effect_id]), true))
		return lines

	var display_effect_id = item.effect_id
	var display_effect_factor = item.effect_factor
	if item.effect_overdrive > 0:
		var overdrive_effect = GameInfo.effects_db.get_effect_by_id(item.effect_overdrive) if GameInfo.effects_db else null
		if overdrive_effect:
			display_effect_id = item.effect_overdrive
			display_effect_factor = overdrive_effect.factor

	if display_effect_id > 0:
		var effect_data = GameInfo.effects_db.get_effect_by_id(display_effect_id) if GameInfo.effects_db else null
		if effect_data and effect_data.description != "":
			lines.append(EFFECT_FORMATTER.format_with_factor(effect_data.description, display_effect_factor, true))
	return lines

func _estimate_text_width(text: String) -> float:
	var longest = 120.0
	for line in text.split("\n"):
		longest = max(longest, float(line.length()) * 7.5)
	return min(MAX_TOOLTIP_WIDTH, longest)

func _make_tooltip_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.058, 0.038, 1.0)
	style.border_color = Color(0.62, 0.42, 0.22, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.shadow_size = 0
	return style

func _install_tooltip_popup_style():
	var empty_style = StyleBoxEmpty.new()
	var theme = ThemeDB.get_default_theme()
	if theme:
		theme.set_stylebox("panel", "TooltipPanel", empty_style)
		theme.set_stylebox("panel", "PopupPanel", empty_style)

func show_tooltip(_item: GameInfo.Item, _slot_node: Control = null):
	pass

func hide_tooltip():
	pass

func show_perk_tooltip(_tooltip_text: String, _slot_node: Control = null):
	pass

func hide_perk_tooltip():
	pass
