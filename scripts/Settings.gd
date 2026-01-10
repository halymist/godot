extends Panel

@onready var ui_size_dropdown: OptionButton = $SettingsContainer/ScrollContainer/CategoriesContainer/Video/UISize/OptionButton
@onready var autoskip_checkbox: CheckBox = $SettingsContainer/ScrollContainer/CategoriesContainer/Gameplay/QuestAutoSkip/CheckBox

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
	# Setup autoskip checkbox
	if autoskip_checkbox:
		autoskip_checkbox.toggled.connect(_on_autoskip_toggled)
		# Set initial state from player data
		if GameInfo.current_player:
			autoskip_checkbox.button_pressed = GameInfo.current_player.autoskip if "autoskip" in GameInfo.current_player else false
			# Disable if not VIP
			var is_vip = GameInfo.current_player.vip if "vip" in GameInfo.current_player else false
			autoskip_checkbox.disabled = not is_vip
			if not is_vip:
				autoskip_checkbox.tooltip_text = "VIP feature - upgrade to unlock"


func _on_autoskip_toggled(enabled: bool):
	"""Handle autoskip checkbox toggle"""
	if GameInfo.current_player:
		GameInfo.current_player.autoskip = enabled
		print("Autoskip ", "enabled" if enabled else "disabled")
		# TODO: Send to server to save setting
