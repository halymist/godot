extends Resource
class_name EffectResource

# Equipment slot enum for effects (only the 8 equipment types)
enum EffectSlot {
	ANY,      # Can be applied to any equipment
	HEAD,
	CHEST,
	HANDS,
	FOOT,
	BELT,
	LEGS,
	RING,
	AMULET,
	WEAPON
}

# Static effect data that lives on the client
@export var id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var slot: EffectSlot = EffectSlot.ANY  # Equipment slot restriction
@export var factor: int = 0  # Enchanting factor (client-side)
@export var icon: Texture2D = null

# Helper function to get slot as string (for compatibility with existing code)
func get_slot_string() -> String:
	match slot:
		EffectSlot.ANY: return ""
		EffectSlot.HEAD: return "Head"
		EffectSlot.CHEST: return "Chest"
		EffectSlot.HANDS: return "Hands"
		EffectSlot.FOOT: return "Foot"
		EffectSlot.BELT: return "Belt"
		EffectSlot.LEGS: return "Legs"
		EffectSlot.RING: return "Ring"
		EffectSlot.AMULET: return "Amulet"
		EffectSlot.WEAPON: return "Weapon"
		_: return ""

