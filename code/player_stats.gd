@tool
extends Node
## PlayerStats Autoload - Manages player currency and persistent stats for shop system
## This autoload centralizes currency management to avoid hardcoded values

signal currency_changed(new_amount: int)
signal stat_changed(stat_name: StringName, new_value: Variant)

# Currency types - extensible for multiple currencies
enum CurrencyType {GOLD, SHIT, FAZTOKENS}

# Default currency amounts
@export var gold: int = 100
@export var shit: int = 0
@export var tokens: int = 25

# Generic stats dictionary for extensibility
var stats: Dictionary[StringName, Variant] = {}
var party: Array[Object] = [load("res://resources/party/freddy.tres").duplicate_deep(), load("res://resources/party/bonnie.tres").duplicate_deep()]
var inventory: Dictionary = {}
var player_position: Vector2

func _ready() -> void:
	add_item(preload("res://resources/items/consumables/small_soda.tres"), 5)
	add_item(preload("res://resources/items/consumables/small_pizza.tres"), 5)
	add_item(preload("res://resources/items/consumables/degreaser.tres"), 5)
	add_item(preload("res://resources/items/armor/EndoBodyA.tres"), 1)
	for p in party:
		p.equip_stats_change()
	# Initialize with some default stats if needed
	stats["reputation"] = 0

## Get currency amount by type
func get_currency(type: CurrencyType = CurrencyType.GOLD) -> int:
	match type:
		CurrencyType.GOLD:
			return gold
		CurrencyType.SHIT:
			return shit
		CurrencyType.FAZTOKENS:
			return tokens
	return 0


## Set currency amount by type, emits signal
func set_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	match type:
		CurrencyType.GOLD:
			gold = max(0, amount)
		CurrencyType.SHIT:
			shit = max(0, amount)
		CurrencyType.FAZTOKENS:
			tokens = max(0, amount)
	currency_changed.emit(get_currency(type))


## Add currency amount by type, emits signal
func add_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	set_currency(get_currency(type) + amount, type)

## Deduct currency amount by type, returns success/failure
## Returns false if insufficient funds
func deduct_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> bool:
	if get_currency(type) >= amount:
		set_currency(get_currency(type) - amount, type)
		return true
	return false

## Check if player has enough currency
func has_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> bool:
	return get_currency(type) >= amount


## Get a generic stat value
func get_stat(stat_name: StringName, default: Variant = null) -> Variant:
	return stats.get(stat_name, default)


## Set a generic stat value, emits signal
func set_stat(stat_name: StringName, value: Variant) -> void:
	stats[stat_name] = value
	stat_changed.emit(stat_name, value)

## Load stats from save data
func load_save_data(data: Dictionary) -> void:
	for v in range(len(data)):
		if self.has_meta(data.keys()[v]):
			self[data.keys()[v]] = data[data.keys()[v]]

# === Inventory Management ===
func add_item(item: Resource, amount: int = 1):
	if not inventory.has(item):
		inventory[item] = 0
	inventory[item] += amount

func remove_item(item: Resource, amount: int = 1):
	if inventory.has(item):
		inventory[item] -= amount
		if inventory[item] <= 0:
			inventory.erase(item)
		return true
	return false

func has_item(item: Resource, amount: int = 1) -> bool:
	if inventory.has(item):
		return inventory[item] >= amount
	return false

func get_item_amount(item: Resource) -> int:
	if inventory.has(item):
		return inventory[item]
	return 0

func clear_inventory():
	inventory.clear()
