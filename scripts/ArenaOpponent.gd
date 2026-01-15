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
	icon.setup(texture, meta)
	active_effects_container.add_child(icon)
