class_name ExpeditionsDatabase
extends Resource

# Collection of slides loaded from server
@export var slides: Array = []  # Array of ExpeditionSlide (untyped for reliable .res serialization)
@export var version: int = 0

func get_slide(slide_id: int) -> ExpeditionSlide:
	"""Get slide by ID"""
	for slide in slides:
		if slide.slide_id == slide_id:
			return slide
	return null
