extends Panel
@export var name_label: Label
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label
@export var effect: Label

func show_description(item_data: Dictionary):
	name_label.text = item_data.get("item_name", "Unknown")
	strength.text = str(item_data.get("strength", 0))
	stamina.text = str(item_data.get("constitution", 0))
	agility.text = str(item_data.get("dexterity", 0))
	luck.text = str(item_data.get("luck", 0))
	armor.text = str(item_data.get("armor", 0))
	effect.text = item_data.get("effect_description", "")
	visible = true

func hide_description():
	visible = false
