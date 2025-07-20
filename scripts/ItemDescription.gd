extends Panel
@export var name_label: Label
@export var strength: Label
@export var stamina: Label
@export var agility: Label
@export var luck: Label
@export var armor: Label
@export var effect: Label

func show_description(item_data: GameInfo.Item):
	if item_data:
		name_label.text = item_data.item_name
		strength.text = str(item_data.strength)
		stamina.text = str(item_data.constitution)
		agility.text = str(item_data.dexterity)
		luck.text = str(item_data.luck)
		armor.text = str(item_data.armor)
		effect.text = item_data.effect_description
		visible = true
	else:
		visible = false

func hide_description():
	visible = false
