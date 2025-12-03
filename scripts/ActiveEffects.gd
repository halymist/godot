extends HBoxContainer

@onready var effects_container = $EffectsContainer

func _ready():
	# Connect to stats_changed to update active effects display
	GameInfo.stats_changed.connect(_on_stats_changed)
	
	# Initial update
	update_active_effects()

func _on_stats_changed(_stats: Dictionary):
	update_active_effects()

func update_active_effects():
	if not GameInfo.current_player or not effects_container:
		return
	
	# Clear existing effect displays
	for child in effects_container.get_children():
		child.queue_free()
	
	# Display active blessing if any
	if GameInfo.current_player.blessing > 0:
		var blessing_effect = GameInfo.effects_db.get_effect_by_id(GameInfo.current_player.blessing)
		if blessing_effect:
			create_effect_display(blessing_effect)

func create_effect_display(effect: EffectResource):
	# Create container for the effect
	var effect_box = VBoxContainer.new()
	effect_box.custom_minimum_size = Vector2(60, 60)
	effect_box.add_theme_constant_override("separation", 2)
	
	# Create square icon container
	var icon_container = AspectRatioContainer.new()
	icon_container.custom_minimum_size = Vector2(48, 48)
	icon_container.ratio = 1.0  # Force square
	icon_container.stretch_mode = AspectRatioContainer.STRETCH_FIT
	
	# Create icon
	if effect.icon:
		var icon = TextureRect.new()
		icon.texture = effect.icon
		icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_container.add_child(icon)
	
	effect_box.add_child(icon_container)
	
	# Create name label
	var name_label = Label.new()
	name_label.text = effect.name
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_box.add_child(name_label)
	
	effects_container.add_child(effect_box)
