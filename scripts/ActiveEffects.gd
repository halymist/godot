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
		var blessing_perk = GameInfo.perks_db.get_perk_by_id(GameInfo.current_player.blessing) if GameInfo.perks_db else null
		if blessing_perk:
			# Get the effect referenced by the blessing perk
			var effect = GameInfo.effects_db.get_effect_by_id(blessing_perk.effect1_id) if GameInfo.effects_db else null
			if effect:
				create_effect_display(effect, blessing_perk.factor1)

func create_effect_display(effect: EffectResource, factor: float = 0.0):
	# Instantiate active effect scene
	var active_effect = ActiveEffectScene.instantiate()
	active_effect.setup(effect, perk_tooltip_panel, factor)
	effects_container.add_child(active_effect)
