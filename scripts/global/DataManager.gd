extends Node

# ============================================
# DATA MANAGER AUTOLOAD
# ============================================
# Handles data versioning, downloading, and local storage
# Downloads data from server and caches in user:// as JSON
# GameInfo loads from cache instead of .tres files

const VERSIONS_FILE = "user://data_versions.cfg"
const CACHE_DIR = "user://data_cache/"

# Cache file paths
const EFFECTS_CACHE = CACHE_DIR + "effects.json"
const ITEMS_CACHE = CACHE_DIR + "items.json"
const PERKS_CACHE = CACHE_DIR + "perks.json"
const ENEMIES_CACHE = CACHE_DIR + "enemies.json"
const EXPEDITIONS_CACHE = CACHE_DIR + "expeditions.json"

# Signals
signal data_sync_completed(success: bool)

# Local version tracking
var local_versions: Dictionary = {
	"effects": 0,
	"items": 0,
	"perks": 0,
	"enemies": 0,
	"expeditions": 0
}

# Server versions (populated from login response)
var server_versions: Dictionary = {}

func _ready():
	print("[DataManager] Ready")
	_ensure_cache_dir()
	_load_local_versions()

func _ensure_cache_dir():
	"""Ensure cache directory exists"""
	var dir = DirAccess.open("user://")
	if dir and not dir.dir_exists("data_cache"):
		dir.make_dir("data_cache")

# ============================================
# VERSION MANAGEMENT
# ============================================

func _load_local_versions():
	"""Load local data versions from config file"""
	var config = ConfigFile.new()
	var err = config.load(VERSIONS_FILE)
	
	if err != OK:
		print("[DataManager] No local versions file, using defaults (all 0)")
		_save_local_versions()
		return
	
	for key in local_versions.keys():
		local_versions[key] = config.get_value("versions", key, 0)
	
	print("[DataManager] Loaded local versions: ", local_versions)

func _save_local_versions():
	"""Save local data versions to config file"""
	var config = ConfigFile.new()
	
	for key in local_versions.keys():
		config.set_value("versions", key, local_versions[key])
	
	var err = config.save(VERSIONS_FILE)
	if err != OK:
		print("[DataManager] Failed to save versions: ", err)
	else:
		print("[DataManager] Saved local versions: ", local_versions)

func set_local_version(data_type: String, version: int):
	"""Set local version for a data type and save"""
	local_versions[data_type] = version
	_save_local_versions()

# ============================================
# DATA SYNC
# ============================================

func sync_data(server_data_versions: Dictionary):
	"""Check and sync all data types with server versions"""
	server_versions = server_data_versions
	print("[DataManager] Server versions: ", server_versions)
	print("[DataManager] Local versions: ", local_versions)
	
	# Sync each data type
	# Note: Server may send "expedition" (singular) but we track as "expeditions" (plural)
	await _sync_data_type("effects", "/download-effects")
	await _sync_data_type("items", "/download-items")
	await _sync_data_type("perks", "/download-perks")
	await _sync_data_type("enemies", "/download-enemies")
	await _sync_data_type("expeditions", "/download-expedition")
	
	print("[DataManager] Data sync completed!")
	data_sync_completed.emit(true)

func _sync_data_type(data_type: String, endpoint: String):
	"""Sync a single data type if needed"""
	# Handle "expedition" vs "expeditions" naming mismatch from server
	var server_key = data_type
	if data_type == "expeditions":
		server_key = "expedition"  # Server sends singular form
	
	var server_version = server_versions.get(server_key, server_versions.get(data_type, 0))
	var local_version = local_versions.get(data_type, 0)
	
	if server_version > local_version:
		print("[DataManager] %s out of date (local: %d, server: %d)" % [data_type, local_version, server_version])
		await _download_data(data_type, endpoint, local_version)
	else:
		print("[DataManager] %s is up to date (version: %d)" % [data_type, local_version])

func _download_data(data_type: String, endpoint: String, local_version: int):
	"""Download data from server"""
	print("[DataManager] Downloading %s (version > %d)..." % [data_type, local_version])
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = Http.base_url + endpoint + "?version=" + str(local_version)
	print("[DataManager] GET ", url)
	
	var error = http_request.request(url, Http._get_headers(true), HTTPClient.METHOD_GET)
	
	if error != OK:
		print("[DataManager] Failed to send %s download request: %d" % [data_type, error])
		http_request.queue_free()
		return
	
	# Wait for response
	var result = await http_request.request_completed
	http_request.queue_free()
	
	var response_code = result[1]
	var body = result[3]
	
	if response_code != 200:
		print("[DataManager] %s download failed (HTTP %d)" % [data_type, response_code])
		return
	
	var body_text = body.get_string_from_utf8()
	print("[DataManager] %s response: %s..." % [data_type, body_text.substr(0, 200)])
	
	# Parse JSON
	var json = JSON.new()
	if json.parse(body_text) != OK:
		print("[DataManager] Failed to parse %s JSON" % data_type)
		return
	
	var data = json.get_data()
	if not data is Array:
		print("[DataManager] Invalid %s data format" % data_type)
		return
	
	# Save to cache and update version
	_save_to_cache(data_type, data)

