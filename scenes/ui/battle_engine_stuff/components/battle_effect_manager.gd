extends Node
class_name EffectManager

## Centralized battle effect resolver with targeting, condition evaluation,
## stat modification, and status system pipelines.
## No _process polling - uses SceneTree timers for duration/tick effects.

# ==================== SIGNALS ====================

signal effect_executed(effect: BattleEffect, targets: Array, success: bool)
signal status_applied(entity: Entity, status_id: String, stacks: int)
signal status_removed(entity: Entity, status_id: String)
signal status_ticked(entity: Entity, status_id: String, remaining: int)
signal modifier_expired(entity: Entity, modifier_id: String)
signal stat_modification_applied(entity: Entity, stat_key: String, delta: int)

# ==================== CONFIGURATION ====================

@export var debug_logging: bool = false
@export var auto_cleanup_on_battle_end: bool = true

# ==================== STATE ====================

## Battle context arrays (set when battle starts)
var _allies: Array = []
var _enemies: Array = []
var _battle_context: Dictionary = {}

## Active timers for cleanup
var _active_timers: Array[Timer] = []

## Status registry lookup (set this to your status definition storage)
var status_registry: Dictionary[String, StatusDefinition] = {}

## Effect execution queue for proper sequencing
var _effect_queue: Array[Dictionary] = []

# ==================== LIFECYCLE ====================

func initialize(party: Array, enemies: Array, context: Dictionary = {}):
	"""
	Initialize the manager for a new battle.
	Call at battle start to set up context arrays.
	"""
	print("battle_effect_manager.gd: initialize: starting initialization")
	_allies = party.filter(func(e): return e != null and is_instance_valid(e))
	_enemies = enemies.filter(func(e): return e != null and is_instance_valid(e))
	_battle_context = context.duplicate()
	_battle_context["turn_number"] = _battle_context.get("turn_number", 0)
	
	print("battle_effect_manager.gd: initialize: allies_count=%d, enemies_count=%d, turn_number=%d" % [_allies.size(), _enemies.size(), _battle_context["turn_number"]])
	_log("BattleEffectManager initialized with %d allies, %d enemies" % [_allies.size(), _enemies.size()])

func cleanup():
	"""
	Clean up all resources, disconnect timers, clear references.
	Call at battle end or when manager is no longer needed.
	"""
	# Stop and clear all timers
	for timer in _active_timers:
		if is_instance_valid(timer):
			timer.stop()
			timer.queue_free()
	_active_timers.clear()
	
	# Clear context
	_allies.clear()
	_enemies.clear()
	_battle_context.clear()
	_effect_queue.clear()
	
	_log("BattleEffectManager cleaned up")

func _exit_tree():
	cleanup()

# ==================== TARGETING SYSTEM ====================

func resolve_targets(effect: BattleEffect, source: Entity, context_override: Dictionary = {}) -> Array[Entity]:
	"""
	Resolve TargetType to actual Entity instances using battle context.
	Returns array of valid targets.
	"""
	print("battle_effect_manager.gd: resolve_targets: resolving targets for effect=%s, source=%s, target_type=%d" % [effect.effect_name if effect else "null", source.name if source else "null", effect.target_type])
	var ctx = context_override if not context_override.is_empty() else _battle_context
	var targets: Array[Entity] = []
	
	match effect.target_type:
		BattleEffect.TargetType.SELF:
			targets.append(source)
			print("battle_effect_manager.gd: resolve_targets: SELF target: %s" % source.name)
		
		BattleEffect.TargetType.SINGLE_ALLY:
			if ctx.has("selected_ally") and ctx["selected_ally"]:
				targets.append(ctx["selected_ally"])
				print("battle_effect_manager.gd: resolve_targets: SINGLE_ALLY (selected): %s" % ctx["selected_ally"].name)
			elif not _allies.is_empty():
				# Pick random alive ally
				var alive_allies = _allies.filter(func(e): return e.hp > 0)
				if not alive_allies.is_empty():
					targets.append(alive_allies[randi() % alive_allies.size()])
					print("battle_effect_manager.gd: resolve_targets: SINGLE_ALLY (random alive): %s" % targets[0].name)
		
		BattleEffect.TargetType.SINGLE_ENEMY:
			if ctx.has("selected_enemy") and ctx["selected_enemy"]:
				targets.append(ctx["selected_enemy"])
				print("battle_effect_manager.gd: resolve_targets: SINGLE_ENEMY (selected): %s" % ctx["selected_enemy"].name)
			elif not _enemies.is_empty():
				# Pick random alive enemy
				var alive_enemies = _enemies.filter(func(e): return e.hp > 0)
				if not alive_enemies.is_empty():
					targets.append(alive_enemies[randi() % alive_enemies.size()])
					print("battle_effect_manager.gd: resolve_targets: SINGLE_ENEMY (random alive): %s" % targets[0].name)
		
		BattleEffect.TargetType.ALL_ALLIES:
			targets.assign(_allies.filter(func(e): return e.hp > 0 or effect.can_target_dead))
			print("battle_effect_manager.gd: resolve_targets: ALL_ALLIES: count=%d" % targets.size())
		
		BattleEffect.TargetType.ALL_ENEMIES:
			targets.assign(_enemies.filter(func(e): return e.hp > 0 or effect.can_target_dead))
			print("battle_effect_manager.gd: resolve_targets: ALL_ENEMIES: count=%d" % targets.size())
		
		BattleEffect.TargetType.PARTY:
			for ally in _allies:
				if ally.role == Entity.Role.PARTY and (ally.hp > 0 or effect.can_target_dead):
					targets.append(ally)
			print("battle_effect_manager.gd: resolve_targets: PARTY: count=%d" % targets.size())
		
		BattleEffect.TargetType.ENTIRE_BATTLE:
			targets.assign(_allies.filter(func(e): return e.hp > 0 or effect.can_target_dead))
			targets.append_array(_enemies.filter(func(e): return e.hp > 0 or effect.can_target_dead))
			print("battle_effect_manager.gd: resolve_targets: ENTIRE_BATTLE: count=%d" % targets.size())
	
	print("battle_effect_manager.gd: resolve_targets: final target count=%d" % targets.size())
	return targets

