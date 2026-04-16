extends Node

#--Battle Variables--
enum effect {Heal, Mana_Heal, Blind, Poison, Bleed, Power, Tough, Focus, Defend, Kill, Absorb, Revive, Sick, Weak, Slow, Sleep, Burn, Freeze, Paralyzed, Shock, Confuse}
enum AI {Dumb, Casual, Violent, Defensive, Intelligent, Flexible}
var battle_ref: Node = null

var battle_current = null

#--Saved Variables--
var inventory: Dictionary = {}
var party: Array = [load("res://resources/party/freddy.tres").duplicate_deep(), load("res://resources/party/bonnie.tres").duplicate_deep()]
var time_played: float = 0.0
var current_scene: String = "res://scenes/maps/1ab.tscn"
var scene_data: Dictionary = {}
var player_position: Vector2

var loading = false

func _ready() -> void:
	add_item(preload("res://resources/items/consumables/small_soda.tres"), 5)
	add_item(preload("res://resources/items/consumables/small_pizza.tres"), 5)
	add_item(preload("res://resources/items/consumables/degreaser.tres"), 5)
	add_item(preload("res://resources/items/armor/EndoBodyA.tres"), 1)
	for p in party:
		p.equip_stats_change()

func _process(delta: float) -> void:
	time_played += delta

# === Save Data Management ===
func serialize_value(value: Variant) -> Variant:
	if value is Resource:
		return value.resource_path if value.resource_path != "" else null
	elif value is Dictionary:
		var new_dict = {}
		for k in value.keys():
			new_dict[serialize_value(k)] = serialize_value(value[k])
		return new_dict
	elif value is Array:
		var new_arr = []
		for v in value:
			new_arr.append(serialize_value(v))
		return new_arr
	elif value is Vector2 or value is Color:
		return var_to_str(value)
	return value

func deserialize_value(value: Variant) -> Variant:
	if value is String and value.ends_with(".tres"):
		return load(value)
	elif value is String and (value.begins_with("Vector2") or value.begins_with("Color")):
		return str_to_var(value)
	elif value is Dictionary:
		var new_dict = {}
		for k in value.keys():
			new_dict[deserialize_value(k)] = deserialize_value(value[k])
		return new_dict
	elif value is Array:
		var new_arr = []
		for v in value:
			new_arr.append(deserialize_value(v))
		return new_arr
	return value

func get_save_data() -> Dictionary:
	var data = {"inventory": {}, "current_scene": current_scene, "player_position": player_position}
	
	for path in inventory.keys():
		data["inventory"][path.resource_path] = inventory[path]
	var p_data = []
	for p in party:
		if p is Resource:
			var p_dict = {"resource_path": p.path_to, "properties": {}}
			for prop in p.get_property_list():
				if prop.usage & PROPERTY_USAGE_STORAGE and prop in Party.new().get_script().get_script_property_list():
					var prop_name = prop.name
					var prop_value = p.get(prop_name)
					p_dict["properties"][prop_name] = serialize_value(prop_value)
			p_data.append(p_dict)
	
	data["party"] = p_data
	return data

func load_save_data(data: Dictionary, scenes_data: Dictionary) -> void:
	var inv_data = data.get("inventory", {})
	inventory.clear()
	for path in inv_data.keys():
		var item = deserialize_value(path)
		var amount = inv_data[path]
		inventory.merge({item: int(amount)})
	party.clear()
	for p_dict in data.get("party", []):
		var resource: Party = load(p_dict["resource_path"]).duplicate_deep()
		if resource:
			resource = resource.duplicate(true)
			for prop_name in p_dict["properties"].keys():
				var prop_value = deserialize_value(p_dict["properties"][prop_name])
				if prop_name in resource:
					resource.set(prop_name, prop_value)
			party.append(resource)
			
	loading = true
	if data.has("current_scene"):
		var vector = str_to_var("Vector2" + data["player_position"])
		player_position = vector
		get_tree().change_scene_to_file(data["current_scene"])
	scene_data = scenes_data
	await get_tree().create_timer(0.03).timeout
	loading = false

