@tool
extends Node
## PlayerStats Autoload - Manages player currency and persistent stats for shop system
## This autoload centralizes currency management to avoid hardcoded values

signal currency_changed(new_amount: int)
signal stat_changed(stat_name: StringName, new_value: Variant)

# Currency types - extensible for multiple currencies
enum CurrencyType { GOLD, SILVER, TOKENS }

# Default currency amounts
@export var gold: int = 500
@export var silver: int = 0
@export var tokens: int = 0

# Generic stats dictionary for extensibility
var stats: Dictionary[StringName, Variant] = {}

func _ready() -> void:
	# Initialize with some default stats if needed
	stats["player_level"] = 1
	stats["reputation"] = 0


## Get currency amount by type
func get_currency(type: CurrencyType = CurrencyType.GOLD) -> int:
	match type:
		CurrencyType.GOLD:
			return gold
		CurrencyType.SILVER:
			return silver
		CurrencyType.TOKENS:
			return tokens
	return 0


## Set currency amount by type, emits signal
func set_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	match type:
		CurrencyType.GOLD:
			gold = max(0, amount)
		CurrencyType.SILVER:
			silver = max(0, amount)
		CurrencyType.TOKENS:
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


## Serialize stats for saving (called from Global.gd save system)
func get_save_data() -> Dictionary:
	return {
		"gold": gold,
		"silver": silver,
		"tokens": tokens,
		"stats": stats
	}


## Load stats from save data (called from Global.gd load system)
func load_save_data(data: Dictionary) -> void:
	if data.has("gold"):
		gold = data["gold"]
	if data.has("silver"):
		silver = data["silver"]
	if data.has("tokens"):
		tokens = data["tokens"]
	if data.has("stats"):
		stats = data["stats"]
	currency_changed.emit(gold)
