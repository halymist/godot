extends Control

# Slot numbering constants
const EQUIPMENT_MIN = 1
const EQUIPMENT_MAX = 9
const BAG_MIN = 10
const BAG_MAX = 14
const ENCHANTER_SLOT = 15
const BLACKSMITH_SLOT = 16
const ALCHEMIST_SLOT_1 = 17
const ALCHEMIST_SLOT_2 = 18
const ALCHEMIST_SLOT_3 = 19
const VENDOR_SELL_SLOT = 20
const VENDOR_MIN = 21
const VENDOR_MAX = 28
const CONSUME_SLOT = 29

@export var item_scene: PackedScene
@export var outline_texture: Texture2D
@onready var item_outline = get_node_or_null("Outline")

@export var slot_type: String = "Bag"
@export var slot_id: int

func _ready():
	# Override cursor to always be arrow (no forbidden cursor during drag)
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	
	# Set outline texture if provided (equipment slots only)
	if outline_texture and item_outline:
		item_outline.texture = outline_texture
	
	update_slot_appearance()
	call_deferred("update_slot_appearance")

func _is_item_child(child: Node) -> bool:
	return child != item_outline and child.has_method("get_item_data")

func _can_drop_data(_pos, data):
	# Check if data is valid drag package
	if not (data is Dictionary and data.has("item") and data["item"] is GameInfo.Item):
		return false
	
	var item = data["item"]
	var item_type = item.type
	var source_container = data.get("source_container")
	var source_slot_id = source_container.slot_id if source_container else -1
	
	print("DEBUG _can_drop_data: Target slot_id=", slot_id, " slot_type=", slot_type, " | Source slot_id=", source_slot_id, " | Dragged item type=", item_type)
	
	# Vendor slots (21-28) accept drops from bag (10-14) for selling
	if slot_id >= VENDOR_MIN and slot_id <= VENDOR_MAX:
		# Only accept items from bag slots (10-14) for selling
		return source_slot_id >= 10 and source_slot_id <= 14
	
	# Vendor display / sell slot (20) accepts items from bag or equipment for selling
	if slot_id == VENDOR_SELL_SLOT:
		return (source_slot_id >= EQUIPMENT_MIN and source_slot_id <= EQUIPMENT_MAX) or (source_slot_id >= BAG_MIN and source_slot_id <= BAG_MAX)
	
	# Cannot drag between vendor slots
	if source_slot_id >= VENDOR_MIN and source_slot_id <= VENDOR_MAX and slot_id >= VENDOR_MIN and slot_id <= VENDOR_MAX:
		return false
	
	# Special case: Allow gems to be dropped on equipment slots (1-9) if item has a socket
	if item_type == "Gem" and slot_id >= EQUIPMENT_MIN and slot_id <= EQUIPMENT_MAX:
		if not is_slot_empty():
			var target_item = get_item_data()
			if target_item and target_item.has_socket and target_item.socket_id == -1:
				# Item has an empty socket, allow the drop
				return true
		# If slot is empty or item doesn't have a socket, reject
		return false
	
	# Allow gems to be dropped on vendor sell slot for selling
	if item_type == "Gem" and slot_id == VENDOR_SELL_SLOT:
		return source_slot_id >= BAG_MIN and source_slot_id <= BAG_MAX
	
	# Special case: Allow hammers to be dropped on any slot with a temperable item OR empty bag slots
	if item_type == "Hammer":
		# Allow selling hammers to vendor
		if slot_id == VENDOR_SELL_SLOT:
			return source_slot_id >= BAG_MIN and source_slot_id <= BAG_MAX
		# Allow movement to empty bag slots (10-14)
		if is_slot_empty() and slot_id >= BAG_MIN and slot_id <= BAG_MAX:
			return true
		if not is_slot_empty():
			var target_item = get_item_data()
			# Check if target item is temperable (not Gem, Scroll, Hammer, Ingredient, Potion, Ration, Elixir)
			if target_item and target_item.type not in ["Gem", "Scroll", "Hammer", "Ingredient", "Potion", "Ration", "Elixir"]:
				return true
		# If slot has non-temperable item, reject
		return false
	
	# Special case: Allow scrolls to be dropped on any slot with an enchantable item OR empty bag slots
	if item_type == "Scroll":
		# Allow selling scrolls to vendor
		if slot_id == VENDOR_SELL_SLOT:
			return source_slot_id >= BAG_MIN and source_slot_id <= BAG_MAX
		# Allow movement to empty bag slots (10-14)
		if is_slot_empty() and slot_id >= BAG_MIN and slot_id <= BAG_MAX:
			return true
		if not is_slot_empty():
			var target_item = get_item_data()
			# Check if target item is enchantable (not Gem, Scroll, Hammer, Ingredient, Potion, Ration, Elixir)
			if target_item and target_item.type not in ["Gem", "Scroll", "Hammer", "Ingredient", "Potion", "Ration", "Elixir"]:
				# Get the scroll's effect and check if the effect slot matches target item type
				var dragged_item_data = data.get("item") if data else null
				if dragged_item_data and dragged_item_data.effect_id > 0 and GameInfo.effects_db:
					var effect = GameInfo.effects_db.get_effect_by_id(dragged_item_data.effect_id)
					if effect:
						# If effect has a slot requirement, it must match the target item type
						var effect_slot = effect.get_slot_string()
						if effect_slot == "" or effect_slot == target_item.type:
							return true
		# If slot has non-enchantable item or effect doesn't match, reject
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
	# Equipment slots are 1-9, and each has a specific type requirement
	if slot_id >= EQUIPMENT_MIN and slot_id <= EQUIPMENT_MAX and source_slot_id >= EQUIPMENT_MIN and source_slot_id <= EQUIPMENT_MAX:
		# Both are equipment slots - only allow swap if same type
		if item_type != existing_item_type:
			return false
	
	# Also check when swapping between equipment and bag
	# If source is equipment (1-9) and target has an item, types must match
	if source_slot_id >= EQUIPMENT_MIN and source_slot_id <= EQUIPMENT_MAX:
		# Source is equipment slot - the item types must match for a swap
		print("DEBUG: Equipment->bag swap check. Source slot: ", source_slot_id, " Target slot: ", slot_id)
		print("DEBUG: Dragged item type: ", item_type, " Existing item type: ", existing_item_type)
		
		# Get the required type for the source equipment slot
		var required_type = ""
		match source_slot_id:
			1: required_type = "Head"
			2: required_type = "Chest"
			3: required_type = "Hands"
			4: required_type = "Foot"
			5: required_type = "Belt"
			6: required_type = "Legs"
			7: required_type = "Ring"
			8: required_type = "Amulet"
			9: required_type = "Weapon"
		
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
	
	# Special case: Purchasing from vendor (slots 21-28)
	if source_slot_id >= VENDOR_MIN and source_slot_id <= VENDOR_MAX:
		handle_vendor_purchase(dragged_item, source_slot_id)
		return
	
	# Special case: Selling to vendor (slot 20 OR vendor display slots 21-28)
	if slot_id == VENDOR_SELL_SLOT or (slot_id >= VENDOR_MIN and slot_id <= VENDOR_MAX):
		handle_vendor_sell(dragged_item, source_slot_id, source_container)
		return
	
	# Special case: Consuming potion/elixir on avatar (slot 9)
	if slot_id == CONSUME_SLOT:
		if dragged_item.type == "Potion" or dragged_item.type == "Elixir":
			_consume_item(dragged_item)
			if source_container:
				source_container.clear_slot()
		return
	
	# Special case: Socketing a gem into an item
	if dragged_item.type == "Gem" and not is_slot_empty():
		var target_item = get_item_data()
		if target_item and target_item.has_socket and target_item.socket_id == -1:
			# Socket the gem into the item
			handle_gem_socketing(dragged_item, target_item, source_slot_id, source_container)
			return
	
	# Special case: Using a hammer to temper an item
	if dragged_item.type == "Hammer" and not is_slot_empty():
		var target_item = get_item_data()
		# Check if target item is temperable
		if target_item and target_item.type not in ["Gem", "Scroll", "Hammer", "Ingredient", "Potion", "Ration", "Elixir"]:
			# Temper the item with the hammer
			handle_hammer_tempering(dragged_item, target_item, source_slot_id, source_container)
			return
	
	# Special case: Using a scroll to enchant an item
	if dragged_item.type == "Scroll" and not is_slot_empty():
		var target_item = get_item_data()
		# Check if target item is enchantable
		if target_item and target_item.type not in ["Gem", "Scroll", "Hammer", "Ingredient", "Potion", "Ration", "Elixir"]:
			# Check effect slot compatibility
			if dragged_item.effect_id > 0 and GameInfo.effects_db:
				var effect = GameInfo.effects_db.get_effect_by_id(dragged_item.effect_id)
				var effect_slot = effect.get_slot_string() if effect else ""
				if effect and (effect_slot == "" or effect_slot == target_item.type):
					# Enchant the item with the scroll
					handle_scroll_enchanting(dragged_item, target_item, source_slot_id, source_container)
					return
	
	# Update GameInfo directly based on the operation
	# SPECIAL: For utility slots (15-19), DON'T change bag_slot_id - they're visual only
	var is_utility_target = slot_id >= ENCHANTER_SLOT and slot_id <= ALCHEMIST_SLOT_3
	var is_utility_source = source_slot_id >= ENCHANTER_SLOT and source_slot_id <= ALCHEMIST_SLOT_3
	
	if is_utility_target:
		# Moving TO a utility slot - just update visuals, don't change bag_slot_id
		# The panel will track the item reference via on_slot_changed
		place_item_in_slot(dragged_item)
		if source_container:
			source_container.clear_slot()
		# Notify the panel about the item being placed (pass the source slot for tracking)
		if UIManager.instance:
			UIManager.instance.notify_utility_slot_item_placed(slot_id, dragged_item, source_slot_id)
	elif is_utility_source:
		# Moving FROM a utility slot back to bag - just update visuals
		place_item_in_slot(dragged_item)
		if source_container:
			source_container.clear_slot()
		if UIManager.instance:
			UIManager.instance.notify_utility_slot_item_removed(source_slot_id)
	elif not is_slot_empty():
		var existing_item = get_item_data()
		
		var dragged_item_in_array = null
		var existing_item_in_array = null
		
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.bag_slot_id == source_slot_id and dragged_item_in_array == null:
				dragged_item_in_array = game_item
			elif game_item.bag_slot_id == slot_id and existing_item_in_array == null:
				existing_item_in_array = game_item
		
		if dragged_item_in_array:
			dragged_item_in_array.bag_slot_id = slot_id
		if existing_item_in_array:
			existing_item_in_array.bag_slot_id = source_slot_id
		
		Websocket.move_item(source_slot_id, slot_id)

		place_item_in_slot(dragged_item)
		if source_container:
			source_container.place_item_in_slot(existing_item)
	else:
		for game_item in GameInfo.current_player.bag_slots:
			if game_item.bag_slot_id == source_slot_id:
				game_item.bag_slot_id = slot_id
				break
		
		Websocket.move_item(source_slot_id, slot_id)
		place_item_in_slot(dragged_item)
		if source_container:
			source_container.clear_slot()

	print("Updated GameInfo: item moved to slot ", slot_id)
	if UIManager.instance:
		UIManager.instance.refresh_bags()
		# Refresh stats if equipment slots (1-9) are involved
		if (slot_id >= EQUIPMENT_MIN and slot_id <= EQUIPMENT_MAX) or (source_slot_id >= EQUIPMENT_MIN and source_slot_id <= EQUIPMENT_MAX):
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
	
	Websocket.buy_item(vendor_item.id, slot_id)
	
	# Add item to player's bag using helper (automatically assigns to empty slot with server day)
	var added = GameInfo.current_player.add_item_to_bag(vendor_item.id)
	if not added:
		print("ERROR: Failed to add purchased item to bag (this shouldn't happen since we checked slot was empty)")
		return
	
	# Get the newly added item from bag_slots
	var purchased_item: GameInfo.Item = null
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == slot_id:
			purchased_item = item
			break
	
	# Remove item from vendor panel's local inventory (don't replenish)
	var vendor_slot_index = _vendor_slot_id - VENDOR_MIN  # Convert slot_id to index
	var vendor_panel = UIManager.instance.vendor_panel if UIManager.instance else null
	if vendor_panel and vendor_slot_index >= 0 and vendor_slot_index < vendor_panel.vendor_items.size():
		vendor_panel.vendor_items.remove_at(vendor_slot_index)
		print("Removed item from vendor inventory at index ", vendor_slot_index)
	
	# Place in visual slot
	place_item_in_slot(purchased_item)
	
	# Notify all bag views to redraw
	if UIManager.instance:
		UIManager.instance.refresh_bags()
		# Trigger chat greeting if on vendor panel
		var current_panel = UIManager.instance.current_panel
		if current_panel and current_panel.name == "VendorPanel" and current_panel.has_method("trigger_purchase_greeting"):
			current_panel.trigger_purchase_greeting()
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
	
	Websocket.sell_item(source_slot_id)
	
	# Remove item from bag_slots
	GameInfo.current_player.bag_slots.erase(item_in_bag)
	
	# Clear the source slot visually
	if source_container:
		source_container.clear_slot()
	
	# Notify all bag views to redraw
	if UIManager.instance:
		UIManager.instance.refresh_bags()
		# Trigger chat greeting if on vendor panel
		var current_panel = UIManager.instance.current_panel
		if current_panel and current_panel.name == "VendorPanel" and current_panel.has_method("trigger_sell_greeting"):
			current_panel.trigger_sell_greeting()
	print("Item sold and removed from inventory")

