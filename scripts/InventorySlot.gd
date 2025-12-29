# SlotContainer.gd - Attach to the slot Control (root level)
extends Control

@export var item_scene: PackedScene
@export var outline_texture: Texture2D  # Outline texture for equipment slots (bag slots leave empty)
@onready var slot_background = get_node_or_null("Background")
@onready var item_outline = get_node_or_null("Outline")

@export var slot_type: String = "Bag" # "Head", "Weapon", "Bag", etc.
@export var slot_id: int

func _ready():
	# Override cursor to always be arrow (no forbidden cursor during drag)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	# Set outline texture if provided (equipment slots only)
	if outline_texture and item_outline:
		item_outline.texture = outline_texture
	
	update_slot_appearance()

func _can_drop_data(_pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("item") and data["item"] is GameInfo.Item):
		return false
	
	var item = data["item"]
	var item_type = item.type
	var source_container = data.get("source_container")
	var source_slot_id = source_container.slot_id if source_container else -1
	
	print("DEBUG _can_drop_data: Target slot_id=", slot_id, " slot_type=", slot_type, " | Source slot_id=", source_slot_id, " | Dragged item type=", item_type)
	
	# Vendor slots (105-112) accept drops from bag (10-14) for selling
	if slot_id >= 105 and slot_id <= 112:
		# Only accept items from bag slots (10-14) for selling
		return source_slot_id >= 10 and source_slot_id <= 14
	
	# Cannot drag between vendor slots
	if source_slot_id >= 105 and source_slot_id <= 112 and slot_id >= 105 and slot_id <= 112:
		return false
	
	# Special case: Allow gems to be dropped on equipment slots (0-8) if item has a socket
	if item_type == "Gem" and slot_id >= 0 and slot_id <= 8:
		if not is_slot_empty():
			var target_item = get_item_data()
			if target_item and target_item.has_socket and target_item.socketed_gem_id == -1:
				# Item has an empty socket, allow the drop
				return true
		# If slot is empty or item doesn't have a socket, reject
		return false
	
	# Check if dragged item can go into this slot
	if not is_valid_item_for_slot(item_type):
		return false
	
	# If slot is empty, we're good
	if is_slot_empty():
		print("DEBUG: Target slot is empty, allowing drop")
		return true
	
	# If slot has an item, check if that item can go back to source
	var existing_item_data = get_item_data()
	print("DEBUG: Target slot has item, existing_item_data = ", existing_item_data)
	if not existing_item_data:
		print("DEBUG: No existing item data found, allowing drop")
		return true
		
	var existing_item_type = existing_item_data.type
	print("DEBUG: Existing item type = ", existing_item_type)
	
	# Special case: Don't allow swapping equipment items of different types
	# Equipment slots are 0-8, and each has a specific type requirement
	if slot_id >= 0 and slot_id <= 8 and source_slot_id >= 0 and source_slot_id <= 8:
		# Both are equipment slots - only allow swap if same type
		if item_type != existing_item_type:
			return false
	
	# Also check when swapping between equipment and bag
	# If source is equipment (0-8) and target has an item, types must match
	if source_slot_id >= 0 and source_slot_id <= 8:
		# Source is equipment slot - the item types must match for a swap
		print("DEBUG: Equipment->bag swap check. Source slot: ", source_slot_id, " Target slot: ", slot_id)
		print("DEBUG: Dragged item type: ", item_type, " Existing item type: ", existing_item_type)
		
		# Get the required type for the source equipment slot
		var required_type = ""
		match source_slot_id:
			0: required_type = "Head"
			1: required_type = "Chest"
			2: required_type = "Hands"
			3: required_type = "Foot"
			4: required_type = "Belt"
			5: required_type = "Legs"
			6: required_type = "Ring"
			7: required_type = "Amulet"
			8: required_type = "Weapon"
		
		# Both items must match the equipment slot's required type
		if item_type != required_type or existing_item_type != required_type:
			print("DEBUG: REJECTING - Types don't match required type: ", required_type)
			return false
		print("DEBUG: ALLOWING - Both items match required type: ", required_type)
	
	# For all other swaps (bag to bag, utility slots, etc.), check if existing item can go to source
	if source_container and source_container.has_method("is_valid_item_for_slot"):
		return source_container.is_valid_item_for_slot(existing_item_type)
	
	# If we can't validate the reverse swap, don't allow it
	return false

