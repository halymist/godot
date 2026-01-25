extends Node

# ============================================
# DATA MANAGER AUTOLOAD
# ============================================
# Handles data versioning and downloading
# Downloads data from server and applies directly to .tres databases
# Assets are downloaded and stored in user:// then applied as textures

const VERSIONS_FILE = "user://data_versions.cfg"
const IMAGES_DIR = "user://images/"
const DATA_DIR = "user://data/"

# Asset base URL
const ASSETS_BASE_URL = "https://gamedata-assets.s3.eu-north-1.amazonaws.com/images/"

# Database paths (all in user://)
const EFFECTS_DB_PATH = "user://data/effects.res"
const ITEMS_DB_PATH = "user://data/items.res"
const PERKS_DB_PATH = "user://data/perks.res"
const ENEMIES_DB_PATH = "user://data/enemies.res"
const EXPEDITIONS_DB_PATH = "user://data/expeditions.res"

# Signals
signal data_sync_completed(success: bool)
signal asset_downloaded(type: String, asset_id: int)

# Loaded databases (populated after sync)
var effects_db: EffectDatabase = null
var items_db: ItemDatabase = null
var perks_db: PerkDatabase = null
var enemies_db: EnemyDatabase = null
var expeditions_db: ExpeditionsDatabase = null

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

# Track pending asset downloads
var _pending_downloads: int = 0

# Track databases that need saving after assets are applied
var _databases_to_save: Array[String] = []

func _ready():
	print("[DataManager] Ready")
	_ensure_cache_dirs()
	_load_local_versions()
	_load_baseline_databases()

func _ensure_cache_dirs():
	"""Ensure cache directories exist"""
	DirAccess.make_dir_recursive_absolute("user://images/items")
	DirAccess.make_dir_recursive_absolute("user://images/perks")
	DirAccess.make_dir_recursive_absolute("user://images/enemies")
	DirAccess.make_dir_recursive_absolute("user://data")
	print("[DataManager] Created cache directories")

func _load_baseline_databases():
	"""Load .tres databases from user:// if exists, otherwise create empty"""
	effects_db = _load_or_create_database(EFFECTS_DB_PATH, "effects")
	items_db = _load_or_create_database(ITEMS_DB_PATH, "items")
	perks_db = _load_or_create_database(PERKS_DB_PATH, "perks")
	enemies_db = _load_or_create_database(ENEMIES_DB_PATH, "enemies")
	expeditions_db = _load_or_create_database(EXPEDITIONS_DB_PATH, "expeditions")
	print("[DataManager] Loaded databases")

func _load_or_create_database(user_path: String, db_type: String) -> Resource:
	"""Load from user:// if exists, otherwise create empty database"""
	if FileAccess.file_exists(user_path):
		var db = load(user_path)
		if db:
			print("[DataManager] Loaded: %s" % user_path)
			# Apply cached textures to loaded database
			_apply_cached_textures_to_database(db_type, db)
			return db
	
	# Create empty database
	print("[DataManager] Creating empty %s database" % db_type)
	match db_type:
		"effects": return EffectDatabase.new()
		"items": return ItemDatabase.new()
		"perks": return PerkDatabase.new()
		"enemies": return EnemyDatabase.new()
		"expeditions": return ExpeditionsDatabase.new()
		_: return null

func _apply_cached_textures_to_database(db_type: String, db: Resource):
	"""Apply cached textures from user:// to a loaded database"""
	match db_type:
		"items":
			for item in db.items:
				if item.asset_id > 0:
					var texture = load_asset_texture("items", item.asset_id)
					if texture:
						item.icon = texture
		"perks":
			for perk in db.perks:
				if perk.asset_id > 0:
					var texture = load_asset_texture("perks", perk.asset_id)
					if texture:
						perk.icon = texture
		"enemies":
			for enemy in db.enemies:
				if enemy.asset_id > 0:
					var texture = load_asset_texture("enemies", enemy.asset_id)
					if texture:
						enemy.texture = texture

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

func reset_all_versions():
	"""Reset all local versions to 0 to force re-download"""
	for key in local_versions.keys():
		local_versions[key] = 0
	_save_local_versions()
	print("[DataManager] Reset all versions to 0")

