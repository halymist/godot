extends PanelContainer

var effect: EffectResource
var tooltip_panel: Panel

@onready var icon = $IconContainer/Icon

func setup(effect_data: EffectResource, tooltip_ref: Panel = null):
	effect = effect_data
	tooltip_panel = tooltip_ref
	
	# Get icon node directly if @onready hasn't run yet
	var icon_node = icon if icon else $IconContainer/Icon
	
	if icon_node and effect_data.icon:
		icon_node.texture = effect_data.icon
	
	# Enable mouse detection for hover if tooltip is available
	if tooltip_panel:
		mouse_filter = Control.MOUSE_FILTER_PASS
		mouse_entered.connect(_on_hover_start)
		mouse_exited.connect(_on_hover_end)

func _on_hover_start():
	if effect and tooltip_panel:
		var tooltip_label = tooltip_panel.get_node("TooltipLabel")
		if tooltip_label:
			# Build tooltip with effect name and description
			var tooltip_text = effect.name
			if effect.description != "":
				tooltip_text += "\n" + effect.description
			
			tooltip_label.text = tooltip_text
			tooltip_panel.visible = true
		
		# Position tooltip above the icon
		var icon_global_pos = global_position
		var icon_size = size
		var tooltip_size = tooltip_panel.size
		
		# Position above the icon, centered horizontally
		tooltip_panel.global_position = Vector2(
			icon_global_pos.x - tooltip_size.x / 2 + icon_size.x / 2,  # Center horizontally on icon
			icon_global_pos.y - tooltip_size.y - 10  # Position above icon with 10px gap
		)

func _on_hover_end():
	if tooltip_panel:
		tooltip_panel.visible = false
