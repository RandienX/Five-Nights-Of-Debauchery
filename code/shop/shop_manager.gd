@tool
extends Node
## ShopManager - Optional manager for handling multiple shops and shop transitions
## This is an example of how to integrate the shop system into your game

signal shop_opened(shop_id: StringName)
signal shop_closed(shop_id: StringName)

const SHOP_SCENE: PackedScene = preload("res://scenes/ui/shop/shop.tscn")

var current_shop_instance: Control
var current_shop_data: ShopData
var is_shop_open: bool = false

func open_shop(shop_data: ShopData, parent: Node = null) -> void:
	if not shop_data:
		push_error("ShopManager: Attempted to open shop with null ShopData")
		return
	
	if not parent:
		parent = get_tree().current_scene
	close_shop()
	
	current_shop_instance = SHOP_SCENE.instantiate()
	
	var shop_ui = current_shop_instance.get_node_or_null(".") as ShopUI
	if not shop_ui:
		shop_ui = current_shop_instance as ShopUI
	
	shop_ui.item_purchased.connect(_on_item_purchased)
	shop_ui.purchase_failed.connect(_on_purchase_failed)
	shop_ui.shop_closed.connect(close_shop)
	
	parent.add_child(current_shop_instance)
	shop_ui.load_shop(shop_data)
	
	current_shop_data = shop_data
	is_shop_open = true
	
	shop_opened.emit(shop_data.shop_id)


## Close the currently open shop
func close_shop() -> void:
	if current_shop_instance:
		current_shop_instance.queue_free()
		current_shop_instance = null
	
	var shop_id = current_shop_data.shop_id if current_shop_data else &""
	current_shop_data = null
	is_shop_open = false
	
	if shop_id != &"":
		shop_closed.emit(shop_id)

func refresh_current_shop() -> void:
	if current_shop_instance and current_shop_data:
		var shop_ui = current_shop_instance.get_node_or_null(".") as ShopUI
		if shop_ui:
			shop_ui.refresh_shop(current_shop_data)


## Switch to a different shop
func switch_shop(new_shop_data: ShopData) -> void:
	open_shop(new_shop_data)


## Handle item purchased signal
func _on_item_purchased(shop_item: ShopItem, quantity: int) -> void:
	print("Purchased %d x %s" % [quantity, shop_item.item.item_name])
	PlayerStats.deduct_currency(shop_item.price, shop_item.currency_type)
	
	# Additional logic can be added here (achievements, quests, etc.)


## Handle purchase failed signal
func _on_purchase_failed(shop_item: ShopItem, reason: String) -> void:
	if shop_item and shop_item.item:
		print("Failed to purchase %s: %s" % [shop_item.item.item_name, reason])
	else:
		print("Purchase failed: %s" % reason)
	# Could show a toast notification here
