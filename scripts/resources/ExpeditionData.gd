class_name ExpeditionData
extends Resource

@export var id: int = 0
@export var name: String = ""
@export var slides: Array[Resource] = []  # Array of ExpeditionSlide

func get_slide(slide_id: int) -> Resource:
	"""Get a slide by its ID"""
	for slide in slides:
		if slide.slide_id == slide_id:
			return slide
	return null
