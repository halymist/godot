extends Control

func _ready():
	custom_minimum_size = Vector2(600, 600)

func _process(_delta):
	var h = get_parent().size.y
	custom_minimum_size = Vector2(h, h)
	scale = Vector2(h / 600.0, h / 600.0)
