extends TextureRect

# Handles drag-and-drop consumption of potions and elixirs

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Accept only Potion or Elixir types
	if data is Dictionary and data.has("item"):
		var item: GameInfo.Item = data["item"]
		return item.type == "Potion" or item.type == "Elixir"
	return false

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if data is Dictionary and data.has("item"):
		var item: GameInfo.Item = data["item"]
		consume_item(item)

func consume_item(item: GameInfo.Item) -> void:
	"""Consume a potion or elixir and apply its effects"""
	if item.type == "Potion":
		# Store potion item ID
		GameInfo.current_player.potion = item.id
		# Remove from bag
		remove_item_from_bag(item)
		
	elif item.type == "Elixir":
		# Store elixir item ID
		GameInfo.current_player.elixir = item.id
		# Remove from bag
		remove_item_from_bag(item)
	
	# Update active perks display to show new consumable
	var active_perks_display = get_node_or_null("/root/Main/CanvasLayer/Portrait/GameScene/Character/ActivePerksBackground/ActivePerks")
	if active_perks_display:
		active_perks_display.update_active_perks()

func remove_item_from_bag(item: GameInfo.Item) -> void:
	"""Remove consumed item from player's bag"""
	for i in range(GameInfo.current_player.bag_slots.size()):
		var slot = GameInfo.current_player.bag_slots[i]
		if slot.id == item.id and slot.bag_slot_id == item.bag_slot_id:
			GameInfo.current_player.bag_slots.remove_at(i)
			GameInfo.bag_slots_changed.emit()
			print("Removed consumed item from bag: ", item.item_name)
			return
