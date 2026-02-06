class_name TalentsDatabase
extends Resource

@export var talents: Array[TalentResource] = []

func get_talent_by_id(talent_id: int) -> TalentResource:
	for talent in talents:
		if talent.talent_id == talent_id:
			return talent
	return null

func get_talents_for_row(row: int) -> Array[TalentResource]:
	var result: Array[TalentResource] = []
	for talent in talents:
		if talent.row == row:
			result.append(talent)
	return result