func _drop_data(_pos, data):
	# Extract item and source container from drag package
	var dragged_item = data["item"]
	var source_container = data["source_container"]
	var source_slot_id = source_container.slot_id if source_container else -1
	
	# Special case: Purchasing from vendor (slots 105-112)
	if source_slot_id >= 105 and source_slot_id <= 112:
		handle_vendor_purchase(dragged_item, source_slot_id)
		return
	
	# Special case: Selling to vendor (slot 113 OR vendor display slots 105-112)
	if slot_id == 113 or (slot_id >= 105 and slot_id <= 112):
		handle_vendor_sell(dragged_item, source_slot_id, source_container)
		return
	
	# Special case: Consuming potion/elixir on avatar (slot 999)
	if slot_id == 999:
		if dragged_item.type == "Potion" or dragged_item.type == "Elixir":
			_consume_item(dragged_item)
			if source_container:
				source_container.clear_slot()
		return
	
	# Special case: Socketing a gem into an item
	if dragged_item.type == "Gem" and not is_slot_empty():
		var target_item = get_item_data()
		if target_item and target_item.has_socket and target_item.socketed_gem_id == -1:
			# Socket the gem into the item
			handle_gem_socketing(dragged_item, target_item, source_slot_id, source_container)
			return
	
	# Update GameInfo directly based on the operation
	if not is_slot_empty():
		# Swapping items
		var existing_item = get_item_data()
		
		# Find the actual item instances in GameInfo.bag_slots by their current bag_slot_id
		# This is more reliable than matching by id (which can have duplicates)
		var dragged_item_in_array = null
		var existing_item_in_array = null
		
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.bag_slot_id == source_slot_id and dragged_item_in_array == null:
				# This is the item being dragged from source
				dragged_item_in_array = game_item
			elif game_item.bag_slot_id == slot_id and existing_item_in_array == null:
				# This is the item currently in this slot
				existing_item_in_array = game_item
		
		# Swap their bag_slot_ids
		if dragged_item_in_array:
			dragged_item_in_array.bag_slot_id = slot_id
		if existing_item_in_array:
			existing_item_in_array.bag_slot_id = source_slot_id

		place_item_in_slot(dragged_item)
		if source_container:
			source_container.place_item_in_slot(existing_item)
	else:
		# Moving to empty slot
		# Find the item by its current slot_id
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.bag_slot_id == source_slot_id:
				game_item.bag_slot_id = slot_id
				break
				
		place_item_in_slot(dragged_item)
		if source_container:
			source_container.clear_slot()

	print("Updated GameInfo: item moved to slot ", slot_id)
	if UIManager.instance:
		UIManager.instance.refresh_bags()
		# Refresh stats if equipment slots (0-8) are involved
		if slot_id <= 8 or source_slot_id <= 8:
			UIManager.instance.refresh_stats()
			UIManager.instance.refresh_stats()

func handle_vendor_purchase(vendor_item: GameInfo.Item, _vendor_slot_id: int):
	# Vendor items cost 2x their base price
	var purchase_price = vendor_item.price * 2
	
	# Check if player has enough gold
	if GameInfo.current_player.silver < purchase_price:
		print("Not enough gold to purchase item! Need ", purchase_price, " but have ", GameInfo.current_player.silver)
		return
	
	# Check if target slot is empty
	if not is_slot_empty():
		print("Target slot must be empty to purchase item")
		return
	
	# Deduct silver
	UIManager.instance.update_silver(-purchase_price)
	print("Purchased ", vendor_item.item_name, " for ", purchase_price, " silver. Remaining silver: ", GameInfo.current_player.silver)
	
	# Create a new item instance from vendor item (copy the data)
	var purchased_item = GameInfo.Item.new({
		"id": vendor_item.id,
		"bag_slot_id": slot_id
	})
	
	# Add to player's bag_slots
	GameInfo.current_player.bag_slots.append(purchased_item)
	
	# Remove item from vendor_items (don't replenish)
	var vendor_slot_index = _vendor_slot_id - 105  # Convert slot_id to index (105->0, 106->1, etc.)
	if vendor_slot_index >= 0 and vendor_slot_index < GameInfo.vendor_items.size():
		GameInfo.vendor_items.remove_at(vendor_slot_index)
		print("Removed item from vendor inventory at index ", vendor_slot_index)
	
	# Place in visual slot
	place_item_in_slot(purchased_item)
	
	# Notify all bag views to redraw
	if UIManager.instance:
		UIManager.instance.refresh_bags()
	print("Item purchased and added to slot ", slot_id)

