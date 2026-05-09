
@tool
extends Resource
class_name Entity

## Unified Entity resource with robust stat tracking, status/modifier system,
## and outside-battle persistence support. Decoupled from battle resolution.

# ==================== ENUMS ====================

enum Role { PARTY, ENEMY }
enum AIType { DUMB, CASUAL, VIOLENT, DEFENSIVE, INTELLIGENT, FLEXIBLE }

# ==================== BASIC INFO ====================

@export_group("Basic Info")
@export var name: String = ""
@export_multiline var description: String = ""
@export var role: Role = Role.PARTY
@export var portrait: Texture2D
@export var portrait_rect := Rect2()
@export var battle_sprite: Texture2D
@export var back_sprite: Texture2D
@export var path_to: String = ""

# ==================== BASE STATS ====================

@export_group("Base Stats")
## Base stats at level 1
@export var base_stats: Dictionary[StringName, int] = {
	&"hp": 100,
	&"mp": 50,
	&"atk": 10,
	&"def": 5,
	&"speed": 10,
	&"magic": 10,
}

## Maximum possible stats (cap)
@export var max_stat_caps: Dictionary[StringName, int] = {
	&"hp": 999,
	&"mp": 999,
	&"atk": 99,
	&"def": 99,
	&"speed": 99,
	&"magic": 99,
}

## Stat gains per level
@export var level_up_gains: Dictionary[StringName, int] = {
	&"hp": 10,
	&"mp": 5,
	&"atk": 2,
	&"def": 1,
	&"speed": 1,
	&"magic": 2,
}

# ==================== CURRENT STATE ====================

@export_group("Current State")
@export var hp: int = 100
@export var mp: int = 50
@export var level: int = 1
@export var xp: int = 0
@export var xp_to_level_up: int = 100
@export var level_up_xp_multiplier: float = 1.5

# Combat state flags (runtime only, not serialized)
@export var skip_turn: bool = false
@export var extra_turn: bool = false
@export var is_defending: bool = false

# ==================== STAT MODIFIERS ====================

## Active stat modifiers: { modifier_id: StatModifierInstance }
## Not exported - managed at runtime
var _stat_modifiers: Dictionary = {}

## Cached effective stats for performance
var _effective_stat_cache: Dictionary[StringName, int] = {}
var _cache_dirty: bool = true

# ==================== STATUS SYSTEM ====================

## Active statuses: { status_id: StatusInstance }
## StatusInstance contains: definition, stacks, duration, applied_modifiers, etc.
var _statuses: Dictionary = {}

## Status registry for looking up definitions by ID
## Set this to a resource or autoload that holds all StatusDefinition resources
var status_registry: Dictionary = {}

# ==================== COMBAT DATA ====================

@export_group("Combat")
@export var skills: Dictionary[int, Array] = {}
@export var default_attack: Skill
@export var passive_effects: Array[BattleEffect] = []
@export var effects_on_spawn: Array[BattleEffect] = []
@export var effects_on_death: Array[BattleEffect] = []

# ==================== EQUIPMENT (Party Only) ====================