func clear_all_cache():
	"""Clear all cached images, persisted databases, and reset versions"""
	reset_all_versions()
	
	# Delete image folders
	for folder in ["items", "perks", "enemies"]:
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
	
	# Delete persisted .tres files
	for db_path in [EFFECTS_DB_PATH, ITEMS_DB_PATH, PERKS_DB_PATH, ENEMIES_DB_PATH, EXPEDITIONS_DB_PATH]:
		if FileAccess.file_exists(db_path):
			DirAccess.remove_absolute(db_path)
	
	# Create empty databases
	effects_db = EffectDatabase.new()
	items_db = ItemDatabase.new()
	perks_db = PerkDatabase.new()
	enemies_db = EnemyDatabase.new()
	expeditions_db = ExpeditionsDatabase.new()
	
	print("[DataManager] Cleared all cache")

# ============================================
# DATA SYNC
# ============================================

func needs_download(server_data_versions: Dictionary) -> bool:
	"""Check if any data needs to be downloaded"""
	for data_type in local_versions.keys():
		var server_key = data_type
		if data_type == "expeditions":
			server_key = "expedition"
		
		var server_version = server_data_versions.get(server_key, server_data_versions.get(data_type, 0))
		var local_version = local_versions.get(data_type, 0)
		
		if server_version > local_version:
			return true
	
	return false

func sync_data(server_data_versions: Dictionary):
	"""Download all data types and assets, waits until complete"""
	server_versions = server_data_versions
	print("[DataManager] Server versions: ", server_versions)
	print("[DataManager] Local versions: ", local_versions)
	
	# Sync each data type
	await _sync_data_type("effects", "/download-effects")
	await _sync_data_type("items", "/download-items")
	await _sync_data_type("perks", "/download-perks")
	await _sync_data_type("enemies", "/download-enemies")
	await _sync_data_type("expeditions", "/download-expedition")
	
	print("[DataManager] Data sync completed!")
	
	# Wait for all asset downloads to complete
	while _pending_downloads > 0:
		print("[DataManager] Waiting for %d asset downloads..." % _pending_downloads)
		await get_tree().create_timer(0.1).timeout
	
	print("[DataManager] All downloads (data + assets) completed!")
	
	# Save databases that were waiting for assets (WITHOUT textures - keeps .tres small)
	for data_type in _databases_to_save:
		_save_database(data_type)
	_databases_to_save.clear()
	
	# NOW apply cached textures to in-memory databases for runtime use
	_apply_all_cached_textures()
	
	data_sync_completed.emit(true)

func _sync_data_type(data_type: String, endpoint: String):
	"""Sync a single data type if needed"""
	var server_key = data_type
	if data_type == "expeditions":
		server_key = "expedition"
	
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
	if not data is Array:
		print("[DataManager] Invalid %s data format" % data_type)
		return
	
	# Apply data directly to .tres database
	_apply_to_database(data_type, data)
	
	# Download assets for types that have images
	if data_type in ["items", "perks", "enemies"]:
		_download_assets_for_data(data_type, data)

