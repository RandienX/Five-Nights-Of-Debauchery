@tool
extends PanelContainer
class_name ShopItemCard
## ShopItemCard - Reusable UI component for displaying a single shop item
## Shows icon, name, description, price, stock, and handles purchase interaction

signal purchase_requested(shop_item: ShopItem, quantity: int)
signal bulk_purchase_requested(shop_item: ShopItem, quantity: int)

# Node references
@onready var icon_texture: TextureRect = $MarginContainer/HBoxContainer/IconTexture
@onready var name_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/DescriptionLabel
@onready var price_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/PriceLabel
@onready var stock_label: Label = $MarginContainer/HBoxContainer/VBoxContainer/StockLabel
@onready var buy_button: Button = $MarginContainer/HBoxContainer/BuyButton
@onready var bulk_container: HBoxContainer = $MarginContainer/HBoxContainer/VBoxContainer/BulkContainer
@onready var quantity_spinbox: SpinBox = $MarginContainer/HBoxContainer/VBoxContainer/BulkContainer/QuantitySpinBox
@onready var bulk_buy_button: Button = $MarginContainer/HBoxContainer/VBoxContainer/BulkContainer/BulkBuyButton

# Data
var shop_item: ShopItem
var quantity: int = 1


func _ready() -> void:
	# Connect button signals
	buy_button.pressed.connect(_on_buy_button_pressed)
	bulk_buy_button.pressed.connect(_on_bulk_buy_button_pressed)
	
	# Setup quantity spinbox
	quantity_spinbox.min_value = 1
	quantity_spinbox.max_value = 99
	quantity_spinbox.step = 1
	quantity_spinbox.value = 1
	
	# Hide bulk container by default (can be shown via enable_bulk_buy())
	bulk_container.visible = false
	
	# Initial visual state update
	_update_visual_state()


## Initialize the card with a ShopItem resource
func init(item: ShopItem) -> void:
	shop_item = item
	_populate_from_item()
	_update_visual_state()


## Populate UI elements from ShopItem data
func _populate_from_item() -> void:
	if not shop_item or not shop_item.item:
		return
	
	# Icon
	if shop_item.item.icon:
		icon_texture.texture = shop_item.item.icon
	elif shop_item.item.texture:
		icon_texture.texture = shop_item.item.texture
	else:
		icon_texture.texture = null
	
	# Name
	name_label.text = shop_item.item.item_name if shop_item.item.item_name != "" else "Unknown Item"
	
	# Description
	description_label.text = shop_item.item.description if shop_item.item.description != "" else "No description"
	
	# Price with currency symbol
	var currency_symbol = _get_currency_symbol(shop_item.currency_type)
	price_label.text = "%d %s" % [shop_item.price, currency_symbol]
	
	# Stock
	_update_stock_display()
	
	# Max quantity for bulk purchase
	if shop_item.max_stock != -1:
		quantity_spinbox.max_value = min(99, shop_item.current_stock)
	else:
		quantity_spinbox.max_value = 99


## Get currency symbol based on type
func _get_currency_symbol(type: PlayerStats.CurrencyType) -> String:
	match type:
		PlayerStats.CurrencyType.GOLD:
			return "G"
		PlayerStats.CurrencyType.SILVER:
			return "S"
		PlayerStats.CurrencyType.TOKENS:
			return "T"
	return ""


## Update stock display text
func _update_stock_display() -> void:
	if shop_item.max_stock == -1:
		stock_label.text = "∞ in stock"
		stock_label.modulate.a = 0.5
	else:
		stock_label.text = "%d left" % shop_item.current_stock
		stock_label.modulate.a = 1.0
		
		# Warn if low stock
		if shop_item.current_stock <= 3:
			stock_label.modulate = Color.RED
		else:
			stock_label.modulate = Color.WHITE


## Update visual state based on purchase availability
func _update_visual_state() -> void:
	if not shop_item:
		set_disabled(true)
		return
	
	var can_afford = shop_item._can_afford()
	var has_stock = shop_item.has_stock()
	
	# Disable if out of stock or can't afford
	set_disabled(not has_stock or not can_afford)
	
	# Update stock display
	_update_stock_display()
	
	# Visual feedback for affordability
	if not can_afford and has_stock:
		price_label.modulate = Color.RED
	else:
		price_label.modulate = Color.WHITE


## Set the card's disabled state
func set_disabled(disabled: bool) -> void:
	buy_button.disabled = disabled
	bulk_buy_button.disabled = disabled
	modulate.a = 0.5 if disabled else 1.0


## Enable bulk purchase UI
func enable_bulk_buy(enabled: bool = true) -> void:
	bulk_container.visible = enabled


## Refresh the card's state (call after purchase or currency change)
func refresh() -> void:
	_update_visual_state()
	_update_stock_display()
	
	# Update max quantity for bulk
	if shop_item and shop_item.max_stock != -1:
		quantity_spinbox.max_value = min(99, shop_item.current_stock)
		quantity_spinbox.value = min(quantity_spinbox.value, quantity_spinbox.max_value)


func _on_buy_button_pressed() -> void:
	if shop_item:
		purchase_requested.emit(shop_item, 1)


func _on_bulk_buy_button_pressed() -> void:
	if shop_item:
		quantity = int(quantity_spinbox.value)
		bulk_purchase_requested.emit(shop_item, quantity)


## Handle external currency change notification
func on_currency_changed() -> void:
	_update_visual_state()


## Handle external stock change notification
func on_stock_changed() -> void:
	refresh()
