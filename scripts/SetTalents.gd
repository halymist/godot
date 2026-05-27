extends GridContainer
@export var talents: Array[AspectRatioContainer] = []
@export var reset_button: Button
@export var title_label: Label

const RESET_COST = 10

var talents_registered_count: int = 0
var displayed_character: GameInfo.GamePlayer = null
var is_read_only: bool = false

func _ready():
	# Auto-populate talents array from children if not set in scene
	if talents.is_empty():
		for child in get_children():
			if child.has_method("update_button_appearance"):
				talents.append(child)
	_sort_talent_nodes_by_grid_position()
	
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

func _sort_talent_nodes_by_grid_position():
	var column_count = max(columns, 1)
	talents.sort_custom(func(a, b):
		var a_id = int(a.get("talentID"))
		var b_id = int(b.get("talentID"))
		var a_row = int((a_id - 1) / column_count)
		var b_row = int((b_id - 1) / column_count)
		if a_row != b_row:
			return a_row > b_row
		return a_id < b_id
	)
	for index in range(talents.size()):
		move_child(talents[index], index)

func refresh_all_talents():
	for talent in talents:
		talent.update_button_appearance()

func display_player():
	displayed_character = GameInfo.current_player
	is_read_only = false
	reset_button.visible = true
	refresh_talents()

func display_character(character: GameInfo.GamePlayer, read_only: bool = true):
	displayed_character = character
	is_read_only = read_only
	reset_button.visible = not read_only
	refresh_talents()

func refresh_talents():
	
	for talent_node in talents:
		if talent_node.has_method("update_from_character"):
			talent_node.update_from_character(displayed_character, is_read_only)
	
	update_title_label()
	update_reset_button_state()

func update_title_label():
	var spent_points = 0
	for talent in displayed_character.talents:
		spent_points += talent.points
	
	if is_read_only:
		title_label.text = "%s's Talents: %d points" % [displayed_character.name, spent_points]
	else:
		title_label.text = "Talent points: %d/%d" % [spent_points, GameInfo.current_player.talent_points]

func update_reset_button_state():
	if not is_read_only:
		var spent_points = 0
		for talent in GameInfo.current_player.talents:
			spent_points += talent.points
		reset_button.disabled = spent_points <= 0 or GameInfo.current_player.silver < RESET_COST

func _on_reset_button_pressed():
	# Check if we have enough silver
	if GameInfo.current_player.silver < RESET_COST:
		return
	
	Websocket.reset_talents()
	if UIManager.instance:
		UIManager.instance.update_silver(-RESET_COST)
	else:
		GameInfo.current_player.silver -= RESET_COST
	
	GameInfo.current_player.talents.clear()
	for talent in talents:
		talent.points = 0
		
	
	for perk in GameInfo.current_player.perks:
		if perk.active:
			perk.active = false

	
	refresh_talents()
	update_reset_button_state()
	
	if UIManager.instance:
		UIManager.instance.refresh_active_effects()
		UIManager.instance.refresh_perks()
