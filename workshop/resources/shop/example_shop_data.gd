@tool
extends Resource
class_name ExampleShopData
## Example ShopData resource for testing and demonstration
## Shows how to create shop inventories using the ShopItem resource

@export var example_items: Array[ShopItem]


func _init() -> void:
	# This is just an example - in practice you'd create ShopData resources in the FileSystem dock
	pass


## Create a sample weapon shop
static func create_weapon_shop() -> ShopData:
	var shop = ShopData.new()
	shop.shop_id = &"weapon_shop"
	shop.shop_name = "Weapon Emporium"
	shop.shop_description = "Finest weapons in the land!"
	
	# Example items would be created via Resource creation in editor
	# This shows the structure:
	# var sword_item = preload("res://resources/items/weapons/sword.tres")
	# var sword_shop_item = ShopItem.new()
	# sword_shop_item.item = sword_item
	# sword_shop_item.price = 250
	# sword_shop_item.max_stock = 10
	# sword_shop_item.current_stock = 10
	# sword_shop_item.category = &"weapons"
	# sword_shop_item.tags = [&"melee", &"weapon"]
	# shop.items.append(sword_shop_item)
	
	shop.categories = [&"all", &"weapons", &"armor", &"accessories"]
	
	return shop


## Create a sample consumables shop
static func create_consumable_shop() -> ShopData:
	var shop = ShopData.new()
	shop.shop_id = &"consumable_shop"
	shop.shop_name = "Potion Shop"
	shop.shop_description = "Healing items and consumables"
	shop.categories = [&"all", &"consumables", &"materials"]
	
	return shop


## Create a sample general store with unlimited stock
static func create_general_store() -> ShopData:
	var shop = ShopData.new()
	shop.shop_id = &"general_store"
	shop.shop_name = "General Store"
	shop.shop_description = "Everything you need for your adventure"
	shop.categories = [&"all", &"tools", &"supplies", &"key_items"]
	
	return shop
