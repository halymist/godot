extends HBoxContainer

const ActiveEffectScene = preload("res://Scenes/activeeffect.tscn")
@export var perk_tooltip_panel: Panel
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
	# Instantiate active effect scene
	var active_effect = ActiveEffectScene.instantiate()
	active_effect.setup(effect, perk_tooltip_panel)
	effects_container.add_child(active_effect)