func _save_to_cache(data_type: String, data: Array):
	"""Save downloaded data to JSON cache file"""
	var cache_path = _get_cache_path(data_type)
	
	# Load existing cache if present
	var existing_data = _load_cache_raw(data_type)
	
	# Merge new data with existing (update existing items, add new ones)
	var merged_data = _merge_data(data_type, existing_data, data)
	
	# Save merged data
	var file = FileAccess.open(cache_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(merged_data, "\t"))
		file.close()
		print("[DataManager] Saved %d %s to cache" % [merged_data.size(), data_type])
	else:
		print("[DataManager] Failed to save %s cache" % data_type)
		return
	
	# Update version to max version in data
	var max_version = _get_max_version(data_type, data)
	set_local_version(data_type, max_version)
	print("[DataManager] %s updated to version %d" % [data_type, max_version])

func _merge_data(data_type: String, existing: Array, new_data: Array) -> Array:
	"""Merge new data into existing, updating existing items by ID"""
	if existing.is_empty():
		return new_data
	
	var id_field = _get_id_field(data_type)
	
	# Create lookup by ID
	var existing_by_id = {}
	for item in existing:
		var item_id = item.get(id_field, 0)
		existing_by_id[item_id] = item
	
	# Update/add from new data
	for item in new_data:
		var item_id = item.get(id_field, 0)
		existing_by_id[item_id] = item  # Replace or add
	
	return existing_by_id.values()

func _get_id_field(data_type: String) -> String:
	"""Get the ID field name for a data type"""
	match data_type:
		"effects": return "effect_id"
		"items": return "item_id"
		"perks": return "perk_id"
		"enemies": return "enemy_id"
		"expeditions": return "slide_id"
		_: return "id"

func _get_max_version(data_type: String, data: Array) -> int:
	"""Get the maximum version from downloaded data"""
	var max_ver = local_versions.get(data_type, 0)
	for item in data:
		var ver = item.get("version", 0)
		if ver > max_ver:
			max_ver = ver
	return max_ver

func _get_cache_path(data_type: String) -> String:
	"""Get cache file path for a data type"""
	match data_type:
		"effects": return EFFECTS_CACHE
		"items": return ITEMS_CACHE
		"perks": return PERKS_CACHE
		"enemies": return ENEMIES_CACHE
		"expeditions": return EXPEDITIONS_CACHE
		_: return ""

func _load_cache_raw(data_type: String) -> Array:
	"""Load raw JSON array from cache file"""
	var cache_path = _get_cache_path(data_type)
	
	if not FileAccess.file_exists(cache_path):
		return []
	
	var file = FileAccess.open(cache_path, FileAccess.READ)
	if not file:
		return []
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) != OK:
		return []
	
	var data = json.get_data()
	return data if data is Array else []

# ============================================
# DATABASE LOADING (called by GameInfo)
# ============================================

func load_effects_database() -> EffectDatabase:
	"""Load effects from cache into EffectDatabase"""
	var db = EffectDatabase.new()
	var data = _load_cache_raw("effects")
	
	if data.is_empty():
		print("[DataManager] No effects cache, database will be empty")
		return db
	
	for item in data:
		var effect = EffectResource.new()
		effect.id = item.get("effect_id", 0)
		effect.name = item.get("name", "")
		effect.description = item.get("description", "")
		effect.slot = item.get("slot", 0)
		effect.factor = item.get("factor", 0)
		db.effects.append(effect)
	
	print("[DataManager] Loaded %d effects from cache" % db.effects.size())
	return db

func load_items_database() -> ItemDatabase:
	"""Load items from cache into ItemDatabase"""
	var db = ItemDatabase.new()
	var data = _load_cache_raw("items")
	
	if data.is_empty():
		print("[DataManager] No items cache, database will be empty")
		return db
	
	for item in data:
		var res = ItemResource.new()
		res.id = item.get("item_id", 0)
		res.item_name = item.get("item_name", "")
		res.type = item.get("type", 0)
		res.strength = item.get("strength", 0)
		res.stamina = item.get("stamina", 0)
		res.agility = item.get("agility", 0)
		res.luck = item.get("luck", 0)
		res.armor = item.get("armor", 0)
		res.damage_min = item.get("min_damage", 0)
		res.damage_max = item.get("max_damage", 0)
		res.effect_id = item.get("effect_id", 0)
		res.effect_factor = item.get("effect_factor", 0)
		res.has_socket = item.get("socket", false)
		res.price = item.get("silver", 0)
		# Note: icon/texture loaded separately by asset_id if needed
		db.items.append(res)
	
	print("[DataManager] Loaded %d items from cache" % db.items.size())
	return db

