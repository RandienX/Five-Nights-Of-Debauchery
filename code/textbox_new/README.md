# Simple Dialogue System for Godot 4.x

A lightweight, RPG Maker-style dialogue system focused on ease-of-use for designers while remaining powerful enough for programmers.

## Features

- **Data-driven**: All dialogue stored in Resources, editable in Inspector
- **Label-based navigation**: No error-prone indices, use human-readable labels
- **Built-in validation**: Catches typos and broken links before runtime
- **9 condition types**: Items, status, variables, random chance, quests
- **10 effect types**: Modify game state directly from dialogue
- **Custom script hooks**: Extend with your own GDScript when needed
- **Simple UI**: Typewriter effect, choices, auto-advance

## Quick Start

### 1. Create Dialogue Data

```gdscript
# In Inspector, create a new DialogueData resource
# Add nodes with labels like "start", "greeting", "end"
```

### 2. Setup Evaluator

```gdscript
# In your game manager or autoload:
var evaluator = DialogueConditionEvaluator.new()

# Connect to your game systems
evaluator.has_item_func = func(item_id: String, amount: int) -> bool:
    return inventory.has_item(item_id, amount)

evaluator.has_status_func = func(effect_id: String) -> bool:
    return player.has_status(effect_id)

evaluator.get_variable_func = func(var_name: String) -> float:
    return game_vars.get(var_name, 0)
```

### 3. Setup Runner & UI

```gdscript
# In your dialogue scene:
@export var dialogue_data: DialogueData
@export var ui: DialogueUI

var runner = DialogueRunner.new()

func _ready():
    add_child(runner)
    ui.connect_to_runner(runner)
    
    # Configure evaluator (or use shared one from autoload)
    var evaluator = DialogueConditionEvaluator.new()
    # ... set up evaluator hooks ...
    
    runner.start(dialogue_data, evaluator)
```

### 4. Control Flow

```gdscript
# Player clicks "next" or presses Enter/Space
runner.advance()

# Player selects a choice
runner.select_choice(choice)
```

## Resource Structure

### DialogueData
Main container holding all nodes and settings.

| Property | Type | Description |
|----------|------|-------------|
| title | String | Display name |
| nodes | Array[DialogueNode] | All dialogue entries |
| start_label | String | Entry point label |

### DialogueNode
Single dialogue entry.

| Property | Type | Description |
|----------|------|-------------|
| label | String | Unique identifier |
| text | String | Dialogue text |
| speaker | String | Character name |
| portrait | Texture2D | Character portrait |
| next_label | String | Where to go next |
| branches | Array[DialogueBranch] | Conditional jumps |
| choices | Array[DialogueChoice] | Player options |
| on_enter_effects | Array[DialogueEffect] | Effects when entering |
| on_exit_effects | Array[DialogueEffect] | Effects when leaving |

### DialogueBranch
Conditional branch evaluated in order.

**Condition Types:**
- `Has Item` - Check inventory
- `Has Status` - Check buff/debuff
- `Var Equals/Less/Greater` - Compare variables
- `Random Chance` - RNG check (0-100%)
- `Quest Complete/Active` - Quest state
- `Custom` - Your own logic

### DialogueChoice
Player selection option.

| Property | Type | Description |
|----------|------|-------------|
| text | String | Button text |
| always_available | bool | Show always? |
| availability_branch | DialogueBranch | Conditional visibility |
| target_label | String | Where choice leads |

### DialogueEffect
Modify game state from dialogue.

**Effect Types:**
- `Set Variable` - Change game variable
- `Add/Remove Item` - Modify inventory
- `Add/Remove Status` - Apply/remove effects
- `Start/Complete Quest` - Quest management
- `Trigger Event` - Fire custom signal
- `Wait` - Pause briefly
- `Custom` - Your own logic

## Custom Scripts

### Custom Condition
```gdscript
# res://conditions/is_daytime.gd
static func evaluate(branch: DialogueBranch, evaluator: DialogueConditionEvaluator) -> bool:
    return GameTime.is_night() == false
```

### Custom Effect
```gdscript
# res://effects/play_sound.gd
static func apply(effect: DialogueEffect, runner: DialogueRunner):
    var sound = load(effect.param_string)
    AudioServer.play_sound(sound)
```

## Best Practices

1. **Use descriptive labels**: `"village_elder_greeting"` not `"node1"`
2. **Validate before play**: Call `data.validate()` in editor or on load
3. **Keep nodes focused**: One idea per node
4. **Test branches**: Ensure all conditions have fallback paths
5. **Reuse evaluator**: Share one evaluator across dialogues

## Signals

### DialogueRunner
- `dialogue_started(data)`
- `node_entered(node)`
- `text_displayed(text)`
- `choice_available(choice)`
- `choice_selected(choice)`
- `dialogue_ended(last_node)`

## Files

```
textbox_new/
├── DialogueData.gd           # Main data container
├── DialogueNode.gd           # Individual entries
├── DialogueBranch.gd         # Conditions
├── DialogueChoice.gd         # Player options
├── DialogueEffect.gd         # State modifiers
├── DialogueConditionEvaluator.gd  # Condition logic
├── DialogueRunner.gd         # Flow controller
├── DialogueUI.gd             # Built-in UI
└── README.md                 # This file
```

## Migration from Old System

The old system used parallel arrays and index-based navigation. The new system:

- Uses explicit `label` strings instead of array indices
- Bundles all node data in `DialogueNode` resources
- Validates references at load time
- Provides clear Inspector organization with export groups

No more typos causing silent failures!
