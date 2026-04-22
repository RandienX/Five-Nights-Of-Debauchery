@tool
extends MarginContainer
class_name ShopItemCard
## ShopItemCard - Reusable UI component for displaying a single shop item
## Shows icon, name, description, price, stock, and handles purchase interaction

signal purchase_requested(shop_item: ShopItem, quantity: int)
signal bulk_purchase_requested(shop_item: ShopItem, quantity: int)

@onready var icon_texture: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/VBoxContainer/Name
@onready var description_label: Label = $HBoxContainer/VBoxContainer/Desc
@onready var price_label: Label = $HBoxContainer/VBoxContainer/Price
@onready var buy_button: Button = $HBoxContainer/VBoxContainer2/MarginContainer/Buy
@onready var quantity_spinbox: SpinBox = $HBoxContainer/VBoxContainer2/SpinBox

var shop_item: ShopItem
var quantity: int = 1

func _ready() -> void:
	# Ensure button connection
	if buy_button:
		buy_button.pressed.connect(_on_buy_button_pressed)
	
	_update_visuals()

func init(item: ShopItem) -> void:
	shop_item = item
	_setup()
	_update_visuals()

func _setup() -> void:
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
		PlayerStats.CurrencyType.SHIT:
			return "S"
		PlayerStats.CurrencyType.FAZTOKENS:
			return "FT"
	return ""

func _update_visuals() -> void:
	if not shop_item:
		set_disabled(true)
		return
	
	var can_afford = shop_item._can_afford()
	var has_stock = shop_item.has_stock()
	
	set_disabled(not has_stock or not can_afford)
	
	if not can_afford and has_stock:
		price_label.modulate = Color.RED
	else:
		price_label.modulate = Color.WHITE

func set_disabled(disabled: bool) -> void:
	if buy_button:
		buy_button.disabled = disabled
	modulate.a = 0.5 if disabled else 1.0

func refresh() -> void:
	_update_visuals()
	
	# Update max quantity for bulk
	if shop_item and shop_item.max_stock != -1:
		quantity_spinbox.max_value = min(99, shop_item.current_stock)
		quantity_spinbox.value = min(quantity_spinbox.value, quantity_spinbox.max_value)

func _on_buy_button_pressed() -> void:
	if shop_item and quantity_spinbox:
		quantity = int(quantity_spinbox.value)
		purchase_requested.emit(shop_item, quantity)

func on_currency_changed() -> void:
	_update_visuals()

func on_stock_changed() -> void:
	refresh()

## Enable or disable bulk buying (show/hide spinbox)
func enable_bulk_buy(enabled: bool) -> void:
	if quantity_spinbox:
		quantity_spinbox.visible = enabled
