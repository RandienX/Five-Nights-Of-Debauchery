# Battle Effect System - Integration Guide

## Overview

This is a complete rewrite of the battle effect/status system with:
- **Data-driven architecture** using `BattleEffect` resources
- **Decoupled entity state** in `Entity` resource
- **Centralized resolution** in `BattleEffectManager`
- **Persistent statuses** that survive outside battle
- **JSON-compatible serialization** for save/load

---

## 1. File Structure

```
code/battle/
├── battle_effect.gd      # Effect resource with sub-resources
└── entity.gd             # Entity with stat/status tracking

scenes/ui/battle_engine_stuff/components/
└── battle_effect_manager.gd  # Centralized effect resolver
```

---

## 2. Core Components

### BattleEffect.gd

Three main sub-resources:

#### ConditionRule
Checks if an effect should trigger.
```gdscript
var condition = BattleEffect.ConditionRule.new()
condition.check_stat = "hp_percent"
condition.operator = BattleEffect.Operator.LESS_THAN
condition.threshold_value = 50.0  # Trigger when HP < 50%
```

#### StatModifier
Temporary or permanent stat changes.
```gdscript
var modifier = BattleEffect.StatModifier.new()
modifier.stat_key = "atk"
modifier.value = 25.0
modifier.stacking_rule = BattleEffect.StatModifier.StackingRule.ADDITIVE
modifier.duration_type = BattleEffect.StatModifier.DurationType.TURNS
modifier.duration_turns = 3
```

#### StatusDefinition
Reusable status effect definitions.
```gdscript
var poison_status = BattleEffect.StatusDefinition.new()
poison_status.id = "poison"
poison_status.name = "Poison"
poison_status.is_positive = false
poison_status.duration_type = BattleEffect.StatusDefinition.DurationType.TURNS
poison_status.duration_value = 4
poison_status.persists_outside_battle = false
```

### Entity.gd

Key APIs:
- `get_effective_stat(stat_key)` - Get stat after modifiers
- `apply_modifier(modifier_id, modifier, source)` - Apply buff/debuff
- `apply_status(status_def, stacks, duration, source)` - Apply status
- `remove_status(status_id, source)` - Remove status
- `tick_statuses()` / `tick_modifiers()` - Decrement durations
- `serialize_state()` / `deserialize_state(data)` - Save/load

### BattleEffectManager.gd

Key APIs:
- `initialize(allies, enemies, context)` - Setup for battle
- `execute_effect(effect, source, context, delay)` - Run effect
- `execute_effects_at_timing(effects, source, timing, context)` - Batch execute
- `tick_all_statuses()` - Call once per turn
- `cleanup()` - End of battle cleanup

---

## 3. Integration Steps

### Step 1: Create Status Definitions

Create a resource or autoload to hold your status definitions:

```gdscript
# status_registry.gd
extends Node

var registry: Dictionary[String, BattleEffect.StatusDefinition] = {}

func _ready():
    # Register all statuses
    register_status(create_poison())
    register_status(create_power_buff())
    # ... etc

func register_status(status: BattleEffect.StatusDefinition):
    registry[status.id] = status

func create_poison() -> BattleEffect.StatusDefinition:
    var status = BattleEffect.StatusDefinition.new()
    status.id = "poison"
    status.name = "Poison"
    status.description = "Takes damage each turn"
    status.duration_type = BattleEffect.StatusDefinition.DurationType.TURNS
    status.duration_value = 4
    status.persists_outside_battle = false
    
    # Add damage-over-time modifier
    var dot_mod = BattleEffect.StatModifier.new()
    dot_mod.stat_key = "hp"
    dot_mod.value = -10.0
    dot_mod.duration_type = BattleEffect.StatModifier.DurationType.INSTANT
    status.stat_modifiers.append(dot_mod)
    
    return status
```

### Step 2: Wire Into Battle Flow

In your battle engine/main scene:

