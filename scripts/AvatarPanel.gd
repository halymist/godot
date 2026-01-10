extends Panel
@export var cosmetics_database: CosmeticDatabase

@onready var avatar_instance: Node = $PreviewPanel/AvatarPreview/AvatarInstance
@onready var selection_grid: GridContainer = $SelectionPanel/SelectionContainer/SelectionGrid
@onready var face_button: Button = $CategoryButtons/FaceButton
@onready var hair_button: Button = $CategoryButtons/HairButton
@onready var eyes_button: Button = $CategoryButtons/EyesButton
@onready var nose_button: Button = $CategoryButtons/NoseButton
@onready var mouth_button: Button = $CategoryButtons/MouthButton
@onready var change_button: Button = $ChangeButton
@onready var change_label: Label = $ChangeButton/ButtonContent/ButtonLabel
@onready var change_icon: TextureRect = $ChangeButton/ButtonContent/ButtonIcon
@onready var change_paren: Label = $ChangeButton/ButtonContent/CloseParen

var current_category: String = "Face"
var selected_cosmetic_id: int = -1
var selected_cosmetics: Dictionary = {}  # Track selected cosmetics by category

# Temporary preview selections (not yet applied)
var preview_face_id: int = 1
var preview_hair_id: int = 10
var preview_eyes_id: int = 20
var preview_nose_id: int = 30
var preview_mouth_id: int = 40

# Original player values (to calculate cost)
var original_face_id: int = 1
var original_hair_id: int = 10
var original_eyes_id: int = 20
var original_nose_id: int = 30
var original_mouth_id: int = 40

func _ready():
	# Load cosmetics database
	if not cosmetics_database:
		cosmetics_database = load("res://data/cosmetics.tres")
	
	# Connect category buttons
	face_button.pressed.connect(_on_category_selected.bind("Face"))
	hair_button.pressed.connect(_on_category_selected.bind("Hair"))
	eyes_button.pressed.connect(_on_category_selected.bind("Eyes"))
	nose_button.pressed.connect(_on_category_selected.bind("Nose"))
	mouth_button.pressed.connect(_on_category_selected.bind("Mouth"))
	
	# Connect change button
	change_button.pressed.connect(_on_change_pressed)
	
	# Connect to character changed signal
	if GameInfo.has_signal("character_changed"):
		GameInfo.character_changed.connect(_on_character_changed)
	
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
		preview_hair_id = GameInfo.current_player.avatar_hair
		preview_eyes_id = GameInfo.current_player.avatar_eyes
		original_face_id = preview_face_id
		original_hair_id = preview_hair_id
		original_eyes_id = preview_eyes_id
	
	# Update change button
	_update_change_button()
	
	# Show face cosmetics by default
	_on_category_selected("Face")

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
		
		# Update avatar preview
		if avatar_instance and avatar_instance.has_method("set_avatar_from_ids"):
			avatar_instance.set_avatar_from_ids(preview_face_id, preview_hair_id, preview_eyes_id, preview_nose_id, preview_mouth_id)
		
		_update_change_button()
		_populate_selection_grid()

func _on_category_selected(category: String):
	current_category = category
	_populate_selection_grid()

func _populate_selection_grid():
	# Clear existing items
	for child in selection_grid.get_children():
		child.queue_free()
	
	# Get cosmetics for current category
	var cosmetics = cosmetics_database.get_cosmetics_by_category(current_category)
	
	# Create button for each cosmetic
	for cosmetic in cosmetics:
		var button = TextureButton.new()
		button.texture_normal = cosmetic.texture
		button.custom_minimum_size = Vector2(80, 80)
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		
		# Add cost label if not free
		if cosmetic.cost > 0:
			var cost_label = Label.new()
			cost_label.text = str(cosmetic.cost)
			cost_label.add_theme_color_override("font_color", Color(1, 0.8, 0))
			button.add_child(cost_label)
		
		button.pressed.connect(_on_cosmetic_selected.bind(cosmetic))
		selection_grid.add_child(button)

func _on_cosmetic_selected(cosmetic: CosmeticResource):
	# Store selected cosmetic for this category
	selected_cosmetics[cosmetic.category] = cosmetic
	
	# Update preview based on category
	match cosmetic.category:
		"Face":
			preview_face_id = cosmetic.id
		"Hair":
			preview_hair_id = cosmetic.id
		"Eyes":
			preview_eyes_id = cosmetic.id
		"Nose":
			preview_nose_id = cosmetic.id
		"Mouth":
			preview_mouth_id = cosmetic.id
	
	# Update avatar preview
	if avatar_instance and avatar_instance.has_method("set_avatar_from_ids"):
		avatar_instance.set_avatar_from_ids(preview_face_id, preview_hair_id, preview_eyes_id, preview_nose_id, preview_mouth_id)
	_update_change_button()

func _calculate_total_cost() -> int:
	var total_cost = 0
	
	print("=== Calculating Cost ===")
	print("Selected cosmetics: ", selected_cosmetics)
	print("Original IDs - Face:", original_face_id, " Hair:", original_hair_id, " Eyes:", original_eyes_id, " Nose:", original_nose_id, " Mouth:", original_mouth_id)
	print("Preview IDs - Face:", preview_face_id, " Hair:", preview_hair_id, " Eyes:", preview_eyes_id, " Nose:", preview_nose_id, " Mouth:", preview_mouth_id)
	
	# Only count cost for changed cosmetics
	for category in selected_cosmetics:
		var cosmetic = selected_cosmetics[category]
		var is_changed = false
		
		match category:
			"Face":
				is_changed = (preview_face_id != original_face_id)
			"Hair":
				is_changed = (preview_hair_id != original_hair_id)
			"Eyes":
				is_changed = (preview_eyes_id != original_eyes_id)
			"Nose":
				is_changed = (preview_nose_id != original_nose_id)
			"Mouth":
				is_changed = (preview_mouth_id != original_mouth_id)
		
		print("Category:", category, " Changed:", is_changed, " Cost:", cosmetic.cost)
		
		if is_changed:
			total_cost += cosmetic.cost
	
	print("Total cost:", total_cost)
	return total_cost

func _has_changes() -> bool:
	"""Check if any avatar part has been changed from original"""
	return (preview_face_id != original_face_id or 
			preview_hair_id != original_hair_id or 
			preview_eyes_id != original_eyes_id or
			preview_nose_id != original_nose_id or
			preview_mouth_id != original_mouth_id)

func _update_change_button():
	var total_cost = _calculate_total_cost()
	var has_changes = _has_changes()
	
	if total_cost > 0:
		change_label.text = "CHANGE (%d " % total_cost
		change_icon.visible = true
		change_paren.visible = true
	else:
		change_label.text = "CHANGE"
		change_icon.visible = false
		change_paren.visible = false
	
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
			print("Not enough mushrooms!")
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
		print("Avatar updated! Face:", preview_face_id, " Hair:", preview_hair_id, " Eyes:", preview_eyes_id, " Nose:", preview_nose_id, " Mouth:", preview_mouth_id)
