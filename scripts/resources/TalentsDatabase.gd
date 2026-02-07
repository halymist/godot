class_name TalentsDatabase
extends Resource

@export var talents: Array[TalentResource] = []

func get_talent_by_id(talent_id: int) -> TalentResource:
	for talent in talents:
		if talent.talent_id == talent_id:
			return talent
	return null

func get_talent_by_grid_index(index: int) -> TalentResource:
	"""Get talent by its position in the grid (0-55). Maps grid index to talent_id."""
	# Grid is 8 columns x 7 rows = 56 slots
	# Index 0 = top-left, increments left-to-right, top-to-bottom
	# Talent IDs: bottom-left = 1, going right, bottom row = 1-8, next row up = 9-16, etc.
	# Formula: talent_id = (rows_from_bottom * 8) + column + 1
	
	var row = index / 8  # 0-6, top to bottom
	var col = index % 8  # 0-7, left to right
	var rows_from_bottom = 6 - row  # 6 = top row, 0 = bottom row
	var talent_id = rows_from_bottom * 8 + col + 1
	
	return get_talent_by_id(talent_id)

func get_talents_for_row(row: int) -> Array[TalentResource]:
	var result: Array[TalentResource] = []
	for talent in talents:
		if talent.row == row:
			result.append(talent)
	return result
