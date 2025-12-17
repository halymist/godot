extends TextureRect
# Store the complete item data
var description_panel: PanelContainer 
var item_data: GameInfo.Item = null

# Double-click detection
var last_click_time: float = 0.0
const DOUBLE_CLICK_TIME: float = 0.3  # 300ms window for double-click

func _ready():
	# Find ItemDescription dynamically since it moves between Portrait/Wide
	var game_root = get_tree().root.get_node_or_null("Game")
	if game_root:
		description_panel = game_root.find_child("ItemDescription", true, false)
	
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))
	connect("gui_input", Callable(self, "_on_gui_input"))
	if description_panel:
		description_panel.visible = false


func _on_mouse_entered():
	if item_data and description_panel:
		var mouse_pos = get_global_mouse_position()
		description_panel.show_description(item_data, mouse_pos)

func _on_mouse_exited():
	if description_panel:
		description_panel.hide_description()

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_click_time < DOUBLE_CLICK_TIME:
			# Double-click detected
			_handle_double_click()
			last_click_time = 0.0  # Reset to prevent triple-click
		else:
			last_click_time = current_time

func _handle_double_click():
	if not item_data:
		return
	
	# Check if item is a consumable (Potion or Elixir) in bag - consume it
	if (item_data.type == "Potion" or item_data.type == "Elixir") and item_data.bag_slot_id >= 10 and item_data.bag_slot_id <= 14:
		_consume_item()
		return
	
	# Get current utility panel from TogglePanel (unified tracking)
	var game_root = get_tree().root.get_node_or_null("Game")
	var toggle_panel = game_root.find_child("Background", true, false) if game_root else null
	var current_utility = toggle_panel.current_utility_panel if toggle_panel else null
	
	# Blacksmith: Move equippable items (not ingredients/consumables) to slot 100
	if current_utility and current_utility.name == "BlacksmithPanel":
		# Check if item can be tempered (not ingredient or consumable)
		if item_data.type != "Ingredient" and item_data.type != "Consumable":
			# Check if item is in bag (10-14)
			if item_data.bag_slot_id >= 10 and item_data.bag_slot_id <= 14:
				# Check if slot 100 is empty
				var slot_100_empty = true
				for item in GameInfo.current_player.bag_slots:
					if item.bag_slot_id == 100:
						slot_100_empty = false
						break
				
				if slot_100_empty:
					item_data.bag_slot_id = 100
					GameInfo.bag_slots_changed.emit()
		return
	
	# Enchanter: Move equippable items (not ingredients/consumables/elixirs/potions) to slot 104
	if current_utility and current_utility.name == "EnchanterPanel":
		# Check if item can be enchanted
		if item_data.type != "Ingredient" and item_data.type != "Consumable" and item_data.type != "Elixir" and item_data.type != "Potion":
			# Check if item is in bag (10-14)
			if item_data.bag_slot_id >= 10 and item_data.bag_slot_id <= 14:
				# Check if slot 104 is empty
				var slot_104_empty = true
				for item in GameInfo.current_player.bag_slots:
					if item.bag_slot_id == 104:
						slot_104_empty = false
						break
				
				if slot_104_empty:
					item_data.bag_slot_id = 104
					GameInfo.bag_slots_changed.emit()
		return
	
	# Alchemist: Move ingredients to slots 101-103
	if current_utility and current_utility.name == "AlchemistPanel":
		# Check if item is an ingredient
		if item_data.type == "Ingredient" and item_data.bag_slot_id >= 10 and item_data.bag_slot_id <= 14:
			# Find first empty ingredient slot (101-103)
			for slot_id in [101, 102, 103]:
				var slot_empty = true
				for item in GameInfo.current_player.bag_slots:
					if item.bag_slot_id == slot_id:
						slot_empty = false
						break
				
				if slot_empty:
					item_data.bag_slot_id = slot_id
					GameInfo.bag_slots_changed.emit()
					break
		return
	
	# Vendor: Sell if in bag, buy if in vendor slots
	if current_utility and current_utility.name == "VendorPanel":
		# Selling: item in bag (10-14)
		if item_data.bag_slot_id >= 10 and item_data.bag_slot_id <= 14:
			# Sell item for its price
			if item_data.price > 0:
				GameInfo.current_player.gold += item_data.price
				GameInfo.current_player.bag_slots.erase(item_data)
				GameInfo.bag_slots_changed.emit()
				GameInfo.gold_changed.emit(GameInfo.current_player.gold)
		
		# Buying: item in vendor slots (105-112)
		elif item_data.bag_slot_id >= 105 and item_data.bag_slot_id <= 112:
			var buy_price = item_data.price * 2
			if GameInfo.current_player.gold >= buy_price:
				# Find first empty bag slot
				for bag_slot_id in range(10, 15):
					var slot_empty = true
					for item in GameInfo.current_player.bag_slots:
						if item.bag_slot_id == bag_slot_id:
							slot_empty = false
							break
					
					if slot_empty:
						GameInfo.current_player.gold -= buy_price
						# Create a copy of the item in the bag
						var new_item = GameInfo.Item.new()
						new_item.id = item_data.id
						new_item.bag_slot_id = bag_slot_id
						new_item.item_name = item_data.item_name
						new_item.type = item_data.type
						new_item.armor = item_data.armor
						new_item.strength = item_data.strength
						new_item.stamina = item_data.stamina
						new_item.agility = item_data.agility
						new_item.luck = item_data.luck
						new_item.damage_min = item_data.damage_min
						new_item.damage_max = item_data.damage_max
						new_item.asset_id = item_data.asset_id
						new_item.effect_id = item_data.effect_id
						new_item.effect_factor = item_data.effect_factor
						new_item.quality = item_data.quality
						new_item.price = item_data.price
						new_item.tempered = item_data.tempered
						new_item.enchant_overdrive = item_data.enchant_overdrive
						new_item.day = item_data.day
						new_item.texture = item_data.texture
						GameInfo.current_player.bag_slots.append(new_item)
						GameInfo.bag_slots_changed.emit()
						GameInfo.gold_changed.emit(GameInfo.current_player.gold)
						break
		return
	
	# Character panel equip/unequip (fallback - only if no utility panel is active)
	var current_panel = GameInfo.get_current_panel()
	if current_panel and current_panel.name == "Character":
		# If item is equipped (0-8), move it to bag
		if item_data.bag_slot_id >= 0 and item_data.bag_slot_id <= 8:
			_unequip_item_to_bag()
			return
		# If item is in bag (10-14), equip it
		elif item_data.bag_slot_id >= 10 and item_data.bag_slot_id <= 14:
			if _can_equip_to_character():
				_equip_item_to_character()
				return



