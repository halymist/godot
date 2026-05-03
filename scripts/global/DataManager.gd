extends Node

# ============================================
# DATA MANAGER AUTOLOAD (JSON-based)
# ============================================
# Handles data versioning and downloading
# Stores data as JSON files, creates database objects at runtime
# Assets are downloaded and stored in user:// then applied as textures

const VERSIONS_FILE = "user://data_versions.cfg"
const LOCAL_VERSIONS_SCHEMA = 4
const IMAGES_DIR = "user://images/"
const DATA_DIR = "user://data/"

# Asset base URL
const ASSETS_BASE_URL = "https://pub-b959ac8ae579488bb4ed33c01a618ae2.r2.dev/images/"

# JSON data file paths
const EFFECTS_JSON = "user://data/effects.json"
const ITEMS_JSON = "user://data/items.json"
const PERKS_JSON = "user://data/perks.json"
const ENEMIES_JSON = "user://data/enemies.json"
const EXPEDITIONS_JSON = "user://data/expeditions.json"
const SETTLEMENTS_JSON = "user://data/settlements.json"
const TALENTS_JSON = "user://data/talents.json"
const QUESTS_JSON = "user://data/quests.json"
const COSMETICS_JSON = "user://data/cosmetics.json"

# Signals
signal data_sync_completed(success: bool)
signal asset_downloaded(type: String, asset_id: int)

# Loaded databases (created from JSON at runtime)
var effects_db: EffectDatabase = null
var items_db: ItemDatabase = null
var perks_db: PerkDatabase = null
var enemies_db: EnemyDatabase = null
var expeditions_db: ExpeditionsDatabase = null
var settlements_db: SettlementsDatabase = null
var talents_db: TalentsDatabase = null
var quests_db: QuestsDatabase = null
var cosmetics_db: CosmeticDatabase = null

# Local version tracking
var local_versions: Dictionary = {
	"effects": 0,
	"items": 0,
	"perks": 0,
	"enemies": 0,
	"expeditions": 0,
	"settlements": 0,
	"talents": 0,
	"quests": 0,
	"cosmetics": 0
}

# Server versions (populated from login response)
var server_versions: Dictionary = {}

# Track pending asset downloads
var _pending_downloads: int = 0
# Track already-queued downloads to avoid duplicates (folder/asset_id -> true)
var _queued_downloads: Dictionary = {}

func _ready():
	print("[DataManager] Ready")
	_ensure_cache_dirs()
	_load_local_versions()

func _ensure_cache_dirs():
	"""Ensure cache directories exist"""
	DirAccess.make_dir_recursive_absolute("user://images/items")
	DirAccess.make_dir_recursive_absolute("user://images/perks")
	DirAccess.make_dir_recursive_absolute("user://images/enemies")
	DirAccess.make_dir_recursive_absolute("user://images/quests")
	DirAccess.make_dir_recursive_absolute("user://images/expedition-maps")
	DirAccess.make_dir_recursive_absolute("user://images/settlements")
	DirAccess.make_dir_recursive_absolute("user://images/cosmetics")
	DirAccess.make_dir_recursive_absolute("user://data")
	print("[DataManager] Created cache directories")

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

	# One-time migrations for local cached version values.
	var schema_version = int(config.get_value("meta", "schema_version", 0))
	var did_migrate = false

	# Migration v1: talents payload switched to ordered entries without row/col fields.
	if schema_version < 1:
		local_versions["talents"] = 0
		did_migrate = true
		print("[DataManager] Applying schema migration 1: reset talents version to 0")

	# Migration v2: force items redownload.
	if schema_version < 2:
		local_versions["items"] = 0
		did_migrate = true
		print("[DataManager] Applying schema migration 2: reset items version to 0")

	# Migration v3: expeditions switched from slides/options to graph map payloads.
	if schema_version < 3:
		local_versions["expeditions"] = 0
		did_migrate = true
		print("[DataManager] Applying schema migration 3: reset expeditions version to 0")

	# Migration v4: force quest redownload to include expedition-node quest additions.
	if schema_version < 4:
		local_versions["quests"] = 0
		did_migrate = true
		print("[DataManager] Applying schema migration 4: reset quests version to 0")

	# Persist migrated schema + versions once.
	if did_migrate:
		_save_local_versions()

	# Backward compatibility guard if constant is increased in future.
	if schema_version < LOCAL_VERSIONS_SCHEMA:
		print("[DataManager] Schema version updated from %d to %d" % [schema_version, LOCAL_VERSIONS_SCHEMA])
	
	print("[DataManager] Loaded local versions: ", local_versions)

func _save_local_versions():
	"""Save local data versions to config file"""
	var config = ConfigFile.new()
	
	for key in local_versions.keys():
		config.set_value("versions", key, local_versions[key])

	config.set_value("meta", "schema_version", LOCAL_VERSIONS_SCHEMA)
	
	var err = config.save(VERSIONS_FILE)
	if err != OK:
		print("[DataManager] Failed to save versions: ", err)
	else:
		print("[DataManager] Saved local versions: ", local_versions)

func set_local_version(data_type: String, version: int):
	"""Set local version for a data type and save"""
	local_versions[data_type] = version
	_save_local_versions()

func reset_all_versions():
	"""Reset all local versions to 0 to force re-download"""
	for key in local_versions.keys():
		local_versions[key] = 0
	_save_local_versions()
	print("[DataManager] Reset all versions to 0")

