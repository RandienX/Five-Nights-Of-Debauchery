@tool
extends Resource
class_name ShopItem
## ShopItem Resource - Defines an item available for purchase in the shop
## Wraps an Item resource with shop-specific metadata (price, stock, tags)

@export_group("Basic Info")
@export var item: Item  ## The actual Item resource this shop entry represents
@export var price: int = 100  ## Cost to purchase one unit
@export var currency_type: PlayerStats.CurrencyType = PlayerStats.CurrencyType.GOLD  ## Which currency to use

@export_group("Stock")
@export var max_stock: int = -1  ## -1 means unlimited stock
@export var current_stock: int = -1  ## Current remaining stock (-1 = unlimited)

@export_group("Categorization")
@export var tags: Array[StringName] = []  ## For filtering items (e.g., "weapon", "consumable", "rare")
@export var category: StringName = &"default"  ## Primary category for tab filtering

@export_group("Display")
@export var sort_order: int = 0  ## For custom sorting in shop UI


func _init() -> void:
	# Initialize stock to max if not set
	if current_stock == -1 and max_stock != -1:
		current_stock = max_stock


## Check if item can be purchased (has stock and player can afford)
func can_purchase() -> bool:
	return has_stock() and _can_afford()


## Check if item has available stock
func has_stock() -> bool:
	return max_stock == -1 or current_stock > 0


## Internal check if player can afford (assumes PlayerStats autoload exists)
func _can_afford() -> bool:
	if not Engine.has_singleton("PlayerStats"):
		return true  # Assume affordable in editor
	var stats = Engine.get_singleton("PlayerStats")
	return stats.has_currency(price, currency_type)


## Purchase one unit, returns success/failure
func purchase() -> bool:
	if not can_purchase():
		return false
	
	if not Engine.has_singleton("PlayerStats"):
		# In editor, just decrement stock
		if max_stock != -1:
			current_stock -= 1
		return true
	
	var stats = Engine.get_singleton("PlayerStats")
	if stats.deduct_currency(price, currency_type):
		if max_stock != -1:
			current_stock -= 1
		return true
	return false


## Purchase multiple units in bulk
func purchase_bulk(quantity: int) -> bool:
	if quantity <= 0:
		return false
	
	if not can_purchase():
		return false
	
	# Check stock availability
	if max_stock != -1 and current_stock < quantity:
		return false
	
	# Check total cost
	var total_cost = price * quantity
	if not Engine.has_singleton("PlayerStats"):
		# In editor, just decrement stock
		if max_stock != -1:
			current_stock -= quantity
		return true
	
	var stats = Engine.get_singleton("PlayerStats")
	if stats.deduct_currency(total_cost, currency_type):
		if max_stock != -1:
			current_stock -= quantity
		return true
	return false


## Get remaining stock (returns -1 for unlimited)
func get_remaining_stock() -> int:
	return current_stock


## Reset stock to max (for restocking)
func restock() -> void:
	if max_stock != -1:
		current_stock = max_stock


## Check if item matches a filter tag
func has_tag(tag: StringName) -> bool:
	return tags.has(tag) or category == tag
