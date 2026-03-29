extends Resource
class_name Party

@export var name: String
@export var face_path: String
@export var face_part_rect: Rect2
@export var base_stats: Dictionary[String, int] = {
	"hp": 0,
	"mp": 0,
	"atk": 0,
	"def": 0,
	"ai": 0,
	"cool": 0,
}
@export var max_stats: Dictionary[String, int] = {
	"hp": 0,
	"mp": 0,
	"atk": 0,
	"def": 0,
	"ai": 0,
	"cool": 0,
}

@export var hp: int = max_stats["hp"]
@export var mp: int = max_stats["mp"]

@export var level_up: Dictionary[String, int] = {
	"hp": 0,
	"mp": 0,
	"atk": 0,
	"def": 0,
	"ai": 0,
	"cool": 0,
}

@export var level_up_xp_multilpier: float = 1.5
@export var xp_to_level_up: int = 100
@export var xp: int = 0
@export var level: int = 1

@export var path_to: String

@export_category("Overview")
@export_multiline var overview: String = ""
@export var overview_model: Texture2D

@export_category("Skills")
@export var skills: Dictionary[int, Skill] = {}

@export var equipped: Dictionary[String, Item] = {"head": null,
													"body": null,
													"legs": null,
													"weapon_left": null,
													"weapon_right": null,
													"shield": null}
@export var effects: Dictionary[Global.effect, Array] = {}  # {effect: [level, duration]}

func equip_stats_change():
	max_stats = base_stats.duplicate()
	for i: Item in equipped.values():
		if i != null:
			for s in range(len(i.item_bonuses)):
				var stat = i.item_bonuses.keys()[s]
				var value = i.item_bonuses.values()[s]
				max_stats[stat] += value
		
			if i.type == 0:  # Weapon
				for effect_key in i.weapon_effects_given.keys():
					var effect_data = i.weapon_effects_given[effect_key]
					if effect_data is Array and effect_data.size() >= 2:
						apply_equipment_effect(effect_key, effect_data[0], effect_data[1])
			
			elif i.type == 1:  # Armor
				for effect_key in i.startup_effects_given.keys():
					var effect_data = i.startup_effects_given[effect_key]
					if effect_data is Array and effect_data.size() >= 2:
						apply_equipment_effect(effect_key, effect_data[0], effect_data[1])

func apply_equipment_effect(effect: int, level: int, duration: int):
	if not effects.has(effect):
		effects[effect] = [0, 0]
	effects[effect][0] = max(effects[effect][0], level)
	effects[effect][1] = max(effects[effect][1], duration)

func remove_item_stats_change(item):
	for s in range(len(item.item_bonuses)):
		var stat = item.item_bonuses.keys()[s]
		var value = item.item_bonuses.values()[s]
		max_stats[stat] -= value
		
	if item.type == 0:  # Weapon
		for effect_key in item.weapon_effects_given.keys():
			if effects.has(effect_key):
				effects.erase(effect_key)
	elif item.type == 1:  # Armor
		for effect_key in item.startup_effects_given.keys():
			if effects.has(effect_key):
				effects.erase(effect_key)
				
