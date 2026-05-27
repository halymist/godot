extends RefCounted
class_name EffectFormatter

static func format_with_factor(description: String, factor: float, append_percent_when_missing: bool = false) -> String:
	if description == "":
		return ""

	var value := str(abs(int(factor)))
	if "*%" in description:
		return description.replace("*%", value + "%")
	if "*" in description:
		return description.replace("*", value)
	if append_percent_when_missing and int(factor) != 0:
		return "%s %s%%" % [description, value]
	return description

static func format_with_progress(description: String, current_factor: float, next_factor: float) -> String:
	if description == "":
		return ""

	var current_text := str(abs(int(current_factor)))
	var next_text := str(abs(int(next_factor)))
	if "*%" in description:
		return description.replace("*%", "%s%% -> %s%%" % [current_text, next_text])
	if "*" in description:
		return description.replace("*", "%s -> %s" % [current_text, next_text])
	return description
