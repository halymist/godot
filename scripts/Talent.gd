extends AspectRatioContainer

@export var talentID: int
@export var talentName: String
@export var maxPoints: int
@export var points: int = 0
@export var isStarter: bool = false

@export var description: String = ""
@export var factor: float = 1.0

@export var isPerk: bool = false  # True if this is a perk talent, false if it's a regular talent

@export var button: Button
@export var upgrade: Button
@export var perkScreen: Button
@export var pointsLabel: Label
@export var neighbor_talents: Array[AspectRatioContainer] = []


func _ready():
	# Find the matching talent in GameInfo
	var found = false
	for talent in GameInfo.current_player.talents:
		if talent.talent_id == talentID:
			points = talent.points
			found = true
			break
	if not found:
		points = 0  # No points spent if not found

	pointsLabel.text = "%d/%d" % [points, maxPoints]
	button.pressed.connect(_on_button_pressed)
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
	var eligible_for_upgrade = can_upgrade()
	if isPerk and points >= maxPoints:
		GameInfo.current_panel_overlay = perkScreen
		perkScreen.visible = true
	else:
		GameInfo.current_panel_overlay = upgrade
		upgrade.set_talent_data(talentName, description, factor, points, maxPoints, eligible_for_upgrade, self)

func can_upgrade() -> bool:
	# Check if talent is already maxed out
	if points >= maxPoints:
		return false
	
	# Check if player has talent points available
	var spent_points = 0
	for talent in GameInfo.current_player.talents:
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
			print("Created new talent entry for ID ", talentID, " with ", points, " points")
		else:
			print("Updated existing talent ID ", talentID, " to ", points, " points")
		
		# Update UI
		pointsLabel.text = "%d/%d" % [points, maxPoints]
		get_parent().refresh_all_talents()
		
		print("Upgraded talent ", talentName, " to ", points, " points. Talent points remaining: ", GameInfo.current_player.talent_points)
	else:
		print("Cannot upgrade: either maxed out or no talent points available")
