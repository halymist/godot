@tool
extends "res://scripts/UtilityPanel.gd"

const BLESSING_COST = 10
const BlessingScene = preload("res://Scenes/blessing.tscn")

@onready var blessings_container = $BlessingsPanel/Content/ScrollContainer/BlessingsContainer
@onready var bless_button = $BlessingsPanel/Content/BlessButton

var selected_blessing_id: int = -1
var blessing_nodes: Dictionary = {}  # Maps effect_id to blessing node for highlighting

func _ready():
	if Engine.is_editor_hint():
		return
	
	super._ready()
	
	# Connect bless button
	if bless_button:
		bless_button.pressed.connect(_on_bless_button_pressed)
	
	# Load blessings when panel becomes visible
	visibility_changed.connect(_on_visibility_changed)
	
	# Connect to gold changes to update button state
	GameInfo.gold_changed.connect(_on_gold_changed)

func _on_visibility_changed():
	if visible and not Engine.is_editor_hint():
		load_blessings()
		update_bless_button_state()

func _on_gold_changed(_new_gold: int = 0):
	if visible and not Engine.is_editor_hint():
		update_bless_button_state()

func load_blessings():
	if not GameInfo.effects_db or not blessings_container:
		return
	
	# Clear existing blessing nodes
	for child in blessings_container.get_children():
		child.queue_free()
	blessing_nodes.clear()
	
	# Load all effects with id >= 100 (blessings)
	for effect in GameInfo.effects_db.effects:
		if effect.id >= 100:
			create_blessing_row(effect)
	
	# Highlight currently active blessing if any
	if GameInfo.current_player and GameInfo.current_player.blessing > 0:
		highlight_active_blessing(GameInfo.current_player.blessing)
	
	print("Loaded ", blessing_nodes.size(), " blessings")

func create_blessing_row(effect: EffectResource):
	# Instantiate blessing scene
	var blessing = BlessingScene.instantiate()
	blessing.setup(effect)
	
	# Store reference
	blessing_nodes[effect.id] = blessing
	
	# Connect to selection signal
	blessing.blessing_selected.connect(_on_blessing_selected)
	
	# Add to container
	blessings_container.add_child(blessing)

func _on_blessing_selected(blessing_id: int):
	# Clear previous selection visual
	for effect_id in blessing_nodes:
		blessing_nodes[effect_id].set_selected(false)
	
	# Update selected blessing
	selected_blessing_id = blessing_id
	
	# Highlight selected blessing
	if blessing_nodes.has(blessing_id):
		blessing_nodes[blessing_id].set_selected(true)
	
	print("Selected blessing: ", blessing_id)
	
	update_bless_button_state()

func update_bless_button_state():
	if not bless_button or not GameInfo.current_player:
		return
	
	var has_selection = selected_blessing_id != -1
	var has_gold = GameInfo.current_player.gold >= BLESSING_COST
	
	bless_button.disabled = not has_selection or not has_gold

func _on_bless_button_pressed():
	if selected_blessing_id == -1 or not GameInfo.current_player:
		return
	
	if GameInfo.current_player.gold < BLESSING_COST:
		print("Not enough gold for blessing")
		return
	
	# Deduct gold
	GameInfo.current_player.gold -= BLESSING_COST
	GameInfo.gold_changed.emit()
	
	# Apply blessing effect
	GameInfo.current_player.blessing = selected_blessing_id
	GameInfo.stats_changed.emit(GameInfo.current_player.get_player_stats())
	print("Received blessing ID: ", selected_blessing_id, " - cost: ", BLESSING_COST, " gold")
	
	# Highlight the newly active blessing
	highlight_active_blessing(selected_blessing_id)
	
	# Clear selection visual and state
	for effect_id in blessing_nodes:
		blessing_nodes[effect_id].set_selected(false)
	selected_blessing_id = -1
	update_bless_button_state()

func highlight_active_blessing(blessing_id: int):
	# Reset all blessing nodes to default style
	for effect_id in blessing_nodes:
		var blessing_node = blessing_nodes[effect_id]
		blessing_node.set_active(false)
	
	# Highlight the active blessing
	if blessing_nodes.has(blessing_id):
		var active_blessing = blessing_nodes[blessing_id]
		active_blessing.set_active(true)