func handle_vendor_sell(_item: GameInfo.Item, source_slot_id: int, source_container):
	# Only accept items from equipment (0-9) or bag (10-14) slots
	if source_slot_id < 0 or source_slot_id > 14:
		print("Can only sell items from equipment or bag slots")
		return
	
	# Find the item in bag_slots by its bag_slot_id
	var item_in_bag = null
	for game_item in GameInfo.current_player.bag_slots:
		if game_item.bag_slot_id == source_slot_id:
			item_in_bag = game_item
			break
	
	if not item_in_bag:
		print("Item not found in bag_slots")
		return
	
	# Add silver for selling the item
	UIManager.instance.update_silver(item_in_bag.price)
	print("Sold ", item_in_bag.item_name, " for ", item_in_bag.price, " silver. Total silver: ", GameInfo.current_player.silver)
	
	# Remove item from bag_slots
	GameInfo.current_player.bag_slots.erase(item_in_bag)
	
	# Clear the source slot visually
	if source_container:
		source_container.clear_slot()
	
	# Notify all bag views to redraw
	if UIManager.instance:
		UIManager.instance.refresh_bags()
	print("Item sold and removed from inventory")

func handle_gem_socketing(gem_item: GameInfo.Item, target_item: GameInfo.Item, gem_source_slot_id: int, gem_source_container):
	"""Socket a gem into an item with an empty socket"""
	print("Socketing gem ", gem_item.item_name, " into ", target_item.item_name)
	
	# Find the actual target item in GameInfo.bag_slots
	var target_item_in_array = null
	for game_item in GameInfo.current_player.bag_slots:
		if game_item.bag_slot_id == slot_id:
			target_item_in_array = game_item
			break
	
	if not target_item_in_array:
		print("Error: Target item not found in bag_slots")
		return
	
	# Socket the gem (store gem's item ID and day value)
	target_item_in_array.socketed_gem_id = gem_item.id
	target_item_in_array.socketed_gem_day = gem_item.day
	print("Socketed gem ID ", gem_item.id, " with day ", gem_item.day, " into item")
	
	# Remove the gem from the player's inventory
	for i in range(GameInfo.current_player.bag_slots.size()):
		var game_item = GameInfo.current_player.bag_slots[i]
		if game_item.bag_slot_id == gem_source_slot_id:
			GameInfo.current_player.bag_slots.remove_at(i)
			print("Removed gem from slot ", gem_source_slot_id)
			break
	
	# Clear the source slot visually
	if gem_source_container:
		gem_source_container.clear_slot()
	
	# Update the item display in this slot to show the socketed gem
	place_item_in_slot(target_item_in_array)
	
	# Notify all bag views to redraw
	if UIManager.instance:
		UIManager.instance.refresh_bags()
		# Refresh stats if the target item is equipped (slots 0-8)
		if slot_id <= 8:
			UIManager.instance.refresh_stats()
	print("Gem socketing complete")

func is_valid_item_for_slot(item_type: String) -> bool:
	match slot_type:
		"Head":
			return item_type == "Head"
		"Chest":
			return item_type == "Chest"
		"Hands":
			return item_type == "Hands"
		"Foot":
			return item_type == "Foot"
		"Belt":
			return item_type == "Belt"		
		"Legs":
			return item_type == "Legs"
		"Ring":
			return item_type == "Ring"
		"Amulet":
			return item_type == "Amulet"
		"Weapon":
			return item_type == "Weapon"
		"Ingredient":
			return item_type == "Ingredient"
		"Blacksmith":
			return item_type != "Ingredient" and item_type != "Consumable" and item_type != "Gem"
		"Enchanter":
			return item_type != "Ingredient" and item_type != "Consumable" and item_type != "Elixir" and item_type != "Potion" and item_type != "Gem"
		"Bag":
			return true  # Bag accepts everything
		"Sell":
			return true  # Sell slot accepts everything from player inventory
		"Consume":
			return item_type == "Potion" or item_type == "Elixir"  # Only consumables
		_:
			return false

func is_slot_empty() -> bool:
	# Check if slot has any children besides Background and Outline
	for child in get_children():
		if child != slot_background and child != item_outline:
			return false
	return true

func place_item_in_slot(item_data: GameInfo.Item):
	if not is_slot_empty():
		clear_slot()
	
	# Create new item
	var new_item = item_scene.instantiate()
	new_item.set_item_data(item_data)
	add_child(new_item)
	
	# Auto-update appearance (hide outline)
	update_slot_appearance()
	
	# Notify UIManager if this is a utility slot (100-104)
	if slot_id >= 100 and slot_id <= 104:
		UIManager.instance.notify_slot_changed(slot_id)

