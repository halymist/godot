extends PanelContainer

const EFFECT_FORMATTER = preload("res://scripts/utils/EffectFormatter.gd")
@export var name_label: Label
@export var price_label: Label
@export var price_icon: TextureRect
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label
@export var damage_label: Label
@export var effect: Label
@export var socket_label: Label
@export var socket_icon: TextureRect
@export var gem_icon: TextureRect

# References to the stat containers for hiding/showing
@onready var price_container = price_label.get_parent() if price_label else null
@onready var socket_container = socket_label.get_parent() if socket_label else null
@onready var strength_container = strength.get_parent()
@onready var stamina_container = stamina.get_parent()
@onready var agility_container = agility.get_parent()
@onready var luck_container = luck.get_parent()
@onready var armor_container = armor.get_parent()
@onready var damage_container = damage_label.get_parent() if damage_label else null

func show_description(item_data: GameInfo.Item, _slot_node: Control = null):
	_ensure_node_refs()
	# Reset size to allow panel to resize for new content
	reset_size()
	
	if item_data:
		var display_name = item_data.item_name
		if item_data.get("tempered") and item_data.tempered > 0:
			display_name += " +" + str(item_data.tempered)
		name_label.text = display_name
		
		# Display price if available and > 0
		if price_label and price_container:
			if item_data.price > 0:
				# Check if item is in vendor slot (20) - show 2x price for buying
				var display_price = item_data.price
				if item_data.bag_slot_id == 20:
					display_price = item_data.price * 2
				price_label.text = str(display_price)
				if price_icon:
					price_icon.visible = true
				price_container.visible = true
			else:
				price_container.visible = false
		
		var is_elixir = item_data.type == "Elixir" and (item_data.ingredients.size() > 0 or item_data.elixir_effects.size() > 0)
		
		if is_elixir:
			strength_container.visible = false
			stamina_container.visible = false
			agility_container.visible = false
			luck_container.visible = false
			armor_container.visible = false
			if damage_container:
				damage_container.visible = false
			
			var effect_map = {}

			if item_data.elixir_effects.size() > 0:
				for entry in item_data.elixir_effects:
					var effect_id = int(entry.get("effect_id", 0))
					var factor = float(entry.get("factor", 0.0))
					if effect_id > 0:
						if effect_map.has(effect_id):
							effect_map[effect_id] += factor
						else:
							effect_map[effect_id] = factor
			else:
				for ingredient_id in item_data.ingredients:
					if ingredient_id > 0:
						var ingredient_resource = GameInfo.items_db.get_item_by_id(ingredient_id)
						if ingredient_resource != null and ingredient_resource.effect_id > 0:
							# Add factor to existing effect or create new entry
							var factor = ingredient_resource.effect_factor
							if effect_map.has(ingredient_resource.effect_id):
								effect_map[ingredient_resource.effect_id] += factor
							else:
								effect_map[ingredient_resource.effect_id] = factor
			
			# Build effect text from combined effects
			var effect_texts = []
			for effect_id in effect_map.keys():
				var effect_data = GameInfo.effects_db.get_effect_by_id(effect_id)
				if effect_data:
					var effect_line = EFFECT_FORMATTER.format_with_factor(effect_data.description, float(effect_map[effect_id]), true)
					effect_texts.append(effect_line)
			
			# Display combined effects
			if effect_texts.size() > 0:
				effect.text = "\n".join(effect_texts)
				effect.visible = true
			else:
				effect.visible = false
		else:
			# Regular item - show stats normally
			# Get socketed gem if exists
			var gem = item_data.get_socketed_gem()
			
			# Handle strength stat - hide if 0
			if item_data.strength != 0 or (gem and gem.strength != 0):
				if gem and gem.strength > 0:
					strength.text = str(item_data.strength) + " + " + str(gem.strength)
				else:
					strength.text = str(item_data.strength)
				strength_container.visible = true
			else:
				strength_container.visible = false
			
			# Handle stamina stat - hide if 0
			if item_data.stamina != 0 or (gem and gem.stamina != 0):
				if gem and gem.stamina > 0:
					stamina.text = str(item_data.stamina) + " + " + str(gem.stamina)
				else:
					stamina.text = str(item_data.stamina)
				stamina_container.visible = true
			else:
				stamina_container.visible = false
			
			# Handle agility stat - hide if 0
			if item_data.agility != 0 or (gem and gem.agility != 0):
				if gem and gem.agility > 0:
					agility.text = str(item_data.agility) + " + " + str(gem.agility)
				else:
					agility.text = str(item_data.agility)
				agility_container.visible = true
			else:
				agility_container.visible = false
			
			# Handle luck stat - hide if 0
			if item_data.luck != 0 or (gem and gem.luck != 0):
				if gem and gem.luck > 0:
					luck.text = str(item_data.luck) + " + " + str(gem.luck)
				else:
					luck.text = str(item_data.luck)
				luck_container.visible = true
			else:
				luck_container.visible = false
			
			# Handle armor stat - hide if 0
			if item_data.armor != 0 or (gem and gem.armor != 0):
				if gem and gem.armor > 0:
					armor.text = str(item_data.armor) + " + " + str(gem.armor)
				else:
					armor.text = str(item_data.armor)
				armor_container.visible = true
			else:
				armor_container.visible = false
			
			# Handle weapon damage - show for weapons only
			if damage_label and damage_container:
				if item_data.type == "Weapon" and (item_data.damage_min > 0 or item_data.damage_max > 0):
					damage_label.text = str(item_data.damage_min) + " - " + str(item_data.damage_max)
					damage_container.visible = true
				else:
					damage_container.visible = false
			
			# Handle effect description - show effect_overdrive if present, otherwise show regular effect
			var display_effect_id = item_data.effect_id
			var display_effect_factor = item_data.effect_factor
			
			# If item has effect_overdrive, use that instead
			if item_data.effect_overdrive > 0:
				var overdrive_effect = GameInfo.effects_db.get_effect_by_id(item_data.effect_overdrive)
				if overdrive_effect:
					display_effect_id = item_data.effect_overdrive
					display_effect_factor = overdrive_effect.factor
			
			# Display effect from database with factor
			if display_effect_id > 0:
				var effect_data = GameInfo.effects_db.get_effect_by_id(display_effect_id)
				if effect_data and effect_data.description != "":
					var effect_text = EFFECT_FORMATTER.format_with_factor(effect_data.description, display_effect_factor, true)
					
					effect.text = effect_text
					effect.visible = true
				else:
					effect.visible = false
			else:
				effect.visible = false
		
		# Handle socket display
		if socket_label and socket_container:
			if item_data.has_socket:
				if item_data.socket_id > 0:
					# Socket has a gem - show socket icon + gem icon + gem name
					var gem_item = GameInfo.items_db.get_item_by_id(item_data.socket_id)
					if gem_item:
						socket_label.text = gem_item.item_name
						socket_label.modulate = Color(0.5, 1.0, 0.5)  # Green for socketed
						if gem_icon:
							gem_icon.texture = gem_item.icon
							gem_icon.visible = true
					else:
						socket_label.text = "Unknown Gem"
						socket_label.modulate = Color(1.0, 0.5, 0.5)  # Red for error
						if gem_icon:
							gem_icon.visible = false
				else:
					# Socket is empty - show socket icon + "Empty" text
					socket_label.text = "Empty"
					socket_label.modulate = Color(0.7, 0.7, 0.7)  # Gray for empty
					if gem_icon:
						gem_icon.visible = false
				socket_container.visible = true
			else:
				# No socket
				socket_container.visible = false
		
		# Reset size again after all content is set to force proper recalculation
		reset_size()
		
		# Show the panel
		visible = true
		
	else:
		visible = false

