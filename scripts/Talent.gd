extends AspectRatioContainer

@export var talentID: int
@export var talentName: String
@export var maxPoints: int
@export var points: int = 0
@export var isStarter: bool = false

@export var effect_id: int = 0  # Reference to effect in effects.tres
@export var factor: float = 1.0  # Custom factor value for this talent

@export var perk_slot: int = 0  # 0 = regular talent, >0 = perk talent with this slot ID

@export var button: Button
@export var pointsLabel: Label
@export var neighbor_talents: Array[AspectRatioContainer] = []

var displayed_character: GameInfo.GamePlayer = null
var is_read_only: bool = false


func _ready():
	# Register this talent's metadata globally
	GameInfo.register_talent(talentID, effect_id, factor, maxPoints, perk_slot)
	
	# Default to current player
	displayed_character = GameInfo.current_player
	is_read_only = false
	
	# Find the matching talent in GameInfo
	var found = false
	for talent in displayed_character.talents:
		if talent.talent_id == talentID:
			points = talent.points
			found = true
			break
	if not found:
		points = 0  # No points spent if not found

	pointsLabel.text = "%d/%d" % [points, maxPoints]
	button.pressed.connect(_on_button_pressed)
	update_button_appearance()

func update_from_character(character: GameInfo.GamePlayer, read_only: bool):
	"""Update this talent to display data from a specific character"""
	displayed_character = character
	is_read_only = read_only
	
	# Find matching talent in character's talents
	var found = false
	for talent in displayed_character.talents:
		if talent.talent_id == talentID:
			points = talent.points
			found = true
			break
	if not found:
		points = 0
	
	pointsLabel.text = "%d/%d" % [points, maxPoints]
	
	# Disable button interaction in read-only mode
	if button:
		button.disabled = read_only
	
	update_button_appearance()

func update_button_appearance():
	if points > 0:
		# Talent is activated - container stays normal
		modulate = Color.WHITE
	elif can_upgrade():
		# Talent is upgradeable but not activated - slightly greyed out
		modulate = Color(0.7, 0.7, 0.7, 1.0)  # Light grey
	else:
		# Talent is locked - fully greyed out
		modulate = Color(0.4, 0.4, 0.4, 1.0)  # Dark grey

func _on_button_pressed():
	# Disable button interaction in read-only mode
	if is_read_only:
		print("Talent: Cannot interact in read-only mode")
		return
	
	# Check if this is a perk slot talent (to select a perk)
	if perk_slot > 0 and points >= maxPoints:
		UIManager.instance.perk_screen.load_active_perks_for_slot(perk_slot)
		UIManager.instance.perk_screen.visible = true
	else:
		# Show upgrade screen for all other cases (unlock perk slot or upgrade regular talent)
		var eligible_for_upgrade = can_upgrade()
		var description = ""
		
		# Check if this is a perk slot talent
		if perk_slot > 0:
			description = "Unlocks an additional perk slot"
		elif effect_id > 0:
			var effect_data = GameInfo.effects_db.get_effect_by_id(effect_id)
			if effect_data:
				description = effect_data.description
				var current_bonus = points * factor
				var next_bonus = (points + 1) * factor
				
				if points >= maxPoints:
					description += " " + str(int(current_bonus)) + "%"
				else:
					description += " " + str(int(current_bonus)) + "% --> " + str(int(next_bonus)) + "%"
		
		UIManager.instance.upgrade_talent.set_talent_data(talentName, description, factor, points, maxPoints, eligible_for_upgrade, self)

func can_upgrade() -> bool:
	# Can't upgrade in read-only mode
	if is_read_only:
		return false
	
	# Check if talent is already maxed out
	if points >= maxPoints:
		return false
	
	# Check if player has talent points available
	var spent_points = 0
	for talent in displayed_character.talents:
		spent_points += talent.points
	if spent_points >= GameInfo.current_player.talent_points:
		return false
	
	# Check if it's a starter talent
	if isStarter:
		return true
	
	# Check if any neighbor is maxed out
	for neighbor in neighbor_talents:
		if neighbor.points == neighbor.maxPoints:
			return true
	
	return false

func upgrade_talent():
	if points < maxPoints and GameInfo.current_player.talent_points > 0:
		points += 1
		
		# Update or add talent in GameInfo
		var found = false
		for talent in GameInfo.current_player.talents:
			if talent.talent_id == talentID:
				talent.points = points
				found = true
				break
		
		if not found:
			# Create new talent entry if it doesn't exist (was 0 points before)
			var new_talent = GameInfo.Talent.new()
			new_talent.talent_id = talentID
			new_talent.points = points
			GameInfo.current_player.talents.append(new_talent)
		
		# Update UI
		pointsLabel.text = "%d/%d" % [points, maxPoints]
		get_parent().refresh_all_talents()
		
		# Refresh stats to recalculate effects
		if UIManager.instance:
			UIManager.instance.refresh_stats()
