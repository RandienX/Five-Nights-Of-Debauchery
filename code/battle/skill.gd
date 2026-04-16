@tool
extends Resource
class_name Skill

## Skill/Ability configuration with comprehensive customization

@export_group("Basic Info")
@export var skill_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Type & Targeting")
@export_enum("Attack", "Buff", "Debuff", "Heal", "Multiattack", "Item", "Custom") var attack_type: int = 0
@export_enum("SingleEnemy", "Self", "Party", "AllEnemies", "SingleAlly", "RandomEnemy") var target_type: int = 0

@export_group("Cost & Accuracy")
@export var mana_cost: int = 0
@export var hp_cost: int = 0
@export_range(0.01, 1.0) var accuracy: float = 1.0
@export var priority: int = 0                    # Higher = acts first

@export_group("Attack Properties")
@export var attack_multiplier: float = 1.0
@export var attack_bonus: int = 0
@export var damage_type: int = 0                 # 0=Physical, 1=Magical
@export var element: int = 0                     # For elemental weaknesses

@export_group("Multiattack")
@export var hit_count: int = 3
@export var hit_damage_multiplier: float = 0.5

@export_group("Effects")
@export var on_use_effects: Array[BattleEffect] = []
@export var on_hit_effects: Array[BattleEffect] = []
@export var on_miss_effects: Array[BattleEffect] = []
@export var legacy_effects: Dictionary[BattleEffect.StatusEffect, Array] = {}  # {effect: [level, duration]}

@export_group("Item Usage")
@export var item_reference: Item

@export_group("Visual & Audio")
@export var animation_name: String = ""
@export var sfx: AudioStreamMP3
@export var camera_shake: float = 0.0

@export_group("Conditions")
@export var require_weapon_type: int = -1       # -1=any, 0=one-handed, 1=two-handed
@export var require_armor_type: int = -1        # -1=any
@export var require_hp_below_percent: int = 0
@export var require_mp_below_percent: int = 0


func get_effective_accuracy(user: Object) -> float:
	var acc = accuracy
	# Could apply buffs/debuffs here
	return acc


func get_total_damage(user: Object, target: Object) -> int:
	var base_dmg = user.damage if user.has_method("get_effective_damage") else user.get("damage", 10)
	var total = floor(base_dmg * attack_multiplier) + attack_bonus
	return max(1, total)


func can_use(user: Object) -> bool:
	if user.mp < mana_cost:
		return false
	if user.hp <= hp_cost:
		return false
	if require_hp_below_percent > 0:
		var hp_percent = (float(user.hp) / float(user.max_stats.get("hp", user.max_hp))) * 100
		if hp_percent >= require_hp_below_percent:
			return false
	if require_mp_below_percent > 0:
		var mp_percent = (float(user.mp) / float(user.max_stats.get("mp", user.max_mp))) * 100
		if mp_percent >= require_mp_below_percent:
			return false
	return true
