extends Control
class_name NpcSpot

## Visual spot for NPC placement
## Resize this Control node - the AspectRatioContainer child enforces 1:2 ratio
## Change the height in Inspector and width will adjust automatically

@export var spot_id: int = 1
@export var debug_color: Color = Color(0, 1, 0, 0.3)  # Green semi-transparent for editor visibility

func _ready():
	# Hide in game, only visible in editor
	if not Engine.is_editor_hint():
		visible = false
