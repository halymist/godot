extends Panel

# Payment panel with three sections: Coupon, Invite Friend, Purchase Currency

@export var coupon_input: LineEdit
@export var redeem_button: Button
@export var invite_link: Label
@export var copy_link_button: Button
@export var purchase_option1: Button
@export var purchase_option2: Button
@export var purchase_option3: Button
@export var purchase_option4: Button

func _ready():
	redeem_button.pressed.connect(_on_redeem_button_pressed)
	copy_link_button.pressed.connect(_on_copy_link_pressed)
	purchase_option1.pressed.connect(_on_purchase_option.bind(1, 250, 2.99))
	purchase_option2.pressed.connect(_on_purchase_option.bind(2, 500, 4.99))
	purchase_option3.pressed.connect(_on_purchase_option.bind(3, 1000, 7.99))
	purchase_option4.pressed.connect(_on_purchase_option.bind(4, 2000, 13.99))
	
	# Generate and display invite link
	_generate_invite_link()

func _on_redeem_button_pressed():
	var code = coupon_input.text.strip_edges()
	if code.is_empty():
		print("Please enter a coupon code")
		return
	
	print("Attempting to redeem coupon code: ", code)
	# TODO: Send code to server for validation
	# For now, just clear the input
	coupon_input.text = ""

func _generate_invite_link():
	"""Generate and display the invite link"""
	var uid = GameInfo.lobby_data.get("user_id", "")
	if uid == null or str(uid) == "":
		invite_link.text = "https://wilds.com/ref="
	else:
		invite_link.text = "https://wilds.com/ref=" + str(uid)

func _on_copy_link_pressed():
	var link_text = invite_link.text
	if link_text.is_empty():
		print("No invite link to copy")
		return
	
	DisplayServer.clipboard_set(link_text)
	print("Invite link copied to clipboard!")

func _on_purchase_option(option_number: int, gold_amount: int, price: float):
	print("Purchase option ", option_number, " clicked: ", gold_amount, " gold for $", price)
	# TODO: Initiate payment flow with payment provider
	# This would typically open a web view or payment dialog
