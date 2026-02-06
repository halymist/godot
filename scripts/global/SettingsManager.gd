extends Node

## Manages local storage and retrieval of character-specific settings
## Settings are saved to user:// directory and are device-specific

const SETTINGS_DIR = "user://settings/"
const SETTINGS_FILE_PREFIX = "character_"
const SETTINGS_FILE_SUFFIX = ".cfg"

# Current settings cache
var current_settings: Dictionary = {}

func _ready():
	# Ensure settings directory exists
	var dir = DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("settings"):
			dir.make_dir("settings")

func save_settings(character_id: String, settings_dict: Dictionary) -> void:
	"""Save settings for a specific character"""
	var config = ConfigFile.new()
	
	# Save all settings to the config file
	for section in settings_dict.keys():
		if settings_dict[section] is Dictionary:
			for key in settings_dict[section].keys():
				config.set_value(section, key, settings_dict[section][key])
		else:
			config.set_value("general", section, settings_dict[section])
	
	var file_path = _get_settings_path(character_id)
	var err = config.save(file_path)
	
	if err != OK:
		push_error("Failed to save settings for character %s: %s" % [character_id, err])
	else:
		print("Settings saved for character: ", character_id)
		current_settings = settings_dict.duplicate(true)

func load_settings(character_id: String) -> Dictionary:
	"""Load settings for a specific character, returns default settings if file doesn't exist"""
	var config = ConfigFile.new()
	var file_path = _get_settings_path(character_id)
	
	var err = config.load(file_path)
	
	if err != OK:
		print("No saved settings found for character %s, using defaults" % character_id)
		var defaults = _get_default_settings()
		current_settings = defaults.duplicate(true)
		return defaults
	
	# Load settings from config file
	var settings = {}
	for section in config.get_sections():
		settings[section] = {}
		for key in config.get_section_keys(section):
			settings[section][key] = config.get_value(section, key)
	
	print("Settings loaded for character: ", character_id)
	current_settings = settings.duplicate(true)
	return settings

func update_setting(character_id: String, section: String, key: String, value) -> void:
	"""Update a single setting and save immediately"""
	if not current_settings.has(section):
		current_settings[section] = {}
	
	current_settings[section][key] = value
	save_settings(character_id, current_settings)

func get_setting(section: String, key: String, default = null):
	"""Get a specific setting from current cache"""
	if current_settings.has(section) and current_settings[section].has(key):
		return current_settings[section][key]
	return default

func _get_settings_path(character_id: String) -> String:
	"""Get the file path for character settings"""
	return SETTINGS_DIR + SETTINGS_FILE_PREFIX + character_id + SETTINGS_FILE_SUFFIX

func _get_default_settings() -> Dictionary:
	"""Return default settings structure"""
	return {
		"gameplay": {
			"disable_ads": false,
			"language": "English"
		},
		"audio": {
			"master_volume": 100.0,
			"music_volume": 100.0
		},
		"video": {
			"ui_size": "Medium"
		}
	}
