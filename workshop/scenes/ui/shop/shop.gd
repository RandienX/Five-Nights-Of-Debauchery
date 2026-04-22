@tool
extends Control
class_name ShopUI
## ShopUI Controller - Main shop scene controller attached to shop.tscn root
## Handles shop data loading, item card instantiation, purchase logic, and filtering

signal item_purchased(shop_item: ShopItem, quantity: int)
signal purchase_failed(shop_item: ShopItem, reason: String)
signal shop_closed()

# Node references
@onready var shop_title: Label = $MarginContainer/VBoxContainer/ShopTitle
@onready var shop_description: Label = $MarginContainer/VBoxContainer/ShopDescription
@onready var currency_label: Label = $MarginContainer/VBoxContainer/CurrencyLabel
@onready var category_container: HBoxContainer = $MarginContainer/VBoxContainer/CategoryContainer
@onready var items_grid: GridContainer = $MarginContainer/VBoxContainer/ScrollContainer/ItemsGrid
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton
@onready var restock_button: Button = $MarginContainer/VBoxContainer/RestockButton

# Shop item card scene
const SHOP_ITEM_CARD_SCENE: PackedScene = preload("res://workshop/scenes/ui/shop/shop_item_card.tscn")

# Current shop data
var current_shop_data: ShopData
var current_filter: StringName = &"all"
var enable_bulk_buy: bool = true

# Cache of instantiated cards for easy refresh
var item_cards: Array[ShopItemCard] = []


func _ready() -> void:
	# Connect UI signals
	close_button.pressed.connect(_on_close_button_pressed)
	restock_button.pressed.connect(_on_restock_button_pressed)
	
	# Connect to PlayerStats currency changes if available
	if Engine.has_singleton("PlayerStats"):
		var stats = Engine.get_singleton("PlayerStats")
		stats.currency_changed.connect(_on_currency_changed)
	
	# Hide restock button by default (only show for debug/testing)
	restock_button.visible = false


## Load a shop with the given ShopData resource
func load_shop(data: ShopData) -> void:
	if not data:
		push_error("ShopUI: Attempted to load null ShopData")
		return
	
	current_shop_data = data
	_populate_shop_ui()
	_update_currency_display()
	_create_category_buttons()
	_populate_items_grid()


## Populate shop title and description from ShopData
func _populate_shop_ui() -> void:
	if not current_shop_data:
		return
	
	shop_title.text = current_shop_data.shop_name
	shop_description.text = current_shop_data.shop_description
	shop_description.visible = not current_shop_data.shop_description.is_empty()


## Create category filter buttons from ShopData categories
func _create_category_buttons() -> void:
	# Clear existing buttons
	for child in category_container.get_children():
		child.queue_free()
	
	if not current_shop_data:
		return
	
	# Create button for each category
	for category in current_shop_data.categories:
		var btn = Button.new()
		btn.text = category.capitalize()
		btn.toggle_mode = true
		btn.pressed.connect(_on_category_button_pressed.bind(category))
		
		# Select "all" by default
		if category == &"all":
			btn.button_pressed = true
		
		category_container.add_child(btn)


## Populate the items grid with ShopItemCards
func _populate_items_grid() -> void:
	# Clear existing cards
	for card in item_cards:
		card.queue_free()
	item_cards.clear()
	
	if not current_shop_data:
		return
	
	# Get filtered and sorted items
	var items = current_shop_data.get_sorted_items(current_filter)
	
	# Create a card for each item
	for shop_item in items:
		var card = SHOP_ITEM_CARD_SCENE.instantiate() as ShopItemCard
		card.init(shop_item)
		card.enable_bulk_buy(enable_bulk_buy)
		
		# Connect purchase signals
		card.purchase_requested.connect(_on_item_purchase_requested)
		card.bulk_purchase_requested.connect(_on_item_bulk_purchase_requested)
		
		items_grid.add_child(card)
		item_cards.append(card)


## Filter items by category/tag
func filter_by_tag(tag: StringName) -> void:
	current_filter = tag
	_populate_items_grid()


## Update currency display from PlayerStats
func _update_currency_display() -> void:
	if not Engine.has_singleton("PlayerStats"):
		currency_label.text = "G: 0"
		return
	
	var stats = Engine.get_singleton("PlayerStats")
	currency_label.text = "G: %d | S: %d | T: %d" % [stats.gold, stats.silver, stats.tokens]


## Handle purchase request from item card
func _on_item_purchase_requested(shop_item: ShopItem, quantity: int) -> void:
	_attempt_purchase(shop_item, quantity)


## Handle bulk purchase request from item card
func _on_item_bulk_purchase_requested(shop_item: ShopItem, quantity: int) -> void:
	_attempt_purchase(shop_item, quantity)


## Attempt to purchase an item
func _attempt_purchase(shop_item: ShopItem, quantity: int) -> void:
	if not shop_item:
		purchase_failed.emit(null, "Invalid item")
		return
	
	# Check stock
	if not shop_item.has_stock():
		purchase_failed.emit(shop_item, "Out of stock")
		return
	
	# Check if requested quantity is available
	if shop_item.max_stock != -1 and shop_item.current_stock < quantity:
		purchase_failed.emit(shop_item, "Not enough stock")
		return
	
	# Attempt purchase
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


## Restock all items (for testing/debugging)
func _on_restock_button_pressed() -> void:
	if current_shop_data:
		current_shop_data.restock_all()
		_populate_items_grid()


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