func clear_slot():
	# Collect children to remove (except Background and Outline)
	var children_to_remove = []
	for child in get_children():
		if child != slot_background and child != item_outline:
			children_to_remove.append(child)
	
	# Free them with queue_free to avoid locked object errors
	for child in children_to_remove:
		child.queue_free()
	
	# Auto-update appearance (deferred so queue_free completes first)
	call_deferred("update_slot_appearance")
	
	# Notify UIManager if this is a utility slot (100-104)
	if slot_id >= 100 and slot_id <= 104:
		UIManager.instance.notify_slot_changed(slot_id)

func update_slot_appearance():
	# Count non-background/outline children that aren't queued for deletion
	var item_count = 0
	for child in get_children():
		if child != slot_background and child != item_outline and not child.is_queued_for_deletion():
			item_count += 1
	
	# Only show outline when empty AND outline_texture is set (equipment slots)
	if item_outline:
		item_outline.visible = (item_count == 0) and (outline_texture != null)

func refresh_slot():
	"""Manual refresh - used by external systems that change bag_slots data directly"""
	# Vendor slots (105-112) are managed by VendorPanel, don't auto-refresh them
	if slot_id >= 105 and slot_id <= 112:
		return
	
	# Clear existing item visuals (keep Background and Outline)
	for child in get_children():
		if child != slot_background and child != item_outline:
			child.queue_free()
	
	# Find if this slot has an item in bag_slots
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == slot_id:
			# Instantiate the item visual
			if item_scene:
				var item_icon = item_scene.instantiate()
				add_child(item_icon)
				if item_icon.has_method("set_item_data"):
					item_icon.set_item_data(item)
			break
	
	# Update appearance (deferred so queue_free completes first)
	call_deferred("update_slot_appearance")

func get_item_data() -> GameInfo.Item:
	if not is_slot_empty():
		# Find the first child that is not background or outline
		for child in get_children():
			if child != slot_background and child != item_outline:
				if child.has_method("get_item_data"):
					return child.get_item_data()
	return null

func handle_double_click(item: GameInfo.Item):
	"""Handle double-click on item - unified with drag-and-drop visual updates"""
	var current_utility = GameInfo.get_current_panel()
	
	print("\n=== DOUBLE CLICK DEBUG ===")
	print("Item: ", item.item_name, " (Type: ", item.type, ", Slot: ", item.bag_slot_id, ")")
	print("Current Panel: ", current_utility.name if current_utility else "null")
	print("==========================\n")
	
	# Check if item is a consumable (Potion or Elixir) in bag - consume it
	# Only consume on Character panel (not utility panels like Vendor, Blacksmith, etc.)
	if (item.type == "Potion" or item.type == "Elixir") and item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
		if current_utility == null or (current_utility and current_utility.name == "Character"):
			_consume_item(item)
		return
	
	# Blacksmith: Move equippable items to slot 100
	if current_utility and current_utility.name == "BlacksmithPanel":
		if item.type != "Ingredient" and item.type != "Consumable" and item.type != "Gem":
			if item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
				var target_slot = _find_slot_by_id(100)
				if target_slot and target_slot.is_slot_empty():
					item.bag_slot_id = 100
					target_slot.place_item_in_slot(item)
					clear_slot()
					UIManager.instance.refresh_bags()
		return
	
	# Enchanter: Move equippable items to slot 104
	if current_utility and current_utility.name == "EnchanterPanel":
		if item.type != "Ingredient" and item.type != "Consumable" and item.type != "Elixir" and item.type != "Potion" and item.type != "Gem":
			if item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
				var target_slot = _find_slot_by_id(104)
				if target_slot and target_slot.is_slot_empty():
					item.bag_slot_id = 104
					target_slot.place_item_in_slot(item)
					clear_slot()
					if UIManager.instance:
						UIManager.instance.refresh_bags()
		return
	
	# Alchemist: Move ingredients to slots 101-103
	if current_utility and current_utility.name == "AlchemistPanel":
		if item.type == "Ingredient" and item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
			for target_slot_id in [101, 102, 103]:
				var target_slot = _find_slot_by_id(target_slot_id)
				if target_slot and target_slot.is_slot_empty():
					item.bag_slot_id = target_slot_id
					target_slot.place_item_in_slot(item)
					clear_slot()
					if UIManager.instance:
						UIManager.instance.refresh_bags()
					break
		return
	
	# Vendor: Sell if in bag, buy if in vendor slots
	if current_utility and current_utility.name == "VendorPanel":
		# Selling: item in bag (10-14)
		if item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
			if item.price > 0:
				UIManager.instance.update_silver(item.price)
				GameInfo.current_player.bag_slots.erase(item)
				clear_slot()
				if UIManager.instance:
					UIManager.instance.refresh_bags()
		# Buying: item in vendor slots (105-112)
		elif item.bag_slot_id >= 105 and item.bag_slot_id <= 112:
			var buy_price = item.price * 2
			if GameInfo.current_player.silver >= buy_price:
				# Find first empty bag slot
				for bag_slot_id in range(10, 15):
					var target_slot = _find_slot_by_id(bag_slot_id)
					if target_slot and target_slot.is_slot_empty():
						UIManager.instance.update_silver(-buy_price)
						print("VENDOR: Purchased item ID ", item.id, " for ", buy_price, " silver")
						
						# Create simplified item (only id, bag_slot_id, and day)
						var new_item = GameInfo.Item.new({
							"id": item.id,
							"bag_slot_id": bag_slot_id,
							"day": GameInfo.current_player.server_day  # Current day for stat scaling
						})
						
						GameInfo.current_player.bag_slots.append(new_item)
						target_slot.place_item_in_slot(new_item)
						print("VENDOR: Item added to bag slot ", bag_slot_id)
						
						UIManager.instance.refresh_bags()
						break
		return
	
	# Character panel equip/unequip (fallback - only if no utility panel is active)
	var current_panel = GameInfo.get_current_panel()
	var current_overlay = GameInfo.get_current_panel_overlay()
	var on_character_panel = (current_panel and current_panel.name == "Character") or (current_overlay and current_overlay.name == "Character")
	
	if on_character_panel:
		# If item is equipped (0-8), move it to bag
		if item.bag_slot_id >= 0 and item.bag_slot_id <= 8:
			_unequip_item_to_bag(item)
			return
		# If item is in bag (10-14), equip it
		elif item.bag_slot_id >= 10 and item.bag_slot_id <= 14:
			if _can_equip_to_character(item):
				_equip_item_to_character(item)
				return

