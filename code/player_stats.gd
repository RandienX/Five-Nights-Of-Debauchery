@tool
extends Node
## PlayerStats Autoload - Manages player currency and persistent stats for shop system
## This autoload centralizes currency management to avoid hardcoded values

signal currency_changed(new_amount: int)
signal stat_changed(stat_name: StringName, new_value: Variant)

enum CurrencyType {GOLD, SHIT, FAZTOKENS}

@export var gold: int = 100
@export var shit: int = 0
@export var tokens: int = 25

var stats: Dictionary[StringName, Variant] = {}
var party: Array[Object] = [load("res://resources/party/freddy.tres").duplicate_deep(), load("res://resources/party/bonnie.tres").duplicate_deep()]
var inventory: Dictionary[Item, int] = {}
var player_position: Vector2 = Vector2(272, -82)

func _ready() -> void:
	add_item(load("res://resources/items/consumables/small_pizza.tres") as Item, 5)
	add_item(load("res://resources/items/consumables/small_soda.tres") as Item, 5)
	add_item(load("res://resources/items/consumables/degreaser.tres") as Item, 5)
	add_item(load("res://resources/items/consumables/molotov.tres") as Item, 1)
	add_item(load("res://resources/items/consumables/attack_item.tres") as Item, 1)
	add_item(load("res://resources/items/armor/EndoBodyA.tres") as Item, 1)
	for p in party:
		p.equip_stats_change()

# === Save/Load Data Management ===
func get_save_data() -> Dictionary:
	var data: Dictionary = {
		"gold": gold,
		"shit": shit,
		"tokens": tokens,
		"stats": stats,
		"player_position": var_to_str(player_position),
		"inventory": {},
		"party": []
	}
	
	# Serialize inventory (Item resources -> resource_path)
	for item in inventory.keys():
		if item and item.resource_path:
			data["inventory"][item.resource_path] = inventory[item]
	
	# Serialize party members with their properties using SaveManager's serialization
	for p in party:
		if p is Resource:
			var p_dict: Dictionary = {
			}
			# Serialize all storage properties
			for prop in p.get_property_list():
				if prop.usage & PROPERTY_USAGE_STORAGE:
					var prop_name: String = prop.name
					# Skip internal/resource management properties
					if prop_name in ["script", "resource_local_to_scene", "resource_name", "_resource_type",
					"metadata/_custom_type_script", "resource_scene_unique_id"]:
						continue
					if p.has_method("get") or prop_name in p:
						var prop_value = p.get(prop_name)
						# Use SaveManager's serialization for consistency
						p_dict[prop_name] = SaveManager.serialize_value(prop_value, prop.type)
			data["party"].append(p_dict)
	
	return data

func load_save_data(data: Dictionary) -> void:
	# Load currency
	if data.has("gold"):
		gold = data["gold"]
	if data.has("shit"):
		shit = data["shit"]
	if data.has("tokens"):
		tokens = data["tokens"]
	
	# Load player position
	if data.has("player_position"):
		player_position = str_to_var(data["player_position"])
	
	# Load inventory
	if data.has("inventory"):
		inventory.clear()
		for path in data["inventory"].keys():
			var item: Item = load(path)
			if item:
				inventory[item] = int(data["inventory"][path])
	
	# Load party
	if data.has("party"):
		party.clear()
		for p_dict in data["party"]:
			var base_entity: Entity = load(p_dict["path_to"])
			if base_entity:
				var resource: Entity = base_entity.duplicate_deep()
				for prop_name in p_dict.keys():
					var prop_value = SaveManager.deserialize_value(p_dict[prop_name])
					if prop_name in resource:
						resource.set(prop_name, prop_value)
				# Re-initialize equipment effects after loading
				resource.equip_stats_change()
				party.append(resource)

# === Currency Management ===
func get_currency(type: CurrencyType = CurrencyType.GOLD) -> int:
	match type:
		CurrencyType.GOLD:
			return gold
		CurrencyType.SHIT:
			return shit
		CurrencyType.FAZTOKENS:
			return tokens
	return 0

func set_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	match type:
		CurrencyType.GOLD:
			gold = max(0, amount)
		CurrencyType.SHIT:
			shit = max(0, amount)
		CurrencyType.FAZTOKENS:
			tokens = max(0, amount)
	currency_changed.emit(get_currency(type))

func add_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> void:
	set_currency(get_currency(type) + amount, type)

func deduct_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> bool:
	if get_currency(type) >= amount:
		set_currency(get_currency(type) - amount, type)
		return true
	return false

func has_currency(amount: int, type: CurrencyType = CurrencyType.GOLD) -> bool:
	return get_currency(type) >= amount

# === Stats Management ===
func get_stat(stat_name: StringName, default: Variant = null) -> Variant:
	return stats.get(stat_name, default)

func set_stat(stat_name: StringName, value: Variant) -> void:
	stats[stat_name] = value
	stat_changed.emit(stat_name, value)

# === Inventory Management ===
func add_item(item: Item, amount: int = 1):
	if not inventory.has(item):
		inventory[item] = 0
	inventory[item] += amount

func remove_item(item: Item, amount: int = 1):
	if inventory.has(item):
		inventory[item] -= amount
		if inventory[item] <= 0:
			inventory.erase(item)
		return true
	return false
	
func use_item(item: Item, target: Array) -> bool:
	if not item or target.size() <= 0:
		print("1")
		print(target)
		return false
	if item.type != 2:  # Not a consumable
		print("2")
		return false
	
	for t in target:
		
		# Apply revive effect
		if item.revive_amount > 0 and t.hp <= 0:
			t.hp = min(item.revive_amount, t.max_stats["hp"])
			
		# Apply heal effects
		if item.heal_amount > 0 and t.hp < t.max_stats["hp"] and t.hp > 0:
			t.hp = min(t.hp + item.heal_amount, t.max_stats["hp"])
	
		# Apply mana restore
		if item.mana_amount > 0 and t.mp < t.max_stats["mp"]:
			t.mp = min(t.mp + item.mana_amount, t.max_stats["mp"])
	
	
		# Remove status effects (heals_effects is Array[int] of effect enum values)
		if item.heals_effects:
			for effect_key in item.heals_effects:
				if t.effects.has(effect_key):
					t.effects.erase(effect_key)
							
		if item.consume_effects:
			for effect in item.consume_effects:
				# Process BattleEffect resources here if needed
				pass
	
	remove_item(item, 1)
	return true
	
func has_item(item: Item, amount: int = 1) -> bool:
	if inventory.has(item):
		return inventory[item] >= amount
	return false

func get_item_amount(item: Item) -> int:
	if inventory.has(item):
		return inventory[item]
	return 0

func clear_inventory():
	inventory.clear()

func get_inventory():
	return inventory