```gdscript
# battle_engine.gd
extends Node

@export var effect_manager: BattleEffectManager
var allies: Array[Entity] = []
var enemies: Array[Entity] = []
var turn_number: int = 0

func _ready():
    # Initialize manager
    effect_manager.initialize(allies, enemies, {
        "turn_number": 0,
        "battle_root": self
    })
    
    # Connect signals for UI updates
    effect_manager.status_applied.connect(_on_status_applied)
    effect_manager.status_removed.connect(_on_status_removed)

func start_battle():
    # Spawn entities
    allies = [create_party_member(), ...]
    enemies = [create_enemy(), ...]
    
    # Execute spawn effects
    for ally in allies:
        effect_manager.execute_effects_at_timing(
            ally.effects_on_spawn, 
            ally, 
            BattleEffect.Timing.ON_CAST
        )

func on_turn_start(entity: Entity):
    # Execute turn-start effects
    effect_manager.execute_effects_at_timing(
        entity.passive_effects,
        entity,
        BattleEffect.Timing.ON_TURN_START
    )
    
    # Tick all statuses
    effect_manager.tick_all_statuses()

func on_turn_end(entity: Entity):
    # Execute turn-end effects
    effect_manager.execute_effects_at_timing(
        entity.passive_effects,
        entity,
        BattleEffect.Timing.ON_TURN_END
    )
    
    turn_number += 1
    effect_manager.set_battle_context_value("turn_number", turn_number)

func end_battle():
    # Cleanup battle-only effects
    for entity in allies + enemies:
        entity.cleanup_battle_end(persist_statuses=true)
    
    effect_manager.cleanup()
```

### Step 3: Hook Into Skill/Attack System

```gdscript
# battle_attack_executor.gd or similar
extends Node

@export var effect_manager: BattleEffectManager

func execute_attack(attacker: Entity, defender: Entity, skill: Skill):
    # Execute ON_HIT effects
    for effect in skill.on_hit_effects:
        effect_manager.execute_effect(effect, attacker, {
            "defender": defender
        })
    
    # Execute ON_USE effects (if not already done)
    for effect in skill.on_use_effects:
        if effect.timing == BattleEffect.Timing.ON_HIT:
            effect_manager.execute_effect(effect, attacker, {
                "defender": defender
            })
```

### Step 4: Integrate With Save System

```gdscript
# save_manager.gd
extends Node

func save_game(filename: String):
    var save_data = {}
    
    # Serialize party
    var party_data = []
    for member in PlayerStats.party_members:
        party_data.append(member.serialize_state())
    save_data["party"] = party_data
    
    # Write JSON
    var file = FileAccess.open(filename, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data, "  "))
    file.close()

func load_game(filename: String):
    var file = FileAccess.open(filename, FileAccess.READ)
    var json = JSON.parse_string(file.get_as_text())
    file.close()
    
    # Deserialize party
    for i in range(json["party"].size()):
        if i < PlayerStats.party_members.size():
            PlayerStats.party_members[i].deserialize_state(json["party"][i])
```

---

## 4. Usage Examples

### Example 1: Damage Over Time (Poison)

```gdscript
# Create poison status definition
var poison = BattleEffect.StatusDefinition.new()
poison.id = "poison"
poison.name = "Poison"
poison.duration_type = BattleEffect.StatusDefinition.DurationType.TURNS
poison.duration_value = 4
poison.persists_outside_battle = false

# Create tick callback for DoT
poison.tick_callback = "_on_poison_tick"

# In your script that applies it:
func _on_poison_tick(status_instance: Dictionary, source: Entity):
    var target = status_instance.get("target")  # You'd need to store this
    if target:
        var dmg = floor(target.max_stats["hp"] * 0.1 * status_instance.stacks)
        target.damage_hp(dmg)

# Or simpler: use StatModifier with INSTANT duration
var dot_mod = BattleEffect.StatModifier.new()
dot_mod.stat_key = "hp"
dot_mod.value = -10.0  # Flat damage per tick
dot_mod.duration_type = BattleEffect.StatModifier.DurationType.INSTANT
poison.stat_modifiers.append(dot_mod)

# Apply via BattleEffect
var poison_effect = BattleEffect.new()
poison_effect.effect_type = BattleEffect.EffectType.STATUS_APPLY
poison_effect.target_type = BattleEffect.TargetType.SINGLE_ENEMY
poison_effect.status_ref = poison
poison_effect.status_apply_chance = 80.0

effect_manager.execute_effect(poison_effect, attacker)
```