func hide_description():
	visible = false
	# Reset size to allow panel to resize for next show
	reset_size()

func _ensure_node_refs():
	if not name_label:
		name_label = get_node_or_null("MarginContainer/VBoxContainer/Name")
	if not price_label:
		price_label = get_node_or_null("MarginContainer/VBoxContainer/PriceContainer/Value")
	if not price_icon:
		price_icon = get_node_or_null("MarginContainer/VBoxContainer/PriceContainer/SilverIcon")
	if not strength:
		strength = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer/Value")
	if not stamina:
		stamina = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer2/Value")
	if not agility:
		agility = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer3/Value")
	if not luck:
		luck = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer4/Value")
	if not armor:
		armor = get_node_or_null("MarginContainer/VBoxContainer/HBoxContainer5/Value")
	if not damage_label:
		damage_label = get_node_or_null("MarginContainer/VBoxContainer/DamageContainer/Value")
	if not effect:
		effect = get_node_or_null("MarginContainer/VBoxContainer/Effect")
	if not socket_label:
		socket_label = get_node_or_null("MarginContainer/VBoxContainer/SocketContainer/Value")
	if not socket_icon:
		socket_icon = get_node_or_null("MarginContainer/VBoxContainer/SocketContainer/SocketIcon")
	if not gem_icon:
		gem_icon = get_node_or_null("MarginContainer/VBoxContainer/SocketContainer/SocketIcon/GemIcon")
	price_container = price_label.get_parent() if price_label else null
	socket_container = socket_label.get_parent() if socket_label else null
	strength_container = strength.get_parent() if strength else null
	stamina_container = stamina.get_parent() if stamina else null
	agility_container = agility.get_parent() if agility else null
	luck_container = luck.get_parent() if luck else null
	armor_container = armor.get_parent() if armor else null
	damage_container = damage_label.get_parent() if damage_label else null
