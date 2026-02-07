extends Control
class_name CharacterDisplay

enum DisplayMode { PLAYER, ENEMY }

@export var display_mode: DisplayMode = DisplayMode.PLAYER

# Button references (only used in PLAYER mode)
@export var talents_button: Button
@export var details_button: Button
@export var avatar_button: Button

# Stats display references
@export var player_name_label: Label
@export var rank_label: Label
@export var faction_label: Label
@export var strength_label: Label
@export var stamina_label: Label
@export var agility_label: Label
@export var luck_label: Label
@export var armor_label: Label
@export var health_bar: TextureProgressBar
@export var damage_spread_label: Label

# Active perks display
@export var active_perks_display: HBoxContainer
@export var perk_mini_scene: PackedScene

# Equipment display
@export var equipment_slots: Array[Control]  # The 9 equipment InventorySlot nodes (0-8)
@export var item_prefab: PackedScene

# Currently displayed character (either player or enemy)
var displayed_character: GameInfo.GamePlayer = null

func _ready():
	# Always connect buttons
	details_button.pressed.connect(_on_details_pressed)
	talents_button.pressed.connect(_on_talents_pressed)
	
	if display_mode == DisplayMode.PLAYER:
		avatar_button.pressed.connect(_on_avatar_pressed)
		# Wait for game_ready before displaying player
		print("CharacterDisplay: _ready() called")
		if UIManager.instance:
			# Check if game is already ready
			if UIManager.instance.game_is_ready:
				print("CharacterDisplay: Game already ready, calling setup immediately")
				call_deferred("_setup")
			else:
				print("CharacterDisplay: Connecting to game_ready signal")
				UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)
		else:
			print("CharacterDisplay: ERROR - UIManager.instance is null!")
			call_deferred("_setup")
	else:
		avatar_button.visible = false

func _setup():
	# Ensure perk data is refreshed from databases before display
	GameInfo.refresh_all_perks()
	if GameInfo.current_player:
		display_player()
	print("CharacterDisplay: Setup complete")

func display_player():
	"""Display the current player"""
	displayed_character = GameInfo.current_player
	refresh_display()

func display_enemy(enemy_name: String):
	"""Display an enemy by name from GameInfo.enemy_players"""
	for enemy in GameInfo.enemy_players:
		if enemy.name == enemy_name:
			displayed_character = enemy
			refresh_display()
			return

func refresh_display():
	"""Refresh all stats and effects for the displayed character"""
	update_stats()
	refresh_active_effects()
	update_equipment()

# Called when character is selected or changed
func _on_character_changed():
	if display_mode == DisplayMode.PLAYER:
		display_player()

# Called when GameInfo current player is updated (for PLAYER mode only, called by UIManager)
func stats_changed(_stats: Dictionary):
	display_player()

func update_stats():
	"""Update stat labels for the displayed character"""
	var total_stats = displayed_character.get_total_stats()
	
	player_name_label.text = total_stats.name
	rank_label.text = displayed_character.get_rank_name() + " (" + str(displayed_character.rank) + ")"
	faction_label.text = displayed_character.get_faction_name()
	strength_label.text = str(total_stats.strength)
	stamina_label.text = str(total_stats.stamina)
	agility_label.text = str(total_stats.agility)
	luck_label.text = str(total_stats.luck)
	armor_label.text = str(total_stats.armor)
	
	# Health bar (stamina * 10)
	var max_health = total_stats.stamina * 10
	health_bar.max_value = max_health
	
	# For current player, show depleted health (max - depleted) / max
	if display_mode == DisplayMode.PLAYER and displayed_character == GameInfo.current_player:
		var depleted = displayed_character.depleted_health
		var current_health = max_health - depleted
		health_bar.value = current_health
		if health_bar.has_node("HealthLabel"):
			health_bar.get_node("HealthLabel").text = str(current_health) + " / " + str(max_health)
	else:
		health_bar.value = max_health
		if health_bar.has_node("HealthLabel"):
			health_bar.get_node("HealthLabel").text = str(max_health)
	
	# Damage spread - calculate from total stats (base + equipment) multiplied by strength
	var damage = displayed_character.get_damage_range()
	damage_spread_label.text = str(int(damage.min)) + " - " + str(int(damage.max))