func _check_line_of_sight(source: Entity, target: Entity) -> bool:
	"""Check if source has line of sight to target. Override for custom logic."""
	# Default: always true. Override for grid-based or obstacle-based battles.
	return true

# ==================== CONDITION EVALUATION ====================

func evaluate_conditions(effect: BattleEffect, source: Entity, target: Entity, context_override: Dictionary) -> bool:
	"""
	Evaluate all conditions on an effect. Returns true only if ALL pass.
	Supports early-exit on first failure for performance.
	"""
	print("battle_effect_manager.gd: evaluate_conditions: evaluating conditions for effect=%s, source=%s, target=%s" % [effect.effect_name if effect else "null", source.name if source else "null", target.name if target else "null"])
	if effect == null:
		print("battle_effect_manager.gd: evaluate_conditions: effect is null, returning false")
		return false
	
	var ctx = context_override if not context_override.is_empty() else _battle_context
	
	for condition in effect.conditions:
		var result = condition.evaluate(target, ctx)
		print("battle_effect_manager.gd: evaluate_conditions: condition=%s, result=%s" % [condition.get_class() if condition.has_method("get_class") else "unknown", result])
		if not result:
			_log("Condition failed: %s on %s" % [condition.check_stat, target.name])
			print("battle_effect_manager.gd: evaluate_conditions: condition failed, returning false")
			return false
	
	# Additional legacy-style checks for backward compatibility
	if _battle_context.has("turn_number"):
		var turn = _battle_context["turn_number"]
		print("battle_effect_manager.gd: evaluate_conditions: turn_number check: turn=%d" % turn)
		# Could add turn-based conditions here if needed
	
	print("battle_effect_manager.gd: evaluate_conditions: all conditions passed, returning true")
	return true

# ==================== EFFECT EXECUTION PIPELINE ====================

func execute_effect(effect: BattleEffect, source: Entity, context_override: Dictionary = {}, delay_seconds: float = 0.0) -> void:
	"""
	Execute a single effect with optional delay.
	Handles targeting, conditions, and effect type resolution.
	"""
	print("battle_effect_manager.gd: execute_effect: START - effect=%s, source=%s, delay=%f" % [effect.effect_name if effect else "null", source.name if source else "null", delay_seconds])
	
	if effect == null:
		print("battle_effect_manager.gd: evaluate_conditions: effect is null, returning false")
		return
	
	if delay_seconds > 0:
		print("battle_effect_manager.gd: execute_effect: scheduling delayed execution")
		_schedule_effect(effect, source, context_override, delay_seconds)
		return
	
	# Check conditions first
	if not evaluate_conditions(effect, source, source, context_override):
		_log("Effect %s blocked by conditions" % effect.effect_name)
		print("battle_effect_manager.gd: execute_effect: effect blocked by conditions, emitting failure signal")
		effect_executed.emit(effect, [], false)
		return
	
	# Resolve targets
	var targets = resolve_targets(effect, source, context_override)
	if targets.is_empty():
		_log("Effect %s has no valid targets" % effect.effect_name)
		print("battle_effect_manager.gd: execute_effect: no valid targets, emitting failure signal")
		effect_executed.emit(effect, [], false)
		return
	
	# Execute based on effect type
	print("battle_effect_manager.gd: execute_effect: executing effect by type")
	var success = _execute_effect_by_type(effect, source, targets, context_override)
	
	print("battle_effect_manager.gd: execute_effect: END - success=%s, target_count=%d" % ["true" if success else "false", targets.size()])
	effect_executed.emit(effect, targets, success)

