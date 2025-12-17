extends PanelContainer
@export var name_label: Label
@export var price_label: Label
@export var price_icon: TextureRect
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label
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

func show_description(item_data: GameInfo.Item, slot_node: Control = null):
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
				# Check if item is in vendor slots (105-112) - show 2x price for buying
				var display_price = item_data.price
				if item_data.bag_slot_id >= 105 and item_data.bag_slot_id <= 112:
					display_price = item_data.price * 2
				price_label.text = str(display_price)
				if price_icon:
					price_icon.visible = true
				price_container.visible = true
			else:
				price_container.visible = false
		
		# Check if this is an elixir (ID > 1000)
		var is_elixir = item_data.id > 1000
		
		if is_elixir:
			# Hide all stat containers for elixirs
			strength_container.visible = false
			stamina_container.visible = false
			agility_container.visible = false
			luck_container.visible = false
			armor_container.visible = false
			
			# Decode ingredient IDs from elixir ID using string manipulation
			# Format: 1000000000000 + ingredientID1(3 digits) + ingredientID2(3 digits) + ingredientID3(3 digits)
			var id_str = str(item_data.id)
			var ingredient1_id = int(id_str.substr(4, 3))  # Characters 4-6 (positions 4,5,6)
			var ingredient2_id = int(id_str.substr(7, 3))  # Characters 7-9 (positions 7,8,9)
			var ingredient3_id = int(id_str.substr(10, 3)) # Characters 10-12 (positions 10,11,12)
			
			# Build effect map to combine duplicate effects
			var effect_map = {}  # Map effect_id to total factor
			for ingredient_id in [ingredient1_id, ingredient2_id, ingredient3_id]:
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
					var effect_line = effect_data.description
					if effect_map[effect_id] > 0:
						effect_line += " " + str(effect_map[effect_id])
					effect_texts.append(effect_line)
			
			# Display combined effects
			if effect_texts.size() > 0:
				effect.text = "\n".join(effect_texts)
				effect.visible = true
			else:
				effect.visible = false
		else:
			# Regular item - show stats normally
			# Get gem stats if item has a socketed gem
			var gem_stats = item_data.get_gem_stats()
			
			# Handle strength stat - hide if 0
			if item_data.strength != 0 or gem_stats.strength != 0:
				if gem_stats.strength > 0:
					strength.text = str(item_data.strength) + " + " + str(gem_stats.strength)
				else:
					strength.text = str(item_data.strength)
				strength_container.visible = true
			else:
				strength_container.visible = false
			
			# Handle stamina stat - hide if 0
			if item_data.stamina != 0 or gem_stats.stamina != 0:
				if gem_stats.stamina > 0:
					stamina.text = str(item_data.stamina) + " + " + str(gem_stats.stamina)
				else:
					stamina.text = str(item_data.stamina)
				stamina_container.visible = true
			else:
				stamina_container.visible = false
			
			# Handle agility stat - hide if 0
			if item_data.agility != 0 or gem_stats.agility != 0:
				if gem_stats.agility > 0:
					agility.text = str(item_data.agility) + " + " + str(gem_stats.agility)
				else:
					agility.text = str(item_data.agility)
				agility_container.visible = true
			else:
				agility_container.visible = false
			
			# Handle luck stat - hide if 0
			if item_data.luck != 0 or gem_stats.luck != 0:
				if gem_stats.luck > 0:
					luck.text = str(item_data.luck) + " + " + str(gem_stats.luck)
				else:
					luck.text = str(item_data.luck)
				luck_container.visible = true
			else:
				luck_container.visible = false
			
			# Handle armor stat - hide if 0
			if item_data.armor != 0 or gem_stats.armor != 0:
				if gem_stats.armor > 0:
					armor.text = str(item_data.armor) + " + " + str(gem_stats.armor)
				else:
					armor.text = str(item_data.armor)
				armor_container.visible = true
			else:
				armor_container.visible = false
			
			# Handle effect description - show enchant_overdrive if present, otherwise show regular effect
			var display_effect_id = item_data.effect_id
			var display_effect_factor = item_data.effect_factor
			
			# If item has enchant_overdrive, use that instead
			if item_data.enchant_overdrive > 0:
				var overdrive_effect = GameInfo.effects_db.get_effect_by_id(item_data.enchant_overdrive)
				if overdrive_effect:
					display_effect_id = item_data.enchant_overdrive
					display_effect_factor = overdrive_effect.factor
			
			# Display effect from database with factor
			if display_effect_id > 0:
				var effect_data = GameInfo.effects_db.get_effect_by_id(display_effect_id)
				if effect_data and effect_data.description != "":
					var effect_text = effect_data.description
					# Append factor to description as integer
					if display_effect_factor != 0.0:
						effect_text += " " + str(int(display_effect_factor))
					
					effect.text = effect_text
					effect.visible = true
				else:
					effect.visible = false
			else:
				effect.visible = false
		
		# Handle socket display
		if socket_label and socket_container:
			if item_data.has_socket:
				if item_data.socketed_gem_id > 0:
					# Socket has a gem - show socket icon + gem icon + gem name
					var gem_item = GameInfo.items_db.get_item_by_id(item_data.socketed_gem_id)
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
		
		# Position the panel relative to the slot if provided
		if slot_node:
			call_deferred("position_near_slot", slot_node)
	else:
		visible = false

func position_near_slot(slot_node: Control):
	# Wait for panel to auto-size
	await get_tree().process_frame
	await get_tree().process_frame  # Wait extra frame to ensure size is stable
	
	# Use the center preset to properly center the panel
	set_anchors_preset(Control.PRESET_CENTER)
	set_offsets_preset(Control.PRESET_CENTER)

func hide_description():
	visible = false
	# Reset size to allow panel to resize for next show
	reset_size()
