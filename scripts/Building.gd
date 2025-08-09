extends TextureRect
class_name Building

@export var building_id: String = ""
@export var building_name: String = ""
@export var interior_texture: Texture2D
@export var interior_background: TextureRect  # Direct reference to interior background
@export var interior_content: Control  # Direct reference to interior content

@onready var click_button: Button = $ClickButton

signal building_clicked(building: Building)

func _ready():
	# Connect the button press signal
	click_button.button_up.connect(_on_button_pressed)

func _on_button_pressed():
	building_clicked.emit(self)

func show_interior():
	# Apply interior texture and adjust size to match texture aspect ratio
	if interior_background and interior_texture and interior_content:
		interior_background.texture = interior_texture
		
		# Get the texture size
		var texture_size = interior_texture.get_size()
		
		# Get the actual height of the interior content area
		var content_height = interior_content.size.y
		if content_height <= 0:
			# Fallback to parent container height
			var scroll_container = interior_content.get_parent()
			if scroll_container:
				content_height = scroll_container.size.y
		
		print("Interior content height: ", content_height)
		
		# Calculate width based on texture aspect ratio and actual content height
		var aspect_ratio = texture_size.x / texture_size.y
		var target_width = content_height * aspect_ratio
		
		# Set the custom minimum size to match the aspect ratio
		interior_content.custom_minimum_size = Vector2(target_width, content_height)
		
		print("Set interior size to ", target_width, "x", content_height, " (aspect ratio: ", aspect_ratio, ")")
		print("Original texture size: ", texture_size)
		
		print("Applied interior texture and sized content")
	else:
		print("Warning: Missing interior references - background:", interior_background != null, " texture:", interior_texture != null, " content:", interior_content != null)