func handle_gem_socketing(gem_item: GameInfo.Item, target_item: GameInfo.Item, gem_source_slot_id: int, gem_source_container):
	print("Socketing gem ", gem_item.item_name, " into ", target_item.item_name)
	
	var target_item_in_array = null
	for game_item in GameInfo.current_player.bag_slots:
		if game_item.bag_slot_id == slot_id:
			target_item_in_array = game_item
			break
	
	if not target_item_in_array:
		print("Error: Target item not found in bag_slots")
		return
	
	Websocket.socket_item(gem_source_slot_id, slot_id)
	
	# Socket the gem (store gem's item ID and day value)
	target_item_in_array.socket_id = gem_item.id
	target_item_in_array.socket_day = gem_item.day
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

func handle_hammer_tempering(hammer_item: GameInfo.Item, target_item: GameInfo.Item, hammer_source_slot_id: int, hammer_source_container):
	print("Tempering ", target_item.item_name, " with ", hammer_item.item_name)
	
	var target_item_in_array = null
	for game_item in GameInfo.current_player.bag_slots:
		if game_item.bag_slot_id == slot_id:
			target_item_in_array = game_item
			break
	
	if not target_item_in_array:
		print("Error: Target item not found in bag_slots")
		return
	
	Websocket.use_hammer(hammer_source_slot_id, slot_id)
	
	# Apply tempering: +10% to all stats (rounded up)
	if target_item_in_array.get("strength") and target_item_in_array.strength > 0:
		target_item_in_array.strength += ceil(target_item_in_array.strength * 0.1)
	if target_item_in_array.get("stamina") and target_item_in_array.stamina > 0:
		target_item_in_array.stamina += ceil(target_item_in_array.stamina * 0.1)
	if target_item_in_array.get("agility") and target_item_in_array.agility > 0:
		target_item_in_array.agility += ceil(target_item_in_array.agility * 0.1)
	if target_item_in_array.get("luck") and target_item_in_array.luck > 0:
		target_item_in_array.luck += ceil(target_item_in_array.luck * 0.1)
	if target_item_in_array.get("armor") and target_item_in_array.armor > 0:
		target_item_in_array.armor += ceil(target_item_in_array.armor * 0.1)
	
	# Increment tempered counter
	if target_item_in_array.get("tempered"):
		target_item_in_array.tempered += 1
	else:
		target_item_in_array.tempered = 1
	
	print("Tempered item to level ", target_item_in_array.tempered)
	
	# Remove the hammer from the player's inventory
	for i in range(GameInfo.current_player.bag_slots.size()):
		var game_item = GameInfo.current_player.bag_slots[i]
		if game_item.bag_slot_id == hammer_source_slot_id:
			GameInfo.current_player.bag_slots.remove_at(i)
			print("Removed hammer from slot ", hammer_source_slot_id)
			break
	
	# Clear the source slot visually
	if hammer_source_container:
		hammer_source_container.clear_slot()
	
	# Update the item display in this slot to show the tempered stats
	place_item_in_slot(target_item_in_array)
	
	# Notify all bag views to redraw
	if UIManager.instance:
		UIManager.instance.refresh_bags()
		# Refresh stats if the target item is equipped (slots 0-8)
		if slot_id <= 8:
			UIManager.instance.refresh_stats()

