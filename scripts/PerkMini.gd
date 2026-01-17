extends Control

@export var icon_texture: TextureRect

var meta_data: Dictionary

func setup(texture: Texture2D, data: Dictionary):
	icon_texture.texture = texture
	meta_data = data
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(TooltipManager.hide_perk_tooltip)

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
			content = item.item_name
			if item.effect_id > 0:
				var effect = GameInfo.effects_db.get_effect_by_id(item.effect_id)
				content += "\n" + effect.description + " " + str(int(item.effect_factor)) + "%"
		
		"elixir":
			content = "Elixir"
			var effect_map = {}
			for ingredient_id in GameInfo.current_player.elixir_ingredients:
				if ingredient_id > 0:
					var ingredient = GameInfo.items_db.get_item_by_id(ingredient_id)
					if ingredient and ingredient.effect_id > 0:
						effect_map[ingredient.effect_id] = effect_map.get(ingredient.effect_id, 0.0) + ingredient.effect_factor
			
			for effect_id in effect_map:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
				content += "\n" + effect.description + " " + str(effect_map[effect_id]) + "%"
		
		"effect":
			var effect = meta_data.effect
			var factor = meta_data.get("factor", 0.0)
			content = effect.name
			if effect.description != "":
				content += "\n" + effect.description
				if factor > 0:
					content += " " + str(int(factor)) + "%"
	
	TooltipManager.show_perk_tooltip(content, self)
