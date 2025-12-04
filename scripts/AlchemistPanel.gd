@tool
extends "res://scripts/UtilityPanel.gd"

const BREW_COST = 10

# Ingredient slot IDs
const SLOT_1 = 100
const SLOT_2 = 101
const SLOT_3 = 102

# Node references
@onready var result_preview = $ItemsPanel/Content/ResultPreview
@onready var brew_button = $ItemsPanel/Content/BrewButton

func _ready():
	super._ready()
	
	if Engine.is_editor_hint():
		return
	
	# Connect brew button
	brew_button.pressed.connect(_on_brew_button_pressed)
	
	# Connect to gold and bag changes to update UI
	if GameInfo.gold_changed:
		GameInfo.gold_changed.connect(_on_gold_changed)
	if GameInfo.bag_slots_changed:
		GameInfo.bag_slots_changed.connect(_on_bag_slots_changed)
	
	update_brew_button_state()
	update_result_preview()

func get_ingredient_in_slot(slot_id: int) -> GameInfo.Item:
	for item in GameInfo.current_player.bag_slots:
		if item.bag_slot_id == slot_id:
			return item
	return null

func update_result_preview():
	var effects = []
	
	# Check all three ingredient slots
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			# Get item resource from database
			var item_resource = GameInfo.items_db.get_item_by_id(item.id)
			if item_resource and item_resource.effect_id > 0:
				# Find effect in database
				var effect = GameInfo.effects_db.get_effect_by_id(item_resource.effect_id)
				if effect:
					var effect_text = effect.name
					if item_resource.effect_factor > 0:
						effect_text += " (x" + str(item_resource.effect_factor) + ")"
					effects.append(effect_text)
	
	# Update preview label
	if effects.size() > 0:
		result_preview.text = "Elixir Effects:\n" + "\n".join(effects)
		result_preview.add_theme_color_override("font_color", Color(0.7, 0.85, 0.6, 1))
	else:
		result_preview.text = "Elixir Effects: None"
		result_preview.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))

func update_brew_button_state():
	# Check if we have at least one ingredient
	var has_ingredients = false
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		if get_ingredient_in_slot(slot_id):
			has_ingredients = true
			break
	
	# Check if we have enough gold
	var has_gold = GameInfo.current_player.gold >= BREW_COST
	
	# Enable button only if both conditions are met
	brew_button.disabled = not (has_ingredients and has_gold)

func _on_brew_button_pressed():
	# Check gold
	if GameInfo.current_player.gold < BREW_COST:
		return
	
	# Check if we have at least one ingredient
	var has_ingredients = false
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		if get_ingredient_in_slot(slot_id):
			has_ingredients = true
			break
	
	if not has_ingredients:
		return
	
	# Deduct gold
	GameInfo.current_player.gold -= BREW_COST
	GameInfo.gold_changed.emit(GameInfo.current_player.gold)
	
	# TODO: Create elixir item and add to inventory
	print("Brewing elixir with effects:")
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			var item_resource = GameInfo.items_db.get_item_by_id(item.id)
			if item_resource:
				print("  - Effect ID: ", item_resource.effect_id, " Factor: ", item_resource.effect_factor)
	
	# Remove ingredients from slots (they get consumed)
	var items_to_remove = []
	for slot_id in [SLOT_1, SLOT_2, SLOT_3]:
		var item = get_ingredient_in_slot(slot_id)
		if item:
			items_to_remove.append(item)
	
	for item in items_to_remove:
		GameInfo.current_player.bag_slots.erase(item)
	
	GameInfo.bag_slots_changed.emit()

func _on_gold_changed(_new_gold: int):
	update_brew_button_state()

func _on_bag_slots_changed():
	update_result_preview()
	update_brew_button_state()