@export_group("Equipment")
@export var equipped: Dictionary = {
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
@export var ai_type: AIType = AIType.CASUAL
@export var aggression: float = 0.5
@export var prefer_defend: bool = false
@export var smart_targeting: bool = true
@export var target_priority: int = 0

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

# ==================== SIGNALS ====================

signal stat_modified(stat_key: StringName, new_value: int)
signal status_applied(status_id: String, stacks: int)
signal status_removed(status_id: String)
signal status_ticked(status_id: String, remaining_duration: int)
signal hp_changed(old_hp: int, new_hp: int)
signal mp_changed(old_mp: int, new_mp: int)
signal died()

# ==================== INITIALIZATION ====================

func _init():
	_initialize_stat_dicts()
	_setup_current_stats()

func _initialize_stat_dicts():
	"""Ensure all stat dictionaries have matching keys."""
	var default_stats = [&"hp", &"mp", &"atk", &"def", &"speed", &"magic"]
	
	for key in default_stats:
		if not base_stats.has(key):
			base_stats[key] = 10
		if not max_stat_caps.has(key):
			max_stat_caps[key] = base_stats[key] * 10
		if not level_up_gains.has(key):
			level_up_gains[key] = base_stats[key]
	level_fix()

func level_fix():
	for lvl in range(level-1):
		var temp := 0
		for stat in [&"hp", &"mp", &"atk", &"def", &"speed"]:
			temp += int(level_up_gains[stat] if level_up_gains.has(stat) else 1)
			max_stat_caps[stat] = max_stat_caps[stat] + temp
			base_stats[stat] = base_stats[stat] + temp

func _setup_current_stats():
	"""Initialize current stats based on max values."""
	if hp <= 0:
		hp = get_max_stat(&"hp")
	if mp <= 0:
		mp = get_max_stat(&"mp")

# ==================== STAT ACCESS API ====================

func get_base_stat(stat_key: StringName) -> int:
	"""Get the raw base stat value without any modifiers."""
	return base_stats.get(stat_key, 0)

func get_max_stat(stat_key: StringName) -> int:
	"""Get the maximum allowed value for a stat (cap)."""
	return max_stat_caps.get(stat_key, 999)

func get_effective_stat(stat_key: StringName) -> int:
	"""
	Get the final stat value after applying all modifiers.
	Caches results for performance; call invalidate_cache() when modifiers change.
	"""
	if _cache_dirty:
		_recalculate_effective_stats()
	
	if _effective_stat_cache.has(stat_key):
		return _effective_stat_cache[stat_key]
	
	# Fallback: return base if not cached
	return get_base_stat(stat_key)

func _recalculate_effective_stats():
	"""Recalculate all effective stats from base + modifiers."""
	_effective_stat_cache.clear()
	
	for stat_key in base_stats.keys():
		var base_value: int = base_stats[stat_key]
		var modified_value: float = float(base_value)
		
		# Apply all active modifiers for this stat
		for mod_id in _stat_modifiers.keys():
			var modifier = _stat_modifiers[mod_id]
			if modifier.stat_key == stat_key:
				match modifier.stacking_rule:
					StatModifier.StackingRule.ADDITIVE:
						modified_value += modifier.applied_delta
					StatModifier.StackingRule.MULTIPLICATIVE:
						modified_value *= (1.0 + modifier.applied_delta / 100.0)
					_:
						# OVERRIDE takes the highest value
						if modifier.applied_delta > modified_value:
							modified_value = modifier.applied_delta
		
		# Clamp to valid range
		var min_val = 0 if stat_key != &"hp" else 1
		var max_val = get_max_stat(stat_key)
		modified_value = clamp(modified_value, min_val, max_val)
		
		_effective_stat_cache[stat_key] = int(round(modified_value))
	
	_cache_dirty = false

func invalidate_stat_cache():
	"""Mark stat cache as dirty; will recalculate on next get_effective_stat()."""
	_cache_dirty = true

# ==================== STAT MODIFIER SYSTEM ====================

func apply_modifier(modifier_id: String, modifier: StatModifier, source: Entity = null) -> bool:
	"""
	Apply a stat modifier to this entity.
	Returns true if successfully applied, false if blocked by stacking rules.
	"""
	var existing = _stat_modifiers.get(modifier_id)
	
	if existing:
		# Handle stacking
		match modifier.stacking_rule:
			StatModifier.StackingRule.NONE:
				return false  # Cannot stack
			StatModifier.StackingRule.OVERRIDE:
				# Remove old, apply new
				remove_modifier(modifier_id)
			StatModifier.StackingRule.EXTEND:
				# Add duration, keep higher value
				existing.turns_remaining += modifier.duration_turns
				if modifier.value > existing.value:
					existing.value = modifier.value
				invalidate_stat_cache()
				return true
			StatModifier.StackingRule.REFRESH:
				# Reset duration
				existing.turns_remaining = modifier.duration_turns
				return true
			StatModifier.StackingRule.CAPPED:
				if existing.stack_count >= modifier.max_stacks:
					return false
				existing.stack_count += 1
				existing.applied_delta += modifier.calculate_final_value(source if source else self, self)
				existing.turns_remaining = max(existing.turns_remaining, modifier.duration_turns)
				invalidate_stat_cache()
				return true
	
	# Create new modifier instance
	var new_modifier = modifier.duplicate()
	new_modifier.applied_delta = new_modifier.calculate_final_value(
		source if source else self, 
		self
	)
	new_modifier.turns_remaining = new_modifier.duration_turns
	new_modifier.stack_count = 1
	
	_stat_modifiers[modifier_id] = new_modifier
	invalidate_stat_cache()
	
	return true

func remove_modifier(modifier_id: String) -> bool:
	"""Remove a stat modifier by ID. Returns true if found and removed."""
	if not _stat_modifiers.has(modifier_id):
		return false
	
	var modifier = _stat_modifiers[modifier_id]
	# Note: applied_delta is already factored into effective stats,
	# and we'll recalculate on next access, so no explicit reversal needed
	_stat_modifiers.erase(modifier_id)
	invalidate_stat_cache()
	
	return true

func tick_modifiers() -> Array[String]:
	"""
	Decrement duration on all turn-based modifiers.
	Returns array of modifier IDs that expired.
	"""
	var expired: Array[String] = []
	
	for mod_id in _stat_modifiers.keys():
		var modifier = _stat_modifiers[mod_id]
		
		if modifier.duration_type == StatModifier.DurationType.TURNS:
			modifier.turns_remaining -= 1
			
			if modifier.turns_remaining <= 0:
				expired.append(mod_id)
	
	# Remove expired modifiers
	for mod_id in expired:
		remove_modifier(mod_id)
	
	return expired

func get_active_modifier_ids() -> Array[String]:
	"""Get list of all active modifier IDs."""
	return _stat_modifiers.keys()

func has_modifier(modifier_id: String) -> bool:
	"""Check if a specific modifier is active."""
	return _stat_modifiers.has(modifier_id)

# ==================== STATUS SYSTEM ====================

func apply_status(status_def: StatusDefinition, stacks: int = 1, duration: int = -1, source: Entity = null) -> bool:
	"""
	Apply a status effect to this entity.
	
	Args:
		status_def: The status definition resource
		stacks: Number of stacks to apply
		duration: Override duration (-1 uses status default)
		source: Entity that applied this status (for callbacks)
	
	Returns:
		true if status was applied, false if blocked (immunity, stacking rules, etc.)
	"""
	print("entity.gd: apply_status: START - status_id=%s, stacks=%d, duration=%d, source=%s" % [status_def.id, stacks, duration, source.name if source else "null"])
	
	# Check immunity
	if not status_def.can_be_removed and has_status(status_def.id):
		print("entity.gd: apply_status: status cannot be removed and already exists, returning false")
		return false  # Already have an unremovable version
	
	var existing = _statuses.get(status_def.id)
	
	if existing:
		print("entity.gd: apply_status: existing status found, handling stacking rule=%d" % status_def.stacking_rule)
		# Handle stacking based on rule
		match status_def.stacking_rule:
			StatModifier.StackingRule.NONE:
				print("entity.gd: apply_status: stacking rule NONE, returning false")
				return false
			StatModifier.StackingRule.OVERRIDE:
				# Replace existing
				print("entity.gd: apply_status: stacking rule OVERRIDE, removing existing")
				_remove_status_internal(status_def.id, source)
			StatModifier.StackingRule.EXTEND:
				existing.duration += duration if duration > 0 else status_def.duration_value
				existing.stacks = max(existing.stacks, stacks)
				_apply_status_modifiers(existing)
				print("entity.gd: apply_status: stacking rule EXTEND, new_duration=%d, new_stacks=%d" % [existing.duration, existing.stacks])
				return true
			StatModifier.StackingRule.REFRESH:
				existing.duration = duration if duration > 0 else status_def.duration_value
				print("entity.gd: apply_status: stacking rule REFRESH, new_duration=%d" % existing.duration)
				return true
			StatModifier.StackingRule.CAPPED:
				if existing.stacks >= status_def.max_stacks:
					print("entity.gd: apply_status: stacking rule CAPPED, max stacks reached (%d)" % status_def.max_stacks)
					return false
				existing.stacks += stacks
				_apply_status_modifiers(existing)
				print("entity.gd: apply_status: stacking rule CAPPED, new_stacks=%d" % existing.stacks)
				return true
	
	# Create new status instance
	var status_instance = {
		"definition": status_def,
		"stacks": stacks,
		"duration": duration if duration > 0 else status_def.duration_value,
		"applied_modifiers": [],  # Track which modifier IDs we created
		"source": source,
	}
	
	_statuses[status_def.id] = status_instance
	print("entity.gd: apply_status: created new status instance with duration=%d" % status_instance["duration"])
	
	# Apply stat modifiers from status
	_apply_status_modifiers(status_instance)
	
	# Call on_apply callback if defined
	if status_def.on_apply_callback != "" and source:
		print("entity.gd: apply_status: calling on_apply callback=%s" % status_def.on_apply_callback)
		_call_status_callback(status_def.on_apply_callback, status_instance, source)
	
	status_applied.emit(status_def.id, stacks)
	print("entity.gd: apply_status: END - status applied successfully")
	
	return true

func _apply_status_modifiers(status_instance: Dictionary):
	"""Apply all stat modifiers from a status instance."""
	print("entity.gd: _apply_status_modifiers: START - status_id=%s, modifier_count=%d" % [status_instance.definition.id, status_instance.definition.stat_modifiers.size()])
	var def = status_instance.definition
	var mod_prefix = "status_" + def.id + "_"

	# Clear existing applied modifiers to prevent duplicates when re-applying
	for mod_id in status_instance.applied_modifiers:
		remove_modifier(mod_id)
		status_instance.applied_modifiers.clear()

	for i in range(def.stat_modifiers.size()):
		var base_mod = def.stat_modifiers[i]
		var mod_id = mod_prefix + str(i)
		print("entity.gd: _apply_status_modifiers: applying modifier[%d], mod_id=%s, stat_key=%s, value=%f" % [i, mod_id, base_mod.stat_key, base_mod.value])
		if apply_modifier(mod_id, base_mod, status_instance.source):
			status_instance.applied_modifiers.append(mod_id)
			print("entity.gd: _apply_status_modifiers: modifier[%d] applied successfully" % i)
		else:
			print("entity.gd: _apply_status_modifiers: modifier[%d] FAILED to apply" % i)
			print("entity.gd: _apply_status_modifiers: END - applied_modifiers_count=%d" % status_instance.applied_modifiers.size())
			"""Apply all stat modifiers from a status instance."""

func _remove_status_internal(status_id: String, source: Entity = null):
	"""Internal removal that cleans up modifiers and calls callbacks."""
	if not _statuses.has(status_id):
		return
	
	var status_instance = _statuses[status_id]
	var def = status_instance.definition
	
	# Remove all applied modifiers
	for mod_id in status_instance.applied_modifiers:
		remove_modifier(mod_id)
	
	# Call on_remove callback
	if def.on_remove_callback != "" and source:
		_call_status_callback(def.on_remove_callback, status_instance, source)
	
	_statuses.erase(status_id)
	status_removed.emit(status_id)

func remove_status(status_id: String, source: Entity = null) -> bool:
	"""
	Remove a status effect by ID.
	Returns true if found and removed, false if not present or cannot be removed.
	"""
	if not _statuses.has(status_id):
		return false
	
	var status_instance = _statuses[status_id]
	if not status_instance.definition.can_be_removed:
		return false  # Cannot remove this status
	
	_remove_status_internal(status_id, source)
	return true

func remove_all_statuses(can_remove_only: bool = true, source: Entity = null) -> int:
	"""
	Remove all status effects.
	Returns count of statuses removed.
	"""
	var removed_count = 0
	var to_remove: Array[String] = []
	
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		if not can_remove_only or instance.definition.can_be_removed:
			to_remove.append(status_id)
	
	for status_id in to_remove:
		_remove_status_internal(status_id, source)
		removed_count += 1
	
	return removed_count

func has_status(status_id: String) -> bool:
	"""Check if entity has a specific status."""
	return _statuses.has(status_id)

func get_status_stacks(status_id: String) -> int:
	"""Get the number of stacks for a status."""
	if not _statuses.has(status_id):
		return 0
	return _statuses[status_id].stacks

func get_status_duration(status_id: String) -> int:
	"""Get remaining duration for a status."""
	if not _statuses.has(status_id):
		return 0
	return _statuses[status_id].duration

func tick_statuses() -> Array[String]:
	"""
	Tick all statuses, decrementing duration and calling tick callbacks.
	Returns array of status IDs that expired.
	"""
	var expired: Array[String] = []
	
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		var def = instance.definition
		
		# Handle duration
		if def.duration_type == StatusDefinition.DurationType.TURNS:
			instance.duration -= 1
			
			if instance.duration <= 0:
				expired.append(status_id)
				continue
		
		# Call tick callback
		if def.tick_callback != "":
			_call_status_callback(def.tick_callback, instance, instance.source)
		
		# Check removal conditions
		for condition in def.removal_conditions:
			if condition.evaluate(self):
				expired.append(status_id)
				break
		
		status_ticked.emit(status_id, instance.duration)
	
	# Remove expired
	for status_id in expired:
		_remove_status_internal(status_id, _statuses[status_id].source)
	
	return expired

func _call_status_callback(callback_name: String, status_instance: Dictionary, source: Entity):
	"""Call a status callback method if it exists on source or self."""
	var target = source if source else self
	if target and target.has_method(callback_name):
		target.call(callback_name, status_instance)

func get_active_status_ids() -> Array[String]:
	"""Get list of all active status IDs."""
	return _statuses.keys()

func get_all_statuses() -> Dictionary:
	"""Get a copy of all status data for serialization."""
	var result = {}
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		result[status_id] = {
			"stacks": instance.stacks,
			"duration": instance.duration,
			"definition_id": instance.definition.id,
		}
	return result

# ==================== HP/MP MANAGEMENT ====================

func modify_hp(amount: int, override_limit: bool = false) -> int:
	"""
	Modify HP by amount (can be negative).
	Returns actual amount applied (may be clamped).
	"""
	var old_hp = hp
	var new_hp = hp + amount
	
	if not override_limit:
		new_hp = clamp(new_hp, 0, get_max_stat(&"hp"))
	
	hp = new_hp
	
	if old_hp != new_hp:
		hp_changed.emit(old_hp, new_hp)
		
		if hp <= 0 and old_hp > 0:
			died.emit()
	
	return new_hp - old_hp

func modify_mp(amount: int) -> int:
	"""
	Modify MP by amount (can be negative).
	Returns actual amount applied (may be clamped).
	"""
	var old_mp = mp
	var new_mp = mp + amount
	new_mp = clamp(new_mp, 0, get_max_stat(&"mp"))
	
	mp = new_mp
	
	if old_mp != new_mp:
		mp_changed.emit(old_mp, new_mp)
	
	return new_mp - old_mp

func heal_hp(amount: int) -> int:
	"""Heal HP (positive amount only). Returns actual healed amount."""
	return modify_hp(abs(amount))

func damage_hp(amount: int) -> int:
	"""Deal damage to HP (positive amount only). Returns actual damage dealt."""
	return modify_hp(-abs(amount))

func is_alive() -> bool:
	return hp > 0

func is_dead() -> bool:
	return hp <= 0

# ==================== SERIALIZATION ====================

func serialize_state() -> Dictionary:
	"""
	Serialize entity state for save/load.
	Includes current stats, active statuses, and modifiers.
	JSON-compatible output.
	"""
	# Serialize statuses
	var statuses_data = []
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		var def = instance.definition
		statuses_data.append({
			"status_id": status_id,
			"stacks": instance.stacks,
			"duration": instance.duration,
			"persists": def.persists_outside_battle,
		})
	
	# Serialize modifiers (only persistent ones)
	var modifiers_data = []
	for mod_id in _stat_modifiers.keys():
		var modifier = _stat_modifiers[mod_id]
		if modifier.duration_type == StatModifier.DurationType.PERMANENT:
			modifiers_data.append({
				"modifier_id": mod_id,
				"stat_key": modifier.stat_key,
				"value": modifier.value,
				"stacks": modifier.stack_count,
			})
	
	return {
		"hp": hp,
		"mp": mp,
		"level": level,
		"xp": xp,
		"base_stats": _dict_to_serializable(base_stats),
		"max_stat_caps": _dict_to_serializable(max_stat_caps),
		"statuses": statuses_data,
		"modifiers": modifiers_data,
		"equipment": _serialize_equipment(),
	}

func deserialize_state(data: Dictionary):
	"""
	Deserialize entity state from save data.
	Restores stats, statuses, and modifiers.
	"""
	if data.has("hp"): hp = data["hp"]
	if data.has("mp"): mp = data["mp"]
	if data.has("level"): level = data["level"]
	if data.has("xp"): xp = data["xp"]
	
	if data.has("base_stats"):
		base_stats = _serializable_to_dict(data["base_stats"])
	if data.has("max_stat_caps"):
		max_stat_caps = _serializable_to_dict(data["max_stat_caps"])
	
	# Restore statuses (only those marked as persist)
	if data.has("statuses"):
		for status_data in data["statuses"]:
			if status_data.get("persists", false):
				var status_id = status_data["status_id"]
				if status_registry.has(status_id):
					var def = status_registry[status_id]
					apply_status(
						def,
						status_data.get("stacks", 1),
						status_data.get("duration", def.duration_value)
					)
	
	# Restore equipment
	if data.has("equipment"):
		_deserialize_equipment(data["equipment"])
	
	invalidate_stat_cache()

func _dict_to_serializable(d: Dictionary) -> Dictionary:
	"""Convert Dictionary with StringName keys to regular strings for JSON."""
	var result = {}
	for key in d.keys():
		result[str(key)] = d[key]
	return result

func _serializable_to_dict(d: Dictionary) -> Dictionary:
	"""Convert string-keyed dict back to StringName keys."""
	var result = {}
	for key in d.keys():
		result[key.to_lower()] = d[key]
	return result

func _serialize_equipment() -> Dictionary:
	"""Serialize equipment slots to paths for save compatibility."""
	var result = {}
	for slot in equipped.keys():
		var item = equipped[slot]
		if item is Resource:
			result[slot] = item.resource_path if item.resource_path != "" else ""
		else:
			result[slot] = ""
	return result

func _deserialize_equipment(data: Dictionary):
	"""Restore equipment from serialized paths."""
	for slot in data.keys():
		var path = data[slot]
		if path != "" and ResourceLoader.exists(path):
			equipped[slot] = ResourceLoader.load(path)
		else:
			equipped[slot] = null

# ==================== UTILITY FUNCTIONS ====================

func full_heal():
	"""Restore HP and MP to maximum."""
	hp = get_max_stat(&"hp")
	mp = get_max_stat(&"mp")
	hp_changed.emit(0, hp)
	mp_changed.emit(0, mp)

func reset_for_battle():
	"""Reset combat state flags before a new battle."""
	skip_turn = false
	extra_turn = false
	is_defending = false
	# Note: We don't clear statuses/modifiers here - they persist if flagged

func cleanup_battle_end(persist_statuses: bool = true):
	"""
	Clean up battle-only effects at end of combat.
	If persist_statuses is true, keeps statuses marked as persists_outside_battle.
	"""
	if not persist_statuses:
		remove_all_statuses(false)
		return
	
	# Remove non-persistent statuses
	var to_remove: Array[String] = []
	for status_id in _statuses.keys():
		var instance = _statuses[status_id]
		if not instance.definition.persists_outside_battle:
			to_remove.append(status_id)
	
	for status_id in to_remove:
		_remove_status_internal(status_id)
	
	# Clear battle-only modifiers
	var mod_to_remove: Array[String] = []
	for mod_id in _stat_modifiers.keys():
		var modifier = _stat_modifiers[mod_id]
		if modifier.duration_type == StatModifier.DurationType.BATTLE:
			mod_to_remove.append(mod_id)
	
	for mod_id in mod_to_remove:
		remove_modifier(mod_id)

# ==================== LEGACY COMPATIBILITY ====================

var damage: int:
	get: return get_base_stat(&"atk")
	set(v): base_stats[&"atk"] = v

var max_hp: int:
	get: return get_max_stat(&"hp")
	set(v): max_stat_caps[&"hp"] = v

var max_mp: int:
	get: return get_max_stat(&"mp")
	set(v): max_stat_caps[&"mp"] = v

var speed: int:
	get: return get_base_stat(&"speed")
	set(v): base_stats[&"speed"] = v

var magic_power: int:
	get: return get_base_stat(&"magic")
	set(v): base_stats[&"magic"] = v

var defense: int:
	get: return get_base_stat(&"def")
	set(v): base_stats[&"def"] = v

func is_party_member() -> bool:
	return role == Role.PARTY

func is_enemy() -> bool:
	return role == Role.ENEMY
	
var equipment_bonus: Dictionary = {}

func equip_stats_change():
	"""
	Directly modify base_stats by adding equipment bonuses.
	This ensures displayed stats and combat calculations use the correct values.
	Called when equipment changes or battle starts.
	"""
	print("entity.gd: apply_equipment_bonuses: START - name=%s" % name)

	# First, remove any existing equipment bonuses to prevent double-dipping
	clear_equipment_bonuses()

	var total_bonus: Dictionary = {}

	# Iterate through all equipment slots and accumulate bonuses
	for slot in equipped.keys():
		var item: Item = equipped[slot]
		if not item:
			continue

		print("entity.gd: apply_equipment_bonuses: processing slot=%s, item=%s, bonuses=%s" % [slot, item.item_name, item.item_bonuses])

		# Accumulate all bonuses from this item
		for stat_key in item.item_bonuses:
			var bonus_value: int = item.item_bonuses[stat_key]
			if bonus_value == 0:
				continue

			if not total_bonus.has(stat_key):
				total_bonus[stat_key] = 0
				total_bonus[stat_key] += bonus_value

		# Apply accumulated bonuses directly to base_stats
		for stat_key in total_bonus:
			var bonus_value = total_bonus[stat_key]
			var original_base = base_stats.get(stat_key, 0)
			base_stats[stat_key] = original_base + bonus_value
			equipment_bonus[stat_key] = bonus_value
			print("entity.gd: apply_equipment_bonuses: base_stats[%s] changed from %d to %d (bonus=%d)" % [stat_key, original_base, base_stats[stat_key], bonus_value])

			print("entity.gd: apply_equipment_bonuses: END - final base_stats=%s" % base_stats)

func clear_equipment_bonuses():
	"""
	Remove equipment bonuses from base_stats to revert to true base values.
	Called before re-applying bonuses or when unequipping items.
	"""
	print("entity.gd: clear_equipment_bonuses: START - name=%s, current_bonus=%s" % [name, equipment_bonus])

	# Subtract tracked bonuses from base_stats to revert to true base
	for stat_key in equipment_bonus:
		var bonus_value = equipment_bonus[stat_key]
		if base_stats.has(stat_key):
			var current_base = base_stats[stat_key]
			base_stats[stat_key] = current_base - bonus_value
			print("entity.gd: clear_equipment_bonuses: base_stats[%s] reverted from %d to %d" % [stat_key, current_base, base_stats[stat_key]])

	# Clear the tracking dictionary
	equipment_bonus.clear()
	print("entity.gd: clear_equipment_bonuses: END - base_stats=%s" % base_stats)
