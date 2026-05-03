@tool
extends Control
class_name ShopUI
## ShopUI Controller - Main shop scene controller attached to shop.tscn root
## Handles shop data loading, item card instantiation, purchase/sell logic, and dialogue

signal item_purchased(shop_item: ShopItem, quantity: int)
signal item_sold(item: Item, quantity: int, earnings: int)
signal purchase_failed(shop_item: ShopItem, reason: String)
signal shop_closed()

# === Cached Node References (@onready for performance) ===
@onready var currency_label: Label = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/Currencies
@onready var category_container: HBoxContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons
@onready var items_container: VBoxContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var exit_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Exit
@onready var buy_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Buy
@onready var talk_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Talk
@onready var sell_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Sell
@onready var question_container: VBoxContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var dialogue_label: RichTextLabel = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/MarginContainer/ColorRect/RichTextLabel

# === Preloaded Scenes ===
const SHOP_ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_item_card.tscn")

# === Export Variables (Editor Integration) ===
@export var current_shop_data: ShopData
@export var enable_bulk_buy: bool = true
@export var chars_per_second: float = 30.0  # Typewriter speed
@export_group("Talk Responses")
@export var talk_responses: Dictionary[String, String] = {
	"Inhale my dong\n enragement child.": "Fuck off.",
	"Give me free shit": "I am a respectable business if you want free shit i can shit into your hands, still with a price but small.",
	"Fatherless piece of shit": "Yes. I am fatherless, my papa didn't come back from the supermatket to get milk, I even bought the milk myself, but he didn't come back... (you see the 6 years expired milk on the shelf)",
	"What do you think about the\n economical situation of\n Slovakia in 2001?": "The... What!?",
}
@export var default_response: String = "I'm not sure what to say about that."

# === State Variables ===
var current_filter: StringName = &"all"
var item_cards: Array[ShopItemCard] = []
var sell_cards: Array[ShopItemCard] = []  # Cards for sell tab
var current_mode: String = "buy"  # "buy", "sell", "talk"

# Talk mode state
var talk_option_buttons: Array[Button] = []
var is_typing: bool = false
var full_dialogue_text: String = ""
var current_char_index: int = 0
var type_timer: Timer
var input_blocked: bool = false


func _ready() -> void:
	_setup_timers()
	_connect_signals()
	load_shop(current_shop_data)


func _setup_timers() -> void:
	type_timer = Timer.new()
	type_timer.wait_time = 1.0 / chars_per_second
	type_timer.timeout.connect(_on_type_tick)
	type_timer.one_shot = false
	add_child(type_timer)


func _connect_signals() -> void:
	if exit_button:
		exit_button.pressed.connect(_on_close_button_pressed)
	
	if buy_button:
		buy_button.pressed.connect(_on_buy_tab_pressed)
	
	if talk_button:
		talk_button.pressed.connect(_on_talk_tab_pressed)
	
	if sell_button:
		sell_button.pressed.connect(_on_sell_tab_pressed)
	
	if PlayerStats:
		var stats = PlayerStats
		stats.currency_changed.connect(_on_currency_changed)


func load_shop(data: ShopData) -> void:
	if not data:
		push_error("ShopUI: Attempted to load null ShopData")
		return
	
	current_shop_data = data
	_setup_shop_ui()
	_update_currency_display()
	_create_category_buttons()
	_setup_items_grid()

func _setup_shop_ui() -> void:
	if not current_shop_data:
		return
	
	# Note: shop title and description are not in the current scene structure
	# They could be added to the talk box RichTextLabel if neededs

func _create_category_buttons() -> void:
	for child in category_container.get_children():
		child.queue_free()
	
	if not current_shop_data:
		return
	
	for category in current_shop_data.categories:
		var btn = Button.new()
		btn.text = category.capitalize()
		btn.toggle_mode = true
		btn.pressed.connect(_on_category_button_pressed.bind(category))
		
		if category == &"all":
			btn.button_pressed = true
		
		category_container.add_child(btn)


func _setup_items_grid() -> void:
	for card in item_cards:
		card.queue_free()
	item_cards.clear()
	
	if not current_shop_data:
		return
	
	var items = current_shop_data.get_sorted_items(current_filter)
	
	for shop_item in items:
		var card = SHOP_ITEM_CARD_SCENE.instantiate() as ShopItemCard
		card.enable_bulk_buy(enable_bulk_buy)
		
		card.purchase_requested.connect(_on_item_purchase_requested)
		
		items_container.add_child(card)
		card.init(shop_item)
		item_cards.append(card)

