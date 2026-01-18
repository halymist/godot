extends Control

@export var yes_button : Button
@export var no_button : Button
@export var background_button : Button

func _ready():
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	background_button.pressed.connect(_on_no_pressed)

func show_dialog():
	UIManager.instance.show_overlay(self)

func _on_yes_pressed():
	var quest_id = GameInfo.current_player.traveling_destination
	var expedition = GameInfo.current_player.expedition
	
	# Check if we're canceling an expedition
	if expedition and expedition.size() > 0:
		print("Expedition canceled by user")
		Websocket.quest_cancel()  # Reuse quest_cancel for expedition too
		GameInfo.current_player.expedition = []
		UIManager.instance.expedition_panel.end_expedition()
		UIManager.instance.hide_current_overlay()
		UIManager.instance.show_panel(UIManager.instance.home_panel)
		return
	
	# Otherwise, handle quest cancellation
	if quest_id != null and quest_id is int:
		Websocket.quest_cancel()
		GameInfo.complete_quest(quest_id)
		print("Quest ", quest_id, " abandoned and marked as completed")
	
	GameInfo.current_player.traveling = 0
	GameInfo.current_player.traveling_destination = null
	
	UIManager.instance.hide_current_overlay()
	UIManager.instance.show_panel(UIManager.instance.home_panel)
	print("Quest canceled by user")

func _on_no_pressed():
	UIManager.instance.hide_current_overlay()