func _execute_effect_by_type(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Route effect to appropriate handler based on type."""
	print("battle_effect_manager.gd: _execute_effect_by_type: routing effect=%s, type=%d, target_count=%d" % [effect.effect_name if effect else "null", effect.effect_type, targets.size()])
	
	match effect.effect_type:
		BattleEffect.EffectType.DAMAGE:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling DAMAGE")
			return _handle_damage(effect, source, targets, context)
		
		BattleEffect.EffectType.HEAL:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling HEAL")
			return _handle_heal(effect, source, targets, context)
		
		BattleEffect.EffectType.BUFF, BattleEffect.EffectType.DEBUFF:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling BUFF/DEBUFF")
			return _handle_stat_modifiers(effect, source, targets, context)
		
		BattleEffect.EffectType.STATUS_APPLY:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling STATUS_APPLY")
			return _handle_status_apply(effect, source, targets, context)
		
		BattleEffect.EffectType.STATUS_REMOVE:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling STATUS_REMOVE")
			return _handle_status_remove(effect, source, targets, context)
		
		BattleEffect.EffectType.PARAMETER_CHANGE:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling PARAMETER_CHANGE")
			return _handle_parameter_change(effect, source, targets, context)
		
		BattleEffect.EffectType.UTILITY:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling UTILITY")
			return _handle_utility(effect, source, targets, context)
		
		BattleEffect.EffectType.CUSTOM:
			print("battle_effect_manager.gd: _execute_effect_by_type: handling CUSTOM")
			return _handle_custom(effect, source, targets, context)
	
	print("battle_effect_manager.gd: _execute_effect_by_type: unknown effect type, returning false")
	return false

func _handle_damage(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Handle damage effects with variance and critical support."""
	print("battle_effect_manager.gd: _handle_damage: START - effect=%s, source=%s, target_count=%d" % [effect.effect_name if effect else "null", source.name if source else "null", targets.size()])
	var total_damage = 0
	
	for target in targets:
		if not is_instance_valid(target) or target.hp <= 0:
			print("battle_effect_manager.gd: _handle_damage: skipping invalid/dead target: %s" % (target.name if target else "null"))
			continue
		
		# Calculate base damage
		var base_dmg = effect.get_scaled_value(source, target)
		print("battle_effect_manager.gd: _handle_damage: target=%s, base_dmg=%f" % [target.name, base_dmg])
		
		# Apply variance
		if effect.variance_percent > 0:
			var variance = randf_range(-effect.variance_percent, effect.variance_percent)
			base_dmg *= (1.0 + variance)
			print("battle_effect_manager.gd: _handle_damage: applied variance=%f, new_dmg=%f" % [variance, base_dmg])
		
		# Check for critical hit (could be expanded)
		var is_critical = false  # Could add crit logic here
		if is_critical:
			base_dmg *= effect.critical_multiplier
			print("battle_effect_manager.gd: _handle_damage: critical hit! dmg=%f" % base_dmg)
		
		# Apply defense reduction (simplified)
		var defense = target.get_effective_stat(&"def")
		var final_dmg = max(1, int(base_dmg - defense * 0.5))
		print("battle_effect_manager.gd: _handle_damage: target_def=%d, final_dmg=%d" % [defense, final_dmg])
		
		# Deal damage
		target.damage_hp(final_dmg)
		total_damage += final_dmg
		
		_log("Dealt %d damage to %s" % [final_dmg, target.name])
		print("battle_effect_manager.gd: _handle_damage: dealt damage, target_now_hp=%d" % target.hp)
		
		# Visual feedback
		_trigger_visuals(effect, target)
	
	print("battle_effect_manager.gd: _handle_damage: END - total_damage=%d" % total_damage)
	return total_damage > 0

func _handle_heal(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Handle healing effects."""
	print("battle_effect_manager.gd: _handle_heal: START - effect=%s, source=%s, target_count=%d" % [effect.effect_name if effect else "null", source.name if source else "null", targets.size()])
	var total_healed = 0
	
	for target in targets:
		if not is_instance_valid(target) or target.hp <= 0:
			print("battle_effect_manager.gd: _handle_heal: skipping invalid/dead target: %s" % (target.name if target else "null"))
			continue
		
		var heal_amount = int(effect.get_scaled_value(source, target))
		print("battle_effect_manager.gd: _handle_heal: target=%s, heal_amount=%d" % [target.name, heal_amount])
		var actual_heal = target.heal_hp(heal_amount)
		total_healed += actual_heal
		
		_log("Healed %s for %d HP" % [target.name, actual_heal])
		print("battle_effect_manager.gd: _handle_heal: target_now_hp=%d" % target.hp)
		_trigger_visuals(effect, target)
	
	print("battle_effect_manager.gd: _handle_heal: END - total_healed=%d" % total_healed)
	return total_healed > 0

func _handle_stat_modifiers(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Apply temporary stat buffs/debuffs."""
	var applied_count = 0
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		for mod in effect.stat_modifiers:
			var mod_id = "effect_%s_%s" % [effect.effect_id.strip_edges(), mod.stat_key]
			if target.apply_modifier(mod_id, mod, source):
				applied_count += 1
				stat_modification_applied.emit(
					target, 
					mod.stat_key, 
					int(mod.applied_delta)
				)
				_log("Applied modifier %s to %s" % [mod_id, target.name])
	
	return applied_count > 0

func _handle_status_apply(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Apply status effects from status_ref definition."""
	if not effect.status_ref:
		push_warning("BattleEffect %s has STATUS_APPLY but no status_ref" % effect.effect_name)
		return false
	
	var applied_count = 0
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# Check resistance
		var apply_chance = effect.status_apply_chance
		
		if randf() * 100 > apply_chance:
			_log("Status %s resisted by %s" % [effect.status_ref.id, target.name])
			continue
		
		# Apply status
		var duration = effect.status_duration_override if effect.status_duration_override > 0 else -1
		if target.apply_status(effect.status_ref, 1, duration, source):
			applied_count += 1
			status_applied.emit(target, effect.status_ref.id, 1)
			_log("Applied status %s to %s" % [effect.status_ref.id, target.name])
	
	return applied_count > 0

func _handle_status_remove(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Remove status effects."""
	var removed_count = 0
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		if effect.status_ref:
			# Remove specific status
			if target.remove_status(effect.status_ref.id, source):
				removed_count += 1
				status_removed.emit(target, effect.status_ref.id)
		else:
			# Remove all removable statuses
			removed_count += target.remove_all_statuses(true, source)
	
	return removed_count > 0

func _handle_parameter_change(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Permanent stat changes (level-up style)."""
	var changed_count = 0
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		for mod in effect.stat_modifiers:
			if mod.duration_type == StatModifier.DurationType.PERMANENT:
				var stat_key = mod.stat_key.to_lower()
				if target.base_stats.has(stat_key):
					target.base_stats[stat_key] += int(mod.value)
					target.invalidate_stat_cache()
					changed_count += 1
					_log("Permanently increased %s to %d" % [stat_key, target.base_stats[stat_key]])
	
	return changed_count > 0

func _handle_utility(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Utility effects: skip turn, extra turn, etc."""
	var applied_count = 0
	
	for target in targets:
		if not is_instance_valid(target):
			continue
		
		# Check custom_data for utility type
		var util_type = effect.custom_data.get("type", "")
		
		match util_type:
			"skip_turn":
				target.skip_turn = true
				applied_count += 1
			"extra_turn":
				target.extra_turn = true
				applied_count += 1
			"defend":
				target.is_defending = true
				applied_count += 1
			_:
				# Default behavior based on effect_id
				if "skip" in effect.effect_id.to_lower():
					target.skip_turn = true
					applied_count += 1
				elif "extra" in effect.effect_id.to_lower():
					target.extra_turn = true
					applied_count += 1
	
	return applied_count > 0

func _handle_custom(effect: BattleEffect, source: Entity, targets: Array[Entity], context: Dictionary) -> bool:
	"""Run custom script for complex effects."""
	if effect.custom_script_path == "":
		return false
	
	var script = load(effect.custom_script_path)
	if not script:
		push_warning("Failed to load custom script: %s" % effect.custom_script_path)
		return false
	
	var executed = false
	for target in targets:
		if script.has_method("execute"):
			script.execute(source, target, context)
			executed = true
	
	return executed

func _trigger_visuals(effect: BattleEffect, target: Entity):
	"""Trigger visual/audio feedback for an effect."""
	# This would integrate with your battle UI system
	# For now, just emit a signal that UI can listen to
	pass

# ==================== TIMING SYSTEM ====================

func execute_effects_at_timing(effects: Array[BattleEffect], source: Entity, timing: BattleEffect.Timing, context: Dictionary = {}) -> void:
	"""
	Execute all effects matching the specified timing.
	Call from battle loop at appropriate phases.
	"""
	for effect in effects:
		if effect.timing == timing:
			execute_effect(effect, source, context)

func schedule_effect_tick(effect: BattleEffect, source: Entity, targets: Array[Entity], interval_seconds: float, repeat_count: int = -1) -> Timer:
	"""
	Schedule a repeating effect using SceneTree timer (no _process polling).
	Use repeat_count = -1 for infinite (must manually stop).
	Returns the Timer for manual control.
	"""
	var timer = Timer.new()
	timer.wait_time = interval_seconds
	timer.autostart = true
	timer.one_shot = false
	
	var ticks_remaining = repeat_count
	var timer_callback = func():
		if ticks_remaining != 0:
			for target in targets:
				if is_instance_valid(target):
					_execute_effect_by_type(effect, source, [target], {})
			
			if ticks_remaining > 0:
				ticks_remaining -= 1
			
			if ticks_remaining == 0:
				timer.stop()
				_active_timers.erase(timer)
				timer.queue_free()
	
	timer.timeout.connect(timer_callback)
	add_child(timer)
	_active_timers.append(timer)
	
	return timer

func _schedule_effect(effect: BattleEffect, source: Entity, context: Dictionary, delay_seconds: float):
	"""Schedule a single delayed effect execution."""
	var timer = Timer.new()
	timer.wait_time = delay_seconds
	timer.one_shot = true
	
	timer.timeout.connect(func():
		execute_effect(effect, source, context)
		if is_instance_valid(timer):
			timer.queue_free()
			_active_timers.erase(timer)
	)
	
	add_child(timer)
	_active_timers.append(timer)

# ==================== STATUS TICKING ====================

func tick_all_statuses():
	"""
	Tick all statuses on all entities.
	Call once per turn during battle loop.
	"""
	for entity in _allies + _enemies:
		if not is_instance_valid(entity):
			continue
		
		# Tick statuses
		var expired = entity.tick_statuses()
		for status_id in expired:
			status_removed.emit(entity, status_id)
			_log("Status %s expired on %s" % [status_id, entity.name])
		
		# Tick modifiers
		var expired_mods = entity.tick_modifiers()
		for mod_id in expired_mods:
			modifier_expired.emit(entity, mod_id)
			

# ==================== UTILITY FUNCTIONS ====================

func get_battle_context() -> Dictionary:
	"""Get current battle context dictionary."""
	return _battle_context.duplicate()

func set_battle_context_value(key: String, value):
	"""Set a value in the battle context."""
	_battle_context[key] = value

func get_all_entities() -> Array[Entity]:
	"""Get all entities (allies + enemies)."""
	return _allies + _enemies

func get_alive_allies() -> Array[Entity]:
	"""Get all living allies."""
	return _allies.filter(func(e): return is_instance_valid(e) and e.hp > 0)

func get_alive_enemies() -> Array[Entity]:
	"""Get all living enemies."""
	return _enemies.filter(func(e): return is_instance_valid(e) and e.hp > 0)

func log_effect_execution(effect_name: String, success: bool):
	"""Log effect execution for debugging."""
	if debug_logging:
		print("[BattleEffect] %s: %s" % [effect_name, "SUCCESS" if success else "FAILED"])

func _log(message: String):
	"""Internal logging with debug toggle."""
	if debug_logging:
		print("[BattleEffectManager] ", message)

# ==================== SERIALIZATION HELPERS ====================

func serialize_entity_states(entities: Array[Entity]) -> Array[Dictionary]:
	"""Serialize all entity states for save system."""
	var result: Array[Dictionary] = []
	for entity in entities:
		if is_instance_valid(entity):
			result.append(entity.serialize_state())
	return result

func deserialize_entity_states(
	entities: Array[Entity], 
	data: Array[Dictionary]
) -> void:
	"""Restore entity states from save data."""
	for i in range(min(entities.size(), data.size())):
		if is_instance_valid(entities[i]):
			entities[i].deserialize_state(data[i])
