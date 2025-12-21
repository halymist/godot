extends Control
class_name Utility

@export var target: Panel

@onready var click_button: Button = $ClickButton
@onready var hover_area: ColorRect = $HoverArea

signal utility_clicked(utility: Utility)

func _ready():
	click_button.button_up.connect(_on_button_pressed)
	click_button.mouse_entered.connect(_on_mouse_entered)
	click_button.mouse_exited.connect(_on_mouse_exited)

func _on_mouse_entered():
	hover_area.color = Color(1, 1, 1, 0.3)

func _on_mouse_exited():
	hover_area.color = Color(1, 1, 1, 0)

func _on_button_pressed():
	if target:
		print("[Utility] Button pressed for: ", target.name)
		# Set the location-specific background for utility panels
		if target.has_method("set_location_texture"):
			var location = GameInfo.current_player.location if GameInfo.current_player else 1
			target.set_location_texture(location)
		
		# Hide current panel if it's not the target
		var current_panel = GameInfo.get_current_panel()
		if current_panel and current_panel != target:
			current_panel.visible = false
		
		# Ensure utility panel has proper z-index and mouse filtering to be on top
		target.z_index = 100
		target.mouse_filter = Control.MOUSE_FILTER_STOP
		print("[Utility] Set z_index=100 and mouse_filter=STOP for ", target.name)
		print("[Utility] Panel parent: ", target.get_parent().name if target.get_parent() else "null")
		print("[Utility] Panel position: ", target.position, " size: ", target.size)
		print("[Utility] Panel anchors: ", target.anchor_left, ",", target.anchor_top, ",", target.anchor_right, ",", target.anchor_bottom)
		
		# Show the target panel and register it as current panel in GameInfo
		target.visible = true
		GameInfo.set_current_panel(target)
		
		# In wide mode, also show character panel on the left
		var resolution_manager = get_node_or_null("/root/Game/ResolutionManager")
		if resolution_manager and resolution_manager.current_layout == resolution_manager.desktop_ui_root:
			print("[Utility] Wide mode detected, showing character panel")
			if resolution_manager.character_panel:
				resolution_manager.character_panel.visible = true
		
		print("[Utility] Set current panel to: ", GameInfo.get_current_panel().name if GameInfo.get_current_panel() else "null")
	utility_clicked.emit(self)
