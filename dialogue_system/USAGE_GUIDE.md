# Dialogue System - Usage Guide

## Quick Start

### 1. Create Dialogue Data

In Godot Editor:
1. Right-click in FileSystem → Create New → Resource
2. Select `DialogueData` class
3. Name it (e.g., `intro_dialogue.tres`)
4. In Inspector, add nodes to the `nodes` array

### 2. Set Up Your Scene

```gdscript
# Attach to a Node in your scene
extends Node

var dialogue_engine: DialogueEngine

func _ready() -> void:
    dialogue_engine = DialogueEngine.new()
    add_child(dialogue_engine)
    
    # Connect signals
    dialogue_engine.node_displayed.connect(_on_node_displayed)
    dialogue_engine.choices_available.connect(_on_choices_available)
    
    # Set up callbacks
    var callbacks = {
        "has_item_callback": Callable(self, "_check_has_item"),
        "get_variable_callback": Callable(self, "_get_variable"),
        "set_variable_callback": Callable(self, "_set_variable"),
    }
    
    # Start dialogue
    var data: DialogueData = load("res://dialogue_system/examples/intro_dialogue.tres")
    dialogue_engine.start(data, "", callbacks)

func _on_node_displayed(node: DialogueNodeData, index: int, data: DialogueData) -> void:
    print("%s: %s" % [node.speaker, node.text])
    # Update your UI here

func _on_choices_available(choices: Array) -> void:
    for i in range(choices.size()):
        print("[%d] %s" % [i, choices[i].text])
    # Create choice buttons in your UI

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        if dialogue_engine.get_is_waiting():
            dialogue_engine.next()
```

### 3. Basic API

```gdscript
# Start dialogue
engine.start(dialogue_data, entry_point, callbacks)

# Advance to next node
engine.next()

# Jump to specific node
engine.jump_to("label_name")  # or engine.jump_to("3")

# Select a choice
engine.select_choice(choice_index)

# Check state
engine.get_is_running()
engine.get_is_waiting()
engine.get_current_node()
```

---

## Creating Dialogue Data

### Node Types

**STANDARD** - Simple dialogue text
- Display text, wait for player to continue
- Next node is current_index + 1

**CHOICE** - Player selects from options
- Add choices with text and targets
- Each choice can have visibility conditions

**CONDITIONAL_BRANCH** - Automatic branching based on conditions
- Add branches with conditions and jump targets
- First true condition triggers its jump
- Last branch can define "on false" behavior

**JUMP** - Immediately jump to another node
- Set jump_target to index or label

**END** - Terminates dialogue

### Example Node Configuration

```
Node 0 (STANDARD):
  label: "greeting_start"
  speaker: "Merchant"
  text: "Welcome to my shop!"
  node_type: STANDARD

Node 1 (CONDITIONAL_BRANCH):
  speaker: "Merchant"
  text: "Looking for anything special?"
  node_type: CONDITIONAL_BRANCH
  branches: [
    {
      condition_id: "has_item",
      arguments: ["rare_gem", 1],
      jump_target: "special_deal",
      on_false_behavior: "NEXT"
    }
  ]

Node 2 (CHOICE):
  speaker: "Merchant"
  text: "What would you like?"
  node_type: CHOICE
  choices: [
    { text: "Show me weapons", target: "weapons_shop" },
    { text: "Leave", target: "farewell" }
  ]

Node 3 (JUMP):
  node_type: JUMP
  jump_target: "greeting_start"

Node 4 (END):
  speaker: "Merchant"
  text: "Come back soon!"
  node_type: END
```

---

## Built-in Conditions

### has_item
Check if player has an item.
```
condition_id: "has_item"
arguments: ["sword", 1]  # [item_id, amount]
```

### has_status_effect
Check if player has a status effect.
```
condition_id: "has_status_effect"
arguments: ["poisoned"]  # [effect_id]
```

### check_variable
Compare a variable to a value.
```
condition_id: "check_variable"
arguments: ["gold", ">=", 100]  # [var_name, operator, value]
# Operators: ==, !=, <, >, <=, >=
```

### random_chance
Random probability check.
```
condition_id: "random_chance"
arguments: [50.0]  # [percent 0-100]
```

---

## Built-in Actions

Actions are specified in `on_enter_actions` or `on_exit_actions` arrays.

Format: `"action_id:arg1:arg2:..."`

### Variable Actions
```
"set_variable:player_reputation:75"
"modify_variable:gold:50"  # Adds 50 to gold
```

### Item Actions
```
"give_item:potion:3"
"remove_item:key:1"
```

### Status Effect Actions
```
"add_status_effect:buff_strength:60.0"  # 60 second duration
"remove_status_effect:poisoned"
```

### Event Actions
```
"trigger_event:start_boss_fight"
"trigger_event:spawn_enemy:goblin:3"
```

### Debug Action
```
"debug_print:Player reached this point"
```

---

## Custom Conditions

Register custom conditions with `DialogueRegistry`:

