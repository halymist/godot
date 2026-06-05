class_name PlayerDataTransformer
extends RefCounted

static func transform(server_data: Dictionary) -> Dictionary:
	var client_data = server_data.duplicate(true)
	var normalized_quest_log = _extract_server_quest_log(server_data)
	if normalized_quest_log.size() > 0:
		client_data["quest_log"] = normalized_quest_log

	if server_data.has("character_name"):
		client_data["name"] = server_data["character_name"]
		client_data.erase("character_name")

	if server_data.has("honnor"):
		client_data["honor"] = server_data["honnor"]
		client_data.erase("honnor")

	if server_data.has("settlement_id"):
		client_data["location"] = server_data["settlement_id"]
		client_data.erase("settlement_id")
		client_data.erase("location_id")
	elif server_data.has("location_id"):
		client_data["location"] = server_data["location_id"]
		client_data.erase("location_id")

	if server_data.has("avatar") and server_data.avatar is Dictionary:
		var avatar_obj = server_data.avatar
		client_data["avatar"] = [
			avatar_obj.get("face", 40),
			avatar_obj.get("hair", 48),
			avatar_obj.get("eyes", 33),
			avatar_obj.get("nose", 88),
			avatar_obj.get("mouth", 80),
			avatar_obj.get("brows", 0),
			avatar_obj.get("ears", 0),
			avatar_obj.get("special", 0)
		]

	if server_data.has("stats") and server_data.stats is Dictionary:
		var stats_obj = server_data.stats
		client_data["stats"] = [
			stats_obj.get("strength", 0),
			stats_obj.get("stamina", 0),
			stats_obj.get("agility", 0),
			stats_obj.get("luck", 0),
			stats_obj.get("armor", 0),
			stats_obj.get("min_damage", 0),
			stats_obj.get("max_damage", 0)
		]

	if server_data.has("inventory") and server_data.inventory is Array:
		var bag_slots_data = []
		for inv_item in server_data.inventory:
			var client_item = {
				"id": inv_item.get("item_id", 0),
				"bag_slot_id": inv_item.get("slot_id", 0),
				"day": inv_item.get("server_day", 0),
				"tempered": inv_item.get("temper", 0),
				"effect_overdrive": inv_item.get("effect_overdrive", 0),
				"socket_id": inv_item.get("socket", -1) if inv_item.get("socket", null) != null else -1,
				"socket_day": inv_item.get("socket_day", 0)
			}
			if inv_item.has("elixir_effect") and inv_item.elixir_effect != null:
				var effects_payload: Array[Dictionary] = []
				var elixir_effect = inv_item.elixir_effect
				if elixir_effect is Dictionary:
					_append_elixir_effect(effects_payload, elixir_effect, "effect1_id", "factor1")
					_append_elixir_effect(effects_payload, elixir_effect, "effect2_id", "factor2")
					_append_elixir_effect(effects_payload, elixir_effect, "effect3_id", "factor3")
					_append_elixir_effect(effects_payload, elixir_effect, "effect_id", "factor")
				if effects_payload.size() > 0:
					client_item["elixir_effects"] = effects_payload
			bag_slots_data.append(client_item)
		client_data["bag_slots"] = bag_slots_data
		client_data.erase("inventory")

	if server_data.has("perks") and server_data.perks is Array:
		var perks_data = []
		for perk in server_data.perks:
			perks_data.append({
				"id": perk.get("perk_id", 0),
				"slot": perk.get("talent_id", 0),
				"active": perk.get("talent_id", 0) > 0
			})
		client_data["perks"] = perks_data

	if server_data.has("talents") and server_data.talents is Array:
		var talents_data = []
		for talent in server_data.talents:
			talents_data.append({
				"talent_id": talent.get("talent_id", 0),
				"points": talent.get("points", 0)
			})
		client_data["talents"] = talents_data

	if server_data.has("destination"):
		client_data["traveling_destination"] = server_data["destination"] if server_data.destination != null else null
	else:
		client_data["traveling_destination"] = null

	if server_data.has("arrival"):
		client_data["traveling"] = _parse_iso_timestamp(server_data["arrival"]) if server_data.arrival != null else 0.0
	else:
		client_data["traveling"] = 0.0

	if server_data.has("expedition") and server_data.expedition is Dictionary:
		var expedition_payload = server_data.expedition
		var expedition_id = int(expedition_payload.get("expedition_id", 0))
		var active_node_id = int(expedition_payload.get("active_node_id", 0))
		client_data["expedition"] = [expedition_id] if expedition_id > 0 and active_node_id > 0 else []
		client_data["expedition_progress_id"] = expedition_id
		client_data["expedition_completed_node_ids"] = _int_array(expedition_payload.get("completed_node_ids", []))
		client_data["expedition_unlocked_node_ids"] = _int_array(expedition_payload.get("unlocked_node_ids", []))
		client_data["expedition_active_node_id"] = active_node_id
	elif server_data.has("expedition_id") and server_data.expedition_id != null:
		client_data["expedition"] = [int(server_data.expedition_id)]
	elif server_data.has("active_expedition_id") and server_data.active_expedition_id != null:
		client_data["expedition"] = [int(server_data.active_expedition_id)]
	else:
		client_data["expedition"] = []

	if server_data.has("elixir_effect1") or server_data.has("elixir_effect2") or server_data.has("elixir_effect3"):
		var elixir_effects = []
		for i in range(1, 4):
			var effect_id = int(server_data.get("elixir_effect" + str(i), 0))
			var factor = float(server_data.get("elixir_factor" + str(i), 0.0))
			if effect_id > 0:
				elixir_effects.append({"effect_id": effect_id, "factor": factor})
		if elixir_effects.size() > 0:
			var raw_elixir = client_data.get("elixir", null)
			var has_valid_elixir_id = raw_elixir is int and int(raw_elixir) > 0
			if not has_valid_elixir_id:
				client_data["elixir"] = 1000
			client_data["elixir_effects"] = elixir_effects
		for i in range(1, 4):
			client_data.erase("elixir_effect" + str(i))
			client_data.erase("elixir_factor" + str(i))

	if server_data.has("enchanter") and (server_data.enchanter is Array or server_data.enchanter is Dictionary):
		client_data["enchanter_effects"] = server_data.enchanter
		client_data.erase("enchanter")

	if server_data.has("vendor") and server_data.vendor is Array:
		client_data["vendor_items"] = server_data.vendor
		client_data.erase("vendor")

	if server_data.has("potion_until") and server_data.potion_until != null:
		client_data["potion_until"] = _parse_iso_timestamp(server_data.potion_until)
	if server_data.has("elixir_until") and server_data.elixir_until != null:
		client_data["elixir_until"] = _parse_iso_timestamp(server_data.elixir_until)

	if server_data.has("potion_day") and server_data.potion_day != null:
		client_data["potion_day"] = server_data.potion_day
	if server_data.has("elixir_day") and server_data.elixir_day != null:
		client_data["elixir_day"] = server_data.elixir_day

	return client_data

