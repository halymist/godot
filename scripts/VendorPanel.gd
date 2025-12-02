@tool
extends Panel

func _process(_delta):
	_update_layout()

func _update_layout():
	var vendor_background = get_node_or_null("VendorBackground")
	var items_panel = get_node_or_null("ItemsPanel")
	var player_bag_panel = get_node_or_null("PlayerBagPanel")
	
	if not vendor_background or not items_panel or not player_bag_panel:
		return
	
	# Get available size
	var panel_width = size.x
	var panel_height = size.y
	
	# Vendor background: full width, height adjusted for 0.75 aspect ratio (width:height = 3:4)
	var bg_height = panel_width / 1.5
	vendor_background.size = Vector2(panel_width, bg_height)
	vendor_background.position = Vector2(0, 0)
	
	# Remaining height after vendor background
	var remaining_height = panel_height - bg_height
	
	# Items panel: 80% of remaining height
	var items_height = remaining_height * 0.8
	items_panel.size = Vector2(panel_width, items_height)
	items_panel.position = Vector2(0, bg_height)
	
	# Player bag panel: 20% of remaining height
	var bag_height = remaining_height * 0.2
	player_bag_panel.size = Vector2(panel_width, bag_height)
	player_bag_panel.position = Vector2(0, bg_height + items_height)
