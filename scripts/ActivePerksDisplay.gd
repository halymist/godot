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
		
		# Position tooltip above the perk icon
		var icon_global_pos = perk_icon.global_position
		var icon_size = perk_icon.size
		var tooltip_size = tooltip_panel.size
		
		# Position above the icon, centered horizontally
		tooltip_panel.global_position = Vector2(
			icon_global_pos.x - tooltip_size.x / 2 + icon_size.x / 2,  # Center horizontally on icon
			icon_global_pos.y - tooltip_size.y - 10  # Position above icon with 10px gap
		)
		
		# Ensure tooltip stays within screen bounds
		var viewport_size = get_viewport().get_visible_rect().size
		if tooltip_panel.global_position.x < 0:
			tooltip_panel.global_position.x = 0
		elif tooltip_panel.global_position.x + tooltip_size.x > viewport_size.x:
			tooltip_panel.global_position.x = viewport_size.x - tooltip_size.x
		
		if tooltip_panel.global_position.y < 0:
			tooltip_panel.global_position.y = icon_global_pos.y + icon_size.y + 10  # Show below if no space above

func _on_perk_hover_end():
	tooltip_panel.visible = false

func get_active_perks() -> Array:
	# Use the new helper method directly on the player
	return GameInfo.current_player.get_active_perks() if GameInfo.current_player else []
