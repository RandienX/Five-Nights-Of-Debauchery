@tool
extends MarginContainer
class_name ShopItemCard
## ShopItemCard - Reusable UI component for displaying a single shop item
## Shows icon, name, description, price, stock, and handles purchase interaction

signal purchase_requested(shop_item: ShopItem, quantity: int)
signal sold(item: Item, quantity: int, currency_type: PlayerStats.CurrencyType, earnings: int)

@onready var icon_texture: TextureRect = $HBoxContainer/Icon
@onready var name_label: Label = $HBoxContainer/VBoxContainer/Name
@onready var description_label: Label = $HBoxContainer/VBoxContainer/ScrollContainer/Desc
@onready var price_label: Label = $HBoxContainer/VBoxContainer/Price
@onready var buy_button: Button = $HBoxContainer/VBoxContainer2/MarginContainer/Buy
@onready var quantity_spinbox: SpinBox = $HBoxContainer/VBoxContainer2/SpinBox

# For buy mode
var shop_item: ShopItem
# For sell mode
var sell_item: Item
var sell_quantity: int = 0
var sell_price_value: int = 0
var sell_currency_type: PlayerStats.CurrencyType = PlayerStats.CurrencyType.GOLD

var quantity: int = 1
var is_sell_mode: bool = false


## Initialize for BUY mode (existing functionality)
func init(item: ShopItem) -> void:
	is_sell_mode = false
	shop_item = item
	_setup()
	_update_visuals()

func setup_for_sell(item: Item, amount: int) -> void:
	print(item.item_name)
	
	is_sell_mode = true
	sell_item = item
	sell_quantity = amount
	print(sell_item)
	
	if item and item.sell_price is Dictionary:
		sell_price_value = item.sell_price.get(PlayerStats.CurrencyType.GOLD, 10)
		sell_currency_type = PlayerStats.CurrencyType.GOLD
	else:
		sell_price_value = 10
		sell_currency_type = PlayerStats.CurrencyType.GOLD
	
	_setup_sell_ui()

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
	
	name_label.text = shop_item.item.item_name if shop_item.item.item_name != "" else "Unknown Item"
	description_label.text = shop_item.item.description if shop_item.item.description != "" else "No description"
	
	var currency_symbol = _get_currency_symbol(shop_item.currency_type)
	price_label.text = "%d %s" % [shop_item.price, currency_symbol]
	
	if shop_item.max_stock != -1:
		quantity_spinbox.max_value = min(99, shop_item.current_stock)
	else:
		quantity_spinbox.max_value = 99

func _setup_sell_ui() -> void:
	# Icon
	if sell_item.icon:
		icon_texture.texture = sell_item.icon
	elif sell_item.texture:
		icon_texture.texture = sell_item.texture
	else:
		icon_texture.texture = null
	
	name_label.text = sell_item.item_name if sell_item.item_name != "" else "Unknown Item"
	description_label.text = sell_item.description if sell_item.description != "" else "No description"
	
	var currency_symbol = _get_currency_symbol(sell_currency_type)
	price_label.text = "Sell: %d %s each\nOwned: %d" % [sell_price_value, currency_symbol, sell_quantity]
	
	quantity_spinbox.max_value = sell_quantity
	quantity_spinbox.value = min(1, sell_quantity)
	
	if buy_button:
		buy_button.text = "Sell"

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
	if is_sell_mode:
		_update_sell_visuals()
		return
	if not shop_item:
		set_disabled(true)
		return
	
	var can_afford = shop_item._can_afford()
	var has_stock = shop_item.has_stock()
	
	if not is_sell_mode:
		set_disabled(not has_stock or not can_afford)
		
		if not can_afford and has_stock:
			price_label.modulate = Color.RED
		else:
			price_label.modulate = Color.WHITE

func _update_sell_visuals() -> void:
	price_label.modulate = Color.GREEN  # Green to indicate earning

func set_disabled(disabled: bool) -> void:
	print("bruh" if disabled else "gut")
	if buy_button:
		buy_button.disabled = disabled
	modulate.a = 0.5 if disabled else 1.0

func refresh() -> void:
	if is_sell_mode:
		_update_sell_visuals()
		# Update quantity in case inventory changed
		if PlayerStats and sell_item:
			sell_quantity = PlayerStats.get_item_amount(sell_item)
			quantity_spinbox.max_value = sell_quantity
			quantity_spinbox.value = min(quantity_spinbox.value, sell_quantity)
			var currency_symbol = _get_currency_symbol(sell_currency_type)
			price_label.text = "Sell: %d %s each\nOwned: %d" % [sell_price_value, currency_symbol, sell_quantity]
	else:
		_update_visuals()
		
		# Update max quantity for bulk
		if shop_item and shop_item.max_stock != -1:
			quantity_spinbox.max_value = min(99, shop_item.current_stock)
			quantity_spinbox.value = min(quantity_spinbox.value, quantity_spinbox.max_value)

func _on_buy_pressed() -> void:
	if is_sell_mode:
		_on_sell_pressed()
	else:
		if shop_item and quantity_spinbox:
			quantity = int(quantity_spinbox.value)
			purchase_requested.emit(shop_item, quantity)

func _on_sell_pressed() -> void:
	if not sell_item or not quantity_spinbox:
		return
	
	var qty_to_sell = int(quantity_spinbox.value)
	if qty_to_sell <= 0 or qty_to_sell > sell_quantity:
		push_warning("ShopItemCard: Invalid sell quantity")
		return
	
	var total_earnings = sell_price_value * qty_to_sell
	
	# Emit sold signal with all necessary data
	sold.emit(sell_item, qty_to_sell, sell_currency_type, total_earnings)

func on_currency_changed() -> void:
	_update_visuals()

func on_stock_changed() -> void:
	refresh()

## Enable or disable bulk buying (show/hide spinbox)
func enable_bulk_buy(enabled: bool) -> void:
	if quantity_spinbox:
		quantity_spinbox.visible = enabled

## Check if this card is in sell mode
func is_in_sell_mode() -> bool:
	return is_sell_mode
