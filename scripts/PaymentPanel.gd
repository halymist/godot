extends Panel

# Payment panel with three sections: Coupon, Invite Friend, Purchase Currency

@onready var coupon_input = $Content/CouponSection/CouponContainer/CouponInput
@onready var redeem_button = $Content/CouponSection/CouponContainer/RedeemButton
@onready var invite_link_input = $Content/InviteSection/InviteContainer/InviteLinkInput
@onready var copy_link_button = $Content/InviteSection/InviteContainer/CopyLinkButton
@onready var purchase_option1 = $Content/PurchaseSection/PurchaseOptions/Option1
@onready var purchase_option2 = $Content/PurchaseSection/PurchaseOptions/Option2
@onready var purchase_option3 = $Content/PurchaseSection/PurchaseOptions/Option3

func _ready():
	if redeem_button:
		redeem_button.pressed.connect(_on_redeem_button_pressed)
	if copy_link_button:
		copy_link_button.pressed.connect(_on_copy_link_pressed)
	if purchase_option1:
		purchase_option1.pressed.connect(_on_purchase_option.bind(1, 100, 4.99))
	if purchase_option2:
		purchase_option2.pressed.connect(_on_purchase_option.bind(2, 500, 19.99))
	if purchase_option3:
		purchase_option3.pressed.connect(_on_purchase_option.bind(3, 1200, 39.99))
	
	# Generate and display invite link
	_generate_invite_link()

func _on_redeem_button_pressed():
	if not coupon_input:
		return
	
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
	var player_id = "PLAYER123"  # Placeholder for now
	var invite_link = "https://game.com/invite?ref=" + str(player_id)
	
	if invite_link_input:
		invite_link_input.text = invite_link

func _on_copy_link_pressed():
	if not invite_link_input:
		return
	
	var invite_link = invite_link_input.text
	if invite_link.is_empty():
		print("No invite link to copy")
		return
	
	print("Copying invite link: ", invite_link)
	
	# Copy to clipboard
	DisplayServer.clipboard_set(invite_link)
	print("Invite link copied to clipboard!")
	
	# TODO: Show confirmation message to user

func _on_purchase_option(option_number: int, gold_amount: int, price: float):
	print("Purchase option ", option_number, " clicked: ", gold_amount, " gold for $", price)
	# TODO: Initiate payment flow with payment provider
	# This would typically open a web view or payment dialog