```gdscript
# Define condition handler (must match signature)
func check_player_level(arguments: Array, context: Dictionary) -> bool:
    var min_level: int = int(arguments[0])
    var player_level: int = get_player_level()  # Your game's function
    return player_level >= min_level

# Register it
DialogueRegistry.register_condition("check_level", 
    Callable(self, "check_player_level"))

# Use in dialogue node branch:
# condition_id: "check_level"
# arguments: [5]  # Requires level 5+
```

---

## Custom Actions

```gdscript
# Define action handler
func play_music(arguments: Array, context: Dictionary) -> void:
    var music_name: String = str(arguments[0])
    $MusicPlayer.play_music(music_name)

# Register it
DialogueRegistry.register_action("play_music", 
    Callable(self, "play_music"))

# Use in node's on_enter_actions:
# on_enter_actions: ["play_music:tense_battle_theme"]
```

---

## Callbacks (Context)

Provide game-specific callbacks when starting dialogue:

```gdscript
var callbacks = {
    # Required for built-in conditions to work:
    "has_item_callback": Callable(self, "_check_has_item"),
    "has_status_effect_callback": Callable(self, "_check_status"),
    "get_variable_callback": Callable(self, "_get_var"),
    "set_variable_callback": Callable(self, "_set_var"),
    "give_item_callback": Callable(self, "_give_item"),
    "remove_item_callback": Callable(self, "_remove_item"),
    "add_status_effect_callback": Callable(self, "_add_effect"),
    "remove_status_effect_callback": Callable(self, "_remove_effect"),
    "trigger_event_callback": Callable(self, "_trigger_event"),
    
    # Optional: initial variables
    "variables": {
        "quest_active": true,
        "npc_friendship": 50,
    }
}

engine.start(dialogue_data, "", callbacks)
```

---

## Loop Protection

The engine tracks jump depth to prevent infinite loops:

```gdscript
# Default max is 100 jumps
engine.max_jump_depth = 100

# If exceeded, dialogue ends with error
# Reset counter manually for long dialogues:
engine.reset_jump_depth()
```

---

## Validation

DialogueData validates on load:

```gdscript
var is_valid: bool = dialogue_data.validate()
# Returns false and pushes errors if:
# - No nodes defined
# - Duplicate labels
# - Invalid jump targets
# - Malformed branches
```

Disable auto-validation:
```gdscript
engine.auto_validate = false
```

---

## Best Practices

### For Designers

1. **Use Labels**: Give important nodes labels for readable jump targets
   ```
   jump_target: "shop_intro"  # Better than "5"
   ```

2. **Test Branches**: Ensure at least one branch condition can be true
   - Use `random_chance` with fallback for probabilistic branches

3. **Organize with Tags**: Use tags for filtering/categorization
   ```
   tags: ["quest", "main_story", "merchant"]
   ```

4. **Entry Points**: Set `entry_point` for non-linear dialogue starts

### For Programmers

1. **Keep Callbacks Light**: Condition checks should be fast
   ```gdscript
   # Good: Simple lookup
   func _check_has_item(id, amount): return inventory.count(id) >= amount
   
   # Bad: Heavy computation
   func _check_has_item(id, amount): 
       recalculate_entire_inventory()  # Don't do this!
   ```

2. **Error Handling**: Always provide fallbacks in callbacks
   ```gdscript
   func _get_variable(name):
       if not game_vars.has(name):
           push_warning("Missing variable: %s" % name)
           return null
       return game_vars[name]
   ```

3. **Debug Mode**: Enable during development
   ```gdscript
   engine.debug_mode = true  # Verbose logging
   ```

4. **Memory Management**: Clear callbacks on scene exit
   ```gdscript
   func _exit_tree():
       DialogueRegistry.clear_custom_registrations()
   ```

### Performance

- Reuse DialogueEngine instances instead of creating new ones
- Cache callback Callables instead of recreating them
- Use labels over numeric indices for maintainability
- Profile condition handlers if dialogue feels slow

---

## Troubleshooting

### "Unknown condition" error
- Check condition_id spelling
- Ensure callback is provided in context
- Verify condition is registered

### Dialogue doesn't advance
- Check `is_waiting` flag before calling `next()`
- Ensure node isn't waiting for choice selection

### Infinite loop detected
- Review JUMP and CONDITIONAL_BRANCH nodes
- Increase `max_jump_depth` if legitimate
- Add END nodes to terminate paths

### Choices not showing
- Verify node_type is CHOICE
- Check visibility conditions aren't hiding all choices
- Ensure `choices_available` signal is connected

---

## File Structure

```
dialogue_system/
├── core/
│   ├── DialogueRegistry.gd    # Condition/action registry
│   └── DialogueEngine.gd      # Main runtime engine
├── data/
│   ├── DialogueNodeData.gd    # Single node definition
│   └── DialogueData.gd        # Full dialogue container
├── ui/
│   └── SimpleTextboxUI.gd     # Example UI implementation
├── examples/
│   └── DialogueExample.gd     # Complete usage example
└── ARCHITECTURE.md            # System design document
```
