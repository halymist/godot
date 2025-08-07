extends VBoxContainer

@export var perk_icon_scene: PackedScene
var perk_icons_container: HBoxContainer
var description_panel: Panel

func _ready():
	perk_icons_container = $PerkIcons
	description_panel = get_tree().root.get_node("Game/Portrait/GameScene/ItemDescription")

func update_active_perks():
	# Clear existing icons
	for child in perk_icons_container.get_children():
		child.queue_free()
	
	# Get all active perks from GameInfo
	var game_perks = GameInfo.current_player.perks
	
	for perk in game_perks:
		if perk.active:
			_create_perk_icon(perk)

func _create_perk_icon(perk: GameInfo.Perk):
	# Create a simple icon for the perk
	var icon_container = AspectRatioContainer.new()
	icon_container.ratio = 1.0  # Square aspect ratio
	icon_container.custom_minimum_size = Vector2(50, 50)
	
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Load perk icon based on asset_id
	var texture_path = "res://assets/images/ui/armor.png"  # Default for now
	icon.texture = load(texture_path)
	
	icon_container.add_child(icon)
	
	# Add hover functionality for description
	icon_container.mouse_entered.connect(_on_perk_icon_hover.bind(perk))
	icon_container.mouse_exited.connect(_on_perk_icon_exit)
	
	perk_icons_container.add_child(icon_container)

func _on_perk_icon_hover(perk: GameInfo.Perk):
	if description_panel:
		# Create a simple item-like object for the description panel
		var perk_display = GameInfo.Item.new()
		perk_display.item_name = perk.perk_name
		perk_display.effect_description = perk.description
		description_panel.show_description(perk_display)

func _on_perk_icon_exit():
	if description_panel:
		description_panel.hide_description()