### Example 2: Conditional Heal (Heal When HP < 30%)

```gdscript
var conditional_heal = BattleEffect.new()
conditional_heal.effect_id = "emergency_heal"
conditional_heal.effect_type = BattleEffect.EffectType.HEAL
conditional_heal.target_type = BattleEffect.TargetType.SELF
conditional_heal.base_value = 50.0
conditional_heal.scaling_type = BattleEffect.ScalingType.FLAT

# Add condition: only trigger if HP < 30%
var condition = BattleEffect.ConditionRule.new()
condition.check_stat = "hp_percent"
condition.operator = BattleEffect.Operator.LESS_THAN
condition.threshold_value = 30.0
conditional_heal.conditions.append(condition)

# Set timing to trigger at turn start
conditional_heal.timing = BattleEffect.Timing.ON_TURN_START

# Add to entity's passive effects
entity.passive_effects.append(conditional_heal)
```

### Example 3: Stat Buff With Stacking (Power Up, max 5 stacks)

```gdscript
# Create status definition
var power_buff = BattleEffect.StatusDefinition.new()
power_buff.id = "power_up"
power_buff.name = "Power Up"
power_buff.is_positive = true
power_buff.duration_type = BattleEffect.StatusDefinition.DurationType.TURNS
power_buff.duration_value = 3
power_buff.stacking_rule = BattleEffect.StatModifier.StackingRule.CAPPED
power_buff.max_stacks = 5

# Add attack bonus modifier
var atk_mod = BattleEffect.StatModifier.new()
atk_mod.stat_key = "atk"
atk_mod.value = 5.0  # +5 ATK per stack
atk_mod.stacking_rule = BattleEffect.StatModifier.StackingRule.ADDITIVE
atk_mod.duration_type = BattleEffect.StatModifier.DurationType.TURNS
atk_mod.duration_turns = 3
power_buff.stat_modifiers.append(atk_mod)

# Register in status registry
status_registry.register_status(power_buff)

# Apply via effect
var buff_effect = BattleEffect.new()
buff_effect.effect_type = BattleEffect.EffectType.STATUS_APPLY
buff_effect.target_type = BattleEffect.TargetType.SELF
buff_effect.status_ref = power_buff
buff_effect.timing = BattleEffect.Timing.ON_USE

effect_manager.execute_effect(buff_effect, entity)
```

### Example 4: Persistent Exploration Debuff

```gdscript
# Cursed status that persists outside battle
var cursed = BattleEffect.StatusDefinition.new()
cursed.id = "curse"
cursed.name = "Curse"
cursed.description = "All stats reduced until cured"
cursed.is_positive = false
cursed.duration_type = BattleEffect.StatusDefinition.DurationType.PERMANENT
cursed.persists_outside_battle = true  # Key flag!
cursed.can_be_removed = true  # Can be removed by items/healing

# Add stat reduction modifiers
for stat in ["atk", "def", "speed", "magic"]:
    var mod = BattleEffect.StatModifier.new()
    mod.stat_key = stat
    mod.value = -20.0  # -20% to all stats
    mod.scaling_type = BattleEffect.ScalingType.PERCENT_BASE
    mod.duration_type = BattleEffect.StatModifier.DurationType.PERMANENT
    cursed.stat_modifiers.append(mod)

# Apply to entity
entity.apply_status(cursed, 1, -1)

# This will persist through battle end and into exploration
# Save system will serialize it automatically
```

### Example 5: Complex Multi-Target Debuff With Resistance

