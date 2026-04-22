@tool
extends Resource
class_name ShopData
## ShopData Resource - Container for shop inventory configuration
## Holds all ShopItems and metadata for a specific shop instance
## This resource is hot-swapped to change entire shop inventories

@export_group("Shop Identity")
@export var shop_id: StringName = &"default_shop"  ## Unique identifier for this shop
@export var shop_name: String = "Shop"  ## Display name
@export var shop_description: String = ""  ## Optional description shown in UI

@export_group("Inventory")
@export var items: Array[ShopItem] = []  ## All items available in this shop

@export_group("Categories")
@export var categories: Array[StringName] = [&"all", &"default"]  ## Available filter categories


func _init() -> void:
	# Auto-populate categories from items if empty
	if categories.is_empty():
		categories.append(&"all")
		for shop_item in items:
			if not categories.has(shop_item.category):
				categories.append(shop_item.category)


## Get all items, optionally filtered by tag/category
func get_items(filter_tag: StringName = &"") -> Array[ShopItem]:
	if filter_tag.is_empty() or filter_tag == &"all":
		return items
	
	var filtered: Array[ShopItem] = []
	for shop_item in items:
		if shop_item.has_tag(filter_tag):
			filtered.append(shop_item)
	return filtered


## Get items sorted by sort_order
func get_sorted_items(filter_tag: StringName = &"") -> Array[ShopItem]:
	var result = get_items(filter_tag)
	result.sort_custom(func(a: ShopItem, b: ShopItem): return a.sort_order < b.sort_order)
	return result


## Get item by its underlying Item resource
func get_item_by_resource(item_res: Item) -> ShopItem:
	for shop_item in items:
		if shop_item.item == item_res:
			return shop_item
	return null


## Check if shop has a specific item
func has_item(item_res: Item) -> bool:
	return get_item_by_resource(item_res) != null


## Get all unique tags from items
func get_all_tags() -> Array[StringName]:
	var tags: Array[StringName] = []
	for shop_item in items:
		for tag in shop_item.tags:
			if not tags.has(tag):
				tags.append(tag)
	return tags


## Restock all items in the shop
func restock_all() -> void:
	for shop_item in items:
		shop_item.restock()


## Get total value of all items in stock (for debugging/economy balancing)
func get_total_stock_value() -> int:
	var total = 0
	for shop_item in items:
		if shop_item.max_stock != -1:
			total += shop_item.price * shop_item.current_stock
	return total


## Duplicate this shop data (for creating instances with independent stock)
func duplicate_shop() -> ShopData:
	var new_shop = ShopData.new()
	new_shop.shop_id = shop_id
	new_shop.shop_name = shop_name
	new_shop.shop_description = shop_description
	new_shop.categories = categories.duplicate()
	
	# Deep duplicate items so each shop instance has independent stock
	for shop_item in items:
		var new_item = shop_item.duplicate() as ShopItem
		new_shop.items.append(new_item)
	
	return new_shop
