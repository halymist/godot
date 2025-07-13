extends TextureRect

func _get_drag_data(_at_position):
	print("ItemDrag _get_drag_data called at position: ", _at_position)
	# Create a preview for dragging
	var preview_texture = TextureRect.new()
	preview_texture.texture = texture
	preview_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_texture.size = size
	# Center the preview on the mouse
	preview_texture.position = -size / 2

	var preview = Control.new()
	preview.add_child(preview_texture)
	set_drag_preview(preview)

	# Clear the texture after starting drag
	var old_texture = texture
	texture = null
	return old_texture

func _can_drop_data(_pos, data):
	return data is Texture2D

func _drop_data(_pos, data):
	texture = data
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
