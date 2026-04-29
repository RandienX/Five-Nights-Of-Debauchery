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

# === Party Management ===
func get_party_members() -> Array[Resource]:
	var members: Array[Resource] = []
	for p in party:
		if is_instance_valid(p):
			members.append(p)
	return members

func add_party_member(member: Resource) -> void:
	if member and not party.has(member):
		party.append(member)
		if member.has_method("equip_stats_change"):
			member.equip_stats_change()

func remove_party_member(member: Resource) -> void:
	if party.has(member):
		party.erase(member)

# === Inventory Accessors ===
func get_inventory() -> Dictionary:
	return inventory.duplicate()

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

# === Item Usage ===
func use_item(item: Item, target: Entity) -> bool:
	if not item or not target or not is_instance_valid(target):
		return false
	if item.type != 2:  # Not a consumable
		return false
	if not has_item(item):
		return false

	# Apply heal effects
	if item.heal_amount > 0 and target.hp < target.max_stats["hp"] and target.hp > 0:
		target.hp = min(target.hp + item.heal_amount, target.max_stats["hp"])
	
	# Apply mana restore
	if item.mana_amount > 0 and target.mp < target.max_stats["mp"]:
		target.mp = min(target.mp + item.mana_amount, target.max_stats["mp"])
	
	# Apply revive effect
	if item.revive_amount > 0 and target.hp <= 0:
		target.hp = min(item.revive_amount, target.max_stats["hp"])
	
	# Remove status effects (heals_effects is Array[int] of effect enum values)
	if item.heals_effects:
		for effect_key in item.heals_effects:
			if target.effects.has(effect_key):
				target.effects.erase(effect_key)
	
	# Apply consume effects from legacy dictionary if present
	if item.legacy_consume_effects:
		for effect_key in item.legacy_consume_effects.keys():
			var effect_data = item.legacy_consume_effects[effect_key]
			if effect_key == BattleEffect.StatusEffect.Revive:
				if target.hp <= 0:
					target.hp = 1
			if effect_data is Array and effect_data.size() >= 2:
				var level = effect_data[0]
				var duration = effect_data[1]
				if target.effects.has(effect_key):
					target.effects[effect_key][0] = max(target.effects[effect_key][0], level)
					target.effects[effect_key][1] = max(target.effects[effect_key][1], duration)
				else:
					target.effects[effect_key] = [level, duration]
	
	# Apply consume effects from new array-based system
	if item.consume_effects:
		for effect in item.consume_effects:
			# Process BattleEffect resources here if needed
			pass
	
	# Remove the item from inventory
	remove_item(item, 1)
	
	return true

# === Item Usage on Party ===
func use_item_on_party(item: Item) -> bool:
	if not item or item.type != 2:  # Not a consumable
		return false
	if not has_item(item):
		return false
	
	# Apply to first alive party member with low HP or who needs it
	for p in party:
		if is_instance_valid(p) and p.hp > 0:
			# Check if this item would be useful
			if item.heal_amount > 0 and p.hp < p.max_stats.get("hp", 100):
				return use_item(item, p)
			elif item.mana_amount > 0 and p.mp < p.max_stats.get("mp", 50):
				return use_item(item, p)
			elif item.revive_amount > 0:
				# Revive items should target dead members specifically
				continue
			else:
				# For other items, just use on first member
				return use_item(item, p)
	
	# If no living member needed it, try to revive someone
	if item.revive_amount > 0:
		for p in party:
			if is_instance_valid(p) and p.hp <= 0:
				return use_item(item, p)
	
	return false
