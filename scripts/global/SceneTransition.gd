extends CanvasLayer

var color_rect: ColorRect

func _ready():
	layer = 100
	var control = Control.new()
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(control)

	color_rect = ColorRect.new()
	color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(color_rect)

func change_scene_to_file(path: String) -> void:
	print("[load] scene transition file fade_out start ", path)
	await fade_out()
	var start_ms = Time.get_ticks_msec()
	get_tree().change_scene_to_file(path)
	print("[load] scene transition file swap ", Time.get_ticks_msec() - start_ms, "ms path=", path)
	await get_tree().process_frame
	await fade_in()

func change_scene_to_packed(scene: PackedScene) -> void:
	print("[load] scene transition packed fade_out start")
	await fade_out()
	var start_ms = Time.get_ticks_msec()
	get_tree().change_scene_to_packed(scene)
	print("[load] scene transition packed swap ", Time.get_ticks_msec() - start_ms, "ms")
	await get_tree().process_frame
	await fade_in()

func change_scene_to_packed_after_dark(scene: PackedScene) -> void:
	"""Switch scene assuming the screen is already faded to black."""
	var start_ms = Time.get_ticks_msec()
	get_tree().change_scene_to_packed(scene)
	print("[load] scene transition packed swap after dark ", Time.get_ticks_msec() - start_ms, "ms")
	await get_tree().process_frame
	await fade_in()

func fade_out(duration: float = 0.35) -> void:
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, duration)
	await tween.finished

func fade_in(duration: float = 0.35) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 0.0, duration)
	await tween.finished
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
