extends Panel

@export var perk_mini_scene: PackedScene
@export var avatar_instance: Node  # Reference to avatar.tscn instance
@export var enemy_id: int = 1
var enemy_name: String = "Enemy"
var enemy_rank: int = 0
var enemy_strength: int = 10
var enemy_stamina: int = 10
var enemy_agility: int = 10
var enemy_luck: int = 10
var enemy_armor: int = 0

@export var name_label: Label
@export var rank_label: Label
@export var strength_label: Label
@export var constitution_label: Label
@export var dexterity_label: Label
@export var luck_label: Label
@export var armor_label: Label
@export var active_effects_container: HBoxContainer

var opponent_data = null

func _ready():
	_update_display()

func _update_display():
	name_label.text = enemy_name.to_upper()
	rank_label.text = "Novice (" + str(enemy_rank) + ")"
	strength_label.text = "STR: " + str(enemy_strength)
	constitution_label.text = "STA: " + str(enemy_stamina)
	dexterity_label.text = "AGI: " + str(enemy_agility)
	luck_label.text = "LCK: " + str(enemy_luck)
	armor_label.text = "ARM: " + str(enemy_armor)
	
	_update_active_effects_display()

func set_enemy_data(id: int, enemy_name_text: String, strength: int, stamina: int, agility: int, luck: int, armor: int):
	enemy_id = id
	enemy_name = enemy_name_text
	enemy_strength = strength
	enemy_stamina = stamina
	enemy_agility = agility
	enemy_luck = luck
	enemy_armor = armor
	_update_display()

func set_opponent_data(opponent):
	opponent_data = opponent
	if opponent:
		var total_stats = opponent.get_total_stats()
		enemy_rank = opponent.rank
		set_enemy_data(enemy_id, opponent.name, total_stats.strength, total_stats.stamina, total_stats.agility, total_stats.luck, total_stats.armor)
		
		# Set avatar appearance from opponent data
		if avatar_instance and avatar_instance.has_method("set_avatar_from_ids"):
			avatar_instance.set_avatar_from_ids(
				opponent.avatar_face,
				opponent.avatar_hair,
				opponent.avatar_eyes
			)

func _update_active_effects_display():
	if not active_effects_container:
		print("WARNING: active_effects_container not assigned in ArenaOpponent!")
		return
	if not opponent_data:
		print("WARNING: opponent_data is null in ArenaOpponent!")
		return
	
	print("Updating active effects for: ", opponent_data.name)
	print("  Elixir: ", opponent_data.elixir)
	print("  Potion: ", opponent_data.potion)
	print("  Blessing: ", opponent_data.blessing)
	print("  Active perks: ", opponent_data.get_active_perks().size())
	
	# Clear existing icons
	for child in active_effects_container.get_children():
		child.queue_free()
	
	# Add equipped elixir first if any
	if opponent_data.elixir > 0:
		var elixir_icon_texture = GameInfo.items_db.get_item_by_id(1000)  # Use elixir base icon
		if elixir_icon_texture and elixir_icon_texture.icon:
			create_consumable_display(elixir_icon_texture.icon, "Elixir", opponent_data.elixir)
	
	# Add equipped potion second if any
	if opponent_data.potion > 0:
		var potion_item = GameInfo.items_db.get_item_by_id(opponent_data.potion)
		if potion_item and potion_item.icon:
			create_consumable_display(potion_item.icon, "Potion", opponent_data.potion)
	
	# Add active blessing effect third if any
	if opponent_data.blessing > 0:
		var blessing_effect = GameInfo.effects_db.get_effect_by_id(opponent_data.blessing)
		if blessing_effect:
			create_effect_display(blessing_effect)
	
	# Add active perks
	var active_perks = opponent_data.get_active_perks()
	for perk in active_perks:
		if perk_mini_scene:
			var perk_icon = perk_mini_scene.instantiate()
			perk_icon.set_meta("perk_data", perk)
			
			var texture_rect = perk_icon.get_node("TextureRect")
			if texture_rect and perk.texture:
				texture_rect.texture = perk.texture
			
			perk_icon.mouse_filter = Control.MOUSE_FILTER_PASS
			perk_icon.mouse_entered.connect(_on_perk_hover_start.bind(perk_icon))
			perk_icon.mouse_exited.connect(_on_perk_hover_end)
			
			active_effects_container.add_child(perk_icon)

