extends Control
class_name Utility

enum PanelType {
	BLACKSMITH,
	VENDOR,
	ALCHEMIST,
	ENCHANTER,
	TRAINER,
	CHURCH
}

@export var panel_type: PanelType = PanelType.BLACKSMITH

var target: Panel

@onready var click_button: Button = $ClickButton
@onready var hover_area: ColorRect = $HoverArea

signal utility_clicked(utility: Utility)

func _ready():
	# Get target panel based on type - defer if UIManager not ready yet
	if UIManager.instance:
		target = _get_panel_for_type(panel_type)
	else:
		call_deferred("_setup_target")
	
	if target and not target:
		print("[Utility] Warning: Could not find panel for type: ", PanelType.keys()[panel_type])
	
	click_button.button_up.connect(_on_button_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)

func _setup_target():
	target = _get_panel_for_type(panel_type)
	if not target:
		print("[Utility] Warning: Could not find panel for type: ", PanelType.keys()[panel_type])

func _get_panel_for_type(type: PanelType) -> Panel:
	if not UIManager.instance:
		return null
	
	match type:
		PanelType.BLACKSMITH:
			return UIManager.instance.blacksmith_panel
		PanelType.VENDOR:
			return UIManager.instance.vendor_panel
		PanelType.ALCHEMIST:
			return UIManager.instance.alchemist_panel
		PanelType.ENCHANTER:
			return UIManager.instance.enchanter_panel
		PanelType.TRAINER:
			return UIManager.instance.trainer_panel
		PanelType.CHURCH:
			return UIManager.instance.church_panel
	return null

func _on_mouse_entered():
	hover_area.color = Color(1, 1, 1, 0.3)

func _on_mouse_exited():
	hover_area.color = Color(1, 1, 1, 0)

func _on_button_pressed():
	if target:
		print("[Utility] Button pressed for: ", target.name)
		
		# Hide current panel if it's not the target
		var current_panel = GameInfo.get_current_panel()
		if current_panel and current_panel != target:
			current_panel.visible = false
		
		# Ensure utility panel has proper z-index and mouse filtering to be on top
		target.z_index = 100
		target.mouse_filter = Control.MOUSE_FILTER_STOP
		
		# Show the target panel and register it as current panel in GameInfo
		target.visible = true
		GameInfo.set_current_panel(target)
		
		# In wide mode, also show character panel on the left
		var resolution_manager = get_node_or_null("/root/Game")
		if resolution_manager and resolution_manager.current_layout == resolution_manager.desktop_ui_root:
			if resolution_manager.character_panel:
				resolution_manager.character_panel.visible = true
	
	utility_clicked.emit(self)
