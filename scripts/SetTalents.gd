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
	
	reset_button.pressed.connect(_on_reset_button_pressed)
	
	if UIManager.instance.game_is_ready:
		_setup()
	else:
		UIManager.instance.game_ready.connect(_setup, CONNECT_ONE_SHOT)

func _setup():
	_apply_downloaded_talent_order()
	display_player()
	if not is_read_only:
		UIManager.instance.refresh_stats()

func _on_stats_changed(_stats: Dictionary):
	update_title_label()

func _apply_downloaded_talent_order():
	if not GameInfo.talents_db or GameInfo.talents_db.talents.is_empty():
		return
	var ordered_talents: Array = GameInfo.talents_db.talents
	var column_count = max(columns, 1)
	var row_count = int(ceil(float(ordered_talents.size()) / float(column_count)))
	for visual_index in range(min(talents.size(), ordered_talents.size())):
		var visual_row = int(visual_index / column_count)
		var col = visual_index % column_count
		var source_row = row_count - 1 - visual_row
		var source_index = source_row * column_count + col
		if source_index < 0 or source_index >= ordered_talents.size():
			continue
		var talent_node = talents[visual_index]
		if talent_node.has_method("configure_from_talent_resource"):
			talent_node.configure_from_talent_resource(ordered_talents[source_index])

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
