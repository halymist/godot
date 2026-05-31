class_name SettlementPanelUtils
extends RefCounted

static func load_utility_content(panel: TextureRect, image_area: TextureRect, chat_bubble: ChatBubble) -> Dictionary:
	var settlement = _get_current_settlement()
	if not settlement:
		return {}
	_apply_texture(panel, image_area, settlement.get_utility_texture())
	_apply_message_bounds(chat_bubble, settlement.has_utility_msg_rect(), settlement.utility_msg_bottom_left, settlement.utility_msg_bottom_right)
	return {
		"entered": settlement.get_utility_on_entered_lines(),
		"placed": settlement.get_utility_on_placed_lines(),
		"action": settlement.get_utility_on_action_lines()
	}

static func load_vendor_content(panel: TextureRect, image_area: TextureRect, chat_bubble: ChatBubble) -> Dictionary:
	var settlement = _get_current_settlement()
	if not settlement:
		return {}
	_apply_texture(panel, image_area, settlement.get_vendor_texture())
	_apply_message_bounds(chat_bubble, settlement.has_vendor_msg_rect(), settlement.vendor_msg_bottom_left, settlement.vendor_msg_bottom_right)
	return {
		"entered": settlement.get_vendor_on_entered_lines(),
		"sold": settlement.get_vendor_on_sold_lines(),
		"bought": settlement.get_vendor_on_bought_lines()
	}

static func load_healer_content(panel: TextureRect, image_area: TextureRect, chat_bubble: ChatBubble) -> Dictionary:
	var settlement = _get_current_settlement()
	if not settlement:
		return {}
	_apply_texture(panel, image_area, settlement.get_healer_texture())
	_apply_message_bounds(chat_bubble, settlement.has_healer_msg_rect(), settlement.healer_msg_bottom_left, settlement.healer_msg_bottom_right)
	return {
		"entered": settlement.get_healer_on_entered_lines(),
		"healed": settlement.get_healer_on_healed_lines(),
		"cured": settlement.get_healer_on_cured_lines()
	}

static func show_greeting(chat_bubble: ChatBubble, greetings: Array[String]):
	if not chat_bubble or greetings.is_empty():
		return
	chat_bubble.show_with_text(greetings[randi() % greetings.size()], 4.0)

static func _get_current_settlement():
	if not GameInfo.current_player or not GameInfo.settlements_db:
		return null
	return GameInfo.settlements_db.get_settlement_by_id(GameInfo.current_player.location)

static func _apply_texture(panel: TextureRect, image_area: TextureRect, panel_texture: Texture2D):
	if not panel_texture:
		return
	if image_area:
		image_area.texture = panel_texture
		if panel:
			panel.texture = null
	elif panel:
		panel.texture = panel_texture

static func _apply_message_bounds(chat_bubble: ChatBubble, has_bounds: bool, corner_a: Vector2, corner_b: Vector2):
	if not chat_bubble:
		return
	if has_bounds:
		chat_bubble.set_message_bounds(corner_a, corner_b)
	else:
		chat_bubble.clear_message_bounds()