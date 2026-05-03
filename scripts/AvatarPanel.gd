extends Panel
@export var cosmetics_database: CosmeticDatabase
@export var avatar_instance: Node
@export var selection_grid: GridContainer
@export var face_button: Button
@export var hair_button: Button
@export var eyes_button: Button
@export var nose_button: Button
@export var mouth_button: Button
@export var brows_button: Button
@export var ears_button: Button
@export var special_button: Button
@export var change_button: Button
@export var create_button: Button
@export var back_button: Button

var current_category: String = "face"
var selected_cosmetic_id: int = -1
var selected_cosmetics: Dictionary = {}  # Track selected cosmetics by category
var is_creation_mode: bool = false  # True when creating new character

signal create_character_pressed
signal back_pressed

# Default avatar values
const DEFAULT_AVATAR = [40, 48, 33, 88, 80, 0, 0, 0]  # [face, hair, eyes, nose, mouth, brows, ears, special]

# Temporary preview selections (not yet applied)
var preview_face_id: int = DEFAULT_AVATAR[0]
var preview_hair_id: int = DEFAULT_AVATAR[1]
var preview_eyes_id: int = DEFAULT_AVATAR[2]
var preview_nose_id: int = DEFAULT_AVATAR[3]
var preview_mouth_id: int = DEFAULT_AVATAR[4]
var preview_brows_id: int = 0
var preview_ears_id: int = 0
var preview_special_id: int = 0

# Original player values (to calculate cost)
var original_face_id: int = DEFAULT_AVATAR[0]
var original_hair_id: int = DEFAULT_AVATAR[1]
var original_eyes_id: int = DEFAULT_AVATAR[2]
var original_nose_id: int = DEFAULT_AVATAR[3]
var original_mouth_id: int = DEFAULT_AVATAR[4]
var original_brows_id: int = 0
var original_ears_id: int = 0
var original_special_id: int = 0