func load_perks_database() -> PerkDatabase:
	"""Load perks from cache into PerkDatabase"""
	var db = PerkDatabase.new()
	var data = _load_cache_raw("perks")
	
	if data.is_empty():
		print("[DataManager] No perks cache, database will be empty")
		return db
	
	for item in data:
		var perk = PerkResource.new()
		perk.id = item.get("perk_id", 0)
		perk.perk_name = item.get("perk_name", "")
		perk.description = item.get("description", "")
		perk.effect1_id = item.get("effect_id_1", 0)
		perk.factor1 = item.get("factor_1", 0.0)
		perk.effect2_id = item.get("effect_id_2", 0)
		perk.factor2 = item.get("factor_2", 0.0)
		# Note: icon loaded separately by asset_id if needed
		db.perks.append(perk)
	
	print("[DataManager] Loaded %d perks from cache" % db.perks.size())
	return db

func load_enemies_database() -> EnemyDatabase:
	"""Load enemies from cache into EnemyDatabase"""
	var db = EnemyDatabase.new()
	var data = _load_cache_raw("enemies")
	
	if data.is_empty():
		print("[DataManager] No enemies cache, database will be empty")
		return db
	
	for item in data:
		var enemy = EnemyResource.new()
		enemy.id = item.get("enemy_id", 0)
		enemy.name = item.get("enemy_name", "")
		enemy.description = item.get("description", "")
		# Note: texture loaded separately by asset_id if needed
		db.enemies.append(enemy)
	
	print("[DataManager] Loaded %d enemies from cache" % db.enemies.size())
	return db

func load_expeditions_database() -> ExpeditionsDatabase:
	"""Load expedition slides from cache into ExpeditionsDatabase"""
	var db = ExpeditionsDatabase.new()
	var data = _load_cache_raw("expeditions")
	
	if data.is_empty():
		print("[DataManager] No expeditions cache, database will be empty")
		return db
	
	for item in data:
		var slide = ExpeditionSlide.new()
		slide.slide_id = item.get("slide_id", 0)
		slide.text = item.get("slide_text", "")
		# Map server reward fields to slide reward
		slide.reward_type = _map_expedition_reward_type(item)
		slide.reward_amount = _get_expedition_reward_amount(item)
		# Note: texture loaded separately by asset_id if needed
		# Note: options are not stored in DB, they come from server at runtime
		db.slides.append(slide)
	
	print("[DataManager] Loaded %d expedition slides from cache" % db.slides.size())
	return db

func _map_expedition_reward_type(item: Dictionary) -> int:
	"""Map server expedition reward fields to RewardType enum"""
	if item.get("reward_stat_type", 0) > 0:
		# Map stat types: 1=str, 2=sta, 3=agi, 4=luck, etc.
		var stat_type = item.get("reward_stat_type", 0)
		match stat_type:
			1: return 4  # STRENGTH
			2: return 5  # STAMINA
			3: return 6  # AGILITY
			4: return 7  # LUCK
			_: return 0
	elif item.get("reward_item", 0) > 0:
		return 2  # ITEM
	elif item.get("reward_perk", 0) > 0:
		return 3  # PERK
	elif item.get("reward_talent", 0) > 0:
		return 17  # TALENT_POINT
	elif item.get("reward_blessing", 0) > 0:
		return 19  # BLESSING
	elif item.get("reward_potion", 0) > 0:
		return 18  # POTION
	return 0  # NONE

func _get_expedition_reward_amount(item: Dictionary) -> int:
	"""Get expedition reward amount from server data"""
	if item.get("reward_stat_amount", 0) > 0:
		return item.get("reward_stat_amount", 0)
	elif item.get("reward_item", 0) > 0:
		return item.get("reward_item", 0)
	elif item.get("reward_perk", 0) > 0:
		return item.get("reward_perk", 0)
	elif item.get("reward_talent", 0) > 0:
		return item.get("reward_talent", 0)
	elif item.get("reward_blessing", 0) > 0:
		return item.get("reward_blessing", 0)
	elif item.get("reward_potion", 0) > 0:
		return item.get("reward_potion", 0)
	return 0

# ============================================
# CACHE STATUS
# ============================================

func has_cache(data_type: String) -> bool:
	"""Check if cache exists for a data type"""
	var cache_path = _get_cache_path(data_type)
	return FileAccess.file_exists(cache_path)

func has_all_caches() -> bool:
	"""Check if all required caches exist"""
	return has_cache("effects") and has_cache("items") and has_cache("perks") and has_cache("enemies") and has_cache("expeditions")