func clear_all_cache():
	"""Clear all cached images, JSON data, and reset versions"""
	reset_all_versions()
	
	# Delete image folders
	for folder in ["items", "perks", "enemies", "expedition", "settlements", "cosmetics"]:
		var folder_path = IMAGES_DIR + folder
		var dir = DirAccess.open(folder_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not dir.current_is_dir():
					dir.remove(file_name)
				file_name = dir.get_next()
			dir.list_dir_end()
	
	# Delete JSON data files
	for json_path in [EFFECTS_JSON, ITEMS_JSON, PERKS_JSON, ENEMIES_JSON, EXPEDITIONS_JSON, SETTLEMENTS_JSON, TALENTS_JSON, QUESTS_JSON, COSMETICS_JSON]:
		if FileAccess.file_exists(json_path):
			DirAccess.remove_absolute(json_path)
	
	# Clear databases
	effects_db = null
	items_db = null
	perks_db = null
	enemies_db = null
	expeditions_db = null
	settlements_db = null
	talents_db = null
	quests_db = null
	cosmetics_db = null
	
	print("[DataManager] Cleared all cache")

# ============================================
# DATA SYNC
# ============================================

func needs_download(server_data_versions: Dictionary) -> bool:
	"""Check if any data needs to be downloaded"""
	for data_type in local_versions.keys():
		var server_key = _get_server_key(data_type)
		var server_version = server_data_versions.get(server_key, 0)
		var local_version = local_versions.get(data_type, 0)
		
		if server_version > local_version:
			return true
	
	return false

func _get_server_key(data_type: String) -> String:
	"""Map local data type to server version key"""
	match data_type:
		"expeditions": return "expedition"
		"settlements": return "world"
		_: return data_type

func sync_data(server_data_versions: Dictionary):
	"""Download all data types and assets, waits until complete"""
	server_versions = server_data_versions
	_queued_downloads.clear()
	print("[DataManager] Server versions: ", server_versions)
	print("[DataManager] Local versions: ", local_versions)
	
	# Sync each data type
	await _sync_data_type("effects", "/download-effects")
	await _sync_data_type("items", "/download-items")
	await _sync_data_type("perks", "/download-perks")
	await _sync_data_type("enemies", "/download-enemies")
	await _sync_data_type("expeditions", "/download-expedition")
	await _sync_data_type("settlements", "/download-world")
	await _sync_data_type("talents", "/download-talents")
	await _sync_data_type("quests", "/download-quests")
	await _sync_data_type("cosmetics", "/download-cosmetics")
	
	print("[DataManager] Data sync completed!")
	
	# Wait for all asset downloads to complete
	while _pending_downloads > 0:
		print("[DataManager] Waiting for %d asset downloads..." % _pending_downloads)
		await get_tree().create_timer(0.1).timeout
	
	print("[DataManager] All downloads (data + assets) completed!")
	data_sync_completed.emit(true)

func _sync_data_type(data_type: String, endpoint: String):
	"""Sync a single data type if needed"""
	var server_key = _get_server_key(data_type)
	var server_version = server_versions.get(server_key, 0)
	var local_version = local_versions.get(data_type, 0)
	
	if server_version > local_version:
		print("[DataManager] %s out of date (local: %d, server: %d)" % [data_type, local_version, server_version])
		await _download_data(data_type, endpoint, local_version)
	else:
		print("[DataManager] %s is up to date (version: %d)" % [data_type, local_version])

func _download_data(data_type: String, endpoint: String, local_version: int):
	"""Download data from server and save as JSON"""
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
	
	var result = await http_request.request_completed
	http_request.queue_free()
	
	var response_code = result[1]
	var body = result[3]
	
	if response_code != 200:
		print("[DataManager] %s download failed (HTTP %d)" % [data_type, response_code])
		return
	
	var body_text = body.get_string_from_utf8()
	print("[DataManager] %s response: %s..." % [data_type, body_text.substr(0, 200)])
	
	var json = JSON.new()
	if json.parse(body_text) != OK:
		print("[DataManager] Failed to parse %s JSON" % data_type)
		return
	
	var data = json.get_data()
	
	# Get version and items from response
	var new_version = 0
	var items_data = []
	var deleted_ids = []
	var deleted_node_ids = []
	var deleted_edge_ids = []
	
	if data is Dictionary:
		new_version = data.get("version", 0)
		# Different endpoints use different array keys
		match data_type:
			"expeditions":
				items_data = data.get("expeditions", [])
				deleted_ids = data.get("deleted_expedition_ids", [])
				deleted_node_ids = data.get("deleted_node_ids", [])
				deleted_edge_ids = data.get("deleted_edge_ids", [])
			"settlements": items_data = data.get("settlements", [])
			"talents": items_data = data.get("talents", [])
			"quests": items_data = data.get("quests", [])
			_: items_data = data.get(data_type, data)
	elif data is Array:
		items_data = data
		# Get max version from items
		for item in data:
			new_version = max(new_version, item.get("version", 0))
	
	# Merge with existing data and save
	_merge_and_save_json(data_type, items_data, new_version, deleted_ids, deleted_node_ids, deleted_edge_ids)
	
	# Download assets for types that have images
	if data_type in ["items", "perks", "enemies"]:
		_download_assets_for_data(data_type, items_data)
	elif data_type == "expeditions":
		_download_expedition_map_assets(items_data)
	elif data_type == "quests":
		_download_quest_assets(items_data)  # Quests also use quests folder
	elif data_type == "settlements":
		_download_settlement_assets(items_data)
	elif data_type == "cosmetics":
		_download_cosmetic_assets(items_data)

func _merge_and_save_json(data_type: String, new_data: Array, new_version: int, deleted_ids: Array = [], deleted_node_ids: Array = [], deleted_edge_ids: Array = []):
	"""Merge new data with existing JSON and save"""
	var json_path = _get_json_path(data_type)
	var id_field = _get_id_field(data_type)
	
	# Load existing data
	var existing_data = _load_json_file(json_path)

	# Deterministic merge that preserves array ordering.
	var deleted_lookup: Dictionary = {}
	for del_id in deleted_ids:
		deleted_lookup[int(del_id)] = true

	var incoming_by_id: Dictionary = {}
	for new_item in new_data:
		incoming_by_id[new_item.get(id_field, 0)] = new_item

	var merged_data: Array = []
	var existing_ids: Dictionary = {}

	# Keep existing order, but overwrite entries that arrived in the delta.
	for item in existing_data:
		var item_id = item.get(id_field, 0)
		existing_ids[item_id] = true

		if deleted_lookup.has(item_id):
			continue

		if incoming_by_id.has(item_id):
			merged_data.append(incoming_by_id[item_id])
		else:
			merged_data.append(item)

	# Append truly new IDs in server-provided order.
	for new_item in new_data:
		var item_id = new_item.get(id_field, 0)
		if deleted_lookup.has(item_id):
			continue
		if not existing_ids.has(item_id):
			merged_data.append(new_item)
	
	if data_type == "expeditions":
		_apply_expedition_child_deletions(merged_data, deleted_node_ids, deleted_edge_ids)

	# Save merged data
	_save_json_file(json_path, merged_data)
	
	# Update version
	set_local_version(data_type, new_version)
	print("[DataManager] %s saved (version %d, %d items)" % [data_type, new_version, merged_data.size()])

func _apply_expedition_child_deletions(expeditions_data: Array, deleted_node_ids: Array, deleted_edge_ids: Array):
	var deleted_node_lookup: Dictionary = {}
	for node_id in deleted_node_ids:
		deleted_node_lookup[int(node_id)] = true

	var deleted_edge_lookup: Dictionary = {}
	for edge_id in deleted_edge_ids:
		deleted_edge_lookup[int(edge_id)] = true

	if deleted_node_lookup.is_empty() and deleted_edge_lookup.is_empty():
		return

	for expedition in expeditions_data:
		if not expedition is Dictionary:
			continue

		if expedition.has("nodes") and expedition.nodes is Array:
			var kept_nodes: Array = []
			for node in expedition.nodes:
				if not deleted_node_lookup.has(int(node.get("node_id", 0))):
					kept_nodes.append(node)
			expedition["nodes"] = kept_nodes

		if expedition.has("edges") and expedition.edges is Array:
			var kept_edges: Array = []
			for edge in expedition.edges:
				if deleted_edge_lookup.has(int(edge.get("edge_id", 0))):
					continue
				if deleted_node_lookup.has(int(edge.get("node_a", 0))) or deleted_node_lookup.has(int(edge.get("node_b", 0))):
					continue
				kept_edges.append(edge)
			expedition["edges"] = kept_edges

func _get_json_path(data_type: String) -> String:
	"""Get JSON file path for data type"""
	match data_type:
		"effects": return EFFECTS_JSON
		"items": return ITEMS_JSON
		"perks": return PERKS_JSON
		"enemies": return ENEMIES_JSON
		"expeditions": return EXPEDITIONS_JSON
		"settlements": return SETTLEMENTS_JSON
		"talents": return TALENTS_JSON
		"quests": return QUESTS_JSON
		"cosmetics": return COSMETICS_JSON
		_: return ""

func _get_id_field(data_type: String) -> String:
	"""Get ID field name for data type"""
	match data_type:
		"effects": return "effect_id"
		"items": return "item_id"
		"perks": return "perk_id"
		"enemies": return "enemy_id"
		"expeditions": return "expedition_id"
		"settlements": return "settlement_id"
		"talents": return "talent_id"
		"quests": return "quest_id"
		"cosmetics": return "id"
		_: return "id"

func _load_json_file(path: String) -> Array:
	"""Load JSON array from file, returns empty array if not found"""
	if not FileAccess.file_exists(path):
		return []
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return []
	
	var content = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(content) != OK:
		print("[DataManager] Failed to parse JSON: %s" % path)
		return []
	
	var data = json.get_data()
	return data if data is Array else []

func _save_json_file(path: String, data: Array):
	"""Save array as JSON file"""
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		print("[DataManager] Failed to open for writing: %s" % path)
		return
	
	file.store_string(JSON.stringify(data, "\t"))
	file.close()

# ============================================
# DATABASE LOADING (from JSON)
# ============================================

func load_databases():
	"""Load all databases from JSON files"""
	effects_db = _load_effects_database()
	items_db = _load_items_database()
	perks_db = _load_perks_database()
	enemies_db = _load_enemies_database()
	expeditions_db = _load_expeditions_database()
	settlements_db = _load_settlements_database()
	talents_db = _load_talents_database()
	quests_db = _load_quests_database()
	cosmetics_db = _load_cosmetics_database()
	print("[DataManager] All databases loaded from JSON")
	
	# Verify assets exist on disk and re-download any missing ones
	_verify_and_repair_assets()

func _load_effects_database() -> EffectDatabase:
	"""Create EffectDatabase from JSON"""
	var db = EffectDatabase.new()
	var data = _load_json_file(EFFECTS_JSON)
	
	for item in data:
		var effect = EffectResource.new()
		effect.id = item.get("effect_id", 0)
		effect.name = item.get("name", "")
		effect.description = item.get("description", "")
		effect.slot = item.get("slot", 0)
		effect.factor = item.get("factor", 0)
		db.effects.append(effect)
	
	print("[DataManager] Loaded %d effects" % db.effects.size())
	return db

func _load_items_database() -> ItemDatabase:
	"""Create ItemDatabase from JSON"""
	var db = ItemDatabase.new()
	var data = _load_json_file(ITEMS_JSON)
	
	for item in data:
		var res = ItemResource.new()
		res.id = item.get("item_id", 0)
		res.item_name = item.get("item_name", "")
		res.type = _map_item_type_to_enum(item.get("type", ""))
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
		res.asset_id = int(item.get("asset_id", 0))
		
		# Load texture from cache
		if res.asset_id > 0:
			res.icon = load_asset_texture("items", res.asset_id)
		
		db.items.append(res)
	
	print("[DataManager] Loaded %d items" % db.items.size())
	return db

func _load_perks_database() -> PerkDatabase:
	"""Create PerkDatabase from JSON"""
	var db = PerkDatabase.new()
	var data = _load_json_file(PERKS_JSON)
	
	for item in data:
		var perk = PerkResource.new()
		perk.id = item.get("perk_id", 0)
		perk.perk_name = item.get("perk_name", "")
		perk.description = item.get("description", "")
		perk.effect1_id = item.get("effect_id_1", 0)
		perk.factor1 = item.get("factor_1", 0.0)
		perk.effect2_id = item.get("effect_id_2", 0)
		perk.factor2 = item.get("factor_2", 0.0)
		perk.asset_id = int(item.get("asset_id", 0))
		perk.is_blessing = item.get("is_blessing", false)
		
		# Load texture from cache
		if perk.asset_id > 0:
			perk.icon = load_asset_texture("perks", perk.asset_id)
		
		db.perks.append(perk)
	
	print("[DataManager] Loaded %d perks" % db.perks.size())
	return db

func _load_enemies_database() -> EnemyDatabase:
	"""Create EnemyDatabase from JSON"""
	var db = EnemyDatabase.new()
	var data = _load_json_file(ENEMIES_JSON)
	
	for item in data:
		var enemy = EnemyResource.new()
		enemy.id = item.get("enemy_id", 0)
		enemy.name = item.get("enemy_name", "")
		enemy.description = item.get("description", "")
		enemy.asset_id = int(item.get("asset_id", 0))
		
		# Load texture from cache
		if enemy.asset_id > 0:
			enemy.texture = load_asset_texture("enemies", enemy.asset_id)
		
		db.enemies.append(enemy)
	
	print("[DataManager] Loaded %d enemies" % db.enemies.size())
	return db

func _load_expeditions_database() -> ExpeditionsDatabase:
	"""Create graph ExpeditionsDatabase from JSON"""
	var db = ExpeditionsDatabase.new()
	var data = _load_json_file(EXPEDITIONS_JSON)
	
	for item in data:
		var expedition = ExpeditionData.new()
		expedition.expedition_id = int(item.get("expedition_id", 0))
		expedition.settlement_id = int(item.get("settlement_id", 0))
		expedition.map_asset_id = int(item.get("map_asset_id", 0))
		expedition.version = int(item.get("version", 0))
		db.version = max(db.version, expedition.version)

		if expedition.map_asset_id > 0:
			expedition.map_texture = load_asset_texture("expedition-maps", expedition.map_asset_id)

		var nodes_data = item.get("nodes", [])
		for node_data in nodes_data:
			var node = load("res://scripts/resources/ExpeditionNode.gd").new()
			node.node_id = int(node_data.get("node_id", 0))
			node.quest_id = int(node_data.get("quest_id", 0))
			node.is_start = bool(node_data.get("is_start", false))
			node.pos_x = float(node_data.get("pos_x", 0.0))
			node.pos_y = float(node_data.get("pos_y", 0.0))
			node.label = str(node_data.get("label", ""))
			node.version = int(node_data.get("version", 0))
			expedition.nodes.append(node)

		var edges_data = item.get("edges", [])
		for edge_data in edges_data:
			var edge = load("res://scripts/resources/ExpeditionEdge.gd").new()
			edge.edge_id = int(edge_data.get("edge_id", 0))
			edge.node_a = int(edge_data.get("node_a", 0))
			edge.node_b = int(edge_data.get("node_b", 0))
			edge.version = int(edge_data.get("version", 0))
			expedition.edges.append(edge)

		db.expeditions.append(expedition)
	
	print("[DataManager] Loaded %d expeditions" % db.expeditions.size())
	return db

func _load_settlements_database() -> SettlementsDatabase:
	"""Create SettlementsDatabase from JSON"""
	var db = SettlementsDatabase.new()
	var data = _load_json_file(SETTLEMENTS_JSON)
	
	for item in data:
		var settlement = Settlement.new()
		settlement.settlement_id = item.get("settlement_id", 0)
		settlement.settlement_name = item.get("settlement_name", "")
		settlement.faction = item.get("faction", 0)
		settlement.description = item.get("description", "")
		settlement.settlement_asset_id = int(item.get("settlement_asset_id", 0))
		settlement.expedition_asset_id = int(item.get("expedition_asset_id", 0))
		settlement.expedition_description = item.get("expedition_description", "")
		settlement.arena_asset_id = int(item.get("arena_asset_id", 0))
		
		# Expedition failure text lines
		var failure_data = item.get("expedition_failure", [])
		if failure_data is Array:
			for line in failure_data:
				settlement.expedition_failure.append(str(line))
		
		# Vendor data
		var vendor_data = item.get("vendor", {})
		if vendor_data is Dictionary:
			settlement.vendor_asset_id = int(vendor_data.get("vendor_asset_id", 0))
			var vendor_msg_points = _extract_msg_rect_points(vendor_data.get("msg_rect", null))
			if vendor_msg_points.size() == 2:
				settlement.vendor_msg_bottom_left = vendor_msg_points[0]
				settlement.vendor_msg_bottom_right = vendor_msg_points[1]
			# Vendor on_entered, on_sold, on_bought arrays
			if vendor_data.has("on_entered") and vendor_data.on_entered is Array:
				for line in vendor_data.on_entered:
					settlement.vendor_on_entered.append(str(line))
			if vendor_data.has("on_sold") and vendor_data.on_sold is Array:
				for line in vendor_data.on_sold:
					settlement.vendor_on_sold.append(str(line))
			if vendor_data.has("on_bought") and vendor_data.on_bought is Array:
				for line in vendor_data.on_bought:
					settlement.vendor_on_bought.append(str(line))
		
		# Utility data
		var utility_data = item.get("utility", {})
		if utility_data is Dictionary:
			settlement.utility_type = utility_data.get("type", "")
			settlement.utility_asset_id = int(utility_data.get("utility_asset_id", 0))
			var utility_msg_points = _extract_msg_rect_points(utility_data.get("msg_rect", null))
			if utility_msg_points.size() == 2:
				settlement.utility_msg_bottom_left = utility_msg_points[0]
				settlement.utility_msg_bottom_right = utility_msg_points[1]
			# Utility on_entered, on_placed, on_action arrays
			if utility_data.has("on_entered") and utility_data.on_entered is Array:
				for line in utility_data.on_entered:
					settlement.utility_on_entered.append(str(line))
			if utility_data.has("on_placed") and utility_data.on_placed is Array:
				for line in utility_data.on_placed:
					settlement.utility_on_placed.append(str(line))
			if utility_data.has("on_action") and utility_data.on_action is Array:
				for line in utility_data.on_action:
					settlement.utility_on_action.append(str(line))
			# Church blessings
			settlement.blessing1 = utility_data.get("blessing1", 0)
			settlement.blessing2 = utility_data.get("blessing2", 0)
			settlement.blessing3 = utility_data.get("blessing3", 0)
		
		# Load textures from cache
		if settlement.settlement_asset_id > 0:
			settlement.settlement_texture = load_asset_texture("settlements", settlement.settlement_asset_id)
		if settlement.expedition_asset_id > 0:
			settlement.expedition_texture = load_asset_texture("settlements", settlement.expedition_asset_id)
		if settlement.vendor_asset_id > 0:
			settlement.vendor_texture = load_asset_texture("settlements", settlement.vendor_asset_id)
		if settlement.utility_asset_id > 0:
			settlement.utility_texture = load_asset_texture("settlements", settlement.utility_asset_id)
		if settlement.arena_asset_id > 0:
			settlement.arena_background = load_asset_texture("settlements", settlement.arena_asset_id)
		
		db.settlements.append(settlement)
	
	print("[DataManager] Loaded %d settlements" % db.settlements.size())
	return db

func _extract_msg_rect_points(raw_msg_rect: Variant) -> Array[Vector2]:
	"""Parse msg_rect payload into [bottom_left, bottom_right] local points.
	Accepts multiple payload shapes for server compatibility."""
	var points: Array[Vector2] = []

	if raw_msg_rect == null:
		return points

	# Shape 1: [{x,y},{x,y}] or [[x,y],[x,y]]
	if raw_msg_rect is Array and raw_msg_rect.size() >= 2:
		var p0 = raw_msg_rect[0]
		var p1 = raw_msg_rect[1]

		if p0 is Dictionary and p1 is Dictionary:
			points.append(Vector2(float(p0.get("x", 0.0)), float(p0.get("y", 0.0))))
			points.append(Vector2(float(p1.get("x", 0.0)), float(p1.get("y", 0.0))))
			return points

		if p0 is Array and p0.size() >= 2 and p1 is Array and p1.size() >= 2:
			points.append(Vector2(float(p0[0]), float(p0[1])))
			points.append(Vector2(float(p1[0]), float(p1[1])))
			return points

	# Shape 2: {x1,y1,x2,y2} or {left,bottom,right,bottom2}
	if raw_msg_rect is Dictionary:
		var d = raw_msg_rect
		if d.has("x1") and d.has("y1") and d.has("x2") and d.has("y2"):
			points.append(Vector2(float(d.get("x1", 0.0)), float(d.get("y1", 0.0))))
			points.append(Vector2(float(d.get("x2", 0.0)), float(d.get("y2", 0.0))))
			return points
		if d.has("left") and d.has("bottom") and d.has("right"):
			var bottom = float(d.get("bottom", 0.0))
			points.append(Vector2(float(d.get("left", 0.0)), bottom))
			points.append(Vector2(float(d.get("right", 0.0)), bottom))
			return points

	# Shape 3: [x1,y1,x2,y2]
	if raw_msg_rect is Array and raw_msg_rect.size() >= 4:
		points.append(Vector2(float(raw_msg_rect[0]), float(raw_msg_rect[1])))
		points.append(Vector2(float(raw_msg_rect[2]), float(raw_msg_rect[3])))

	return points

func _load_talents_database() -> TalentsDatabase:
	"""Create TalentsDatabase from JSON"""
	var db = TalentsDatabase.new()
	var data = _load_json_file(TALENTS_JSON)
	
	for item in data:
		var talent = TalentResource.new()
		talent.talent_id = item.get("talent_id", 0)
		talent.name = item.get("name", "")
		talent.description = item.get("description", "")
		talent.max_points = item.get("max_points", 0)
		talent.perk_slot = item.get("perk_slot", false)
		talent.effect_id = item.get("effect_id", 0)
		talent.factor = item.get("factor", 0.0)
		db.talents.append(talent)
	
	print("[DataManager] Loaded %d talents" % db.talents.size())
	return db

func _parse_quest_stat_type(value) -> int:
	if value is int or value is float:
		return int(value)
	if value is String:
		var normalized = String(value).strip_edges().to_lower()
		match normalized:
			"strength", "str":
				return 1
			"stamina", "sta":
				return 2
			"agility", "agi":
				return 3
			"luck", "lck":
				return 4
			"armor", "arm", "defense", "defence":
				return 5
	return 0

func _load_quests_database() -> QuestsDatabase:
	"""Create QuestsDatabase from JSON"""
	var db = QuestsDatabase.new()
	var data = _load_json_file(QUESTS_JSON)
	
	for item in data:
		var quest = QuestData.new()
		quest.quest_id = item.get("quest_id", 0)
		quest.quest_name = item.get("name", "")
		quest.travel_text = item.get("travel_text", "")
		quest.initial_text = item.get("start_text", "")
		quest.settlement_id = item.get("settlement_id", 0)
		quest.asset_id = int(item.get("asset_id", 0))
		quest.ending = item.get("ending", false)
		quest.failure_text = item.get("failure_text", "")
		
		# Load background texture from cache (uses quests folder)
		if quest.asset_id > 0:
			quest.background_texture = load_asset_texture("quests", quest.asset_id)
		
		# Default entry determines initially visible options
		var default_entry = int(item.get("default_entry", 0))
		if default_entry > 0:
			quest.initially_visible_options.append(default_entry)
		
		# Load options
		var options_data = item.get("options", [])
		for opt in options_data:
			var option = QuestOption.new()
			option.option_id = int(opt.get("option_id", 0))
			option.option_text = str(opt.get("option_text", ""))
			option.node_text = str(opt.get("node_text", ""))
			option.response_text = str(opt.get("response_text", ""))
			option.on_lose_response_text = str(opt.get("on_lose_response_text", ""))
			
			# Requirements - server renamed fields
			option.stat_type = _parse_quest_stat_type(opt.get("stat_type", 0))
			option.stat_required = int(opt.get("stat_required", 0))
			option.effect_id = int(opt.get("effect_id_required", opt.get("effect_id", 0)))
			option.effect_amount = int(opt.get("effect_amount_required", opt.get("effect_amount", 0)))
			option.silver_required = int(opt.get("silver_required", 0))
			option.faction_required = int(opt.get("faction_required", 0))
			option.enemy_id = int(opt.get("enemy_id", 0))
			option.is_start = bool(opt.get("start", false))
			option.ends_quest = bool(opt.get("quest_end", opt.get("ends_quest", false)))
			
			# Effect applied when option is chosen
			option.effect_applied = int(opt.get("effect_applied", 0))
			option.effect_applied_factor = float(opt.get("effect_applied_factor", 0.0))
			
			# Visibility control
			var shows = opt.get("shows_option_ids", [])
			for s in shows:
				option.shows_option_ids.append(int(s))
			var hides = opt.get("hides_option_ids", [])
			for h in hides:
				option.hides_option_ids.append(int(h))
			var lose_shows = opt.get("on_lose_shows_option_ids", [])
			for ls in lose_shows:
				option.on_lose_shows_option_ids.append(int(ls))
			var lose_hides = opt.get("on_lose_hides_option_ids", [])
			for lh in lose_hides:
				option.on_lose_hides_option_ids.append(int(lh))
			
			# Rewards - support nested "reward" object or flat fields
			var reward_data = opt.get("reward", {})
			if reward_data is Dictionary and reward_data.size() > 0:
				option.reward_stat_type = int(reward_data.get("reward_stat_type", reward_data.get("stat_type", 0)))
				option.reward_stat_amount = int(reward_data.get("reward_stat_amount", reward_data.get("stat_amount", 0)))
				option.reward_talent = int(reward_data.get("talent", 0))
				option.reward_item = int(reward_data.get("item", 0))
				option.reward_perk = int(reward_data.get("perk", 0))
				option.reward_blessing = int(reward_data.get("blessing", 0))
				option.reward_potion = int(reward_data.get("potion", 0))
				option.reward_silver = int(reward_data.get("silver", 0))
			else:
				option.reward_stat_type = int(opt.get("reward_stat_type", 0))
				option.reward_stat_amount = int(opt.get("reward_stat_amount", 0))
				option.reward_talent = int(opt.get("reward_talent", 0))
				option.reward_item = int(opt.get("reward_item", 0))
				option.reward_perk = int(opt.get("reward_perk", 0))
				option.reward_blessing = int(opt.get("reward_blessing", 0))
				option.reward_potion = int(opt.get("reward_potion", 0))
				option.reward_silver = int(opt.get("reward_silver", 0))
			
			# Requirements (options that must be clicked first)
			var requirements = opt.get("requirements", [])
			for req in requirements:
				option.requirements.append(int(req))
			
			quest.options.append(option)
			
			# If this is a start option, add to initially visible
			if option.is_start and option.option_id not in quest.initially_visible_options:
				quest.initially_visible_options.append(option.option_id)
		
		db.quests.append(quest)
	
	print("[DataManager] Loaded %d quests" % db.quests.size())
	return db

func _load_cosmetics_database() -> CosmeticDatabase:
	"""Create CosmeticDatabase from JSON"""
	var db = CosmeticDatabase.new()
	var data = _load_json_file(COSMETICS_JSON)
	
	for item in data:
		var cosmetic = CosmeticResource.new()
		cosmetic.id = int(item.get("id", 0))
		cosmetic.cosmetic_name = str(item.get("name", ""))
		cosmetic.category = str(item.get("type", ""))
		cosmetic.cost = int(item.get("price", 0))
		cosmetic.offset_x = float(item.get("offset_x", 0.0))
		cosmetic.offset_y = float(item.get("offset_y", 0.0))
		cosmetic.scale = float(item.get("scale", 100.0))
		
		# Load texture from cache (cosmetic ID is the asset ID)
		if cosmetic.id > 0:
			cosmetic.texture = load_asset_texture("cosmetics", cosmetic.id)
		
		db.cosmetics.append(cosmetic)
	
	print("[DataManager] Loaded %d cosmetics" % db.cosmetics.size())
	return db

func _map_item_type_to_enum(item_type_string: String) -> int:
	"""Map item type string to ItemResource.ItemType enum"""
	# ItemType enum: HEAD=0, CHEST=1, HANDS=2, FOOT=3, BELT=4, LEGS=5, RING=6, AMULET=7, WEAPON=8, GEM=9, POTION=10, ELIXIR=11, SCROLL=12, HAMMER=13, RATION=14, INGREDIENT=15
	match item_type_string.to_lower():
		"head", "helmet": return 0  # HEAD
		"chest": return 1  # CHEST
		"hand", "hands", "gloves": return 2  # HANDS
		"foot", "feet", "boots": return 3  # FOOT
		"belt": return 4  # BELT
		"legs": return 5  # LEGS
		"ring", "back": return 6  # RING/BACK
		"amulet": return 7  # AMULET
		"weapon": return 8  # WEAPON
		"gem": return 9  # GEM
		"potion": return 10  # POTION
		"elixir": return 11  # ELIXIR
		"scroll": return 12  # SCROLL
		"hammer": return 13  # HAMMER
		"ration": return 14  # RATION
		"ingredient": return 15  # INGREDIENT
		_: return 0

# ============================================
# ASSET INTEGRITY VERIFICATION
# ============================================

func _verify_and_repair_assets():
	"""Scan all JSON data for asset IDs, re-download any missing files from S3"""
	var missing_count = 0
	
	# Items
	var items_data = _load_json_file(ITEMS_JSON)
	for item in items_data:
		var asset_id = int(item.get("asset_id", 0))
		if asset_id > 0 and not has_asset("items", asset_id):
			_download_asset("items", asset_id)
			missing_count += 1
	
	# Perks
	var perks_data = _load_json_file(PERKS_JSON)
	for item in perks_data:
		var asset_id = int(item.get("asset_id", 0))
		if asset_id > 0 and not has_asset("perks", asset_id):
			_download_asset("perks", asset_id)
			missing_count += 1
	
	# Enemies
	var enemies_data = _load_json_file(ENEMIES_JSON)
	for item in enemies_data:
		var asset_id = int(item.get("asset_id", 0))
		if asset_id > 0 and not has_asset("enemies", asset_id):
			_download_asset("enemies", asset_id)
			missing_count += 1
	
	# Expedition maps
	var expeditions_data = _load_json_file(EXPEDITIONS_JSON)
	for item in expeditions_data:
		var asset_id = int(item.get("map_asset_id", 0))
		if asset_id > 0 and not has_asset("expedition-maps", asset_id):
			_download_asset("expedition-maps", asset_id)
			missing_count += 1
	
	# Quests (use quests folder)
	var quests_data = _load_json_file(QUESTS_JSON)
	for item in quests_data:
		var asset_id = int(item.get("asset_id", 0))
		if asset_id > 0 and not has_asset("quests", asset_id):
			_download_asset("quests", asset_id)
			missing_count += 1
	
	# Settlements (multiple asset fields)
	var settlements_data = _load_json_file(SETTLEMENTS_JSON)
	for item in settlements_data:
		for key in ["settlement_asset_id", "expedition_asset_id", "arena_asset_id"]:
			var asset_id = int(item.get(key, 0))
			if asset_id > 0 and not has_asset("settlements", asset_id):
				_download_asset("settlements", asset_id)
				missing_count += 1
		var vendor_data = item.get("vendor", {})
		if vendor_data is Dictionary:
			var asset_id = int(vendor_data.get("vendor_asset_id", 0))
			if asset_id > 0 and not has_asset("settlements", asset_id):
				_download_asset("settlements", asset_id)
				missing_count += 1
		var utility_data = item.get("utility", {})
		if utility_data is Dictionary:
			var asset_id = int(utility_data.get("utility_asset_id", 0))
			if asset_id > 0 and not has_asset("settlements", asset_id):
				_download_asset("settlements", asset_id)
				missing_count += 1
	
	# Cosmetics (cosmetic ID is the asset ID)
	var cosmetics_data = _load_json_file(COSMETICS_JSON)
	for item in cosmetics_data:
		var cosmetic_id = int(item.get("id", 0))
		if cosmetic_id > 0 and not has_asset("cosmetics", cosmetic_id):
			_download_asset("cosmetics", cosmetic_id)
			missing_count += 1
	
	if missing_count > 0:
		print("[DataManager] Asset integrity check: %d missing assets queued for download" % missing_count)
	else:
		print("[DataManager] Asset integrity check: all assets present")

# ============================================
# ASSET DOWNLOADING
# ============================================

func _download_assets_for_data(data_type: String, data: Array):
	"""Download images for all items in data"""
	for item in data:
		var asset_id = int(item.get("asset_id", 0))
		if asset_id > 0:
			_download_asset(data_type, asset_id)

# Track downloaded quest/expedition assets to avoid duplicates
var _downloaded_quest_assets: Dictionary = {}

func _download_quest_assets(data: Array):
	"""Download quest assets"""
	for item in data:
		var asset_id = int(item.get("asset_id", 0))
		if asset_id > 0 and not _downloaded_quest_assets.has(asset_id):
			_downloaded_quest_assets[asset_id] = true
			_download_asset("quests", asset_id)

func _download_expedition_map_assets(data: Array):
	"""Download expedition map assets"""
	for item in data:
		var asset_id = int(item.get("map_asset_id", 0))
		if asset_id > 0:
			_download_asset("expedition-maps", asset_id)

func _download_cosmetic_assets(data: Array):
	"""Download cosmetic images (each cosmetic's ID is its asset ID)"""
	for item in data:
		var cosmetic_id = int(item.get("id", 0))
		if cosmetic_id > 0:
			_download_asset("cosmetics", cosmetic_id)

func _download_settlement_assets(settlements_data: Array):
	"""Download settlement assets"""
	var downloaded_ids = {}
	for item in settlements_data:
		for key in ["settlement_asset_id", "expedition_asset_id", "arena_asset_id"]:
			var asset_id = int(item.get(key, 0))
			if asset_id > 0 and not downloaded_ids.has(asset_id):
				downloaded_ids[asset_id] = true
				_download_asset("settlements", asset_id)
		
		# Vendor asset
		var vendor_data = item.get("vendor", {})
		if vendor_data is Dictionary:
			var asset_id = int(vendor_data.get("vendor_asset_id", 0))
			if asset_id > 0 and not downloaded_ids.has(asset_id):
				downloaded_ids[asset_id] = true
				_download_asset("settlements", asset_id)
		
		# Utility asset
		var utility_data = item.get("utility", {})
		if utility_data is Dictionary:
			var asset_id = int(utility_data.get("utility_asset_id", 0))
			if asset_id > 0 and not downloaded_ids.has(asset_id):
				downloaded_ids[asset_id] = true
				_download_asset("settlements", asset_id)

func _get_asset_extension(folder: String) -> String:
	"""Get file extension for asset type"""
	if folder == "cosmetics":
		return ".png"
	return ".webp"

func _download_asset(folder: String, asset_id: int):
	"""Download an asset (skips if already queued or on disk)"""
	var key = "%s/%d" % [folder, asset_id]
	if _queued_downloads.has(key):
		return
	_queued_downloads[key] = true
	
	# Skip if already on disk
	if has_asset(folder, asset_id):
		return
	
	var ext = _get_asset_extension(folder)
	var local_path = get_asset_path(folder, asset_id)
	var remote_url = "%s%s/%d%s" % [ASSETS_BASE_URL, folder, asset_id, ext]
	
	print("[DataManager] Downloading asset: %s" % remote_url)
	
	_pending_downloads += 1
	
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_asset_downloaded.bind(folder, asset_id, local_path, http))
	
	var error = http.request(remote_url)
	if error != OK:
		print("[DataManager] Failed to request asset %s/%d: %d" % [folder, asset_id, error])
		http.queue_free()
		_pending_downloads -= 1

