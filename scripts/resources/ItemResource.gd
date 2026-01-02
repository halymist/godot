extends Resource
class_name ItemResource

# Item type enum
enum ItemType {
	HEAD,
	CHEST,
	HANDS,
	FOOT,
	BELT,
	LEGS,
	RING,
	AMULET,
	WEAPON,
	GEM,
	POTION,
	ELIXIR,
	SCROLL,
	HAMMER,
	RATION,
	INGREDIENT
}

# Static item data that lives on the client
@export var id: int = 0
@export var item_name: String = ""
@export var type: ItemType = ItemType.HEAD
@export var armor: int = 0
@export var strength: int = 0
@export var stamina: int = 0
@export var agility: int = 0
@export var luck: int = 0
@export var damage_min: int = 0
@export var damage_max: int = 0
@export var effect_id: int = 0  # References EffectResource by ID (0 if no effect)
@export var effect_factor: int = 0  # Strength/magnitude of the effect
@export var price: int = 0
@export var has_socket: bool = false  # Whether item has a socket slot
@export var icon: Texture2D = null

# Helper function to get type as string (for compatibility with existing code)
func get_type_string() -> String:
	match type:
		ItemType.HEAD: return "Head"
		ItemType.CHEST: return "Chest"
		ItemType.HANDS: return "Hands"
		ItemType.FOOT: return "Foot"
		ItemType.BELT: return "Belt"
		ItemType.LEGS: return "Legs"
		ItemType.RING: return "Ring"
		ItemType.AMULET: return "Amulet"
		ItemType.WEAPON: return "Weapon"
		ItemType.GEM: return "Gem"
		ItemType.POTION: return "Potion"
		ItemType.ELIXIR: return "Elixir"
		ItemType.SCROLL: return "Scroll"
		ItemType.HAMMER: return "Hammer"
		ItemType.RATION: return "Ration"
		ItemType.INGREDIENT: return "Ingredient"
		_: return "Unknown"