func refresh_active_effects():
	"""Refresh active effects display (blessings, potions, elixirs, perks)"""
	for child in active_perks_display.get_children():
		child.queue_free()
	
	# Add equipped elixir first if any
	if displayed_character.elixir > 0:
		var elixir_res = GameInfo.items_db.get_item_by_id(1000)
		var icon = perk_mini_scene.instantiate()
		var elixir_until = displayed_character.elixir_until if "elixir_until" in displayed_character else 0.0
		icon.setup(elixir_res.icon, {"type": "elixir", "id": displayed_character.elixir, "expire_until": elixir_until})
		active_perks_display.add_child(icon)
	
	# Add equipped potion second if any
	if displayed_character.potion > 0:
		var potion_res = GameInfo.items_db.get_item_by_id(displayed_character.potion)
		var icon = perk_mini_scene.instantiate()
		var potion_until = displayed_character.potion_until if "potion_until" in displayed_character else 0.0
		icon.setup(potion_res.icon, {"type": "potion", "id": displayed_character.potion, "expire_until": potion_until})
		active_perks_display.add_child(icon)
	
	# Add active blessing effect third if any
	if displayed_character.blessing > 0:
		var blessing_perk = GameInfo.perks_db.get_perk_by_id(displayed_character.blessing)
		if blessing_perk:
			var effect = GameInfo.effects_db.get_effect_by_id(blessing_perk.effect1_id)
			if effect:
				var icon = perk_mini_scene.instantiate()
				icon.setup(blessing_perk.icon, {"type": "blessing", "perk": blessing_perk})
				active_perks_display.add_child(icon)
	
	# Get active perks from GameInfo
	var active_perks = displayed_character.get_active_perks()
	
	# Create icon for each active perk
	for perk in active_perks:
		var icon = perk_mini_scene.instantiate()
		icon.setup(perk.texture, {"type": "perk", "perk": perk})
		active_perks_display.add_child(icon)
	
	# Refresh stats after updating effects (only for player mode)
	if display_mode == DisplayMode.PLAYER:
		update_stats()

func _on_talents_pressed():
	if display_mode == DisplayMode.PLAYER:
		# Show player talents (editable)
		UIManager.instance.show_talents_panel(GameInfo.current_player, false)
	else:  # ENEMY mode
		# Show enemy talents (read-only)
		if displayed_character:
			UIManager.instance.show_talents_panel(displayed_character, true)

func _on_details_pressed():
	if display_mode == DisplayMode.PLAYER:
		# Show details for current player
		UIManager.instance.show_details_panel(GameInfo.current_player)
	else:  # ENEMY mode
		# Show details for displayed enemy
		if displayed_character:
			UIManager.instance.show_details_panel(displayed_character)

func _on_avatar_pressed():
	UIManager.instance.toggle_avatar_overlay()

func update_equipment():
	"""Update equipment slots from displayed character's bag_slots (equipment: 1-9)"""
	# Clear all equipment slots
	for slot in equipment_slots:
		slot.clear_slot()
	
	# Display items from bag_slots (1-9 are equipment)
	for item in displayed_character.bag_slots:
		var bag_slot_id = item.bag_slot_id
		# Server sends slot_id 1-9, array is indexed 0-8
		if bag_slot_id >= 1 and bag_slot_id <= 9:
			var array_index = bag_slot_id - 1
			if array_index < equipment_slots.size():
				var icon = item_prefab.instantiate()
				icon.set_item_data(item)
				
				if display_mode == DisplayMode.ENEMY:
					icon.disable_dragging()
				
				equipment_slots[array_index].add_child(icon)
	
	# Update slot appearances
	for slot in equipment_slots:
		slot.update_slot_appearance()