func _on_asset_downloaded(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, folder: String, asset_id: int, local_path: String, http: HTTPRequest):
	"""Handle downloaded asset"""
	http.queue_free()
	_pending_downloads -= 1
	
	if response_code != 200:
		print("[DataManager] Asset download failed %s/%d (HTTP %d)" % [folder, asset_id, response_code])
		return
	
	var file = FileAccess.open(local_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		print("[DataManager] Saved asset: %s" % local_path)
		asset_downloaded.emit(folder, asset_id)
	else:
		print("[DataManager] Failed to save asset: %s" % local_path)

func get_asset_path(folder: String, asset_id: int) -> String:
	"""Get the local path for an asset"""
	var ext = _get_asset_extension(folder)
	return "%s%s/%d%s" % [IMAGES_DIR, folder, asset_id, ext]

func load_asset_texture(folder: String, asset_id: int) -> ImageTexture:
	"""Load an asset texture from cache, returns null if not found"""
	var local_path = get_asset_path(folder, asset_id)
	
	if not FileAccess.file_exists(local_path):
		return null
	
	var img = Image.new()
	var err = img.load(local_path)
	if err != OK:
		print("[DataManager] Failed to load image: %s (error %d)" % [local_path, err])
		return null
	
	return ImageTexture.create_from_image(img)

func has_asset(folder: String, asset_id: int) -> bool:
	"""Check if an asset exists in cache"""
	return FileAccess.file_exists(get_asset_path(folder, asset_id))

# ============================================
# DATABASE ACCESS (used by GameInfo)
# ============================================

func get_effects_database() -> EffectDatabase:
	if not effects_db:
		effects_db = _load_effects_database()
	return effects_db

func get_items_database() -> ItemDatabase:
	if not items_db:
		items_db = _load_items_database()
	return items_db

func get_perks_database() -> PerkDatabase:
	if not perks_db:
		perks_db = _load_perks_database()
	return perks_db

func get_enemies_database() -> EnemyDatabase:
	if not enemies_db:
		enemies_db = _load_enemies_database()
	return enemies_db

func get_expeditions_database() -> ExpeditionsDatabase:
	if not expeditions_db:
		expeditions_db = _load_expeditions_database()
	return expeditions_db

func get_settlements_database() -> SettlementsDatabase:
	if not settlements_db:
		settlements_db = _load_settlements_database()
	return settlements_db

func get_talents_database() -> TalentsDatabase:
	if not talents_db:
		talents_db = _load_talents_database()
	return talents_db

func get_quests_database() -> QuestsDatabase:
	if not quests_db:
		quests_db = _load_quests_database()
	return quests_db

func get_cosmetics_database() -> CosmeticDatabase:
	if not cosmetics_db:
		cosmetics_db = _load_cosmetics_database()
	return cosmetics_db
