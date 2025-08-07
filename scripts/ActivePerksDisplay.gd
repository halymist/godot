extends HBoxContainer

@export var perk_mini_scene: PackedScene

func update_active_perks():
	print("ActivePerksDisplay: Updating active perks...")
	
	# Clear existing icons
	for child in get_children():
		child.queue_free()
	
	# Get active perks from GameInfo
	var active_perks = get_active_perks()
	print("ActivePerksDisplay: Found ", active_perks.size(), " active perks")
	
	# Create icon for each active perk
	for perk in active_perks:
		print("ActivePerksDisplay: Creating icon for: ", perk.perk_name)
		
		if perk_mini_scene:
			var perk_icon = perk_mini_scene.instantiate()
			add_child(perk_icon)
			print("ActivePerksDisplay: Added perk icon to HBox")
		else:
			print("ERROR: perk_mini_scene is null!")

func get_active_perks() -> Array:
	var active_perks = []
	if GameInfo.current_player and GameInfo.current_player.perks:
		for perk in GameInfo.current_player.perks:
			if perk.active:
				active_perks.append(perk)
	return active_perks
