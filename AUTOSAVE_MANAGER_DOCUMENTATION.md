# AutoSaveManager - Automated Save/Load System Documentation

## 1. Architecture & Data Flow Overview

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                      Game Scene Tree                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐ │
│  │ Player Node │  │  Enemy Node │  │  Custom Scripted Nodes  │ │
│  │ (tracked)   │  │  (tracked)  │  │       (tracked)         │ │
│  └──────┬──────┘  └──────┬──────┘  └───────────┬─────────────┘ │
│         │                │                      │               │
│         └────────────────┴──────────────────────┘               │
│                          │                                      │
│                          ▼                                      │
│              ┌───────────────────────┐                          │
│              │  AutoSaveManager      │                          │
│              │  (Autoload Singleton) │                          │
│              └───────────┬───────────┘                          │
│                          │                                      │
└──────────────────────────┼──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌───────────────┐  ┌───────────────┐
│ Global.gd     │  │ PlayerStats   │  │ saves.gd      │
│ (scene_data)  │  │ (singleton)   │  │ (API layer)   │
└───────┬───────┘  └───────┬───────┘  └───────┬───────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                           ▼
                 ┌─────────────────┐
                 │  JSON Files     │
                 │  user://saves/  │
                 │  slot_X.json    │
                 └─────────────────┘
```

### Data Flow

#### Save Operation
1. **Trigger**: Manual save call or autosave timer
2. **Capture Global State**: `Global.time_played`, `Global.current_scene`, `Global.player_position`
3. **Capture Singletons**: `PlayerStats` properties (gold, inventory, party, etc.)
4. **Register & Capture Scene Nodes**: 
   - Recursively traverse scene tree
   - Register nodes with scripts/exportable properties
   - Serialize transforms, properties, and custom data
5. **Serialize to JSON**: Convert all data to human-readable format
6. **Write to Disk**: Save as `user://saves/slot_X.json`

#### Load Operation
1. **Read JSON File**: Parse save file from disk
2. **Validate & Migrate**: Check schema version, apply migrations if needed
3. **Change Scene**: Load the saved scene file
4. **Restore Global State**: Apply `Global.*` variables
5. **Restore Singletons**: Apply `PlayerStats` and other singleton data
6. **Restore Node States**: Find nodes by path/UID and apply saved properties
7. **Resume Game**: Clear loading flag, game continues from saved state

### Save Data Structure

```json
{
  "schema_version": "1.0",
  "timestamp": "2024-01-15T14:30:00",
  "save_name": "My Save",
  "time_played": 3600.5,
  "global_data": {
    "current_scene": "res://scenes/maps/1ab.tscn",
    "player_position": "Vector2(128, 256)",
    "time_played": 3600.5,
    "player_stats": {
      "gold": 100,
      "shit": 0,
      "tokens": 25,
      "stats": {"reputation": 0}
    },
    "singletons": {...}
  },
  "scenes_data": {
    "res://scenes/maps/1ab.tscn": {
      "nodes": {
        "Player": {
          "_uid": "abc123def456",
          "position": "Vector2(128, 256)",
          "rotation": 0.0,
          "scale": "Vector2(1, 1)",
          "hp": 100,
          "max_hp": 100
        },
        "Door": {
          "_uid": "xyz789ghi012",
          "is_open": true
        }
      },
      "custom_data": {}
    }
  },
  "registered_nodes": {
    "abc123def456": {
      "class": "CharacterBody2D",
      "path": "Player",
      "state": {...}
    }
  }
}
```

---

## 2. Core Implementation Code

The main implementation is in `/workspace/code/auto_save_manager.gd`. Key components:

### Key Classes & Methods

#### AutoSaveManager (Main Class)

| Method | Purpose |
|--------|---------|
| `save_game(slot, name)` | Manual save to slot |
| `load_game(slot)` | Load from slot |
| `trigger_autosave()` | Trigger automatic save |
| `set_autosave_enabled(bool)` | Toggle autosave |
| `get_slot_info(slot)` | Get save metadata |
| `delete_slot(slot)` | Delete save file |
| `register_node(node)` | Track node for saving |
| `print_debug_info()` | Debug output |

#### Serialization Pipeline

| Method | Purpose |
|--------|---------|
| `_serialize_value()` | Convert any value to JSON-safe format |
| `_deserialize_value()` | Restore value from JSON |
| `_serialize_node()` | Capture node state |
| `_serialize_object_properties()` | Extract object properties |

#### Scene Management

| Method | Purpose |
|--------|---------|
| `_capture_all_scenes_data()` | Snapshot all scene states |
| `_apply_scenes_data()` | Restore scene states |
| `_register_scene_nodes()` | Auto-register trackable nodes |