func handle_scroll_enchanting(scroll_item: GameInfo.Item, target_item: GameInfo.Item, scroll_source_slot_id: int, scroll_source_container):
	print("Enchanting ", target_item.item_name, " with ", scroll_item.item_name)
	
	var target_item_in_array = null
	for game_item in GameInfo.current_player.bag_slots:
		if game_item.bag_slot_id == slot_id:
			target_item_in_array = game_item
			break
	
	if not target_item_in_array:
		print("Error: Target item not found in bag_slots")
		return
	
	Websocket.use_scroll(scroll_source_slot_id, slot_id)
	
	# Apply enchantment: set effect_overdrive to the scroll's effect_id
	if scroll_item.effect_id > 0:
		target_item_in_array.effect_overdrive = scroll_item.effect_id
		print("Applied enchantment effect_overdrive: ", scroll_item.effect_id)
	else:
		print("Warning: Scroll has no effect_id")
		return
	
	# Remove the scroll from the player's inventory
	for i in range(GameInfo.current_player.bag_slots.size()):
		var game_item = GameInfo.current_player.bag_slots[i]
		if game_item.bag_slot_id == scroll_source_slot_id:
			GameInfo.current_player.bag_slots.remove_at(i)
			print("Removed scroll from slot ", scroll_source_slot_id)
			break
	
	# Clear the source slot visually
	if scroll_source_container:
		scroll_source_container.clear_slot()
	
	# Update the item display in this slot to show the enchanted effect
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
			return item_type not in ["Gem", "Scroll", "Hammer", "Ingredient", "Potion", "Ration", "Elixir"]
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
	for child in get_children():
		if _is_item_child(child):
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
	
	# Notify UIManager if this is a utility slot (15-19)
	if slot_id >= ENCHANTER_SLOT and slot_id <= ALCHEMIST_SLOT_3:
		UIManager.instance.notify_slot_changed(slot_id)

