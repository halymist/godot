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

# Billing (Android / iOS)
var billing: Node = null
var billing_ready: bool = false
var platform: String = ""

# Product IDs must match what you create in Google Play Console / App Store Connect
const PRODUCT_IDS = ["mushrooms_250", "mushrooms_500", "mushrooms_1000", "mushrooms_2000"]

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

	visibility_changed.connect(_on_visibility_changed)

	platform = OS.get_name()
	if platform == "Android":
		_init_google_billing()
	elif platform == "iOS":
		_init_apple_billing()
	elif platform == "HTML5" or platform == "Web":
		_init_stripe_payment()

	# Add Stripe button for browser/PC
	if platform == "HTML5" or platform == "Web" or platform == "Windows" or platform == "X11":
		var stripe_button = Button.new()
		stripe_button.text = "Pay with Stripe"
		stripe_button.pressed.connect(_on_stripe_button_pressed)
		add_child(stripe_button)
# =============================================================================
# STRIPE PAYMENT (HTML5/PC)
# =============================================================================

func _init_stripe_payment():
	pass
	# Placeholder for Stripe setup (e.g., load JS, set up bridge)

func _on_stripe_button_pressed():
	pass
	# Placeholder for Stripe payment logic
	# In production, use JavaScript.eval() to call Stripe.js or your backend

# =============================================================================
# GOOGLE PLAY BILLING (Android)
# =============================================================================

func _init_google_billing():
	if not ClassDB.class_exists("BillingClient") and not ClassDB.class_exists(&"BillingClient"):
		# BillingClient class comes from the GodotGooglePlayBilling plugin.
		# It registers a class_name so we can instantiate it dynamically.
		var script = load("res://addons/GodotGooglePlayBilling/BillingClient.gd")
		if script == null:
			return
		billing = script.new()
	else:
		billing = ClassDB.instantiate(&"BillingClient")

	billing.connected.connect(_on_billing_connected)
	billing.disconnected.connect(_on_billing_disconnected)
	billing.connect_error.connect(_on_billing_connect_error)
	billing.query_product_details_response.connect(_on_query_product_details_response)
	billing.on_purchase_updated.connect(_on_purchase_updated)
	billing.consume_purchase_response.connect(_on_consume_purchase_response)
	add_child(billing)
	billing.start_connection()

func _on_billing_connected():
	billing_ready = true
	# ProductType.INAPP = 0
	billing.query_product_details(PackedStringArray(PRODUCT_IDS), 0)

func _on_billing_disconnected():
	billing_ready = false

func _on_billing_connect_error(_response_code: int, _debug_message: String):
	billing_ready = false

func _on_query_product_details_response(query_result: Dictionary):
	# BillingResponseCode.OK = 0
	if query_result.get("response_code", -1) == 0:
		pass
	else:
		pass

func _on_purchase_updated(result: Dictionary):
	if result.get("response_code", -1) == 0:
		for purchase in result.get("purchases", []):
			_process_purchase(purchase)
	else:
		pass

func _process_purchase(purchase: Dictionary):
	# PurchaseState.PURCHASED = 1
	if purchase.get("purchase_state", 0) == 1:
		billing.consume_purchase(purchase.purchase_token)
	# PurchaseState.PENDING = 2
	elif purchase.get("purchase_state", 0) == 2:
		pass

func _on_consume_purchase_response(result: Dictionary):
	if result.get("response_code", -1) == 0:
		pass
		# TODO: Send purchase token to server for verification & mushroom grant
	else:
		pass

func _purchase_google(product_id: String):
	if not billing_ready:
		if billing:
			billing.start_connection()
		return
	var result = billing.purchase(product_id)
	if result.get("response_code", -1) == 0:
		pass
	else:
		pass

# =============================================================================
# APPLE IN-APP PURCHASES (iOS)
# =============================================================================

func _init_apple_billing():
	if not Engine.has_singleton("InAppStore"):
		return

	var store = Engine.get_singleton("InAppStore")
	# Request product info from App Store
	var result = store.request_product_info({"product_ids": PRODUCT_IDS})
	if result != OK:
		return
	billing_ready = true

func _purchase_apple(product_id: String):
	if not Engine.has_singleton("InAppStore"):
		return
	var store = Engine.get_singleton("InAppStore")
	var result = store.purchase({"product_id": product_id})
	if result != OK:
		pass
	else:
		pass

func _process_apple():
	"""Call this from _process or a timer to poll iOS purchase results."""
	if platform != "iOS" or not Engine.has_singleton("InAppStore"):
		return
	var store = Engine.get_singleton("InAppStore")
	while store.get_pending_event_count() > 0:
		var event = store.pop_pending_event()
		if event.type == "purchase":
			if event.result == "ok":
				pass
				# TODO: Send receipt to server for verification & mushroom grant
			else:
				pass

# =============================================================================
# COMMON
# =============================================================================

func _on_redeem_button_pressed():
	var code = coupon_input.text.strip_edges()
	if code.is_empty():
		return
	# TODO: Send code to server for validation
	coupon_input.text = ""

func _on_visibility_changed():
	if visible:
		_generate_invite_link()

func _generate_invite_link():
	var uid = GameInfo.user_id
	if uid.is_empty():
		invite_link.text = "Login to get your invite link"
	else:
		invite_link.text = "https://wilds.com/ref=" + uid

func _on_copy_link_pressed():
	var link_text = invite_link.text
	if link_text.is_empty():
		return
	DisplayServer.clipboard_set(link_text)

func _on_purchase_option(product_id: String):
	match platform:
		"Android":
			_purchase_google(product_id)
		"iOS":
			_purchase_apple(product_id)
		_:
			var _mushrooms = PRODUCT_MUSHROOMS.get(product_id, 0)
