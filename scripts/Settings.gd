extends Control

@export var ui_size_dropdown: OptionButton
@export var autoskip_checkbox: CheckButton
@export var disable_ads_checkbox: CheckButton
@export var master_volume_slider: HSlider
@export var music_volume_slider: HSlider
@export var language_dropdown: OptionButton

# Font size presets for small, medium, large
const FONT_SIZES = {
	"small": 14,
	"medium": 18,
	"large": 22
}

# Control types that need font size updates
const CONTROL_TYPES = [
	"Label",
	"Button",
	"LineEdit",
	"TextEdit",
	"CheckBox",
	"OptionButton",
	"CheckButton"
]

func _ready():
	# Load settings for current character
	_load_character_settings()
	
	# Connect all signals
	_connect_signals()

func _connect_signals():
	"""Connect all UI element signals"""
	disable_ads_checkbox.toggled.connect(_on_disable_ads_toggled)
	autoskip_checkbox.toggled.connect(_on_autoskip_quest_toggled)
	language_dropdown.item_selected.connect(_on_language_selected)
	master_volume_slider.value_changed.connect(_on_master_volume_changed)
	music_volume_slider.value_changed.connect(_on_music_volume_changed)
	ui_size_dropdown.item_selected.connect(_on_ui_size_selected)

func _load_character_settings():
	"""Load and apply settings for current character"""
	var character_id = str(GameInfo.current_player.character_id)
	var settings = SettingsManager.load_settings(character_id)
	
	# Apply gameplay settings
	disable_ads_checkbox.button_pressed = settings.gameplay.disable_ads
	autoskip_checkbox.button_pressed = settings.gameplay.autoskip_quest
	
	# Disable quest autoskip if not VIP
	var is_vip = GameInfo.current_player.vip if "vip" in GameInfo.current_player else false
	autoskip_checkbox.disabled = not is_vip
	if not is_vip:
		autoskip_checkbox.tooltip_text = "VIP feature - upgrade to unlock"
	
	# Set language dropdown
	var lang_index = 0
	match settings.gameplay.language:
		"English": lang_index = 0
		"Czech": lang_index = 1
		"German": lang_index = 2
	language_dropdown.selected = lang_index
	
	# Apply audio settings
	master_volume_slider.value = settings.audio.master_volume
	music_volume_slider.value = settings.audio.music_volume
	
	# Apply video settings
	var ui_size_index = 1  # Default to medium
	match settings.video.ui_size:
		"Small": ui_size_index = 0
		"Medium": ui_size_index = 1
		"Large": ui_size_index = 2
	ui_size_dropdown.selected = ui_size_index

func _save_setting(section: String, key: String, value):
	"""Save a single setting"""
	var character_id = str(GameInfo.current_player.character_id)
	SettingsManager.update_setting(character_id, section, key, value)

# Gameplay callbacks
func _on_disable_ads_toggled(enabled: bool):
	_save_setting("gameplay", "disable_ads", enabled)
	print("Disable ads: ", enabled)

func _on_autoskip_quest_toggled(enabled: bool):
	_save_setting("gameplay", "autoskip_quest", enabled)
	print("Quest auto-skip: ", enabled)

func _on_language_selected(index: int):
	var languages = ["English", "Czech", "German"]
	var language = languages[index] if index < languages.size() else "English"
	_save_setting("gameplay", "language", language)
	print("Language changed to: ", language)

# Audio callbacks
func _on_master_volume_changed(value: float):
	_save_setting("audio", "master_volume", value)
	# TODO: Apply to audio bus

func _on_music_volume_changed(value: float):
	_save_setting("audio", "music_volume", value)
	# TODO: Apply to music bus

# Video callbacks
func _on_ui_size_selected(index: int):
	var sizes = ["Small", "Medium", "Large"]
	var size = sizes[index] if index < sizes.size() else "Medium"
	_save_setting("video", "ui_size", size)
	print("UI size changed to: ", size)
	# TODO: Apply UI size changes
