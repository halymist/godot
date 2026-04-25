class_name TalentsDatabase
extends Resource

@export var talents: Array[TalentResource] = []

const GRID_COLUMNS := 7

func get_talent_by_id(talent_id: int) -> TalentResource:
	for talent in talents:
		if talent.talent_id == talent_id:
			return talent
	return null

func get_talent_by_grid_index(index: int) -> TalentResource:
	"""Get talent by visual grid index based on server-provided list order."""
	if index < 0 or index >= talents.size():
		return null
	return talents[index]

func get_talents_for_row(row: int) -> Array[TalentResource]:
	var result: Array[TalentResource] = []
	if row < 0:
		return result

	var start_index = row * GRID_COLUMNS
	if start_index >= talents.size():
		return result

	var end_index = min(start_index + GRID_COLUMNS, talents.size())
	for i in range(start_index, end_index):
		result.append(talents[i])
	return result
