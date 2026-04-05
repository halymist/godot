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

# Google Play Billing
var billing_client: Node = null  # BillingClient instance (only on Android)
var billing_ready: bool = false

# Product IDs must match what you create in Google Play Console
const PRODUCT_IDS = ["mushrooms_250", "mushrooms_500", "mushrooms_1000", "mushrooms_2000"]

# Map product IDs to mushroom amounts
const PRODUCT_MUSHROOMS = {
	"mushrooms_250": 250,
	"mushrooms_500": 500,
	"mushrooms_1000": 1000,
	"mushrooms_2000": 2000
}

func _ready():
	redeem_button.pressed.connect(_on_redeem_button_pressed)
	copy_link_button.pressed.connect(_on_copy_link_pressed)
	purchase_option1.pressed.connect(_on_purchase_option.bind("mushrooms_250"))
	purchase_option2.pressed.connect(_on_purchase_option.bind("mushrooms_500"))
	purchase_option3.pressed.connect(_on_purchase_option.bind("mushrooms_1000"))
	purchase_option4.pressed.connect(_on_purchase_option.bind("mushrooms_2000"))
	
	# Regenerate invite link each time panel becomes visible
	visibility_changed.connect(_on_visibility_changed)
	
	# Initialize Google Play Billing on Android
	if OS.get_name() == "Android":
		_init_billing()

func _init_billing():
	billing_client = BillingClient.new()
	billing_client.connected.connect(_on_billing_connected)
	billing_client.disconnected.connect(_on_billing_disconnected)
	billing_client.connect_error.connect(_on_billing_connect_error)
	billing_client.query_product_details_response.connect(_on_query_product_details_response)
	billing_client.on_purchase_updated.connect(_on_purchase_updated)
	billing_client.consume_purchase_response.connect(_on_consume_purchase_response)
	billing_client.start_connection()
	print("[Billing] Starting connection...")

func _on_billing_connected():
	print("[Billing] Connected! Querying product details...")
	billing_ready = true
	billing_client.query_product_details(PRODUCT_IDS, BillingClient.ProductType.INAPP)

func _on_billing_disconnected():
	print("[Billing] Disconnected")
	billing_ready = false

func _on_billing_connect_error(response_code: int, debug_message: String):
	print("[Billing] Connection error: ", response_code, " - ", debug_message)
	billing_ready = false

func _on_query_product_details_response(query_result: Dictionary):
	if query_result.response_code == BillingClient.BillingResponseCode.OK:
		print("[Billing] Product details loaded: ", query_result.product_details.size(), " products")
		for product in query_result.product_details:
			print("[Billing]   ", product)
	else:
		print("[Billing] Product details query failed: ", query_result.response_code, " - ", query_result.debug_message)

func _on_purchase_updated(result: Dictionary):
	if result.response_code == BillingClient.BillingResponseCode.OK:
		print("[Billing] Purchase updated")
		for purchase in result.purchases:
			_process_purchase(purchase)
	else:
		print("[Billing] Purchase error: ", result.response_code, " - ", result.debug_message)

func _process_purchase(purchase: Dictionary):
	if purchase.purchase_state == BillingClient.PurchaseState.PURCHASED:
		# Mushrooms are consumable — consume so user can buy again
		print("[Billing] Consuming purchase token: ", purchase.purchase_token)
		billing_client.consume_purchase(purchase.purchase_token)
	elif purchase.purchase_state == BillingClient.PurchaseState.PENDING:
		print("[Billing] Purchase pending, waiting for completion...")

func _on_consume_purchase_response(result: Dictionary):
	if result.response_code == BillingClient.BillingResponseCode.OK:
		print("[Billing] Purchase consumed successfully, token: ", result.token)
		# TODO: Send purchase token to your server for verification and mushroom grant
		# For now, just log it. Server should verify via Google Play Developer API
		# and then grant mushrooms via WebSocket/HTTP.
	else:
		print("[Billing] Consume failed: ", result.response_code, " - ", result.debug_message)

func _on_redeem_button_pressed():
	var code = coupon_input.text.strip_edges()
	if code.is_empty():
		print("Please enter a coupon code")
		return
	
	print("Attempting to redeem coupon code: ", code)
	# TODO: Send code to server for validation
	coupon_input.text = ""

func _on_visibility_changed():
	if visible:
		_generate_invite_link()

func _generate_invite_link():
	"""Generate and display the invite link"""
	var uid = GameInfo.user_id
	if uid.is_empty():
		invite_link.text = "Login to get your invite link"
	else:
		invite_link.text = "https://wilds.com/ref=" + uid

func _on_copy_link_pressed():
	var link_text = invite_link.text
	if link_text.is_empty():
		print("No invite link to copy")
		return
	
	DisplayServer.clipboard_set(link_text)
	print("Invite link copied to clipboard!")

func _on_purchase_option(product_id: String):
	if OS.get_name() == "Android":
		if not billing_ready:
			print("[Billing] Not connected yet, retrying connection...")
			if billing_client:
				billing_client.start_connection()
			return
		var result = billing_client.purchase(product_id)
		if result.response_code == BillingClient.BillingResponseCode.OK:
			print("[Billing] Purchase flow launched for: ", product_id)
		else:
			print("[Billing] Failed to launch purchase: ", result.response_code, " - ", result.debug_message)
	else:
		var mushrooms = PRODUCT_MUSHROOMS.get(product_id, 0)
		print("[Payment] Purchase clicked: ", product_id, " (", mushrooms, " mushrooms) — billing only available on Android")
