# Quest & Achievement System - Integration Guide

## Overview
This system provides a complete, data-driven Quest and Achievement pipeline for Godot 4 with:
- Custom Resources for quests, steps, points, conditions, and effects
- Central autoload managers with 1.0s evaluation loops (no `_process` polling)
- Scene-agnostic trigger registration via signals
- Separate persistence for achievements (`user://achievements.json`)
- UI components with tween-based notifications

---

## 📁 File Structure

```
code/quest_system/
├── quest.gd                    # Quest Resource
├── quest_step.gd               # QuestStep Resource
├── quest_point.gd              # QuestPoint Resource  
├── quest_point_condition.gd    # QuestPointCondition Resource
├── quest_effect.gd             # QuestEffect Resource
├── quest_system.gd             # QuestSystem Autoload
├── achievement.gd              # Achievement Resource
├── achievement_system.gd       # AchievementSystem Autoload
├── quest_log_ui.gd             # QuestLogUI Control
└── achievement_ui.gd           # AchievementUI Control

resources/quests/               # Place .tres quest files here
resources/achievements/         # Place .tres achievement files here
```

---

## 🔧 Step 1: Register Autoloads

In Project Settings → Autoload, add:

| Path | Name |
|------|------|
| `res://code/quest_system/quest_system.gd` | `QuestSystem` |
| `res://code/quest_system/achievement_system.gd` | `AchievementSystem` |

---

## 📝 Step 2: Create Quest Resources

### Creating a Quest in the Editor

1. **Create Quest resource:**
   - Right-click in `resources/quests/` folder
   - Create → Resource → Quest
   - Set `quest_name`, `description`, `category`

2. **Add QuestSteps:**
   - In Quest inspector, expand `steps` array
   - Add new `QuestStep` resources
   - Set `step_name` and `description`

3. **Add QuestPoints to each step:**
   - In QuestStep, expand `points` array
   - Add `QuestPoint` resources
   - Set `point_name`, `logic_gate` (AND/OR/NOT)
   - Add `depends_on` if this point requires others

4. **Add Conditions to each point:**
   - In QuestPoint, expand `conditions` array
   - Add `QuestPointCondition` resources
   - Configure:
     - `type`: HAS_ITEM, KILLED_ENEMY, VISITED_LOCATION, etc.
     - `target_key`: Item name, enemy ID, location ID
     - `progress_target`: How many needed (e.g., 5 for "Kill 5 slimes")

5. **Add Rewards (optional):**
   - In Quest, expand `rewards` array
   - Add `QuestEffect` resources
   - Configure type and params

### Example Quest Structure

```
Quest: "The Slime Hunter"
├── Step 1: "Track the Slimes"
│   └── Point: "Find slime evidence"
│       ├── Condition: HAS_ITEM, target_key="slime_core", progress_target=3
│       └── Condition: VISITED_LOCATION, target_key="slime_forest"
│       └── logic_gate: AND
├── Step 2: "Hunt the Slimes"
│   └── Point: "Defeat slimes"
│       └── Condition: KILLED_ENEMY, target_key="slime", progress_target=5
└── Rewards
    ├── ADD_ITEM, params={item_resource="res://.../gold_pouch.tres", count=1}
    └── ADD_CURRENCY, params={amount=100, currency_type="gold"}
```

---

## 🏆 Step 3: Create Achievement Resources

Similar to quests, but simpler:

1. Create `Achievement` resource in `resources/achievements/`
2. Set `achievement_name`, `description`, `icon`
3. Add `steps` with `QuestStep` resources (reuses quest condition logic)
4. Optionally add `rewards`
5. Set `hidden` or `is_secret` for special achievements

---

## 🎮 Step 4: Integrate with game_menu UI

### Adding Quest Log Tab

1. In your `game_menu.tscn`, add a new tab/button for quests

2. Add a Control node as child of the tab content:
   ```gdscript
   # Attach QuestLogUI script
   var quest_log = preload("res://code/quest_system/quest_log_ui.gd").new()
   quest_log.name = "QuestLog"
   $TabControl/QuestsTab.add_child(quest_log)
   ```

3. **Required node structure** (QuestLogUI will auto-find these with % prefixes):
   ```
   QuestLog (Control)
   ├── %QuestList (VBoxContainer)      # List of quest items
   ├── %QuestDetail (Panel)            # Selected quest details
   └── %NotificationOverlay (Control)  # Popup notifications
   ```

4. Connect tab open/close events:
   ```gdscript
   func _on_quests_tab_opened():
       quest_log._on_tab_opened()
   
   func _on_quests_tab_closed():
       quest_log._on_tab_closed()
   ```

### Adding Achievement Tab

Same process with `AchievementUI`:

```gdscript
var achievement_ui = preload("res://code/quest_system/achievement_ui.gd").new()
achievement_ui.name = "AchievementUI"
$TabControl/AchievementsTab.add_child(achievement_ui)
```

Required structure:
```
AchievementUI (Control)
├── %AchievementList (VBoxContainer)
├── %AchievementDetail (Panel)
└── %NotificationOverlay (Control)
```

---

## 🔌 Step 5: Scene-Agonostic Trigger Registration

### Method A: Using progress_condition() (Recommended)

From any scene, call:

```gdscript
# When player picks up an item
QuestSystem.progress_condition(
    QuestPointCondition.ConditionType.HAS_ITEM,
    "slime_core",
    1.0  # amount
)

# When player kills an enemy
QuestSystem.progress_condition(
    QuestPointCondition.ConditionType.KILLED_ENEMY,
    "slime",
    1.0
)

# When player visits a location
QuestSystem.progress_condition(
    QuestPointCondition.ConditionType.VISITED_LOCATION,
    "slime_forest",
    1.0
)
```

### Method B: Register Custom Triggers

For complex conditions:

```gdscript
# In your scene's _ready()
func _ready():
    QuestSystem.register_scene_triggers({
        "boss_defeated": _on_boss_defeated,
        "puzzle_solved": _on_puzzle_solved
    })

func _on_boss_defeated(boss_id: String):
    # Custom logic here
    QuestSystem.progress_condition(
        QuestPointCondition.ConditionType.CUSTOM,
        "boss_" + boss_id,
        1.0
    )
```

### Method C: Connect to Global Signals

The QuestSystem automatically connects to these if they exist:
- `PlayerStats.item_added`
- `Global.battle_won`

Add these signals to your existing systems for automatic tracking.

---

## 💾 Step 6: Save/Load Integration

### In Your Save Manager

```gdscript
# When saving
func get_save_data() -> Dictionary:
    return {
        # ... your existing save data ...
        "quest_system": QuestSystem.get_save_data(),
        # Note: Achievements save separately to user://achievements.json
    }

# When loading
func load_save_data(data: Dictionary):
    # ... load your existing data ...
    if data.has("quest_system"):
        QuestSystem.load_save_data(data["quest_system"])
```

### Automatic Achievement Persistence

Achievements auto-save to `user://achievements.json` on every unlock.
No manual save/load needed - AchievementSystem handles it independently.

---

## 🛠️ Step 7: Custom Conditions & Effects

### Adding Custom Condition Types

1. Extend `QuestPointCondition.ConditionType` enum in `quest_point_condition.gd`

2. Add evaluation logic:
```gdscript
func _evaluate_custom_type() -> bool:
    # Your custom logic here
    # Update progress_current as needed
    return progress_current >= progress_target
```

3. Handle in main `evaluate()` function

### Adding Custom Effect Types

1. Extend `QuestEffect.EffectType` enum

2. Add execution logic:
```gdscript
func _execute_custom_type() -> bool:
    var param = params.get("custom_param")
    # Your effect logic here
    return true
```

3. Handle in main `execute()` function

### Using Signals for Extensions

Connect to QuestSystem signals for external handling:

```gdscript
# In your custom system
QuestSystem.custom_condition_evaluated.connect(_on_custom_condition)
QuestSystem.custom_effect_executed.connect(_on_custom_effect)

func _on_custom_condition(condition: QuestPointCondition):
    # Evaluate using your game's logic
    condition.progress_current = calculate_progress(condition.target_key)

func _on_custom_effect(effect: QuestEffect):
    # Execute custom effect
    handle_custom_effect(effect.params)
```

---

## 🎨 UI Customization

### Custom Quest Item Scene

1. Create a scene with your desired layout
2. Ensure it can store metadata (`set_meta("quest", quest)`)
3. Export to QuestLogUI:
```gdscript
@export var quest_item_scene: PackedScene
```

### Styling Notifications

Modify `show_notification()` in QuestLogUI/AchievementUI:
- Change colors per state
- Adjust tween durations
- Add sound effects
- Use custom notification prefabs

---

## 🐛 Debug Utilities

```gdscript
# Enable debug logging
QuestSystem.set_debug_mode(true)
AchievementSystem.set_debug_mode(true)

# Get debug info
print(QuestSystem.get_debug_info())
print(AchievementSystem.get_debug_info())

# Force unlock achievement (testing)
AchievementSystem.force_unlock("achievement_id")

# Reset achievement (testing)
AchievementSystem.reset_achievement("achievement_id")

# Reset all (dangerous!)
AchievementSystem.reset_all_achievements()
```

---

## ⚠️ Edge Case Handling

### Logic Gate Conflicts

- **AND gates**: All conditions must be true; shows PROGRESS if any are advancing
- **OR gates**: Any condition true completes; checks all for progress
- **NOT gates**: All conditions must be false; triggers FAIL state if any true

