extends HBoxContainer

@export var perk_mini_scene: PackedScene
@export var tooltip_panel: Panel
@export var tooltip_label: Label


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
			# Store perk data in the icon for hover functionality
			perk_icon.set_meta("perk_data", perk)
			
			# Set the perk texture if available
			var texture_rect = perk_icon.get_node("TextureRect")
			if texture_rect and perk.texture:
				texture_rect.texture = perk.texture
			
			# Enable mouse detection for hover
			perk_icon.mouse_filter = Control.MOUSE_FILTER_PASS
			
			# Connect hover signals
			perk_icon.mouse_entered.connect(_on_perk_hover_start.bind(perk_icon))
			perk_icon.mouse_exited.connect(_on_perk_hover_end)
			
			add_child(perk_icon)
			print("ActivePerksDisplay: Added perk icon to HBox")
		else:
			print("ERROR: perk_mini_scene is null!")

func _on_perk_hover_start(perk_icon):
	var perk_data = perk_icon.get_meta("perk_data")
	if perk_data:
		tooltip_label.text = perk_data.perk_name + "\n\n" + perk_data.description
		tooltip_panel.visible = true

func _on_perk_hover_end():
	tooltip_panel.visible = false

func get_active_perks() -> Array:
	var active_perks = []
	if GameInfo.current_player and GameInfo.current_player.perks:
		for perk in GameInfo.current_player.perks:
			if perk.active:
				active_perks.append(perk)
	return active_perks
