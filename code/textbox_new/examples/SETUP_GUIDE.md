# Dialogue System - Quick Setup Guide

## Example: Area2D Trigger Setup

### 1. Create the Trigger Node

In your scene:
1. Add an `Area2D` node
2. Add a `CollisionShape2D` child to define the trigger zone
3. Attach the `DialogueTriggerArea2D.gd` script
4. Assign a `DialogueData` resource in the Inspector

### 2. Configure Player Reference (Optional)

If you want to disable player movement during dialogue:
- Set `Player Node Path` to your player character node
- Your player should have a `set_input_enabled(bool)` method

Example player method:
```gdscript
# In your Player.gd
func set_input_enabled(enabled: bool) -> void:
    can_move = enabled
```

### 3. Create Dialogue Data

Right-click in FileSystem → Create New → Resource → DialogueData

Add nodes with:
- **Speaker**: Character name
- **Text**: Dialogue content (supports BBCode)
- **Next Label**: Where to go next (leave empty for sequential)
- **Branches**: Conditional paths
- **Choices**: Player options
- **Effects**: Actions to run (give_item, set_flag, etc.)

### 4. Built-in Conditions

Available in DialogueBranch:
- `has_item` - Check inventory
- `has_status` - Check buffs/debuffs
- `variable_check` - Compare game variables
- `random_chance` - RNG branches
- `quest_state` - Quest progress checks
- `custom_condition` - Your own logic

### 5. Built-in Effects

Available in DialogueEffect:
- `give_item` / `remove_item` - Inventory management
- `set_variable` - Store game state
- `set_flag` - Boolean toggles
- `spawn_entity` - Create objects
- `play_sound` - Audio feedback
- `custom_effect` - Your own logic

## Minimal Example Dialogue

**Node 1: "start"**
```
Speaker: Old Wizard
Text: Welcome, traveler! Do you seek knowledge?
Choices:
  - "Yes, teach me!" → jump to "teach"
  - "No, I'm just passing through." → jump to "farewell"
```

**Node 2: "teach"**
```
Speaker: Old Wizard
Text: Very well! Here is a magic sword.
Effects: give_item("magic_sword", 1)
Next: END
```

**Node 3: "farewell"**
```
Speaker: Old Wizard
Text: Safe travels then!
Next: END
```

## Custom Logic

### Custom Condition
In DialogueBranch, set type to `custom_condition`:
```gdscript
# In your game's condition evaluator setup
evaluator.custom_conditions["player_is_night"] = func() -> bool:
    return GameTime.is_night()
```

### Custom Effect
In DialogueEffect, set type to `custom_effect`:
```gdscript
# In your game's effect handler
evaluator.custom_effects["heal_party"] = func(params: Dictionary) -> void:
    Party.heal_all(params.get("amount", 10))
```

## Signals Available

DialogueRunner emits:
- `dialogue_started()` - When dialogue begins
- `node_displayed(node)` - Each new line
- `choice_made(index)` - Player selected option
- `dialogue_ended()` - Conversation complete

Connect to these for custom behavior like camera changes, music, etc.