---

## 3. Step-by-Step Integration Guide

### Step 1: Add AutoSaveManager as Autoload

1. Open Godot Project Settings
2. Navigate to **Autoload** tab
3. Click **Add** and select `/workspace/code/auto_save_manager.gd`
4. Name it `AutoSaveManager`
5. Ensure it's listed in project.godot under `[autoload]`:

```ini
[autoload]

Global="*res://code/global.gd"
PlayerStats="*res://code/player_stats.gd"
Saves="*res://code/saves.gd"
AutoSaveManager="*res://code/auto_save_manager.gd"
```

### Step 2: Update Existing Save UI

Your existing save system (`saves.gd`) has been updated to automatically use `AutoSaveManager` when available. No changes needed to existing UI code that calls:
- `Saves.save_game(slot, name)`
- `Saves.load_game(slot)`
- `Saves.get_slot_info(slot)`

### Step 3: Enable Autosave (Optional)

Add to your game's initialization (e.g., in `global.gd._ready()` or main menu):

```gdscript
func _ready() -> void:
    # Enable autosave every 5 minutes (300 seconds)
    Saves.enable_autosave()
    
    # Or manually control AutoSaveManager:
    # AutoSaveManager.set_autosave_enabled(true)
```

### Step 4: Mark Important Nodes (Optional)

Nodes are auto-registered, but you can manually register important nodes:

```gdscript
extends CharacterBody2D

@export var hp: int = 100
@export var max_hp: int = 100
@export var inventory: Array = []

func _ready() -> void:
    # Register this node for explicit tracking
    AutoSaveManager.register_node(self)
```

### Step 5: Add Custom Scene Data (Optional)

For complex scene state not captured automatically:

```gdscript
extends Node2D

# Called during save
func get_custom_scene_data() -> Dictionary:
    return {
        "puzzle_state": puzzle_solved,
        "enemies_defeated": defeated_enemies,
        "collectibles_found": collected_items
    }

# Called during load
func set_custom_scene_data(data: Dictionary) -> void:
    puzzle_solved = data.get("puzzle_state", false)
    defeated_enemies = data.get("enemies_defeated", [])
    collected_items = data.get("collectibles_found", [])
```

---

## 4. Usage Examples

### Basic Save/Load

```gdscript
# Save to slot 1
Saves.save_game(1, "Before Boss Fight")

# Load from slot 1
Saves.load_game(1)

# Check if slot has save
var info = Saves.get_slot_info(1)
if info.exists:
    print("Save: ", info.save_name, " Time: ", Saves.format_time(info.time))
```

### Autosave at Checkpoints

```gdscript
extends Area2D

func _on_body_entered(body: Node) -> void:
    if body.is_in_group("player"):
        # Trigger autosave at checkpoint
        Saves.trigger_autosave()
        print("Checkpoint reached - Game autosaved")
```

### Save Before Scene Change

```gdscript
func change_scene(scene_path: String) -> void:
    # Quick autosave before transition
    Saves.save_game(0, "Autosave - Scene Transition")
    get_tree().change_scene_to_file(scene_path)
```

### Custom Save Metadata

```gdscript
# In your save menu UI
func display_save_slots() -> void:
    for i in range(Saves.MAX_SLOTS):
        var info = Saves.get_slot_info(i)
        if info.exists:
            save_buttons[i].text = info.save_name
            save_buttons[i].time_label.text = Saves.format_time(info.time)
            save_buttons[i].scene_label.text = info.current_scene.get_file()
        else:
            save_buttons[i].text = "Empty Slot"
```

### Debug & Testing

```gdscript
# Print all registered nodes
AutoSaveManager.print_debug_info()

# Manually trigger save for testing
func _input(event: InputEvent) -> void:
    if event.is_action_pressed("ui_save"):
        Saves.save_game(9, "Debug Save")
    
    if event.is_action_pressed("ui_load"):
        Saves.load_game(9)
```

---

## 5. Limitations & Edge Cases

### What Gets Saved Automatically

✅ **Automatically Captured:**
- Export variables (`@export`)
- Built-in properties (position, rotation, scale, etc.)
- Basic types (int, float, String, Vector2, Color, etc.)
- Arrays and Dictionaries of serializable types
- Resource references (stored as paths)
- Node transforms (Node2D/Node3D)
- Properties on scripted nodes

❌ **NOT Automatically Captured:**
- Local variables inside functions
- Signals and connections
- Timer states (paused/running)
- Animation states mid-playback
- Physics states (velocity, sleeping) unless exposed
- References to non-Resource objects
- Open file handles or network connections

