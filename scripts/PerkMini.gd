extends Control

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")

@export var icon_texture: TextureRect

var meta_data: Dictionary

func setup(texture: Texture2D, data: Dictionary):
	icon_texture.texture = texture
	meta_data = data
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(TooltipManager.hide_perk_tooltip)

func _format_time_remaining(expire_until: float) -> String:
	"""Format the remaining time until expiration in a human-readable way."""
	if expire_until <= 0:
		return ""
	
	var current_time = Time.get_unix_time_from_system()
	var seconds_left = expire_until - current_time
	
	if seconds_left <= 0:
		return "[Expired]"

	# UX requirement: show rounded-up hours while >= 1h, then rounded-up minutes below 1h.
	if seconds_left >= 3600.0:
		var hours_left = int(ceil(seconds_left / 3600.0))
		return "[%dh remaining]" % [hours_left]

	var minutes_left = int(ceil(seconds_left / 60.0))
	minutes_left = max(minutes_left, 1)
	return "[%dm remaining]" % [minutes_left]

func _format_effect_line(effect: EffectResource, factor_value: float) -> String:
	if not effect:
		return ""
	return EFFECT_FORMATTER.format_with_factor(effect.description, factor_value)

func _append_effect_lines(content: String, effect_map: Dictionary) -> String:
	for effect_id in effect_map:
		var effect = GameInfo.effects_db.get_effect_by_id(int(effect_id)) if GameInfo and GameInfo.effects_db else null
		if effect:
			var effect_line = _format_effect_line(effect, float(effect_map[effect_id]))
			if effect_line != "":
				content += "\n" + effect_line
	return content

func _on_hover():
	var content = ""
	
	match meta_data.type:
		"perk":
			var perk = meta_data.perk
			content = perk.perk_name
			if perk.effect1_description != "":
				var line1 = EFFECT_FORMATTER.format_with_factor(perk.effect1_description, perk.factor1)
				content += "\n" + line1
			if perk.effect2_description != "":
				var line2 = EFFECT_FORMATTER.format_with_factor(perk.effect2_description, perk.factor2)
				content += "\n" + line2
		
		"blessing":
			var perk = meta_data.perk
			var effect = GameInfo.effects_db.get_effect_by_id(perk.effect1_id)
			content = perk.perk_name
			if effect:
				content += "\n" + _format_effect_line(effect, perk.factor1)
		
		"potion":
			var item = GameInfo.items_db.get_item_by_id(meta_data.id)
			if not item:
				content = "Unknown Potion (ID: " + str(meta_data.id) + ")"
			else:
				content = item.item_name
				# Use the same effect formatting behavior as elixirs.
				var effect_map = {}
				if item.effect_id > 0:
					effect_map[item.effect_id] = float(item.effect_factor)
				content = _append_effect_lines(content, effect_map)
			# Show expiration time if available
			var expire_until = meta_data.get("expire_until", 0.0)
			if expire_until > 0:
				content += "\n" + _format_time_remaining(expire_until)
		
		"elixir":
			content = "Elixir"
			var effect_map = {}

			# Preferred path: direct active elixir effects from server.
			if "elixir_effects" in GameInfo.current_player and GameInfo.current_player.elixir_effects.size() > 0:
				for entry in GameInfo.current_player.elixir_effects:
					var effect_id = int(entry.get("effect_id", 0))
					var factor = float(entry.get("factor", 0.0))
					if effect_id > 0:
						effect_map[effect_id] = effect_map.get(effect_id, 0.0) + factor
			else:
				# Backward compatibility: derive effects from ingredient item IDs.
				for ingredient_id in GameInfo.current_player.elixir_ingredients:
					if ingredient_id > 0:
						var ingredient = GameInfo.items_db.get_item_by_id(ingredient_id)
						if ingredient and ingredient.effect_id > 0:
							effect_map[ingredient.effect_id] = effect_map.get(ingredient.effect_id, 0.0) + ingredient.effect_factor
			
			content = _append_effect_lines(content, effect_map)
			
			# Show expiration time if available
			var expire_until = meta_data.get("expire_until", 0.0)
			if expire_until > 0:
				content += "\n" + _format_time_remaining(expire_until)
		
		"effect":
			var effect = meta_data.effect
			var factor = meta_data.get("factor", 0.0)
			content = effect.name
			if effect.description != "":
				content += "\n" + _format_effect_line(effect, factor)
	
	TooltipManager.show_perk_tooltip(content, self)
