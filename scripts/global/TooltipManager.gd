extends CanvasLayer

var tooltip_panel: Control

func _ready():
	# Create tooltip panel once
	var tooltip_scene = preload("res://Scenes/item_description.tscn")
	tooltip_panel = tooltip_scene.instantiate()
	add_child(tooltip_panel)
	tooltip_panel.visible = false
	
	# Ensure this layer is on top of everything
	layer = 100

func show_tooltip(item: GameInfo.Item, slot_node: Control = null):
	if tooltip_panel:
		tooltip_panel.show_description(item, slot_node)

func hide_tooltip():
	if tooltip_panel:
		tooltip_panel.hide_description()