func filter_by_tag(tag: StringName) -> void:
	current_filter = tag
	_setup_items_grid()

func _update_currency_display() -> void:
	if not currency_label:
		return
	
	if not PlayerStats:
		currency_label.text = "Gold:\nShit:\nFazTokens:"
		return
	
	var stats = PlayerStats
	currency_label.text = "Gold: %d\nShit: %d\nFazTokens: %d" % [stats.gold, stats.shit, stats.tokens]

func _on_item_purchase_requested(shop_item: ShopItem, quantity: int) -> void:
	_attempt_purchase(shop_item, quantity)

func _attempt_purchase(shop_item: ShopItem, quantity: int) -> void:
	if not shop_item:
		purchase_failed.emit(null, "Invalid item")
		return
	
	if not shop_item.has_stock():
		purchase_failed.emit(shop_item, "Out of stock")
		return
	
	if shop_item.max_stock != -1 and shop_item.current_stock < quantity:
		purchase_failed.emit(shop_item, "Not enough stock")
		return
	
	var success = false
	if quantity == 1:
		success = shop_item.purchase()
	else:
		success = shop_item.purchase_bulk(quantity)
	
	if success:
		_add_item_to_inventory(shop_item.item, quantity)
		
		item_purchased.emit(shop_item, quantity)
		_on_currency_changed()
		_refresh_all_cards()
	else:
		purchase_failed.emit(shop_item, "Insufficient funds")

## Add purchased item to player inventory
func _add_item_to_inventory(item: Item, quantity: int) -> void:
	PlayerStats.add_item(item, quantity)

## Refresh all item cards (call after purchase or currency change)
func _refresh_all_cards() -> void:
	for card in item_cards:
		card.refresh()

## Handle currency change signal from PlayerStats
func _on_currency_changed(_new_amount: int = 0) -> void:
	_update_currency_display()
	_refresh_all_cards()

## Handle category button press
func _on_category_button_pressed(category: StringName) -> void:
	filter_by_tag(category)
	
	# Update button states
	for child in category_container.get_children():
		if child is Button:
			child.button_pressed = (child.text.to_lower() == category.capitalize().to_lower())
			
## Close button handler
func _on_close_button_pressed() -> void:
	shop_closed.emit()

## Public method to close the shop
func close_shop() -> void:
	_on_close_button_pressed()

## Enable or disable bulk buying on all cards
func set_bulk_buy_enabled(enabled: bool) -> void:
	enable_bulk_buy = enabled
	for card in item_cards:
		card.enable_bulk_buy(enabled)

## Refresh shop with new data (hot-swap)
func refresh_shop(new_data: ShopData) -> void:
	load_shop(new_data)

## Get current shop ID
func get_shop_id() -> StringName:
	return current_shop_data.shop_id if current_shop_data else &""

func _on_buy_tab_pressed() -> void:
	if current_mode == "buy":
		return
	current_mode = "buy"
	_clear_all_cards()
	_clear_talk_buttons()
	_setup_items_grid()
	_update_button_states()


# ========== SELL TAB ==========

func _on_sell_tab_pressed() -> void:
	if current_mode == "sell":
		return
	current_mode = "sell"
	_clear_all_cards()
	_clear_talk_buttons()
	_setup_sell_grid()
	_update_button_states()

## Setup the sell grid by pulling items from PlayerStats.inventory
func _setup_sell_grid() -> void:
	for card in sell_cards:
		if is_instance_valid(card):
			card.queue_free()
			sell_cards.clear()

	if not PlayerStats or PlayerStats.inventory.is_empty():
		_show_empty_sell_message()
		return

	for item: Item in PlayerStats.inventory.keys():
		var amount: int = PlayerStats.inventory[item]
		if amount <= 0 or not item:
			continue

		var card = _create_sell_card(item, amount)
		if card:
			sell_cards.append(card)


## Create a sell card for an inventory item
func _create_sell_card(item: Item, amount: int) -> ShopItemCard:
	if not SHOP_ITEM_CARD_SCENE:
		push_error("ShopUI: SHOP_ITEM_CARD_SCENE not loaded")
		return null

	var card = SHOP_ITEM_CARD_SCENE.instantiate() as ShopItemCard
	if not card:
		push_error("ShopUI: Failed to instantiate SellItemCard")
		return null
	items_container.add_child(card)
	
	card.setup_for_sell(item, amount)
	card.set_disabled(false)
	card.sold.connect(_on_item_sold)
	return card

