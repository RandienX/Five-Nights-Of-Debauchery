@tool
extends Resource
class_name Entity

## Unified Entity resource combining Party and Enemy functionality
## Can be used for both party members and enemies with role-specific configuration

enum Role { PARTY, ENEMY }
enum AIType { Dumb, Casual, Violent, Defensive, Intelligent, Flexible }

# ==================== BASIC INFO ====================
@export_group("Basic Info")
@export var name: String = ""
@export_multiline var description: String = ""
@export var role: Role = Role.PARTY
@export var portrait: Texture2D
@export var battle_sprite: Texture2D
@export var back_sprite: Texture2D

# ==================== STATS - BASE ====================
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

# ==================== CURRENT STATS ====================
@export_group("Current Stats")
@export var hp: int = 100
@export var mp: int = 50
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_level_up: int = 100
@export var level_up_xp_multiplier: float = 1.5

# ==================== COMBAT ====================
@export_group("Combat")
@export var skills: Dictionary[int, Array[Skill]] = {}
@export var default_attack: Skill
@export var passive_effects: Array[BattleEffect] = []
@export var effects_on_spawn: Array[BattleEffect] = []
@export var effects_on_death: Array[BattleEffect] = []

# ==================== STATUS EFFECTS ====================
@export_group("Status Effects")
@export var effects: Dictionary[BattleEffect.StatusEffect, Array] = {}
@export var immune_to_effects: Array[BattleEffect.StatusEffect] = []

# ==================== EQUIPMENT (Party Only) ====================
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

# ==================== AI BEHAVIOR ====================
@export_group("AI Behavior")
@export var ai_type: AIType = AIType.Casual
@export var aggression: float = 0.5            # 0=passive, 1=aggressive
@export var prefer_defend: bool = false
@export var smart_targeting: bool = true
@export var target_priority: int = 0           # 0=random, 1=lowest HP, 2=highest threat

# ==================== REWARDS (Enemy Only) ====================
@export_group("Rewards")
@export var xp_reward: int = 10
@export var currency_reward: int = 0
@export var item_drops: Array[BattleItemDrop] = []

# ==================== BATTLE SETTINGS ====================
@export_group("Battle Settings")
@export var is_boss: bool = false
@export var can_flee: bool = false
@export var flee_threshold_hp_percent: int = 25

# ==================== LEGACY COMPATIBILITY ====================
@export_category("Legacy Compatibility")
@export var face_path: String = ""
@export var face_part_rect: Rect2
@export var path_to: String = ""
@export var overview: String = ""
@export var overview_model: Texture2D
@export var items: Dictionary = {}


func _init():
	# Initialize stat dictionaries if empty
	for key in base_stats.keys():
		if not max_stats.has(key):
			max_stats[key] = base_stats[key] * 10
		if not level_up_gains.has(key):
			level_up_gains[key] = base_stats[key]
	
	# Set current stats to max on initialization
	if hp <= 0:
		hp = max_stats.get("hp", 100)
	if mp <= 0:
		mp = max_stats.get("mp", 50)


# ==================== SETUP FUNCTIONS ====================
func setup_from_base():
	hp = max_stats.get("hp", 100)
	mp = max_stats.get("mp", 50)
	if role == Role.PARTY:
		equip_stats_change()


# ==================== EQUIPMENT FUNCTIONS (Party) ====================
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


# ==================== LEVEL UP FUNCTIONS (Party) ====================
func gain_xp(amount: int) -> bool:
	if role != Role.PARTY:
		return false
	
	xp += amount
	if xp >= xp_to_level_up:
		level_up()
		return true
	return false


func level_up():
	if role != Role.PARTY:
		return
	
	level += 1
	xp -= xp_to_level_up
	xp_to_level_up = floor(xp_to_level_up * level_up_xp_multiplier)
	
	for stat in level_up_gains.keys():
		if max_stats.has(stat):
			max_stats[stat] += level_up_gains[stat]
	
	hp = max_stats.get("hp", hp)
	mp = max_stats.get("mp", mp)
	
	# Check if any new skills are unlocked at this level
	if skills.has(level):
		pass  # Learn new skills from skills[level] array


func can_learn_skill(skill: Skill) -> bool:
	# Check if skill is already learned at any level
	for level_skills in skills.values():
		if skill in level_skills:
			return false
	return true


# ==================== STAT HELPERS ====================
func get_effective_stat(stat_name: String) -> int:
	var base = max_stats.get(stat_name, 0)
	return base


func get_effective_damage() -> int:
	var dmg = base_stats.get("atk", 10)
	# Could apply buffs/debuffs here
	return dmg


func get_effective_defense() -> int:
	var def_stat = base_stats.get("def", 5)
	# Could apply buffs/debuffs here
	return def_stat


# ==================== STATUS EFFECT FUNCTIONS ====================
func is_immune_to(effect: BattleEffect.StatusEffect) -> bool:
	return effect in immune_to_effects


# ==================== DUPLICATION ====================
func duplicate_deep_custom() -> Entity:
	var new_entity = duplicate(true)
	new_entity.hp = max_stats.get("hp", 100)
	new_entity.mp = max_stats.get("mp", 50)
	return new_entity


# ==================== ROLE HELPERS ====================
func is_party_member() -> bool:
	return role == Role.PARTY


func is_enemy() -> bool:
	return role == Role.ENEMY


# ==================== LEGACY COMPATIBILITY ====================
# These properties provide backward compatibility with old Party and Enemy code
var damage: int:
	get:
		return base_stats.get("atk", 10)
	set(value):
		base_stats["atk"] = value

var max_hp: int:
	get:
		return max_stats.get("hp", 100)
	set(value):
		max_stats["hp"] = value

var max_mp: int:
	get:
		return max_stats.get("mp", 50)
	set(value):
		max_stats["mp"] = value

var speed: int:
	get:
		return base_stats.get("speed", 10)
	set(value):
		base_stats["speed"] = value

var magic_power: int:
	get:
		return base_stats.get("magic", 10)
	set(value):
		base_stats["magic"] = value

var magic_defense: int:
	get:
		return base_stats.get("def", 5)
	set(value):
		base_stats["def"] = value
