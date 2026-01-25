extends Resource
class_name EnemyResource

@export var id: int = 0
@export var name: String = ""
@export var description: String = ""
@export var asset_id: int = 0  # Asset ID for texture lookup (not the texture itself)
@export var version: int = 0  # Data version for sync tracking

# Runtime-only (NOT persisted to .res file - loaded from user://images/)
var texture: Texture2D = null
