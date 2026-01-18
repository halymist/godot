class_name ExpeditionsDatabase
extends Resource

# Just a collection of slides - no expedition grouping needed
# Server controls which slides are shown and in what order
@export var slides: Array[Resource] = []  # Array of ExpeditionSlide

func get_slide(slide_id: int) -> Resource:
	"""Get slide by ID"""
	for slide in slides:
		if slide.slide_id == slide_id:
			return slide
	return null