func _apply_to_database(data_type: String, data: Array):
	"""Apply downloaded JSON data directly to the .tres database"""
	var id_field = _get_id_field(data_type)
	var max_version = local_versions.get(data_type, 0)
	
	match data_type:
		"effects":
			for item in data:
				var effect = _find_or_create_effect(item.get(id_field, 0))
				effect.id = item.get("effect_id", 0)
				effect.name = item.get("name", "")
				effect.description = item.get("description", "")
				effect.slot = item.get("slot", 0)
				effect.factor = item.get("factor", 0)
				max_version = max(max_version, item.get("version", 0))
			print("[DataManager] Applied %d effects to database (total: %d)" % [data.size(), effects_db.effects.size()])
		
		"items":
			for item in data:
				var res = _find_or_create_item(item.get(id_field, 0))
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
				res.asset_id = item.get("asset_id", 0)
				res.version = item.get("version", 0)
				max_version = max(max_version, item.get("version", 0))
			print("[DataManager] Applied %d items to database (total: %d)" % [data.size(), items_db.items.size()])
		
		"perks":
			for item in data:
				var perk = _find_or_create_perk(item.get(id_field, 0))
				perk.id = item.get("perk_id", 0)
				perk.perk_name = item.get("perk_name", "")
				perk.description = item.get("description", "")
				perk.effect1_id = item.get("effect_id_1", 0)
				perk.factor1 = item.get("factor_1", 0.0)
				perk.effect2_id = item.get("effect_id_2", 0)
				perk.factor2 = item.get("factor_2", 0.0)
				perk.asset_id = item.get("asset_id", 0)
				perk.version = item.get("version", 0)
				max_version = max(max_version, item.get("version", 0))
			print("[DataManager] Applied %d perks to database (total: %d)" % [data.size(), perks_db.perks.size()])
		
		"enemies":
			for item in data:
				var enemy = _find_or_create_enemy(item.get(id_field, 0))
				enemy.id = item.get("enemy_id", 0)
				enemy.name = item.get("enemy_name", "")
				enemy.description = item.get("description", "")
				enemy.asset_id = item.get("asset_id", 0)
				enemy.version = item.get("version", 0)
				max_version = max(max_version, item.get("version", 0))
			print("[DataManager] Applied %d enemies to database (total: %d)" % [data.size(), enemies_db.enemies.size()])
		
		"expeditions":
			for item in data:
				var slide = _find_or_create_expedition_slide(item.get(id_field, 0))
				slide.slide_id = item.get("slide_id", 0)
				slide.text = item.get("slide_text", "")
				slide.reward_type = _map_expedition_reward_type(item)
				slide.reward_amount = _get_expedition_reward_amount(item)
				max_version = max(max_version, item.get("version", 0))
			print("[DataManager] Applied %d expedition slides to database (total: %d)" % [data.size(), expeditions_db.slides.size()])
	
	# Update local version
	set_local_version(data_type, max_version)
	print("[DataManager] %s updated to version %d" % [data_type, max_version])
	
	# Save database immediately if no assets, otherwise defer until assets are applied
	if data_type not in ["items", "perks", "enemies"]:
		_save_database(data_type)
	else:
		if data_type not in _databases_to_save:
			_databases_to_save.append(data_type)
			print("[DataManager] %s will be saved after assets are applied" % data_type)

func _save_database(data_type: String):
	"""Save database to user:// as .tres file"""
	var db: Resource
	var path: String
	
	match data_type:
		"effects":
			db = effects_db
			path = EFFECTS_DB_PATH
		"items":
			db = items_db
			path = ITEMS_DB_PATH
		"perks":
			db = perks_db
			path = PERKS_DB_PATH
		"enemies":
			db = enemies_db
			path = ENEMIES_DB_PATH
		"expeditions":
			db = expeditions_db
			path = EXPEDITIONS_DB_PATH
		_:
			print("[DataManager] Unknown data type for save: %s" % data_type)
			return
	
	var err = ResourceSaver.save(db, path)
	if err != OK:
		print("[DataManager] Failed to save %s: %d" % [path, err])
	else:
		print("[DataManager] Saved %s" % path)

# ============================================
# FIND OR CREATE HELPERS
# ============================================

func _find_or_create_effect(effect_id: int) -> EffectResource:
	"""Find existing effect by ID or create new one"""
	for effect in effects_db.effects:
		if effect.id == effect_id:
			return effect
	var new_effect = EffectResource.new()
	new_effect.id = effect_id
	effects_db.effects.append(new_effect)
	return new_effect

func _find_or_create_item(item_id: int) -> ItemResource:
	"""Find existing item by ID or create new one"""
	for item in items_db.items:
		if item.id == item_id:
			return item
	var new_item = ItemResource.new()
	new_item.id = item_id
	items_db.items.append(new_item)
	return new_item

func _find_or_create_perk(perk_id: int) -> PerkResource:
	"""Find existing perk by ID or create new one"""
	for perk in perks_db.perks:
		if perk.id == perk_id:
			return perk
	var new_perk = PerkResource.new()
	new_perk.id = perk_id
	perks_db.perks.append(new_perk)
	return new_perk

