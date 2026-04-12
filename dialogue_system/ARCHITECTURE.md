# Dialogue System Architecture Overview

## Core Components

### 1. Data Layer (`data/`)
- **DialogueNodeData.gd**: Resource defining individual dialogue steps
- **DialogueData.gd**: Resource containing the full dialogue tree with all nodes

### 2. Logic Layer (`core/`)
- **DialogueRegistry.gd**: Static registry for preset and custom condition checks
- **DialogueEngine.gd**: Main runtime executor handling flow, conditions, and signals

### 3. Runtime Execution
- State tracking (current node index, visited nodes, variables)
- Signal emission for UI integration
- Loop protection and validation

## Data Flow

```
Designer creates DialogueData Resource
         ↓
DialogueEngine loads data
         ↓
Validates structure (push_error/push_warning)
         ↓
Starts at entry point (index 0 or labeled node)
         ↓
Evaluates conditions → Determines next node
         ↓
Emits signals → UI displays text
         ↓
User input → engine.next()
         ↓
Repeats until END node
```

## Extensibility Points

1. **Custom Conditions**: Register via `DialogueRegistry.register_condition()`
2. **Custom Actions**: Register via `DialogueRegistry.register_action()`
3. **UI Integration**: Connect to engine signals (`dialogue_started`, `node_displayed`, `dialogue_ended`)
4. **Variable System**: Plug in your own variable storage via callbacks

## Key Design Decisions

- **Resource-based**: All dialogue data is stored as Godot Resources (`.tres` files)
- **Index + Label Navigation**: Support both numeric indices and string labels
- **Type-safe Conditions**: Built-in conditions use explicit types
- **Safe Defaults**: Invalid conditions/logic gracefully fallback with warnings
- **Inspector-friendly**: All properties visible and editable in Godot editor
