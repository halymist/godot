extends Control
class_name NpcSpot

## Visual spot for NPC placement
## The size of this control determines the NPC size
## The position determines where the NPC's bottom-center will be placed

@export var spot_id: int = 1
@export var debug_color: Color = Color(0, 1, 0, 0.3)  # Green semi-transparent for editor visibility

func _ready():
	# Hide in game, only visible in editor
	visible = false

func _draw():
	# Draw a rectangle in the editor to show the spot area
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), debug_color)
		# Draw a line at the bottom center to show where feet will be
		var bottom_center = Vector2(size.x / 2.0, size.y)
		draw_circle(bottom_center, 5, Color.RED)