func _find_or_create_enemy(enemy_id: int) -> EnemyResource:
	"""Find existing enemy by ID or create new one"""
	for enemy in enemies_db.enemies:
		if enemy.id == enemy_id:
			return enemy
	var new_enemy = EnemyResource.new()
	new_enemy.id = enemy_id
	enemies_db.enemies.append(new_enemy)
	return new_enemy

func _find_or_create_expedition_slide(slide_id: int) -> ExpeditionSlide:
	"""Find existing slide by ID or create new one"""
	for slide in expeditions_db.slides:
		if slide.slide_id == slide_id:
			return slide
	var new_slide = ExpeditionSlide.new()
	new_slide.slide_id = slide_id
	expeditions_db.slides.append(new_slide)
	return new_slide

func _get_id_field(data_type: String) -> String:
	"""Get the ID field name for a data type"""
	match data_type:
		"effects": return "effect_id"
		"items": return "item_id"
		"perks": return "perk_id"
		"enemies": return "enemy_id"
		"expeditions": return "slide_id"
		_: return "id"

# ============================================
# EXPEDITION REWARD MAPPING
# ============================================

func _map_expedition_reward_type(item: Dictionary) -> int:
	"""Map server expedition reward fields to RewardType enum"""
	if item.get("reward_stat_type", 0) > 0:
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
# ASSET DOWNLOADING
# ============================================

func _download_assets_for_data(data_type: String, data: Array):
	"""Download images for all items in data (always re-download to get latest)"""
	for item in data:
		var asset_id = item.get("asset_id", 0)
		if asset_id > 0:
			_download_asset(data_type, asset_id)

func _download_asset(folder: String, asset_id: int):
	"""Download an asset (always download to ensure we have latest version)"""
	var local_path = get_asset_path(folder, asset_id)
	var remote_url = "%s%s/%d.webp" % [ASSETS_BASE_URL, folder, asset_id]
	
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
	
	# Save the webp file
	var file = FileAccess.open(local_path, FileAccess.WRITE)
	if file:
		file.store_buffer(body)
		file.close()
		print("[DataManager] Saved asset: %s" % local_path)
		asset_downloaded.emit(folder, asset_id)
	else:
		print("[DataManager] Failed to save asset: %s" % local_path)

func _apply_asset_to_database(folder: String, asset_id: int):
	"""Apply a cached asset texture to the appropriate database entry"""
	var texture = load_asset_texture(folder, asset_id)
	if not texture:
		return
	
	match folder:
		"items":
			for item in items_db.items:
				if item.asset_id == asset_id:
					item.icon = texture
		"perks":
			for perk in perks_db.perks:
				if perk.asset_id == asset_id:
					perk.icon = texture
		"enemies":
			for enemy in enemies_db.enemies:
				if enemy.asset_id == asset_id:
					enemy.texture = texture

func _apply_all_cached_textures():
	"""Apply all cached textures to in-memory databases"""
	print("[DataManager] Applying cached textures to databases...")
	
	# Items
	for item in items_db.items:
		if item.asset_id > 0:
			var texture = load_asset_texture("items", item.asset_id)
			if texture:
				item.icon = texture
	
	# Perks
	for perk in perks_db.perks:
		if perk.asset_id > 0:
			var texture = load_asset_texture("perks", perk.asset_id)
			if texture:
				perk.icon = texture
	
	# Enemies
	for enemy in enemies_db.enemies:
		if enemy.asset_id > 0:
			var texture = load_asset_texture("enemies", enemy.asset_id)
			if texture:
				enemy.texture = texture
	
	print("[DataManager] Cached textures applied")

func get_asset_path(folder: String, asset_id: int) -> String:
	"""Get the local path for an asset"""
	return "%s%s/%d.webp" % [IMAGES_DIR, folder, asset_id]

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
	"""Get the effects database"""
	return effects_db

func get_items_database() -> ItemDatabase:
	"""Get the items database"""
	return items_db

func get_perks_database() -> PerkDatabase:
	"""Get the perks database"""
	return perks_db

func get_enemies_database() -> EnemyDatabase:
	"""Get the enemies database"""
	return enemies_db

func get_expeditions_database() -> ExpeditionsDatabase:
	"""Get the expeditions database"""
	return expeditions_db