### Handling Runtime-Spawned Objects

Runtime-spawned objects are tracked via unique IDs:

```gdscript
# Spawning enemy that should be saved
func spawn_enemy(position: Vector2) -> void:
    var enemy = enemy_scene.instantiate()
    enemy.position = position
    add_child(enemy)
    
    # Register for save tracking
    AutoSaveManager.register_node(enemy)
    
    # Enemy will now be included in saves
```

On load, the system attempts to restore these by:
1. Finding node by stored path
2. If not found, searching by unique ID
3. If still not found, logging warning (node may need respawn logic)

### Schema Versioning & Migration

The system includes basic versioning:

```gdscript
# Current version
const SAVE_VERSION := "1.0"

# Migration happens automatically
func _validate_and_migrate(save_data: Dictionary) -> bool:
    var version := save_data.get("schema_version", "0.0")
    
    if version != SAVE_VERSION:
        print("Migrating from %s to %s" % [version, SAVE_VERSION])
        # Add migration logic here for future versions
        
    return true
```

Future migration example:

```gdscript
func _migrate_from_09_to_10(save_data: Dictionary) -> void:
    # Example: rename old field to new field
    if save_data["global_data"].has("old_field"):
        save_data["global_data"]["new_field"] = save_data["global_data"]["old_field"]
        save_data["global_data"].erase("old_field")
```

### Error Handling

The system handles common errors gracefully:

| Error | Behavior |
|-------|----------|
| Missing save file | Returns false, no crash |
| Corrupted JSON | Logs error, returns false |
| Missing scene on load | Logs error, stays in current scene |
| Missing node on restore | Logs warning, continues |
| Invalid property value | Skips property, continues |
| Unserializable type | Logs warning, skips value |

### Performance Considerations

- **Save Frequency**: Autosave interval defaults to 5 minutes. Adjust based on game needs.
- **Scene Size**: Large scenes with many nodes take longer to serialize.
- **Deep Nesting**: Very deep node hierarchies may cause stack issues.
- **Large Arrays/Dicts**: Consider limiting what gets serialized.

### Best Practices

1. **Use @export for save-worthy variables**: Makes serialization automatic
2. **Keep resources in res://**: External resources save as paths
3. **Test save/load cycles**: Verify state restores correctly
4. **Version your saves**: Increment `SAVE_VERSION` when changing structure
5. **Backup saves**: Copy save files before major updates
6. **Don't save transient state**: Particles, temporary effects, etc.

---

## 6. Troubleshooting

### Common Issues

**Problem**: Variables not saving  
**Solution**: Ensure they're `@export` or have `PROPERTY_USAGE_STORAGE`

**Problem**: Scene doesn't restore correctly  
**Solution**: Check that scene path exists and hasn't changed

**Problem**: Runtime nodes missing after load  
**Solution**: Implement respawn logic for critical runtime nodes

**Problem**: Save file too large  
**Solution**: Exclude large arrays/dicts from serialization

**Problem**: Autosave not triggering  
**Solution**: Verify `AutoSaveManager` is in Autoload list

### Debug Commands

```gdscript
# In-game console or debugger
AutoSaveManager.print_debug_info()  # Show registered nodes
Saves.get_slot_info(0)              # Check autosave slot
ProjectSettings.globalize_path("user://saves/")  # Find save folder
```

---

## 7. API Reference Summary

### Saves.gd (Convenience Layer)

```gdscript
Saves.save_game(slot: int, name: String) -> bool
Saves.load_game(slot: int) -> bool
Saves.get_slot_info(slot: int) -> Dictionary
Saves.delete_slot(slot: int) -> bool
Saves.enable_autosave(interval: float) -> void
Saves.disable_autosave() -> void
Saves.trigger_autosave() -> void
Saves.format_time(seconds: float) -> String
```

### AutoSaveManager (Full Control)

```gdscript
AutoSaveManager.save_game(slot, name) -> bool
AutoSaveManager.load_game(slot) -> bool
AutoSaveManager.set_autosave_enabled(enabled: bool) -> void
AutoSaveManager.register_node(node: Node) -> String
AutoSaveManager.unregister_node(node: Node) -> void
AutoSaveManager.get_slot_info(slot: int) -> Dictionary
AutoSaveManager.delete_slot(slot: int) -> bool
AutoSaveManager.print_debug_info() -> void
```

### Signals

```gdscript
AutoSaveManager.save_completed.connect(func(success, slot))
AutoSaveManager.load_completed.connect(func(success, slot))
AutoSaveManager.autosave_triggered.connect(func())
```