### Missing Effects

Effects gracefully fail if resources don't exist:
```gdscript
if not item_res:
    return false  # Effect fails silently
```

### Rapid UI Tweens

Tweens are interrupt-safe:
```gdscript
if _notification_tween and _notification_tween.is_valid():
    _notification_tween.kill()  # Cancel existing before creating new
```

### Save Compatibility

- Quest templates loaded from `res://resources/quests/`
- Save data stores only state (progress, indices), not full definitions
- Missing templates logged but don't crash

### NPC Clear Triggers

To clear quests via NPC interaction:
```gdscript
# In your NPC dialogue system
func _on_quest_turned_in(quest: Quest):
    QuestSystem.complete_quest(quest)
    # Give rewards, update reputation, etc.
```

---

## 📊 Signal Flow Diagram

```
┌─────────────────┐
│   Game Scenes   │
│  (Any location) │
└────────┬────────┘
         │ progress_condition()
         │ OR register_scene_triggers()
         ▼
┌─────────────────────────────────────┐
│          QuestSystem                │
│  ┌─────────────────────────────┐    │
│  │  1.0s Evaluation Loop       │    │
│  │  - Evaluate all quests      │    │
│  │  - Check state transitions  │    │
│  │  - Queue UI notifications   │    │
│  └──────────────┬──────────────┘    │
│                 │                   │
│  Signals:       │                   │
│  - quest_added  │                   │
│  - quest_completed                  │
│  - quest_progress_updated           │
│  - quest_ui_notification            │
└─────────────────┼───────────────────┘
                  │
         ┌────────┴────────┐
         │                 │
         ▼                 ▼
┌─────────────────┐ ┌──────────────────┐
│   QuestLogUI    │ │  SaveManager     │
│  (game_menu)    │ │                  │
│                 │ │  get_save_data() │
│ - Quest list    │ │  load_save_data()│
│ - Detail panel  │ └──────────────────┘
│ - Notifications │
└─────────────────┘

┌─────────────────────────────────────┐
│       AchievementSystem             │
│  ┌─────────────────────────────┐    │
│  │  1.0s Evaluation Loop       │    │
│  │  - Independent from quests  │    │
│  │  - Auto-saves on unlock     │    │
│  └──────────────┬──────────────┘    │
│                 │                   │
│  Saves to: user://achievements.json │
└─────────────────┼───────────────────┘
                  │
                  ▼
         ┌─────────────────┐
         │  AchievementUI  │
         │   (game_menu)   │
         └─────────────────┘
```

---

## 🔄 State Transition Diagram

```
QuestPoint.QuestState Transitions:

        ┌──────┐
        │  NO  │ ◄── Initial state
        └──┬───┘
           │ Condition detected with progress > 0
           ▼
     ┌──────────┐
     │ PROGRESS │ ◄── Updating progress bars
     └────┬─────┘
          │
    ┌─────┴─────┐
    │           │
    ▼           ▼
┌───────┐   ┌────────┐
│ DONE  │   │  FAIL  │ ◄── NOT gate violated
└───┬───┘   └────────┘
    │           
    │ All conditions met
    ▼
┌─────────┐
│   YES   │ ◄── Advance to next step/complete
└─────────┘
```

---

## 📋 Quick Reference

### Progress Condition Types
| Type | target_key Example |
|------|-------------------|
| HAS_ITEM | "health_potion" |
| HAS_STATUS | "poison" |
| DONE_THING | "opened_chest_01" |
| DONE_DIALOGUE | "intro_conversation" |
| KILLED_ENEMY | "goblin" |
| VISITED_LOCATION | "dark_cave" |
| TALKED_TO_NPC | "elder_npc" |
| BATTLE_WON | "forest_battle_01" |

### Effect Types
| Type | params |
|------|--------|
| ADD_ITEM | {item_resource, count} |
| ADD_CURRENCY | {amount, currency_type} |
| ADD_STATUS | {effect_type/effect_name, level, duration} |
| START_DIALOGUE | {dialogue_id} |
| START_BATTLE | {battle_resource} |
| CHANGE_SCENE | {scene_path, spawn_position} |
| SAVE_GAME | {slot, auto_name} |
| SET_FLAG | {flag_name, value} |

---

## ✅ Checklist

- [ ] Register QuestSystem and AchievementSystem as autoloads
- [ ] Create quest/achievement .tres resources
- [ ] Add QuestLogUI and AchievementUI to game_menu
- [ ] Connect tab open/close events
- [ ] Call `progress_condition()` from scenes when relevant events occur
- [ ] Integrate save/load with QuestSystem.get_save_data()
- [ ] Test quest progression flow
- [ ] Test achievement unlocking
- [ ] Verify save/load persistence
- [ ] Enable debug mode during development

---

For questions or issues, check the inline documentation in each script file.
