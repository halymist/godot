@tool
extends Control

func _process(_delta):
	var parent = get_parent()
	if parent:
		var h = parent.size.y
		custom_minimum_size.x = h
		size.x = h
