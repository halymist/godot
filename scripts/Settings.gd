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
	# Connect the UI size dropdown
	if ui_size_dropdown:
		ui_size_dropdown.item_selected.connect(_on_ui_size_changed)
		
		# Apply the current selection on load
		_apply_font_size(ui_size_dropdown.selected)
	
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

func _on_ui_size_changed(index: int):
	_apply_font_size(index)

func _apply_font_size(size_index: int):
	# Get the theme from the root Control
	var root_control = get_tree().root.get_node("Game/Portrait")
	if not root_control:
		push_error("Could not find Portrait control node")
		return
	
	var root_theme = root_control.theme
	if not root_theme:
		push_error("Portrait control has no theme")
		return
	
	# Determine font size based on selection
	var font_size = FONT_SIZES["medium"]  # default
	match size_index:
		0:  # Small
			font_size = FONT_SIZES["small"]
		1:  # Medium
			font_size = FONT_SIZES["medium"]
		2:  # Large
			font_size = FONT_SIZES["large"]
	
	# Update font size for all control types
	for control_type in CONTROL_TYPES:
		root_theme.set_font_size("font_size", control_type, font_size)
	
	print("Font size updated to: ", font_size)

func _on_autoskip_toggled(enabled: bool):
	"""Handle autoskip checkbox toggle"""
	if GameInfo.current_player:
		GameInfo.current_player.autoskip = enabled
		print("Autoskip ", "enabled" if enabled else "disabled")
		# TODO: Send to server to save setting
