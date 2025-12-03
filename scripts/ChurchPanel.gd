@tool
extends "res://scripts/UtilityPanel.gd"

const BLESSING_COST = 10

@onready var blessings_container = $BlessingsPanel/Content/ScrollContainer/BlessingsContainer
@onready var bless_button = $BlessingsPanel/Content/BlessButton

var selected_blessing_id: int = -1
var blessing_buttons: Array = []

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
	
	# Clear existing blessing buttons
	for child in blessings_container.get_children():
		child.queue_free()
	blessing_buttons.clear()
	
	# Load all effects with id >= 100 (blessings)
	for effect in GameInfo.effects_db.effects:
		if effect.id >= 100:
			create_blessing_row(effect)
	
	print("Loaded ", blessing_buttons.size(), " blessings")

func create_blessing_row(effect: EffectResource):
	# Create HBoxContainer for the row
	var row = HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.custom_minimum_size = Vector2(0, 60)
	
	# Create selection button (acts like radio button)
	var select_button = Button.new()
	select_button.custom_minimum_size = Vector2(40, 40)
	select_button.toggle_mode = true
	select_button.text = ""
	select_button.pressed.connect(_on_blessing_selected.bind(effect.id, select_button))
	blessing_buttons.append(select_button)
	row.add_child(select_button)
	
	# Create icon (placeholder for now)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# TODO: Load actual blessing icon when available
	row.add_child(icon)
	
	# Create info container
	var info = VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	# Create name label
	var name_label = Label.new()
	name_label.text = effect.name
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	name_label.add_theme_font_size_override("font_size", 15)
	info.add_child(name_label)
	
	# Create description label
	var desc_label = Label.new()
	desc_label.text = effect.description
	desc_label.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65, 1))
	desc_label.add_theme_font_size_override("font_size", 12)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_label)
	
	row.add_child(info)
	blessings_container.add_child(row)

func _on_blessing_selected(blessing_id: int, button: Button):
	# Deselect all other buttons
	for btn in blessing_buttons:
		if btn != button:
			btn.button_pressed = false
	
	# Update selected blessing
	if button.button_pressed:
		selected_blessing_id = blessing_id
		print("Selected blessing: ", blessing_id)
	else:
		selected_blessing_id = -1
	
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
	
	# TODO: Apply blessing effect (store active blessing ID in player data)
	print("Received blessing ID: ", selected_blessing_id, " - cost: ", BLESSING_COST, " gold")
	
	# Deselect all buttons after blessing
	for btn in blessing_buttons:
		btn.button_pressed = false
	selected_blessing_id = -1
	update_bless_button_state()
