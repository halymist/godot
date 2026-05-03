extends Control

@export var yes_button : Button
@export var no_button : Button
@export var background_button : Button
@export var dialog_label : Label

var _custom_confirm_callback: Callable = Callable()

func _ready():
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	background_button.pressed.connect(_on_no_pressed)

func show_dialog():
	# Update dialog text based on what we're canceling
	var expedition = GameInfo.current_player.expedition
	var is_expedition_travel = UIManager.instance.map_panel.is_expedition_travel
	_custom_confirm_callback = Callable()
	if (expedition and expedition.size() > 0) or is_expedition_travel:
		dialog_label.text = "Do you wish to abandon the expedition?"
	else:
		dialog_label.text = "Do you wish to abandon the quest?"
	
	UIManager.instance.show_overlay(self)

func show_custom_dialog(message: String, on_yes_callback: Callable):
	"""Show a generic yes/no dialog using the same overlay style."""
	dialog_label.text = message
	_custom_confirm_callback = on_yes_callback
	UIManager.instance.show_overlay(self)

func _on_yes_pressed():
	if _custom_confirm_callback.is_valid():
		var callback = _custom_confirm_callback
		_custom_confirm_callback = Callable()
		UIManager.instance.hide_current_overlay()
		callback.call()
		return

	var quest_id = GameInfo.current_player.traveling_destination
	var expedition = GameInfo.current_player.expedition
	var map = UIManager.instance.map_panel
	var is_expedition_travel = map.is_expedition_travel
	
	# Check if we're canceling an expedition (active or traveling/arrived to one)
	if (expedition and expedition.size() > 0) or is_expedition_travel:
		print("Expedition canceled by user")
		GameInfo.current_player.expedition = []
		
		# Reset map panel expedition state
		map.is_expedition_travel = false
		map.expedition_travel_end = 0.0
		map.has_arrived = false
		map.pending_expedition_id = 0
		map.pending_expedition_node_id = 0
		map.pending_expedition_quest_id = 0
		map.set_process(false)
		
		if expedition and expedition.size() > 0:
			UIManager.instance.expedition_panel.end_expedition()
		
		UIManager.instance.hide_current_overlay()
		UIManager.instance.show_panel(UIManager.instance.home_panel)
		return
	
	# Otherwise, handle quest cancellation
	if quest_id != null:
		Websocket.quest_cancel()
		# Only remove from available quests if player clicked at least one option
		var clicked = UIManager.instance.quest.clicked_option_ids
		if clicked.size() > 0:
			GameInfo.complete_quest(int(quest_id))
			print("Quest ", quest_id, " abandoned (options clicked) and removed from daily quests")
		else:
			print("Quest ", quest_id, " canceled before any options clicked, keeping in daily quests")
	
	GameInfo.current_player.traveling = 0
	GameInfo.current_player.traveling_destination = null
	
	# Reset quest panel state so it can reload cleanly
	UIManager.instance.quest.current_quest_id = 0
	UIManager.instance.quest.current_quest = null
	UIManager.instance.quest.clicked_option_ids.clear()
	
	# Reset map panel state
	map.has_arrived = false
	map.set_process(false)
	
	UIManager.instance.hide_current_overlay()
	UIManager.instance.show_panel(UIManager.instance.home_panel)
	print("Quest canceled by user")

func _on_no_pressed():
	_custom_confirm_callback = Callable()
	UIManager.instance.hide_current_overlay()
