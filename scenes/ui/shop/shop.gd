@tool
extends Control
class_name ShopUI
## ShopUI Controller - Main shop scene controller attached to shop.tscn root
## Handles shop data loading, item card instantiation, purchase logic, and filtering

signal item_purchased(shop_item: ShopItem, quantity: int)
signal item_sold(item: Item, quantity: int, earnings: int)
signal purchase_failed(shop_item: ShopItem, reason: String)
signal shop_closed()

# Updated node paths to match actual shop.tscn structure
@onready var currency_label: Label = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/Currencies
@onready var category_container: HBoxContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ItemCategoryButtons
@onready var items_container: VBoxContainer = $HBoxContainer/ColorRect/MarginContainer/VBoxContainer/ScrollContainer/VBoxContainer
@onready var exit_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Exit
@onready var buy_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Buy
@onready var talk_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Talk
@onready var sell_button: Button = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/buttons/VBoxContainer/Sell
@onready var question_container: VBoxContainer = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/MarginContainer/ColorRect/QuestionContainer
@onready var dialogue_label: RichTextLabel = $HBoxContainer/VBoxContainer/HBoxContainer/ColorRect/MarginContainer/ColorRect/RichTextLabel

const SHOP_ITEM_CARD_SCENE: PackedScene = preload("res://scenes/ui/shop/shop_item_card.tscn")

@export var current_shop_data: ShopData
@export var current_dialogue_data: DialogueData
var current_filter: StringName = &"all"
var enable_bulk_buy: bool = true

var item_cards: Array[ShopItemCard] = []
var dialogue_runner: DialogueRunner
var dialogue_evaluator: DialogueConditionEvaluator
var is_typing: bool = false
var full_text: String = ""
var current_char_index: int = 0
var type_timer: Timer
var chars_per_second: float = 30.0
var current_mode: String = "buy"  # "buy", "sell", "talk"


func _ready() -> void:
	if exit_button:
		exit_button.pressed.connect(_on_close_button_pressed)
	
	if Engine.has_singleton("PlayerStats"):
		var stats = Engine.get_singleton("PlayerStats")
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
	# They could be added to the talk box RichTextLabel if needed


func _create_category_buttons() -> void:
	# Clear existing buttons
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
	# Clear existing cards
	for card in item_cards:
		card.queue_free()
	item_cards.clear()
	
	if not current_shop_data:
		return
	
	var items = current_shop_data.get_sorted_items(current_filter)
	
	for shop_item in items:
		var card = SHOP_ITEM_CARD_SCENE.instantiate() as ShopItemCard
		card.init(shop_item)
		card.enable_bulk_buy(enable_bulk_buy)
		
		card.purchase_requested.connect(_on_item_purchase_requested)
		card.bulk_purchase_requested.connect(_on_item_bulk_purchase_requested)
		
		items_container.add_child(card)
		item_cards.append(card)

func filter_by_tag(tag: StringName) -> void:
	current_filter = tag
	_setup_items_grid()

func _update_currency_display() -> void:
	if not currency_label:
		return
	
	if not Engine.has_singleton("PlayerStats"):
		currency_label.text = "Gold:\nShit:\nFazTokens:"
		return
	
	var stats = Engine.get_singleton("PlayerStats")
	currency_label.text = "Gold: %d\nShit: %d\nFazTokens: %d" % [stats.gold, stats.silver, stats.tokens]

func _on_item_purchase_requested(shop_item: ShopItem, quantity: int) -> void:
	_attempt_purchase(shop_item, quantity)

func _on_item_bulk_purchase_requested(shop_item: ShopItem, quantity: int) -> void:
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
		# Add item to player inventory via Global
		_add_item_to_inventory(shop_item.item, quantity)
		
		# Emit success signal
		item_purchased.emit(shop_item, quantity)
		
		# Refresh UI
		_on_currency_changed()
		_refresh_all_cards()
	else:
		purchase_failed.emit(shop_item, "Insufficient funds")


## Add purchased item to player inventory
func _add_item_to_inventory(item: Item, quantity: int) -> void:
	if Engine.has_singleton("Global"):
		var global = Engine.get_singleton("Global")
		if global.has_method("add_item"):
			global.add_item(item, quantity)


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