func _ready():
	# Connect category buttons
	face_button.pressed.connect(_on_category_selected.bind("face"))
	hair_button.pressed.connect(_on_category_selected.bind("hair"))
	eyes_button.pressed.connect(_on_category_selected.bind("eyes"))
	nose_button.pressed.connect(_on_category_selected.bind("nose"))
	mouth_button.pressed.connect(_on_category_selected.bind("mouth"))
	brows_button.pressed.connect(_on_category_selected.bind("brows"))
	ears_button.pressed.connect(_on_category_selected.bind("ears"))
	special_button.pressed.connect(_on_category_selected.bind("special"))
	
	# Connect change button
	change_button.pressed.connect(_on_change_pressed)
	create_button.pressed.connect(_on_create_pressed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
	
	# Initialize with current player avatar
	if GameInfo.current_player:
		preview_face_id = GameInfo.current_player.avatar_face
		preview_hair_id = GameInfo.current_player.avatar_hair
		preview_eyes_id = GameInfo.current_player.avatar_eyes
		preview_nose_id = GameInfo.current_player.avatar_nose
		preview_mouth_id = GameInfo.current_player.avatar_mouth
		
		original_face_id = GameInfo.current_player.avatar_face
		original_hair_id = GameInfo.current_player.avatar_hair
		original_eyes_id = GameInfo.current_player.avatar_eyes
		original_nose_id = GameInfo.current_player.avatar_nose
		original_mouth_id = GameInfo.current_player.avatar_mouth
	
	# Update change button
	_update_change_button()
	
	# Default category is face; grid is populated once databases are loaded
	current_category = "face"

func _refresh_preview():
	"""Update the avatar preview with all current selections"""
	if avatar_instance and avatar_instance.has_method("set_avatar_ids"):
		avatar_instance.set_avatar_ids(_get_preview_ids())


func _get_preview_ids() -> Dictionary:
	"""Get current preview cosmetic IDs as a dictionary"""
	var ids = {
		"face": preview_face_id,
		"hair": preview_hair_id,
		"eyes": preview_eyes_id,
		"nose": preview_nose_id,
		"mouth": preview_mouth_id,
	}
	if preview_brows_id > 0:
		ids["brows"] = preview_brows_id
	if preview_ears_id > 0:
		ids["ears"] = preview_ears_id
	if preview_special_id > 0:
		ids["special"] = preview_special_id
	return ids

func _on_character_changed():
	if GameInfo.current_player:
		preview_face_id = GameInfo.current_player.avatar_face
		preview_hair_id = GameInfo.current_player.avatar_hair
		preview_eyes_id = GameInfo.current_player.avatar_eyes
		preview_nose_id = GameInfo.current_player.avatar_nose
		preview_mouth_id = GameInfo.current_player.avatar_mouth
		
		original_face_id = GameInfo.current_player.avatar_face
		original_hair_id = GameInfo.current_player.avatar_hair
		original_eyes_id = GameInfo.current_player.avatar_eyes
		original_nose_id = GameInfo.current_player.avatar_nose
		original_mouth_id = GameInfo.current_player.avatar_mouth
		
		_refresh_preview()
		_update_change_button()
		_populate_selection_grid()

func _on_category_selected(category: String):
	current_category = category
	_populate_selection_grid()

func _populate_selection_grid():
	# Do not load cosmetics before the central database init flow in GameInfo
	if not GameInfo.databases_loaded:
		return

	# Ensure cosmetics are loaded
	if not cosmetics_database:
		cosmetics_database = GameInfo.cosmetics_db if GameInfo.cosmetics_db else DataManager.get_cosmetics_database()
	if not cosmetics_database:
		return
	
	# Clear existing items
	for child in selection_grid.get_children():
		child.queue_free()
	
	# Get cosmetics for current category
	var cosmetics = cosmetics_database.get_cosmetics_by_category(current_category)
	
	# Create button for each cosmetic
	for cosmetic in cosmetics:
		var tex = cosmetic.texture
		# Try loading from disk if texture wasn't loaded at DB init time
		if not tex and cosmetic.id > 0:
			tex = DataManager.load_asset_texture("cosmetics", cosmetic.id)
			if tex:
				cosmetic.texture = tex
		if not tex:
			# Use fallback texture for grid display
			var fallback_path = "res://assets/images/fallback/avatar_%s.png" % current_category
			if ResourceLoader.exists(fallback_path):
				tex = load(fallback_path)
		if not tex:
			continue
		
		var button = TextureButton.new()
		button.texture_normal = tex
		button.custom_minimum_size = Vector2(80, 80)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# Add name label so cosmetics with fallback textures are distinguishable
		if cosmetic.cosmetic_name != "":
			var name_label = Label.new()
			name_label.text = cosmetic.cosmetic_name
			name_label.add_theme_font_size_override("font_size", 10)
			name_label.add_theme_color_override("font_color", Color.WHITE)
			name_label.add_theme_color_override("font_shadow_color", Color.BLACK)
			name_label.add_theme_constant_override("shadow_offset_x", 1)
			name_label.add_theme_constant_override("shadow_offset_y", 1)
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.anchors_preset = Control.PRESET_BOTTOM_WIDE
			button.add_child(name_label)
		
		# Add cost label if not free
		if cosmetic.cost > 0:
			var cost_label = Label.new()
			cost_label.text = str(cosmetic.cost)
			cost_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			button.add_child(cost_label)
		
		button.pressed.connect(_on_cosmetic_selected.bind(cosmetic))
		selection_grid.add_child(button)

func on_databases_loaded():
	"""Called by LobbyPanel once GameInfo databases are ready."""
	cosmetics_database = GameInfo.cosmetics_db
	_populate_selection_grid()

func _on_cosmetic_selected(cosmetic: CosmeticResource):
	# Store selected cosmetic for this category
	selected_cosmetics[cosmetic.category] = cosmetic
	
	# Update preview based on category
	match cosmetic.category:
		"face":
			preview_face_id = cosmetic.id
		"hair":
			preview_hair_id = cosmetic.id
		"eyes":
			preview_eyes_id = cosmetic.id
		"nose":
			preview_nose_id = cosmetic.id
		"mouth":
			preview_mouth_id = cosmetic.id
		"brows":
			preview_brows_id = cosmetic.id
		"ears":
			preview_ears_id = cosmetic.id
		"special":
			preview_special_id = cosmetic.id
	
	# Update avatar preview
	_refresh_preview()
	_update_change_button()

func _calculate_total_cost() -> int:
	var total_cost = 0
	
	
	# Only count cost for changed cosmetics
	for category in selected_cosmetics:
		var cosmetic = selected_cosmetics[category]
		var is_changed = false
		
		match category:
			"face":
				is_changed = (preview_face_id != original_face_id)
			"hair":
				is_changed = (preview_hair_id != original_hair_id)
			"eyes":
				is_changed = (preview_eyes_id != original_eyes_id)
			"nose":
				is_changed = (preview_nose_id != original_nose_id)
			"mouth":
				is_changed = (preview_mouth_id != original_mouth_id)
			"brows":
				is_changed = (preview_brows_id != original_brows_id)
			"ears":
				is_changed = (preview_ears_id != original_ears_id)
			"special":
				is_changed = (preview_special_id != original_special_id)
		
		
		if is_changed:
			total_cost += cosmetic.cost
	
	return total_cost

func _has_changes() -> bool:
	"""Check if any avatar part has been changed from original"""
	return (preview_face_id != original_face_id or 
			preview_hair_id != original_hair_id or 
			preview_eyes_id != original_eyes_id or
			preview_nose_id != original_nose_id or
			preview_mouth_id != original_mouth_id or
			preview_brows_id != original_brows_id or
			preview_ears_id != original_ears_id or
			preview_special_id != original_special_id)

func _update_change_button():
	# Skip update if in creation mode
	if is_creation_mode:
		return
	
	var total_cost = _calculate_total_cost()
	var has_changes = _has_changes()
	
	# Enable/disable button based on affordability and if there are changes
	if GameInfo.current_player:
		change_button.disabled = not has_changes or (total_cost > GameInfo.current_player.mushrooms)
	else:
		change_button.disabled = not has_changes

func _on_change_pressed():
	var total_cost = _calculate_total_cost()
	
	# Check if player can afford
	if total_cost > 0 and GameInfo.current_player:
		if GameInfo.current_player.mushrooms < total_cost:
			return

		UIManager.instance.update_mushrooms(-total_cost)
	
	# Apply changes to player data
	if GameInfo.current_player:
		GameInfo.current_player.avatar_face = preview_face_id
		GameInfo.current_player.avatar_hair = preview_hair_id
		GameInfo.current_player.avatar_eyes = preview_eyes_id
		GameInfo.current_player.avatar_nose = preview_nose_id
		GameInfo.current_player.avatar_mouth = preview_mouth_id
		
		# Update original values
		original_face_id = preview_face_id
		original_hair_id = preview_hair_id
		original_eyes_id = preview_eyes_id
		original_nose_id = preview_nose_id
		original_mouth_id = preview_mouth_id
		
		# Update all avatar displays
		if UIManager.instance:
			UIManager.instance.refresh_avatars()
		
		# Clear selected cosmetics and update button
		selected_cosmetics.clear()
		_update_change_button()
		
		# Hide avatar panel (same as back button behavior)
		visible = false
		
		# TODO: Send to server to save

func _on_create_pressed():
	"""Handle create character button press during character creation"""
	create_character_pressed.emit()

func _on_back_pressed():
	"""Handle back button press"""
	back_pressed.emit()

func set_creation_mode(enabled: bool):
	"""Toggle between creation mode and normal mode"""
	is_creation_mode = enabled
	
	# If nodes aren't ready yet, defer the visibility changes
	if not is_node_ready():
		await ready
	
	if change_button:
		change_button.visible = not enabled
	if create_button:
		create_button.visible = enabled
	if back_button:
		back_button.visible = enabled
	
	if enabled:
		# Set default avatar values for new character
		preview_face_id = DEFAULT_AVATAR[0]
		preview_hair_id = DEFAULT_AVATAR[1]
		preview_eyes_id = DEFAULT_AVATAR[2]
		preview_nose_id = DEFAULT_AVATAR[3]
		preview_mouth_id = DEFAULT_AVATAR[4]
		preview_brows_id = 0
		preview_ears_id = 0
		preview_special_id = 0
		
		_refresh_preview()

func get_avatar_data() -> Dictionary:
	return {
		"face": preview_face_id,
		"hair": preview_hair_id,
		"eyes": preview_eyes_id,
		"nose": preview_nose_id,
		"mouth": preview_mouth_id,
		"brows": preview_brows_id,
		"ears": preview_ears_id,
		"special": preview_special_id
	}
