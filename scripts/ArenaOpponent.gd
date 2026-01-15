extends Panel

@export var perk_mini_scene: PackedScene
@export var avatar_instance: Node
@export var name_label: Label
@export var rank_label: Label
@export var strength_label: Label
@export var constitution_label: Label
@export var dexterity_label: Label
@export var luck_label: Label
@export var armor_label: Label
@export var active_effects_container: GridContainer
@export var damage_spread_label: Label

var opponent_data: GameInfo.GamePlayer = null

func set_opponent_data(opponent: GameInfo.GamePlayer):
	opponent_data = opponent
	_update_display()
	
	# Set avatar appearance
	avatar_instance.refresh_avatar(
		opponent.avatar_face,
		opponent.avatar_hair,
		opponent.avatar_eyes,
		opponent.avatar_nose,
		opponent.avatar_mouth
	)

func _update_display():
	if not opponent_data:
		return
	
	var total_stats = opponent_data.get_total_stats()
	var damage = opponent_data.get_damage_range()
	
	name_label.text = opponent_data.name.to_upper()
	rank_label.text = opponent_data.get_rank_name() + " (" + str(opponent_data.rank) + ")"
	strength_label.text = "Strength: " + str(total_stats.strength)
	constitution_label.text = "Stamina: " + str(total_stats.stamina)
	dexterity_label.text = "Agility: " + str(total_stats.agility)
	luck_label.text = "Luck: " + str(total_stats.luck)
	armor_label.text = "Armor: " + str(total_stats.armor)
	damage_spread_label.text = str(damage.min) + " - " + str(damage.max)
	
	_update_active_effects()

func _update_active_effects():
	# Clear existing icons
	for child in active_effects_container.get_children():
		child.queue_free()
	
	# Elixir
	if opponent_data.elixir > 0:
		var elixir_res = GameInfo.items_db.get_item_by_id(1000)
		_create_icon(elixir_res.icon, {"type": "elixir", "id": opponent_data.elixir})
	
	# Potion
	if opponent_data.potion > 0:
		var potion_res = GameInfo.items_db.get_item_by_id(opponent_data.potion)
		_create_icon(potion_res.icon, {"type": "potion", "id": opponent_data.potion})
	
	# Blessing
	if opponent_data.blessing > 0:
		var blessing_perk = GameInfo.perks_db.get_perk_by_id(opponent_data.blessing)
		_create_icon(blessing_perk.icon, {"type": "blessing", "perk": blessing_perk})
	
	# Active perks
	for perk in opponent_data.get_active_perks():
		_create_icon(perk.texture, {"type": "perk", "perk": perk})

func _create_icon(texture: Texture2D, meta: Dictionary):
	var icon = perk_mini_scene.instantiate()
	icon.get_node("TextureRect").texture = texture
	icon.set_meta("data", meta)
	icon.mouse_filter = Control.MOUSE_FILTER_PASS
	icon.mouse_entered.connect(_on_icon_hover.bind(icon))
	icon.mouse_exited.connect(TooltipManager.hide_perk_tooltip)
	active_effects_container.add_child(icon)

func _on_icon_hover(icon: Control):
	var data = icon.get_meta("data")
	var content = ""
	
	match data.type:
		"perk":
			var perk = data.perk
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
			var perk = data.perk
			var effect = GameInfo.effects_db.get_effect_by_id(perk.effect1_id)
			content = perk.perk_name
			if effect:
				content += "\n" + effect.description + " " + str(int(perk.factor1)) + "%"
		
		"potion":
			var item = GameInfo.items_db.get_item_by_id(data.id)
			content = item.item_name
			if item.effect_id > 0:
				var effect = GameInfo.effects_db.get_effect_by_id(item.effect_id)
				content += "\n" + effect.description + " " + str(int(item.effect_factor)) + "%"
		
		"elixir":
			content = "Elixir"
			var id_str = str(data.id)
			var effect_map = {}
			for i in [4, 7, 10]:
				var ingredient_id = int(id_str.substr(i, 3))
				if ingredient_id > 0:
					var ingredient = GameInfo.items_db.get_item_by_id(ingredient_id)
					if ingredient and ingredient.effect_id > 0:
						effect_map[ingredient.effect_id] = effect_map.get(ingredient.effect_id, 0.0) + ingredient.effect_factor
			
			for effect_id in effect_map:
				var effect = GameInfo.effects_db.get_effect_by_id(effect_id)
				content += "\n" + effect.description + " " + str(effect_map[effect_id]) + "%"
	
	TooltipManager.show_perk_tooltip(content, icon)
