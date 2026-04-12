# Ultra-Minimalist Dialogue System for Godot 4.x

**Zero code for 95% of dialogue cases. Full control for the 5% edge cases.**

## Quick Start (3 Steps)

### 1. Create Dialogue Data
- Right-click in FileSystem → **Create New → Resource → DialogueData**
- Add `DialogueNodeData` elements in Inspector
- Fill in text, set conditions/actions from dropdowns

### 2. Setup Your Game (One-Time)
```gdscript
# In your game's autoload or main scene
func _ready() -> void:
    DialogueRegistry.on_has_item = func(item, amount): 
        return Inventory.has(item, amount)
    
    DialogueRegistry.on_check_variable = func(name, op, val): 
        return GameVars.check(name, op, val)
    
    DialogueRegistry.on_get_party_level = func(member): 
        return Party.get_level(member)
```

### 3. Use in Scene
```gdscript
@export var dialogue_data: DialogueData
var engine: DialogueEngine

func start_dialogue():
    engine = DialogueEngine.new()
    add_child(engine)
    engine.text_displayed.connect(func(text, speaker): $Textbox/Label.text = text)
    engine.start(dialogue_data)

func _input(event):
    if event.is_action_pressed("ui_accept"):
        engine.next()
```

## Built-In Conditions (No Code!)

| Condition | Arguments | Example |
|-----------|-----------|---------|
| `has_item` | `[item_id, amount]` | `["magic_key", 1]` |
| `check_variable` | `[var_name, operator, value]` | `["gold", ">=", 100]` |
| `party_level` | `[member_name, min_level]` | `["hero", 5]` |
| `random_chance` | `[percent]` | `[50]` (50% chance) |
| `has_status` | `[effect_id]` | `["poisoned"]` |

## Built-In Actions (No Code!)

| Action | Arguments | Example |
|--------|-----------|---------|
| `set_variable` | `[var_name, value]` | `["quest_done", true]` |
| `modify_variable` | `[var_name, delta]` | `["gold", -50]` |
| `give_item` | `[item_id, amount]` | `["potion", 3]` |
| `trigger_event` | `[event_name, ...args]` | `["open_door"]` |

## Inspector Workflow (Drag & Drop)

1. **Create DialogueData resource**
2. **Add nodes** via Inspector array
3. **Set text** in multiline field
4. **Add condition** (optional): Select from dropdown, fill args
5. **Add action** (optional): Select from dropdown, fill args
6. **Link nodes**: Set `next_index` (0 = first node, 1 = second, etc.)
7. **Conditional branching**: Set `jump_if_false_index` to skip to different node

## Example: Check Item & Party Level

**Node 0:** "Do you have the Magic Key?"
- Next Index: 1

**Node 1:** "Great! Let me check your team's strength..."
- Condition: `has_item` → Args: `["magic_key", 1]`
- If False Jump To: 3 (failure dialogue)
- Next Index: 2

**Node 2:** "Perfect! Your party is strong enough."
- Condition: `party_level` → Args: `["hero", 5]`
- If False Jump To: 3
- Next Index: -1 (end)

**Node 3:** "Come back when you're prepared."
- Next Index: -1

## Custom Logic (5% Edge Cases)

```gdscript
# Register custom condition
DialogueRegistry.register_condition("quest_completed", func(args):
    return QuestSystem.is_complete(args[0])
)

# Register custom action
DialogueRegistry.register_action("spawn_boss", func(args):
    BossSpawner.spawn(args[0])
)
```

Then use `"quest_completed"` or `"spawn_boss"` in Inspector dropdowns!

## Safety Features

- **Loop Protection**: Max 100 jumps per dialogue (prevents infinite loops)
- **Graceful Errors**: Unknown conditions log warning, continue safely
- **Type Hints**: Full GDScript typing for IDE support
- **Validation**: Empty data shows clear error messages

## File Structure

```
dialogue_system/
├── core/
│   ├── DialogueEngine.gd      # Runtime executor
│   └── DialogueRegistry.gd    # Conditions/actions library
├── data/
│   ├── DialogueData.gd        # Container resource
│   └── DialogueNodeData.gd    # Individual node resource
└── examples/
    └── DialogueExample.gd     # Complete usage example
```

## API Reference

### DialogueEngine
- `start(data: DialogueData, start_index: int = 0)` - Begin dialogue
- `next()` - Advance to next node
- `jump_to(index: int)` - Jump to specific node
- `end_dialogue()` - Force end

### Signals
- `text_displayed(text, speaker)` - Show text in UI
- `dialogue_started` - Dialogue began
- `dialogue_ended` - Dialogue finished
- `action_triggered(action_id, args)` - Action executed

---

**That's it! No boilerplate, no 100 lines per textbox.**
