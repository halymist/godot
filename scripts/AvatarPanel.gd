extends "res://scripts/ConstrainedPanel.gd"

@export var cosmetics_database: CosmeticDatabase

@onready var avatar_instance: Node = $AvatarPreview/AvatarInstance
@onready var selection_grid: GridContainer = $SelectionContainer/SelectionGrid
@onready var face_button: Button = $CategoryButtons/FaceButton
@onready var hair_button: Button = $CategoryButtons/HairButton
@onready var eyes_button: Button = $CategoryButtons/EyesButton
@onready var nose_button: Button = $CategoryButtons/NoseButton
@onready var mouth_button: Button = $CategoryButtons/MouthButton
@onready var change_button: Button = $ChangeButton

var current_category: String = "Face"
var selected_cosmetic_id: int = -1

# Temporary preview selections (not yet applied)
var preview_face_id: int = 1
var preview_hair_id: int = 1
var preview_eyes_id: int = 1
var preview_nose_id: int = 1
var preview_mouth_id: int = 1

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
	
	# Initialize with current player avatar
	if GameInfo.current_player:
		preview_face_id = GameInfo.current_player.avatar_face
		preview_hair_id = GameInfo.current_player.avatar_hair
		preview_eyes_id = GameInfo.current_player.avatar_eyes
	
	# Show face cosmetics by default
	_on_category_selected("Face")

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
	# Check if player can afford
	if cosmetic.cost > 0 and GameInfo.current_player:
		if GameInfo.current_player.mushrooms < cosmetic.cost:
			print("Not enough mushrooms!")
			return
	
	# Update preview based on category
	match cosmetic.category:
		"Face":
			preview_face_id = cosmetic.id
		"Hair":
			preview_hair_id = cosmetic.id - 9  # Convert cosmetic ID to hair texture index
		"Eyes":
			preview_eyes_id = cosmetic.id - 19  # Convert cosmetic ID to eyes texture index
		"Nose":
			preview_nose_id = cosmetic.id
		"Mouth":
			preview_mouth_id = cosmetic.id
	
	# Update avatar preview
	if avatar_instance and avatar_instance.has_method("set_avatar_from_ids"):
		avatar_instance.set_avatar_from_ids(preview_face_id, preview_hair_id, preview_eyes_id)
	
	selected_cosmetic_id = cosmetic.id

func _on_change_pressed():
	if selected_cosmetic_id < 0:
		return
	
	# Get the cosmetic
	var cosmetic = cosmetics_database.get_cosmetic_by_id(selected_cosmetic_id)
	if not cosmetic:
		return
	
	# Check cost and deduct
	if cosmetic.cost > 0 and GameInfo.current_player:
		if GameInfo.current_player.mushrooms < cosmetic.cost:
			print("Not enough mushrooms!")
			return
		GameInfo.current_player.mushrooms -= cosmetic.cost
	
	# Apply changes to player data
	if GameInfo.current_player:
		GameInfo.current_player.avatar_face = preview_face_id
		GameInfo.current_player.avatar_hair = preview_hair_id
		GameInfo.current_player.avatar_eyes = preview_eyes_id
		
		# TODO: Send to server to save
		print("Avatar updated! Face:", preview_face_id, " Hair:", preview_hair_id, " Eyes:", preview_eyes_id)