func set_scene_data(data: Object):
	var is_room = scene_data.find_key(data.room_name)
	if is_room:
		scene_data.merge({data.room_name: {"textboxes_deactivated": data.textboxes_deactivated}}, true)
	else:
		scene_data.assign({data.room_name: {"textboxes_deactivated": data.textboxes_deactivated}})

func get_scenes_data():
	return scene_data

func reload_last_save() -> void:
	var file = FileAccess.open("user://save.save", FileAccess.READ)
	if not file:
		get_tree().change_scene_to_file(current_scene)
		return
	var json = file.get_as_text()
	file.close()
	var data = JSON.parse_string(json)
	if data:
		var scenes_file = FileAccess.open("user://scene_data.save", FileAccess.READ)
		var scenes_data = {}
		if scenes_file:
			var scenes_json = scenes_file.get_as_text()
			scenes_file.close()
			scenes_data = JSON.parse_string(scenes_json) if scenes_json else {}
		load_save_data(data, scenes_data)
	else:
		get_tree().change_scene_to_file(current_scene)

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
func use_item(item: Resource, target: Object) -> bool:
	if not item or not target or not is_instance_valid(target):
		return false
	if item.type != 2: 
		return false

	if not has_item(item):
		return false

	if item.consume_effects_given:
		for effect_key in item.consume_effects_given.keys():
			var effect_data = item.consume_effects_given[effect_key]
			if effect_key == BattleEffect.StatusEffect.Revive:
				if target.hp <= 0:
					target.hp = 1
				elif target.hp > 0:
					if target is Party:
						target.hp = target.max_stats["hp"]
					elif target is Enemy:
						target.hp = target.max_hp
			if effect_data is Array and effect_data.size() >= 2:
				var level = effect_data[0]
				var duration = effect_data[1]
				apply_effect(target, effect_key, level, duration)

	if item.heal_amount > 0 and target.hp < target.max_stats["hp"] and target.hp > 0:
		target.hp = min(target.hp + item.heal_amount, target.max_stats["hp"])
	
	if item.mana_amount > 0 and target.mp < target.max_stats["mp"]:
		target.mp = min(target.mp + item.mana_amount, target.max_stats["mp"])

	if item.heals_effects:
		for effect_key in item.heals_effects:
			if target.effects.has(effect_key):
				target.effects.erase(effect_key)

	remove_item(item, 1)

	if battle_ref and battle_ref.has_method("update_effect_ui"):
		battle_ref.update_effect_ui(target)

	return true

func apply_effect(target: Object, effect: int, level: int, duration: int):
	if not target.effects.has(effect):
		target.effects[effect] = [0, 0]
	target.effects[effect][0] = max(target.effects[effect][0], level)
	target.effects[effect][1] = max(target.effects[effect][1], duration)

	if battle_ref and battle_ref.has_method("apply_effect_duration"):
		battle_ref.apply_effect_duration(target, effect, level, duration)

# === Tools ===
func lower_font(target: Label):
	target.theme.default_font_size = 48
	while target.theme.default_font.get_string_size(target.text, target.horizontal_alignment, -1, target.theme.default_font_size).x > target.custom_minimum_size.x:
		target.default_font_size -= 1

# === Mics ===
func load_battle(battle: Battle):
	battle_current = battle
	get_tree().change_scene_to_file("res://scenes/ui/battle_engine_stuff/battle_engine.tscn")

func tb_has_item(item_path: String, amount: int = 1) -> bool:
	var item = load(item_path) if item_path != "" else null
	print(true if has_item(item, amount) else false)
	return has_item(item, amount) if item else false

func tb_remove_item(item_path: String, amount: int = 1) -> void:
	var item = load(item_path) if item_path != "" else null
	if item: remove_item(item, amount)

func tb_set_flag(key: String, value: bool = true) -> void:
	scene_data[key] = value

func tb_get_flag(key: String, default: bool = false) -> bool:
	return scene_data.get(key, default)
