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

func get_npcs_for_quests(quest_ids: Array, _quest_log: Array, building_id: int) -> Array[NpcResource]:
	var visible_npcs: Array[NpcResource] = []
	
	print("=== NpcDatabase.get_npcs_for_quests ===")
	print("Quest IDs: ", quest_ids)
	print("Building ID: ", building_id)
	print("Total NPCs in database: ", npcs.size())
	
	for npc in npcs:
		print("Checking NPC: ", npc.name, " (building_id=", npc.building_id, ")")
		
		# Only check NPCs in the current location
		if npc.building_id != building_id:
			print("  Skipping - wrong building")
			continue
		
		# Check if NPC has quest dialogues for any daily quest
		print("  Checking quest dialogues...")
		print("  quest_dialogues array size: ", npc.quest_dialogues.size())
		
		for quest_id in quest_ids:
			var quest_dialogue = npc.get_quest_dialogue(quest_id)
			if quest_dialogue:
				print("  Found matching quest dialogue for quest ", quest_id)
				visible_npcs.append(npc)
				break  # Found a matching quest, add NPC and move to next
			else:
				print("  No quest dialogue for quest ", quest_id)
	
	print("Returning ", visible_npcs.size(), " NPCs")
	return visible_npcs
