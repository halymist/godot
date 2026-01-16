extends GridContainer
@export var talents: Array[AspectRatioContainer] = []
@export var reset_button: Button
@export var title_label: Label

var talents_registered_count: int = 0
var displayed_character: GameInfo.GamePlayer = null
var is_read_only: bool = false

func _ready():
	reset_button.pressed.connect(_on_reset_button_pressed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	display_player()
	if not is_read_only:
		UIManager.instance.refresh_stats()

func _on_stats_changed(_stats: Dictionary):
	update_title_label()

func refresh_all_talents():
	for talent in talents:
		talent.update_button_appearance()

func display_player():
	print("SetTalents: display_player called")
	displayed_character = GameInfo.current_player
	is_read_only = false
	reset_button.visible = true
	refresh_talents()

func display_character(character: GameInfo.GamePlayer, read_only: bool = true):
	print("SetTalents: display_character called for: ", character.name, " read_only=", read_only)
	displayed_character = character
	is_read_only = read_only
	reset_button.visible = not read_only
	refresh_talents()

func refresh_talents():
	print("SetTalents: Refreshing talents for: ", displayed_character.name)
	
	for talent_node in talents:
		if talent_node.has_method("update_from_character"):
			talent_node.update_from_character(displayed_character, is_read_only)
	
	update_title_label()

func update_title_label():
	var spent_points = 0
	for talent in displayed_character.talents:
		spent_points += talent.points
	
	if is_read_only:
		title_label.text = "%s's Talents: %d points" % [displayed_character.name, spent_points]
	else:
		title_label.text = "Talent points: %d/%d" % [spent_points, GameInfo.current_player.talent_points]

func _on_reset_button_pressed():	
	Websocket.reset_talents()
	
	GameInfo.current_player.talents.clear()
	for talent in talents:
		talent.points = 0
		
	print("Reset all talents - cleared GameInfo talent data")
	
	for perk in GameInfo.current_player.perks:
		if perk.active:
			perk.active = false

	print("Reset perks - deactivated all active perks")
	
	refresh_all_talents()
	update_title_label()
	
	UIManager.instance.refresh_active_effects()
	UIManager.instance.refresh_perks()
	print("Reset complete - all talents reset to 0 points")
