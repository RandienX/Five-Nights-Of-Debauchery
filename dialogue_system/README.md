yes this was made by ai and polished by me. Considering the battle system was made by me and was abt same size, its good in a way that makes be quicker.

# Dialogue System

## ✨ Features

- **Node-Based Flow**: Index and label-based navigation through dialogue trees
- **Data-Driven**: All dialogue stored as Godot Resources (`.tres` files) - no coding required for designers
- **Conditional Branching**: Built-in conditions for items, status effects, variables, and random chance
- **Custom Logic**: Register your own GDScript conditions and actions via `Callable`s
- **Type-Safe**: Strongly typed GDScript with explicit type hints
- **Loop Protection**: Automatic infinite loop detection with configurable depth limits
- **Validation**: Load-time validation with clear error/warning logging
- **Signal-Based**: Clean UI integration via Godot signals
- **Inspector-Friendly**: All properties editable in Godot Editor

## 📁 File Structure

```
dialogue_system/
├── core/
│   ├── DialogueRegistry.gd    # Condition/action registry (static)
│   └── DialogueEngine.gd      # Main runtime engine
├── data/
│   ├── DialogueNodeData.gd    # Single dialogue node definition
│   └── DialogueData.gd        # Full dialogue tree container
├── ui/
│   └── SimpleTextboxUI.gd     # Example textbox UI with typewriter effect
├── examples/
│   └── DialogueExample.gd     # Complete usage example with callbacks
├── ARCHITECTURE.md            # System design documentation
├── USAGE_GUIDE.md             # Detailed usage instructions
└── README.md                  # This file
```

## 🚀 Quick Start

### 1. Install

Copy the `dialogue_system/` folder into your Godot project's `res://` directory.

### 2. Create Dialogue Data

1. In Godot Editor: Right-click FileSystem → **Create New** → **Resource**
2. Select `DialogueData` class
3. Name it (e.g., `intro_dialogue.tres`)
4. Add nodes to the `nodes` array in the Inspector

### 3. Set Up Your Scene

```gdscript
extends Node

var dialogue_engine: DialogueEngine

func _ready() -> void:
    dialogue_engine = DialogueEngine.new()
    add_child(dialogue_engine)
    
    # Connect to signals
    dialogue_engine.node_displayed.connect(_on_node_displayed)
    dialogue_engine.choices_available.connect(_on_choices_available)
    dialogue_engine.dialogue_ended.connect(_on_dialogue_ended)
    
    # Set up game callbacks
    var callbacks = {
        "has_item_callback": Callable(self, "_check_has_item"),
        "get_variable_callback": Callable(self, "_get_variable"),
        "set_variable_callback": Callable(self, "_set_variable"),
    }
    
    # Load and start dialogue
    var data: DialogueData = load("res://path/to/your/dialogue.tres")
    dialogue_engine.start(data, "", callbacks)

func _on_node_displayed(node: DialogueNodeData, index: int, data: DialogueData) -> void:
    print("%s: %s" % [node.speaker, node.text])
    # Update your UI here

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        if dialogue_engine.get_is_waiting():
            dialogue_engine.next()
```

## 🎯 Core API

### Starting Dialogue

```gdscript
engine.start(dialogue_data: DialogueData, entry_point: String = "", callbacks: Dictionary = {}) -> bool
```

### Navigation

```gdscript
engine.next()                          # Advance to next node
engine.jump_to("label_or_index")       # Jump to specific node
engine.select_choice(index: int)       # Select from CHOICE node
```

### State Queries

```gdscript
engine.get_is_running() -> bool        # Is dialogue active?
engine.get_is_waiting() -> bool        # Waiting for player input?
engine.get_current_node() -> DialogueNodeData
engine.get_current_index() -> int
```

## 🔧 Built-in Conditions

Use these in `CONDITIONAL_BRANCH` nodes:

| Condition | Arguments | Description |
|-----------|-----------|-------------|
| `has_item` | `[item_id: String, amount: int]` | Check player inventory |
| `has_status_effect` | `[effect_id: String]` | Check active effects |
| `check_variable` | `[var_name, operator, value]` | Compare variables (`==`, `!=`, `<`, `>`, `<=`, `>=`) |
| `random_chance` | `[percent: float]` | Random probability (0-100) |

## ⚡ Built-in Actions

Use these in `on_enter_actions` or `on_exit_actions`:

```
"set_variable:gold:100"
"modify_variable:reputation:10"
"give_item:potion:3"
"remove_item:key:1"
"add_status_effect:buff:60.0"
"trigger_event:start_quest"
"debug_print:Player reached checkpoint"
```

Format: `"action_id:arg1:arg2:..."`

## 🛠️ Custom Conditions & Actions

### Register Custom Condition

```gdscript
func check_player_level(arguments: Array, context: Dictionary) -> bool:
    var min_level: int = int(arguments[0])
    return get_player_level() >= min_level

DialogueRegistry.register_condition("check_level", 
    Callable(self, "check_player_level"))

# Use in dialogue: condition_id = "check_level", arguments = [5]
```

### Register Custom Action

```gdscript
func play_music(arguments: Array, context: Dictionary) -> void:
    $MusicPlayer.play(arguments[0])

DialogueRegistry.register_action("play_music", 
    Callable(self, "play_music"))

# Use in node: on_enter_actions = ["play_music:battle_theme"]
```

## 🎮 Node Types

| Type | Description |
|------|-------------|
| `STANDARD` | Display text, wait for input, proceed to next index |
| `CHOICE` | Show player choices, jump to selected target |
| `CONDITIONAL_BRANCH` | Evaluate conditions, auto-jump based on results |
| `JUMP` | Immediately jump to another node |
| `END` | Terminate dialogue |

## 📖 Documentation

- **[USAGE_GUIDE.md](USAGE_GUIDE.md)** - Detailed usage instructions, examples, troubleshooting
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - System design, data flow, extensibility points

## 🎨 Example Dialogue Structure

```
Node 0: "greeting_start" (STANDARD)
  Speaker: "Merchant"
  Text: "Welcome to my shop!"

Node 1: (CONDITIONAL_BRANCH)
  Speaker: "Merchant"
  Text: "Looking for anything special?"
  Branch 1: if has_item("rare_gem", 1) → jump to "special_deal"
  Default: continue to next

Node 2: (CHOICE)
  Speaker: "Merchant"
  Text: "What would you like?"
  Choice 1: "Show weapons" → jump to "weapons_shop"
  Choice 2: "Leave" → jump to "farewell"

Node 3: "farewell" (END)
  Speaker: "Merchant"
  Text: "Come back soon!"
```
