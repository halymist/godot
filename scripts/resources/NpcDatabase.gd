extends Resource
class_name NpcDatabase

@export var npcs: Array[NpcResource] = []

func get_npc_by_id(npc_id: int) -> NpcResource:
	for npc in npcs:
		if npc.id == npc_id:
			return npc
	return null

func get_npcs_for_location(building_id: int) -> Array[NpcResource]:
	var location_npcs: Array[NpcResource] = []
	for npc in npcs:
		if npc.building_id == building_id:
			location_npcs.append(npc)
	return location_npcs

func get_npcs_for_quests(quest_ids: Array, quest_log: Array, building_id: int) -> Array[NpcResource]:
	var visible_npcs: Array[NpcResource] = []
	
	for npc in npcs:
		# Only check NPCs in the current location
		if npc.building_id != building_id:
			continue
		
		# Check if any of the NPC's dialogues match the current quest state
		for dialogue in npc.dialogues:
			var quest_id = dialogue.questID
			var stage = dialogue.stage
			
			# Check if this dialogue matches current quest state
			if quest_id in quest_ids or _is_quest_at_stage(quest_log, quest_id, stage):
				visible_npcs.append(npc)
				break  # Found a matching dialogue, add NPC and move to next
	
	return visible_npcs

func _is_quest_at_stage(quest_log: Array, quest_id: int, stage: int) -> bool:
	for quest_entry in quest_log:
		if quest_entry.get("quest_id", 0) == quest_id:
			var slides = quest_entry.get("slides", [])
			return stage in slides
	return false