func set_item_data(data: GameInfo.Item):
	item_data = data
	if data:
		texture = data.texture

func _get_drag_data(_at_position):
	if not item_data:
		return null
			
	# Create a preview for dragging
	var preview_texture = TextureRect.new()
	preview_texture.texture = texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.size = size
	preview_texture.position = -size / 2

	var preview = Control.new()
	preview.add_child(preview_texture)
	# Set high z-index so drag preview appears above all panels
	preview.z_index = 1000
	set_drag_preview(preview)

	# Create a drag data package with item and source reference
	var drag_package = {
		"item": item_data,
		"source_container": get_parent()
	}
	modulate.a = 0
	return drag_package

# Add this method to handle failed drops
func _notification(what):
	if what == NOTIFICATION_DRAG_END:
		# Restore full opacity - drag ended
		modulate.a = 1.0

func get_item_data() -> GameInfo.Item:
	return item_data

func _consume_item():
	"""Consume a potion or elixir and apply its effects"""
	if item_data.type == "Potion":
		# Store potion item ID
		GameInfo.current_player.potion = item_data.id
		# Remove from bag
		for i in range(GameInfo.current_player.bag_slots.size()):
			var slot = GameInfo.current_player.bag_slots[i]
			if slot.id == item_data.id and slot.bag_slot_id == item_data.bag_slot_id:
				GameInfo.current_player.bag_slots.remove_at(i)
				break
		
	elif item_data.type == "Elixir":
		# Store elixir item ID
		GameInfo.current_player.elixir = item_data.id
		# Remove from bag
		for i in range(GameInfo.current_player.bag_slots.size()):
			var slot = GameInfo.current_player.bag_slots[i]
			if slot.id == item_data.id and slot.bag_slot_id == item_data.bag_slot_id:
				GameInfo.current_player.bag_slots.remove_at(i)
				break
	
	# Update active perks display to show new consumable
	var game_root = get_tree().root.get_node_or_null("Game")
	var active_perks_display = game_root.find_child("ActivePerks", true, false) if game_root else null
	if active_perks_display:
		active_perks_display.update_active_perks()
	
	GameInfo.emit_signal.call_deferred("bag_slots_changed")

func _can_equip_to_character() -> bool:
	"""Check if item can be equipped to character"""
	return item_data.type in ["Head", "Chest", "Hands", "Foot", "Belt", "Legs", "Ring", "Amulet", "Weapon"]

func _equip_item_to_character():
	"""Equip item from bag to character equipment slot"""
	var target_slot_id = -1
	
	# Map item type to equipment slot
	match item_data.type:
		"Head": target_slot_id = 0
		"Chest": target_slot_id = 1
		"Hands": target_slot_id = 2
		"Foot": target_slot_id = 3
		"Belt": target_slot_id = 4
		"Legs": target_slot_id = 5
		"Ring": target_slot_id = 6
		"Amulet": target_slot_id = 7
		"Weapon": target_slot_id = 8
	
	if target_slot_id == -1:
		return  # Item type can't be equipped
	
	# Check if there's already an item in the target slot
	var existing_item = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == target_slot_id:
			existing_item = item
			break
	
	# If there's an existing item, make sure it's the correct type for the source bag slot
	# We can always swap to bag since bag accepts everything
	if existing_item:
		# The existing item must be equippable to be in an equipment slot
		# So any swap to bag is valid - no extra validation needed
		pass
	
	# Swap items
	var source_slot = item_data.bag_slot_id
	item_data.bag_slot_id = target_slot_id
	
	if existing_item:
		# Move existing equipped item to the bag slot
		existing_item.bag_slot_id = source_slot
	
	GameInfo.emit_signal.call_deferred("bag_slots_changed")

func _unequip_item_to_bag():
	"""Move equipped item to first available bag slot"""
	# Find first empty bag slot
	for bag_slot_id in range(10, 15):
		var slot_empty = true
		for item in GameInfo.current_player.bag_slots:
			if item.bag_slot_id == bag_slot_id:
				slot_empty = false
				break
		
		if slot_empty:
			item_data.bag_slot_id = bag_slot_id
			GameInfo.emit_signal.call_deferred("bag_slots_changed")
			return
