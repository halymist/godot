class_name Player
extends RefCounted

# Base Player class - contains fields shared between CurrentPlayer and ArenaOpponent
# This corresponds to the core fields in your Go structs

var character_id: int = 0      # characterID in Go
var name: String = ""          # Name in Go  
var strength: int = 0          # Strength in Go
var constitution: int = 0      # Constitution in Go
var dexterity: int = 0         # Dexterity in Go
var luck: int = 0              # Luck in Go
var armor: int = 0             # Armor in Go
var bag_slots: Array = []      # BagSlots in Go
var perks: Array = []          # Perks in Go  
var talents: Array = []        # Talents in Go

# MessagePack field mappings - corresponds to Go struct tags
const MSGPACK_FIELDS = {
	"character_id": "characterID",
	"name": "name", 
	"strength": "strength",
	"constitution": "constitution",
	"dexterity": "dexterity",
	"luck": "luck",
	"armor": "armor",
	"bag_slots": "bagSlots",
	"perks": "perks",
	"talents": "talents"
}
	"luck": "luck",
	"armor": "armor",
	"bag_slots": "bagSlots",
	"perks": "perks",
	"talents": "talents"
}

func _init():
	# Base constructor - child classes will call this

# Load from MessagePack format (matches Go struct tags)
func load_from_msgpack(msgpack_data: Dictionary):
	character_id = msgpack_data.get("characterID", 0)
	name = msgpack_data.get("name", "")
	strength = msgpack_data.get("strength", 0)
	constitution = msgpack_data.get("constitution", 0)
	dexterity = msgpack_data.get("dexterity", 0)
	luck = msgpack_data.get("luck", 0)
	armor = msgpack_data.get("armor", 0)
	
	load_items(msgpack_data.get("bagSlots", []))
	load_perks(msgpack_data.get("perks", []))
	load_talents(msgpack_data.get("talents", []))

func load_items(items_data: Array):
	bag_slots = []
	for item_data in items_data:
		var item = {
			"id": item_data.get("id", 0),
			"bag_slot_id": item_data.get("bag_slot_id", 0),
			"item_name": item_data.get("item_name", ""),
			"type": item_data.get("type", ""),
			"subtype": item_data.get("subtype", ""),
			"armor": item_data.get("armor", 0),
			"strength": item_data.get("strength", 0),
			"constitution": item_data.get("constitution", 0),
			"dexterity": item_data.get("dexterity", 0),
			"luck": item_data.get("luck", 0),
			"damage_min": item_data.get("damage_min", 0),
			"damage_max": item_data.get("damage_max", 0),
			"asset_id": item_data.get("asset_id", 0),
			"effect_name": item_data.get("effect_name", ""),
			"effect_description": item_data.get("effect_description", ""),
			"effect_factor": item_data.get("effect_factor", 0.0),
			"quality": item_data.get("quality", 1),
			"price": item_data.get("price", 0)
		}
		if GameInfo:
			item["texture"] = GameInfo.get_fallback_texture(item["asset_id"])
		bag_slots.append(item)

func load_perks(perks_data: Array):
	perks = []
	for perk_data in perks_data:
		var perk = {
			"perk_name": perk_data.get("perk_name", ""),
			"active": perk_data.get("active", false),
			"description": perk_data.get("description", ""),
			"asset_id": perk_data.get("asset_id", 0),
			"slot": perk_data.get("slot", 0),
			"effect1": perk_data.get("effect1", ""),
			"factor1": perk_data.get("factor1", 0.0),
			"effect2": perk_data.get("effect2", ""),
			"factor2": perk_data.get("factor2", 0.0)
		}
		if GameInfo:
			perk["texture"] = GameInfo.get_fallback_texture(perk["asset_id"])
		perks.append(perk)

func load_talents(talents_data: Array):
	talents = []
	for talent_data in talents_data:
		var talent = {
			"talent_id": talent_data.get("talent_id", 0),
			"points": talent_data.get("points", 0)
		}
		talents.append(talent)

func get_base_stats() -> Dictionary:
	return {
		"name": name,
		"strength": strength,
		"stamina": constitution,  # Map constitution to stamina for UI
		"agility": dexterity,     # Map dexterity to agility for UI
		"luck": luck,
		"armor": armor
	}

func get_total_stats() -> Dictionary:
	var base_stats = get_base_stats()
	var total_stats = base_stats.duplicate()
	
	# Initialize totals with base stats
	total_stats.strength = int(base_stats.strength)
	total_stats.stamina = int(base_stats.stamina)
	total_stats.agility = int(base_stats.agility)
	total_stats.luck = int(base_stats.luck)
	total_stats.armor = int(base_stats.armor)
	
	# Add stats from equipped items (slots 0-9)
	for item in bag_slots:
		var slot_id = int(item.get("bag_slot_id", -1))
		if slot_id >= 0 and slot_id < 10:
			total_stats.strength += int(item.get("strength", 0))
			total_stats.stamina += int(item.get("constitution", 0))
			total_stats.agility += int(item.get("dexterity", 0))
			total_stats.luck += int(item.get("luck", 0))
			total_stats.armor += int(item.get("armor", 0))
	
	return total_stats