static func _append_elixir_effect(effects_payload: Array[Dictionary], elixir_effect: Dictionary, effect_key: String, factor_key: String):
	if not elixir_effect.has(effect_key):
		return
	var effect_id = int(elixir_effect.get(effect_key, 0))
	var factor = float(elixir_effect.get(factor_key, 0.0))
	if effect_id > 0:
		effects_payload.append({"effect_id": effect_id, "factor": factor})

static func _int_array(value: Variant) -> Array[int]:
	var result: Array[int] = []
	if value is Array:
		for item in value:
			result.append(int(item))
	return result

static func _normalize_quest_log_entries(raw_entries: Variant) -> Array:
	var result: Array = []
	if not (raw_entries is Array):
		return result

	for raw_entry in raw_entries:
		if not (raw_entry is Dictionary):
			continue
		var quest_id = int(raw_entry.get("quest_id", raw_entry.get("questId", 0)))
		var option_id = int(raw_entry.get("option_id", raw_entry.get("optionId", 0)))
		if quest_id <= 0 or option_id <= 0:
			continue
		result.append({
			"quest_id": quest_id,
			"option_id": option_id,
			"finished": bool(raw_entry.get("finished", false))
		})

	return result

static func _extract_quest_log_from_container(container: Dictionary) -> Array:
	var direct = container.get("quest_log", container.get("questLog", container.get("questlog", null)))
	if direct is Array:
		return _normalize_quest_log_entries(direct)
	if direct is String:
		var parsed = JSON.new()
		if parsed.parse(direct) == OK:
			return _normalize_quest_log_entries(parsed.get_data())

	for nested_key in ["character", "player", "data"]:
		var nested = container.get(nested_key, null)
		if nested is Dictionary:
			var nested_result = _extract_quest_log_from_container(nested)
			if nested_result.size() > 0:
				return nested_result

	return []

static func _extract_server_quest_log(server_data: Dictionary) -> Array:
	if not (server_data is Dictionary):
		return []
	return _extract_quest_log_from_container(server_data)

static func _parse_iso_timestamp(iso_string: Variant) -> float:
	if iso_string == null or not iso_string is String or iso_string.is_empty():
		return 0.0
	var datetime_dict = Time.get_datetime_dict_from_datetime_string(iso_string, true)
	if datetime_dict.is_empty():
		return 0.0
	return Time.get_unix_time_from_datetime_dict(datetime_dict)