## Show a message when inventory is empty
func _show_empty_sell_message() -> void:
	var label = Label.new()
	label.text = "Your inventory is empty.\nNothing to sell!"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	items_container.add_child(label)

## Handle item sold signal from a sell card
func _on_item_sold(item: Item, quantity: int, currency_type: PlayerStats.CurrencyType, earnings: int) -> void:
	if not item or quantity <= 0:
		push_warning("ShopUI: Invalid sell transaction")
		return

	var removed = PlayerStats.remove_item(item, quantity)
	if not removed:
		push_warning("ShopUI: Failed to remove sold item from inventory")
		return

	PlayerStats.add_currency(earnings, currency_type)
	item_sold.emit(item, quantity, earnings)

	_refresh_sell_grid()
	_update_currency_display()

## Refresh the sell grid after a sale
func _refresh_sell_grid() -> void:
	_clear_all_cards()
	_setup_sell_grid()


# ========= TALK TAB =========

func _on_talk_tab_pressed() -> void:
	if current_mode == "talk":
		return
	current_mode = "talk"
	_clear_all_cards()
	_clear_talk_buttons()
	_setup_talk_ui()
	_update_button_states()


## Setup the talk UI with dialogue buttons
func _setup_talk_ui() -> void:
	_stop_typing()
	dialogue_label.text = ""
	_clear_talk_buttons()

	if not question_container:
		push_error("ShopUI: question_container not found - cannot setup talk UI")
		return

	if talk_responses.is_empty():
		_show_default_talk_option()
		return

	for key in talk_responses.keys():
		var button = _create_talk_button(key)
		if button:
			talk_option_buttons.append(button)
			question_container.add_child(button)

## Create a single talk button
func _create_talk_button(option_key: String) -> Button:
	var button = Button.new()
	button.text = option_key
	button.pressed.connect(_on_talk_option_selected.bind(option_key))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.custom_minimum_size.x = 200
	return button


## Show a default talk option if none are configured
func _show_default_talk_option() -> void:
	var button = Button.new()
	button.text = "Talk"
	button.pressed.connect(_on_talk_option_selected.bind("default"))
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	question_container.add_child(button)
	talk_option_buttons.append(button)


## Clear all talk buttons
func _clear_talk_buttons() -> void:
	for button in talk_option_buttons:
		if is_instance_valid(button):
			button.queue_free()
	talk_option_buttons.clear()


## Handle talk option selection
func _on_talk_option_selected(option_key: String) -> void:
	if input_blocked or is_typing:
		return  # Prevent rapid clicking during typing

	# Disable input during typing
	input_blocked = true

	# Get the response text
	var response_text: String = ""
	if option_key == "default":
		response_text = default_response
	elif talk_responses.has(option_key):
		response_text = talk_responses[option_key]
	else:
		response_text = default_response
	push_warning("ShopUI: Missing dialogue response for key: %s" % option_key)

	# Start typewriter effect
	_start_typewriter(response_text)

## Start the typewriter effect
func _start_typewriter(text: String) -> void:
	full_dialogue_text = text
	current_char_index = 0
	dialogue_label.text = ""
	is_typing = true
	type_timer.start()

## Timer tick for typewriter effect
func _on_type_tick() -> void:
	if current_char_index < full_dialogue_text.length():
		dialogue_label.text += full_dialogue_text[current_char_index]
		current_char_index += 1
	else:
		_finish_typing()

## Finish typing and re-enable input
func _finish_typing() -> void:
	is_typing = false
	input_blocked = false
	type_timer.stop()
	dialogue_label.text = full_dialogue_text

## Stop typing immediately (used when switching tabs)
func _stop_typing() -> void:
	is_typing = false
	input_blocked = false
	type_timer.stop()

# ============================================================================
# === UTILITY FUNCTIONS ===
# ============================================================================

## Clear all item cards (both buy and sell)
func _clear_all_cards() -> void:
	# Clear buy cards
	for card in item_cards:
		if is_instance_valid(card):
			card.queue_free()
	item_cards.clear()

	# Clear sell cards
	for card in sell_cards:
		if is_instance_valid(card):
			card.queue_free()
	sell_cards.clear()

	# Clear talk buttons
	_clear_talk_buttons()

	# Stop any active typing
	_stop_typing()

## Update button states based on current mode
func _update_button_states() -> void:
	if buy_button:
		buy_button.button_pressed = (current_mode == "buy")
	if talk_button:
		talk_button.button_pressed = (current_mode == "talk")
	if sell_button:
		sell_button.button_pressed = (current_mode == "sell")
