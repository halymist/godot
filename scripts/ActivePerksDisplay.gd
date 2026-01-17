extends HBoxContainer

@export var perk_mini_scene: PackedScene

func _ready():
	# Initialize if character is already selected
	if GameInfo.current_player:
		refresh_effects()

func refresh_effects():
	print("ActivePerksDisplay: Updating active perks and effects...")
	
	if not GameInfo.current_player:
		print("ActivePerksDisplay: No character selected yet")
		return
	
	# Clear existing icons
	for child in get_children():
		child.queue_free()
	
	# Add equipped elixir first if any
	if GameInfo.current_player and GameInfo.current_player.elixir > 0:
		var elixir_icon_texture = GameInfo.items_db.get_item_by_id(1000)  # Use elixir base icon
		if elixir_icon_texture and elixir_icon_texture.icon:
			create_consumable_display(elixir_icon_texture.icon, "Elixir", GameInfo.current_player.elixir)
	
	# Add equipped potion second if any
	if GameInfo.current_player and GameInfo.current_player.potion > 0:
		var potion_item = GameInfo.items_db.get_item_by_id(GameInfo.current_player.potion)
		if potion_item and potion_item.icon:
			create_consumable_display(potion_item.icon, "Potion", GameInfo.current_player.potion)
	
	# Add active blessing effect third if any
	if GameInfo.current_player and GameInfo.current_player.blessing > 0:
		var blessing_perk = GameInfo.perks_db.get_perk_by_id(GameInfo.current_player.blessing) if GameInfo.perks_db else null
		if blessing_perk:
			# Get the effect referenced by the blessing perk
			var blessing_effect = GameInfo.effects_db.get_effect_by_id(blessing_perk.effect1_id) if GameInfo.effects_db else null
			if blessing_effect:
				create_blessing_display(blessing_perk, blessing_effect)
	
	# Get active perks from GameInfo
	var active_perks = get_active_perks()
	
	# Create icon for each active perk
	for perk in active_perks:
		if perk_mini_scene:
			var perk_icon = perk_mini_scene.instantiate()
			perk_icon.setup(perk.texture, {"type": "perk", "perk": perk})
			add_child(perk_icon)

func create_consumable_display(icon_texture: Texture2D, consumable_type: String, item_id: int):
	if perk_mini_scene:
		var consumable_icon = perk_mini_scene.instantiate()
		var type_key = consumable_type.to_lower()
		consumable_icon.setup(icon_texture, {"type": type_key, "id": item_id})
		add_child(consumable_icon)

func create_blessing_display(perk: PerkResource, _effect: EffectResource):
	if perk_mini_scene:
		var blessing_icon = perk_mini_scene.instantiate()
		blessing_icon.setup(perk.icon, {"type": "blessing", "perk": perk})
		add_child(blessing_icon)

func create_effect_display(effect: EffectResource, factor: float = 0.0):
	if perk_mini_scene:
		var effect_icon = perk_mini_scene.instantiate()
		effect_icon.setup(effect.icon, {"type": "effect", "effect": effect, "factor": factor})
		add_child(effect_icon)

func get_active_perks() -> Array:
	return GameInfo.current_player.get_active_perks() if GameInfo.current_player else []