func create_consumable_display(icon_texture: Texture2D, consumable_type: String, item_id: int):
	if perk_mini_scene:
		var consumable_icon = perk_mini_scene.instantiate()
		consumable_icon.set_meta("consumable_type", consumable_type)
		consumable_icon.set_meta("item_id", item_id)
		
		var texture_rect = consumable_icon.get_node("TextureRect")
		if texture_rect:
			texture_rect.texture = icon_texture
		
		consumable_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		consumable_icon.mouse_entered.connect(_on_consumable_hover_start.bind(consumable_icon))
		consumable_icon.mouse_exited.connect(_on_perk_hover_end)
		
		active_effects_container.add_child(consumable_icon)

func create_effect_display(effect: EffectResource):
	if perk_mini_scene:
		var effect_icon = perk_mini_scene.instantiate()
		effect_icon.set_meta("effect_data", effect)
		
		var texture_rect = effect_icon.get_node("TextureRect")
		if texture_rect and effect.icon:
			texture_rect.texture = effect.icon
		
		effect_icon.mouse_filter = Control.MOUSE_FILTER_PASS
		effect_icon.mouse_entered.connect(_on_effect_hover_start.bind(effect_icon))
		effect_icon.mouse_exited.connect(_on_perk_hover_end)
		
		active_effects_container.add_child(effect_icon)

func _on_perk_hover_start(perk_icon):
	var perk_data = perk_icon.get_meta("perk_data")
	if perk_data:
		var tooltip_text = perk_data.perk_name
		
		if perk_data.effect1_description != "":
			var effect1_text = perk_data.effect1_description
			if perk_data.factor1 != 0.0:
				effect1_text += " " + str(int(perk_data.factor1)) + "%"
			tooltip_text += "\n" + effect1_text
		
		if perk_data.effect2_description != "":
			var effect2_text = perk_data.effect2_description
			if perk_data.factor2 != 0.0:
				effect2_text += " " + str(int(perk_data.factor2)) + "%"
			tooltip_text += "\n" + effect2_text
		
		TooltipManager.show_perk_tooltip(tooltip_text, perk_icon)

func _on_effect_hover_start(effect_icon):
	var effect_data = effect_icon.get_meta("effect_data")
	if effect_data:
		var tooltip_text = effect_data.name
		if effect_data.description != "":
			tooltip_text += "\n" + effect_data.description
		
		TooltipManager.show_perk_tooltip(tooltip_text, effect_icon)

func _on_consumable_hover_start(consumable_icon):
	var consumable_type = consumable_icon.get_meta("consumable_type")
	var item_id = consumable_icon.get_meta("item_id")
	if consumable_type:
		var tooltip_text = ""
		
		if consumable_type == "Elixir":
			tooltip_text = "Elixir"
			var id_str = str(item_id)
			var ingredient1_id = int(id_str.substr(4, 3))
			var ingredient2_id = int(id_str.substr(7, 3))
			var ingredient3_id = int(id_str.substr(10, 3))
			
			var effect_map = {}
			for ingredient_id in [ingredient1_id, ingredient2_id, ingredient3_id]:
				if ingredient_id > 0:
					var ingredient_resource = GameInfo.items_db.get_item_by_id(ingredient_id)
					if ingredient_resource and ingredient_resource.effect_id > 0:
						if effect_map.has(ingredient_resource.effect_id):
							effect_map[ingredient_resource.effect_id] += ingredient_resource.effect_factor
						else:
							effect_map[ingredient_resource.effect_id] = ingredient_resource.effect_factor
			
			for effect_id in effect_map.keys():
				var effect_data = GameInfo.effects_db.get_effect_by_id(effect_id)
				if effect_data:
					var effect_line = effect_data.description
					if effect_map[effect_id] > 0:
						effect_line += " " + str(effect_map[effect_id]) + "%"
					tooltip_text += "\n" + effect_line
			
		elif consumable_type == "Potion":
			var potion_item = GameInfo.items_db.get_item_by_id(item_id)
			if potion_item:
				tooltip_text = potion_item.item_name
				if potion_item.effect_id > 0:
					var effect_data = GameInfo.effects_db.get_effect_by_id(potion_item.effect_id)
					if effect_data:
						var effect_line = effect_data.description
						if potion_item.effect_factor > 0:
							effect_line += " " + str(int(potion_item.effect_factor)) + "%"
						tooltip_text += "\n" + effect_line
		
		TooltipManager.show_perk_tooltip(tooltip_text, consumable_icon)

func _on_perk_hover_end():
	TooltipManager.hide_perk_tooltip()
