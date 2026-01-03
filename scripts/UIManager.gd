extends Node
class_name UIManager

static var instance: UIManager

@export var portrait_ui: Control
@export var wide_ui: Control


# Reference to all silver/gold display labels
@export var silver_labels: Array[Label] = []
@export var mushrooms_labels: Array[Label] = []
@export var bag_views: Array[Node] = []
@export var stats_panel: Control
@export var active_effects: Node
@export var avatars: Array[Node] = []

# Reference to resolution manager (Game node)
@export var resolution_manager: Node

@export var blacksmith: Panel
@export var alchemist: Panel
@export var enchanter: Panel
@export var vendor: Panel
@export var trainer: Panel
@export var church: Panel
@export var perk_screen: Control
@export var upgrade_talent: Control
@export var combat: Node

# Signal for utility slot changes (100-104)
signal utility_slot_changed(slot_id: int)

func _ready():
	instance = self
	# Initial update
	update_display()

func update_silver(amount: int):
	"""Add or subtract silver and update all displays"""
	print("UIManager.update_silver called with amount: ", amount)
	print("Current silver before: ", GameInfo.current_player.silver)
	GameInfo.current_player.silver += amount
	print("Current silver after: ", GameInfo.current_player.silver)
	update_display()

func update_mushrooms(amount: int):
	"""Add or subtract mushrooms and update all displays"""
	print("UIManager.update_mushrooms called with amount: ", amount)
	print("Current mushrooms before: ", GameInfo.current_player.mushrooms)
	GameInfo.current_player.mushrooms += amount
	print("Current mushrooms after: ", GameInfo.current_player.mushrooms)
	update_display()

func update_display():
	"""Refresh all silver label displays"""
	print("UIManager.update_display called, silver_labels count: ", silver_labels.size())
	var silver_text = str(GameInfo.current_player.silver)
	for label in silver_labels:
		if label:
			print("Updating label to: ", silver_text)
			label.text = silver_text
		else:
			print("Warning: null label in silver_labels array")

	# Refresh mushrooms label displays
	print("UIManager.update_display mushrooms_labels count: ", mushrooms_labels.size())
	var mushrooms_text = str(GameInfo.current_player.mushrooms)
	for m_label in mushrooms_labels:
		m_label.text = mushrooms_text

func refresh_bags():
	"""Ask all registered bag views to refresh from GameInfo state"""
	print("UIManager.refresh_bags bag_views count: ", bag_views.size())
	for view in bag_views:
		view.update_equip_slots()

func refresh_stats():
	"""Ask all registered stats panels to recalculate stats"""
	stats_panel.stats_changed(GameInfo.get_player_stats())

func refresh_active_effects():
	"""Refresh active effects display (blessings, potions, elixirs)"""
	active_effects.refresh_effects()
	refresh_stats()  # Blessings may affect stats

func refresh_perks():
	"""Refresh perks grid when new perks are added"""
	if perk_screen and perk_screen.has_method("refresh_perks"):
		perk_screen.refresh_perks()

func refresh_avatars():
	"""Update all avatar displays with current player data"""
	print("UIManager.refresh_avatars avatars count: ", avatars.size())
	if not GameInfo.current_player:
		return
	
	for avatar in avatars:
		avatar.refresh_avatar(
			GameInfo.current_player.avatar_face,
			GameInfo.current_player.avatar_hair,
			GameInfo.current_player.avatar_eyes,
			GameInfo.current_player.avatar_nose,
			GameInfo.current_player.avatar_mouth
		)
		
func notify_slot_changed(slot_id: int):
	"""Notify panels when a utility slot (100-104) changes"""
	utility_slot_changed.emit(slot_id)
