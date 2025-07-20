class_name ArenaOpponent
extends Player

# ArenaOpponent matches the Go struct exactly:
# type ArenaOpponent struct {
#   characterID  int
#   Name         string    `msgpack:"name"`
#   Strength     int       `msgpack:"strength"`
#   Constitution int       `msgpack:"constitution"`
#   Dexterity    int       `msgpack:"dexterity"`
#   Luck         int       `msgpack:"luck"`
#   Armor        int       `msgpack:"armor"`
#   BagSlots     []Item    `msgpack:"bagSlots"`
#   Perks        []Perk    `msgpack:"perks"`
#   Talents      []Talent  `msgpack:"talents"`
#   TimeStamp    time.Time `msgpack:"-"`
# }

var timestamp: String = ""  # Store as string since we can't use time.Time directly

func _init():
	super()  # Call parent constructor

# This loads directly from MessagePack data that matches the Go struct
func load_from_msgpack(msgpack_data: Dictionary):
	# Call parent's load_from_msgpack to handle all the shared fields
	super.load_from_msgpack(msgpack_data)
	
	# ArenaOpponent doesn't have additional fields beyond what Player has
	# The timestamp field is ignored in MessagePack (msgpack:"-" in Go)
	
	print("ArenaOpponent loaded:")
	print("  characterID: ", character_id)
	print("  name: ", name)
	print("  strength: ", strength)
	print("  constitution: ", constitution)
	print("  dexterity: ", dexterity)
	print("  luck: ", luck)
	print("  armor: ", armor)
	print("  bagSlots: ", bag_slots.size())
	print("  perks: ", perks.size())
	print("  talents: ", talents.size())

# ArenaOpponent is static data - no need for update methods or signals
# It's just used for comparison/combat calculations
