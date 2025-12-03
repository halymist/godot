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
	effect_box.custom_minimum_size = Vector2(80, 40)
	
	# Create name label
	var name_label = Label.new()
	name_label.text = effect.name
	name_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7, 1))
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_box.add_child(name_label)
	
	# TODO: Add effect icon above name when available
	
	effects_container.add_child(effect_box)
