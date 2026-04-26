extends Control

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
	
	# Convert to hours and minutes
	var hours_left = int(seconds_left / 3600)
	var minutes_left = int(float(int(seconds_left) % 3600) / 60.0)
	
	if hours_left >= 24:
		var days_left = int(float(hours_left) / 24.0)
		hours_left = hours_left % 24
		if days_left == 1:
			return "[%dd %dh remaining]" % [days_left, hours_left]
		return "[%dd %dh remaining]" % [days_left, hours_left]
	elif hours_left > 0:
		return "[%dh %dm remaining]" % [hours_left, minutes_left]
	elif minutes_left > 0:
		return "[%dm remaining]" % [minutes_left]
	else:
		return "[< 1m remaining]"

func _on_hover():
	var content = ""
	
	match meta_data.type:
		"perk":
			var perk = meta_data.perk
			content = perk.perk_name
			if perk.effect1_description != "":
				content += "\n" + perk.effect1_description
				if perk.factor1 != 0.0:
					content += " " + str(int(perk.factor1)) + "%"
			if perk.effect2_description != "":
				content += "\n" + perk.effect2_description
				if perk.factor2 != 0.0:
					content += " " + str(int(perk.factor2)) + "%"
		
		"blessing":
			var perk = meta_data.perk
			var effect = GameInfo.effects_db.get_effect_by_id(perk.effect1_id)
			content = perk.perk_name
			if effect:
				content += "\n" + effect.description + " " + str(int(perk.factor1)) + "%"
		
		"potion":
			var item = GameInfo.items_db.get_item_by_id(meta_data.id)
			if not item:
				print("ERROR: Potion item not found in items_db: ", meta_data.id)
				content = "Unknown Potion (ID: " + str(meta_data.id) + ")"
			else:
				content = item.item_name
				print("Potion found: ", item.item_name, " (ID: ", meta_data.id, ")")
				print("  - effect_id: ", item.effect_id, ", effect_factor: ", item.effect_factor)
				# Show effect + factor from item database
				if item.effect_id > 0:
					var effect = GameInfo.effects_db.get_effect_by_id(item.effect_id)
					if effect:
						print("  - Effect found: ", effect.description)
						content += "\n" + effect.description + " " + str(int(item.effect_factor)) + "%"
					else:
						print("  - ERROR: Effect not found in effects_db: ", item.effect_id)
				else:
					print("  - No effect_id on this item")
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
			
			for effect_id in effect_map:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
				if effect:
					var effect_line = effect.description
					var factor_value = int(effect_map[effect_id])
					if "*" in effect_line:
						effect_line = effect_line.replace("*", str(factor_value))
					elif factor_value > 0:
						effect_line += " " + str(factor_value) + "%"
					content += "\n" + effect_line
			
			# Show expiration time if available
			var expire_until = meta_data.get("expire_until", 0.0)
			if expire_until > 0:
				content += "\n" + _format_time_remaining(expire_until)
		
		"effect":
			var effect = meta_data.effect
			var factor = meta_data.get("factor", 0.0)
			content = effect.name
			if effect.description != "":
				content += "\n" + effect.description
				if factor > 0:
					content += " " + str(int(factor)) + "%"
	
	TooltipManager.show_perk_tooltip(content, self)