func clear_slot():
	var children_to_remove = []
	for child in get_children():
		if _is_item_child(child):
			children_to_remove.append(child)
	
	for child in children_to_remove:
		child.queue_free()
	
	# Auto-update appearance (deferred so queue_free completes first)
	call_deferred("update_slot_appearance")
	
	# Notify UIManager if this is a utility slot (15-19)
	if slot_id >= ENCHANTER_SLOT and slot_id <= ALCHEMIST_SLOT_3:
		UIManager.instance.notify_slot_changed(slot_id)

func update_slot_appearance():
	var item_count = 0
	for child in get_children():
		if _is_item_child(child) and not child.is_queued_for_deletion():
			item_count += 1
	
	if item_outline:
		if outline_texture and item_outline.texture != outline_texture:
			item_outline.texture = outline_texture
		item_outline.visible = (item_count == 0) and (outline_texture != null)

func refresh_slot():
	if slot_id >= VENDOR_MIN and slot_id <= VENDOR_MAX:
		return
	
	for child in get_children():
		if child != item_outline:
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
		for child in get_children():
			if child != item_outline:
				if child.has_method("get_item_data"):
					return child.get_item_data()
	return null

func handle_double_click(item: GameInfo.Item):
	"""Handle double-click on item - unified with drag-and-drop visual updates"""
	var current_utility = UIManager.instance.current_panel
	
	print("\n=== DOUBLE CLICK DEBUG ===")
	print("Item: ", item.item_name, " (Type: ", item.type, ", Slot: ", item.bag_slot_id, ")")
	print("Current Panel: ", current_utility.name if current_utility else "null")
	print("==========================\n")
	
	# Check if item is a consumable (Potion or Elixir) in bag - consume it
	# Only consume on Character panel (not utility panels like Vendor, Blacksmith, etc.)
	if (item.type == "Potion" or item.type == "Elixir") and item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
		if current_utility == null or (current_utility and current_utility.name == "Character"):
			_consume_item(item)
		return
	
	# Blacksmith: Move temperable items to slot 16 (visually only, don't change bag_slot_id)
	if current_utility and current_utility.name == "BlacksmithPanel":
		if item.type not in ["Gem", "Scroll", "Hammer", "Ingredient", "Potion", "Ration", "Elixir"]:
			if item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
				var target_slot = _find_slot_by_id(BLACKSMITH_SLOT)
				if target_slot and target_slot.is_slot_empty():
					var source_slot_id = item.bag_slot_id  # Save original before placing
					# DON'T change bag_slot_id - this is a visual-only move
					target_slot.place_item_in_slot(item)
					# Notify panel about the item placement
					UIManager.instance.notify_utility_slot_item_placed(BLACKSMITH_SLOT, item, source_slot_id)
					UIManager.instance.refresh_bags()  # Will exclude item from bag display
		return
	
	# Enchanter: Move equippable items to slot 15 (visually only, don't change bag_slot_id)
	if current_utility and current_utility.name == "EnchanterPanel":
		if item.type != "Ingredient" and item.type != "Consumable" and item.type != "Elixir" and item.type != "Potion" and item.type != "Gem":
			if item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
				var target_slot = _find_slot_by_id(ENCHANTER_SLOT)
				if target_slot and target_slot.is_slot_empty():
					var source_slot_id = item.bag_slot_id  # Save original before placing
					# DON'T change bag_slot_id - this is a visual-only move
					target_slot.place_item_in_slot(item)
					# Notify panel about the item placement
					if UIManager.instance:
						UIManager.instance.notify_utility_slot_item_placed(ENCHANTER_SLOT, item, source_slot_id)
						UIManager.instance.refresh_bags()  # Will exclude item from bag display
		return
	
	# Alchemist: Move ingredients to slots 17-19 (visually only, don't change bag_slot_id)
	if current_utility and current_utility.name == "AlchemistPanel":
		if item.type == "Ingredient" and item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
			for target_slot_id in [ALCHEMIST_SLOT_1, ALCHEMIST_SLOT_2, ALCHEMIST_SLOT_3]:
				var target_slot = _find_slot_by_id(target_slot_id)
				if target_slot and target_slot.is_slot_empty():
					var source_slot_id = item.bag_slot_id  # Save original before placing
					# DON'T change bag_slot_id - this is a visual-only move
					target_slot.place_item_in_slot(item)
					# Notify panel about the item placement
					if UIManager.instance:
						UIManager.instance.notify_utility_slot_item_placed(target_slot_id, item, source_slot_id)
						UIManager.instance.refresh_bags()  # Will exclude item from bag display
					break
		return
	
	# Vendor: Sell if in bag/equipment, buy if in vendor slots
	if current_utility and current_utility.name == "VendorPanel":
		# Selling: item in equipment (0-8) or bag (10-14)
		if (item.bag_slot_id >= EQUIPMENT_MIN and item.bag_slot_id <= EQUIPMENT_MAX) or (item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX):
			if item.price > 0:
				Websocket.sell_item(item.bag_slot_id)
				UIManager.instance.update_silver(item.price)
				GameInfo.current_player.bag_slots.erase(item)
				clear_slot()
				if UIManager.instance:
					UIManager.instance.refresh_bags()
		# Buying: item in vendor slots (21-29)
		elif item.bag_slot_id >= VENDOR_MIN and item.bag_slot_id <= VENDOR_MAX:
			var buy_price = item.price * 2
			if GameInfo.current_player.silver >= buy_price:
				# Find first empty bag slot
				for bag_slot_id in range(BAG_MIN, BAG_MAX + 1):
					var target_slot = _find_slot_by_id(bag_slot_id)
					if target_slot and target_slot.is_slot_empty():
						UIManager.instance.update_silver(-buy_price)
						print("VENDOR: Purchased item ID ", item.id, " for ", buy_price, " silver")
						
						Websocket.buy_item(item.id, bag_slot_id)
						
						# Remove item from vendor panel's local inventory
						var vendor_slot_index = item.bag_slot_id - VENDOR_MIN
						var vendor_panel = UIManager.instance.vendor_panel if UIManager.instance else null
						if vendor_panel and vendor_slot_index >= 0 and vendor_slot_index < vendor_panel.vendor_items.size():
							vendor_panel.vendor_items.remove_at(vendor_slot_index)
						
						# Create simplified item (only id, bag_slot_id, and day)
						var new_item = GameInfo.Item.new({
							"id": item.id,
							"bag_slot_id": bag_slot_id,
							"day": GameInfo.current_player.server_day
						})
						
						GameInfo.current_player.bag_slots.append(new_item)
						target_slot.place_item_in_slot(new_item)
						print("VENDOR: Item added to bag slot ", bag_slot_id)
						
						UIManager.instance.refresh_bags()
						
						# Trigger purchase greeting and refresh vendor display
						if vendor_panel and vendor_panel.has_method("trigger_purchase_greeting"):
							vendor_panel.trigger_purchase_greeting()
						break
		return
	
	# Character panel equip/unequip (fallback - only if no utility panel is active)
	var current_panel = UIManager.instance.current_panel
	var current_overlay = UIManager.instance.current_panel_overlay
	var on_character_panel = (current_panel and current_panel.name == "Character") or (current_overlay and current_overlay.name == "Character")
	
	if on_character_panel:
		# If item is equipped (0-8), move it to bag
		if item.bag_slot_id >= EQUIPMENT_MIN and item.bag_slot_id <= EQUIPMENT_MAX:
			_unequip_item_to_bag(item)
			return
		# If item is in bag (10-14), equip it
		elif item.bag_slot_id >= BAG_MIN and item.bag_slot_id <= BAG_MAX:
			if _can_equip_to_character(item):
				_equip_item_to_character(item)
				return