```gdscript
var weaken_all = BattleEffect.new()
weaken_all.effect_id = "mass_weaken"
weaken_all.effect_name = "Mass Weaken"
weaken_all.effect_type = BattleEffect.EffectType.STATUS_APPLY
weaken_all.target_type = BattleEffect.TargetType.ALL_ENEMIES
weaken_all.timing = BattleEffect.Timing.ON_HIT

# Create weaken status
var weaken = BattleEffect.StatusDefinition.new()
weaken.id = "weaken"
weaken.name = "Weaken"
weaken.duration_value = 3

var atk_mod = BattleEffect.StatModifier.new()
atk_mod.stat_key = "atk"
atk_mod.value = -30.0
atk_mod.scaling_type = BattleEffect.ScalingType.PERCENT_BASE
weaken.stat_modifiers.append(atk_mod)

weaken_all.status_ref = weaken
weaken_all.status_apply_chance = 75.0  # Base 75% chance
weaken_all.status_resist_stat = "magic"  # Target's magic stat reduces chance

effect_manager.execute_effect(weaken_all, caster)
```

---

## 5. Edge Cases & Performance Notes

### Rapid Triggers
- Use `delay_seconds` parameter to space out rapid effect executions
- For repeating effects, use `schedule_effect_tick()` which returns a Timer you can control
- Always check `is_instance_valid(target)` before operating on entities

```gdscript
# Space out 5 damage instances over 2 seconds
for i in range(5):
    effect_manager.execute_effect(damage_effect, source, {}, i * 0.4)
```

### Missing Stats
- All stat access goes through `get_base_stat()` and `get_effective_stat()` which have safe defaults
- Unknown stat keys return 0 instead of crashing
- Use `StringName` for stat keys for performance (`&"atk"` not `"atk"`)

### Save Compatibility
- Only statuses with `persists_outside_battle = true` are saved
- Modifiers must have `duration_type = PERMANENT` to be serialized
- Equipment is saved as resource paths, not references
- Always call `serialize_state()` which handles StringName → String conversion

### Overlapping Effects
- Stacking rules prevent unintended behavior:
  - `NONE`: Second application ignored
  - `OVERRIDE`: New replaces old
  - `EXTEND`: Durations add, higher value kept
  - `REFRESH`: Duration resets, value unchanged
  - `ADDITIVE`: Values stack (watch for runaway numbers!)
  - `CAPPED`: Stack up to max_stacks

### Memory Safety
- `BattleEffectManager.cleanup()` disconnects all timers
- Always use `is_instance_valid()` before accessing entities
- Timers created by `schedule_effect_tick()` are tracked and cleaned up
- Entities hold no references to managers (prevents circular refs)

### Performance Optimizations
- Effective stats are cached; cache invalidates only when modifiers change
- Condition evaluation uses early-exit (stops on first failure)
- Target resolution filters dead entities upfront
- No `_process()` polling - all timing uses SceneTree timers

---

## 6. Migration From Old System

### Old → New Mapping

| Old System | New System |
|------------|------------|
| `Global.effect` enum | `BattleEffect.StatusDefinition` |
| `target.effects[effect] = [level, duration]` | `target.apply_status(status_def, stacks, duration)` |
| Manual duration ticking in battle loop | `entity.tick_statuses()` |
| `EffectManager.update_effects()` | `effect_manager.tick_all_statuses()` |
| Direct stat modification | `apply_modifier()` with proper stacking |

### Backward Compatibility

The new `Entity.gd` includes legacy property aliases:
- `effects` dict getter/setter (warns on use)
- `damage`, `max_hp`, `speed`, etc. properties
- `equip_stats_change()`, `get_effective_damage()`, etc.

Gradually migrate to new APIs:
```gdscript
# Old (still works but deprecated)
target.effects[BattleEffect.StatusEffect.Poison] = [2, 4]

# New (preferred)
var poison = status_registry.registry["poison"]
target.apply_status(poison, 2, 4)
```

---

## 7. Debugging

Enable debug logging:
```gdscript
effect_manager.debug_logging = true
```

Check active effects:
```gdscript
print("Statuses: ", entity.get_active_status_ids())
print("Modifiers: ", entity.get_active_modifier_ids())
print("Effective ATK: ", entity.get_effective_stat(&"atk"))
```

Verify serialization:
```gdscript
var data = entity.serialize_state()
print(JSON.stringify(data, "  "))
```