func _consume_item(item: GameInfo.Item):
	"""Consume a potion or elixir and apply its effects"""
	print("Consuming item: ", item.item_name, " (Type: ", item.type, ")")
	if item.type == "Potion":
		GameInfo.current_player.potion = item.id
		GameInfo.current_player.bag_slots.erase(item)
		clear_slot()
	elif item.type == "Elixir":
		GameInfo.current_player.elixir = item.id
		GameInfo.current_player.bag_slots.erase(item)
		clear_slot()
	
	# Update active perks display
	UIManager.instance.refresh_active_effects()
	UIManager.instance.refresh_bags()
	UIManager.instance.refresh_stats()

func _can_equip_to_character(item: GameInfo.Item) -> bool:
	return item.type in ["Head", "Chest", "Hands", "Foot", "Belt", "Legs", "Ring", "Amulet", "Weapon"]

func _equip_item_to_character(item: GameInfo.Item):
	"""Equip item from bag to character equipment slot"""
	var target_slot_id = -1
	match item.type:
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
		return
	
	var target_slot = _find_slot_by_id(target_slot_id)
	if not target_slot:
		return
	
	if target_slot.is_slot_empty():
		# Simple equip - no swap
		item.bag_slot_id = target_slot_id
		target_slot.place_item_in_slot(item)
		clear_slot()
	else:
		# Swap with existing equipped item
		var existing_item = target_slot.get_item_data()
		var source_slot_id = item.bag_slot_id
		item.bag_slot_id = target_slot_id
		existing_item.bag_slot_id = source_slot_id
		target_slot.place_item_in_slot(item)
		place_item_in_slot(existing_item)
	
	if UIManager.instance:
		UIManager.instance.call_deferred("refresh_bags")
		UIManager.instance.call_deferred("refresh_stats")

func _unequip_item_to_bag(item: GameInfo.Item):
	"""Move equipped item to first available bag slot"""
	for bag_slot_id in range(10, 15):
		var target_slot = _find_slot_by_id(bag_slot_id)
		if target_slot and target_slot.is_slot_empty():
			item.bag_slot_id = bag_slot_id
			target_slot.place_item_in_slot(item)
			clear_slot()
			if UIManager.instance:
				UIManager.instance.call_deferred("refresh_bags")
				UIManager.instance.call_deferred("refresh_stats")
			return

func _find_slot_by_id(target_slot_id: int):
	"""Find an InventorySlot by its slot_id"""
	var game_root = get_tree().root.get_node_or_null("Game")
	if not game_root:
		return null
	
	# Search for slot with matching slot_id
	var queue = [game_root]
	while queue.size() > 0:
		var node = queue.pop_front()
		
		# Check if this node is an InventorySlot with matching slot_id
		if node.get_script() == get_script() and node.get("slot_id") == target_slot_id:
			return node
		
		# Add children to queue
		for child in node.get_children():
			queue.append(child)
	
	return null