func _consume_item(item: GameInfo.Item):
	print("Consuming item: ", item.item_name, " (Type: ", item.type, ")")
	if item.type == "Potion":
		Websocket.use_potion(item.bag_slot_id)
		GameInfo.current_player.potion = item.id
		GameInfo.current_player.bag_slots.erase(item)
		clear_slot()
	elif item.type == "Elixir":
		Websocket.use_elixir(item.bag_slot_id)
		GameInfo.current_player.elixir = item.id
		GameInfo.current_player.elixir_ingredients = item.ingredients.duplicate()
		GameInfo.current_player.bag_slots.erase(item)
		clear_slot()
	
	UIManager.instance.refresh_active_effects()
	UIManager.instance.refresh_bags()
	UIManager.instance.refresh_stats()

func _can_equip_to_character(item: GameInfo.Item) -> bool:
	return item.type in ["Head", "Chest", "Hands", "Foot", "Belt", "Legs", "Ring", "Amulet", "Weapon"]

func _equip_item_to_character(item: GameInfo.Item):
	"""Equip item from bag to character equipment slot"""
	var target_slot_id = -1
	match item.type:
		"Head": target_slot_id = 1
		"Chest": target_slot_id = 2
		"Hands": target_slot_id = 3
		"Foot": target_slot_id = 4
		"Belt": target_slot_id = 5
		"Legs": target_slot_id = 6
		"Ring": target_slot_id = 7
		"Amulet": target_slot_id = 8
		"Weapon": target_slot_id = 9
	
	if target_slot_id == -1:
		return
	
	var target_slot = _find_slot_by_id(target_slot_id)
	if not target_slot:
		return
	
	if target_slot.is_slot_empty():
		# Simple equip - no swap
		var source_slot_id = item.bag_slot_id
		item.bag_slot_id = target_slot_id
		target_slot.place_item_in_slot(item)
		clear_slot()
		Websocket.move_item(source_slot_id, target_slot_id)
	else:
		# Swap with existing equipped item
		var existing_item = target_slot.get_item_data()
		var source_slot_id = item.bag_slot_id
		item.bag_slot_id = target_slot_id
		existing_item.bag_slot_id = source_slot_id
		target_slot.place_item_in_slot(item)
		place_item_in_slot(existing_item)
		Websocket.move_item(source_slot_id, target_slot_id)
	
	if UIManager.instance:
		UIManager.instance.call_deferred("refresh_bags")
		UIManager.instance.call_deferred("refresh_stats")

func _unequip_item_to_bag(item: GameInfo.Item):
	"""Move equipped item to first available bag slot"""
	for bag_slot_id in range(BAG_MIN, BAG_MAX + 1):
		var target_slot = _find_slot_by_id(bag_slot_id)
		if target_slot and target_slot.is_slot_empty():
			var source_slot_id = item.bag_slot_id
			item.bag_slot_id = bag_slot_id
			target_slot.place_item_in_slot(item)
			clear_slot()
			Websocket.move_item(source_slot_id, bag_slot_id)
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
