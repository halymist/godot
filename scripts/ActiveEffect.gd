extends PanelContainer

var effect: EffectResource

@onready var icon = $IconContainer/Icon

func setup(effect_data: EffectResource):
	effect = effect_data
	
	# Get icon node directly if @onready hasn't run yet
	var icon_node = icon if icon else $IconContainer/Icon
	
	if icon_node and effect_data.icon:
		icon_node.texture = effect_data.icon
