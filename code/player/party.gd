@tool
extends Resource
class_name Party

## Party member configuration with comprehensive customization

@export_group("Basic Info")
@export var character_name: String = ""
@export_multiline var overview: String = ""
@export var portrait: Texture2D
@export var battle_sprite: Texture2D
@export var back_sprite: Texture2D

@export_group("Stats - Base")
@export var base_stats: Dictionary[String, int] = {
"hp": 100,
"mp": 50,
"atk": 10,
"def": 5,
"speed": 10,
"magic": 10,
}

@export_group("Stats - Growth")
@export var max_stats: Dictionary[String, int] = {
"hp": 999,
"mp": 999,
"atk": 99,
"def": 99,
"speed": 99,
"magic": 99,
}

@export var level_up_gains: Dictionary[String, int] = {
"hp": 10,
"mp": 5,
"atk": 2,
"def": 1,
"speed": 1,
"magic": 2,
}

@export_group("Current Stats")
@export var hp: int = 100
@export var mp: int = 50
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_level_up: int = 100
@export var level_up_xp_multiplier: float = 1.5

@export_group("Combat")
@export var skills: Dictionary[int, Skill] = {}
@export var default_attack: Skill
@export var passive_effects: Array[BattleEffect] = []

@export_group("Equipment")
@export var equipped: Dictionary[String, Item] = {
"head": null,
"body": null,
"legs": null,
"weapon_left": null,
"weapon_right": null,
"shield": null,
"accessory_1": null,
"accessory_2": null,
}

@export_group("Status Effects")
@export var effects: Dictionary[BattleEffect.StatusEffect, Array] = {}

@export_group("AI Behavior")
@export var ai_type: Global.AI = Global.AI.Casual
@export var aggression: float = 0.5
@export var prefer_defend: bool = false
@export var smart_targeting: bool = true

@export_category("Legacy Compatibility")
@export var face_path: String = ""
@export var face_part_rect: Rect2
@export var path_to: String = ""
@export var overview_model: Texture2D


func _init():
for key in base_stats.keys():
if not max_stats.has(key):
max_stats[key] = base_stats[key] * 10
if not level_up_gains.has(key):
level_up_gains[key] = base_stats[key]


func setup_from_base():
hp = max_stats.get("hp", 100)
mp = max_stats.get("mp", 50)
equip_stats_change()


func equip_stats_change():
max_stats = base_stats.duplicate()
effects.clear()

for slot_name in equipped.keys():
var item: Item = equipped[slot_name]
if item != null:
for stat in item.item_bonuses.keys():
var value = item.item_bonuses[stat]
if max_stats.has(stat):
max_stats[stat] += value

if item.type == 0:
for effect_key in item.weapon_effects_given.keys():
var effect_data = item.weapon_effects_given[effect_key]
if effect_data is Array and effect_data.size() >= 2:
apply_equipment_effect(effect_key, effect_data[0], effect_data[1])

elif item.type == 1:
for effect_key in item.startup_effects_given.keys():
var effect_data = item.startup_effects_given[effect_key]
if effect_data is Array and effect_data.size() >= 2:
apply_equipment_effect(effect_key, effect_data[0], effect_data[1])


func apply_equipment_effect(effect: int, level: int, duration: int):
if not effects.has(effect):
effects[effect] = [0, 0]
effects[effect][0] = max(effects[effect][0], level)
effects[effect][1] = max(effects[effect][1], duration)


func remove_item_stats_change(item: Item):
for stat in item.item_bonuses.keys():
var value = item.item_bonuses[stat]
if max_stats.has(stat):
max_stats[stat] -= value

if item.type == 0:
for effect_key in item.weapon_effects_given.keys():
if effects.has(effect_key):
effects.erase(effect_key)
elif item.type == 1:
for effect_key in item.startup_effects_given.keys():
if effects.has(effect_key):
effects.erase(effect_key)


func gain_xp(amount: int) -> bool:
xp += amount
if xp >= xp_to_level_up:
level_up()
return true
return false


func level_up():
level += 1
xp -= xp_to_level_up
xp_to_level_up = floor(xp_to_level_up * level_up_xp_multiplier)

for stat in level_up_gains.keys():
if max_stats.has(stat):
max_stats[stat] += level_up_gains[stat]

hp = max_stats.get("hp", hp)
mp = max_stats.get("mp", mp)

if skills.has(level):
pass


func can_learn_skill(skill: Skill) -> bool:
for s in skills.values():
if s == skill:
return false
return true


func get_effective_stat(stat_name: String) -> int:
var base = max_stats.get(stat_name, 0)
return base
