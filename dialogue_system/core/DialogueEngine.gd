class_name DialogueEngine
extends Node

## Main runtime executor for the dialogue system.
## Handles loading, validation, flow control, condition evaluation, and signal emission.
## Connect to signals for UI integration.


# =====================
# Signals for UI Integration
# =====================

## Emitted when dialogue starts
signal dialogue_started(data: DialogueData)

## Emitted when a node is displayed (main signal for UI to show text)
signal node_displayed(node: DialogueNodeData, index: int, data: DialogueData)

## Emitted when choices are available (UI should show choice buttons)
signal choices_available(choices: Array[DialogueChoice])

## Emitted when dialogue ends naturally (reaches END node or no more nodes)
signal dialogue_ended(data: DialogueData)

## Emitted when an action is executed (for game logic hooks)
signal action_executed(action_id: String, arguments: Array)

## Emitted on error during execution
signal execution_error(message: String)

## Emitted on warning during execution  
signal execution_warning(message: String)


# =====================
# Configuration
# =====================

## Maximum jump depth before loop protection triggers
@export var max_jump_depth: int = 100

## Enable verbose logging
@export var debug_mode: bool = false

## Auto-validate data on start
@export var auto_validate: bool = true


# =====================
# Runtime State
# =====================

## Current dialogue data
var current_data: DialogueData = null

## Current node index
var current_index: int = -1

## Stack of visited indices (for history/backtracking if needed)
var visited_indices: Array[int] = []

## Jump depth counter (loop protection)
var jump_depth: int = 0

## Runtime context (callbacks, variables, etc.)
var context: Dictionary = {}

## Whether dialogue is currently running
var is_running: bool = false

## Whether waiting for user input (paused state)
var is_waiting: bool = false

## Current pending branch evaluations (for CONDITIONAL_BRANCH nodes)
var pending_branches: Array[DialogueBranch] = []


# =====================
# Lifecycle Methods
# =====================

func _ready() -> void:
	# Initialize random seed
	randomize()
	
	if debug_mode:
		print("DialogueEngine: Ready")


# =====================
# Public API
# =====================

## Start a dialogue with the given data
## @param data: DialogueData resource to run
## @param entry_point: Optional label or index to start at (overrides data.entry_point)
## @param callbacks: Dictionary of game-specific callbacks
func start(data: DialogueData, entry_point: String = "", callbacks: Dictionary = {}) -> bool:
	if data == null:
		push_error("DialogueEngine: Cannot start with null DialogueData")
		execution_error.emit("Cannot start with null DialogueData")
		return false
	
	if not is_running:
		is_running = true
	
	current_data = data
	context = callbacks.duplicate()
	jump_depth = 0
	visited_indices.clear()
	
	# Validate if enabled
	if auto_validate and not current_data.validate():
		push_error("DialogueEngine: Data validation failed")
		execution_error.emit("Data validation failed")
		is_running = false
		return false
	
	# Determine entry point
	var start_index: int = 0
	if entry_point != "":
		start_index = current_data.resolve_target(entry_point)
	else:
		start_index = current_data.get_entry_index()
	
	if start_index < 0 or start_index >= current_data.nodes.size():
		push_error("DialogueEngine: Invalid entry point index %d" % start_index)
		execution_error.emit("Invalid entry point")
		is_running = false
		return false
	
	current_index = start_index
	visited_indices.append(current_index)
	
	if debug_mode:
		print("DialogueEngine: Starting dialogue '%s' at index %d" % [current_data.title, current_index])
	
	dialogue_started.emit(current_data)
	
	# Process the first node
	_process_current_node()
	
	return true


## Advance to the next node (called by UI on user input)
## Returns true if successfully advanced, false if at end or waiting for choice
func next() -> bool:
	if not is_running:
		push_warning("DialogueEngine: Cannot call next() - dialogue not running")
		return false
	
	if is_waiting:
		push_warning("DialogueEngine: Cannot call next() - waiting for choice selection")
		return false
	
	# Execute exit actions for current node
	_execute_actions(current_data.nodes[current_index].on_exit_actions, "on_exit")
	
	# Move to next index
	var next_index: int = current_index + 1
	
	if next_index >= current_data.nodes.size():
		_end_dialogue()
		return false
	
	current_index = next_index
	visited_indices.append(current_index)
	
	_process_current_node()
	return true


## Jump to a specific target (index or label)
## @param target: Index as string ("3") or label ("greeting_start")
func jump_to(target: String) -> bool:
	if not is_running:
		push_warning("DialogueEngine: Cannot jump - dialogue not running")
		return false
	
	# Loop protection
	jump_depth += 1
	if jump_depth > max_jump_depth:
		push_error("DialogueEngine: Loop protection triggered! Max jump depth (%d) exceeded" % max_jump_depth)
		execution_error.emit("Infinite loop detected - dialogue aborted")
		_end_dialogue()
		return false
	
	var resolved_index: int = current_data.resolve_target(target, current_index)
	
	if resolved_index < 0 or resolved_index >= current_data.nodes.size():
		push_error("DialogueEngine: Could not resolve jump target '%s'" % target)
		execution_error.emit("Invalid jump target: %s" % target)
		return false
	
	if debug_mode:
		print("DialogueEngine: Jumping from %d to %d (target: %s)" % [current_index, resolved_index, target])
	
	# Execute exit actions
	_execute_actions(current_data.nodes[current_index].on_exit_actions, "on_exit")
	
	current_index = resolved_index
	visited_indices.append(current_index)
	
	_process_current_node()
	return true


## Select a choice from a CHOICE node
## @param choice_index: Index of the choice in the choices array
func select_choice(choice_index: int) -> bool:
	if not is_running:
		push_warning("DialogueEngine: Cannot select choice - dialogue not running")
		return false
	
	if not is_waiting:
		push_warning("DialogueEngine: Cannot select choice - not waiting for choice")
		return false
	
	var current_node: DialogueNodeData = current_data.nodes[current_index]
	
	if current_node.node_type != DialogueNodeData.NodeType.CHOICE:
		push_error("DialogueEngine: Current node is not a CHOICE type")
		return false
	
	if choice_index < 0 or choice_index >= current_node.choices.size():
		push_error("DialogueEngine: Choice index %d out of range" % choice_index)
		return false
	
	var choice: DialogueChoice = current_node.choices[choice_index]
	
	# Check visibility condition if present
	if choice.is_visible_condition != "":
		var is_visible: bool = DialogueRegistry.evaluate_condition(
			choice.is_visible_condition, 
			choice.is_visible_args, 
			context
		)
		if not is_visible:
			push_warning("DialogueEngine: Selected choice is hidden by condition")
	
	if debug_mode:
		print("DialogueEngine: Selected choice '%s' -> target '%s'" % [choice.text, choice.target])
	
	is_waiting = false
	
	# Jump to choice target
	return jump_to(choice.target)


## Pause dialogue (sets is_waiting flag without requiring choice)
func pause() -> void:
	is_waiting = true
	if debug_mode:
		print("DialogueEngine: Paused")


## Resume dialogue after pause
func resume() -> bool:
	if not is_waiting:
		return false
	
	is_waiting = false
	return next()


## Stop dialogue immediately
func stop() -> void:
	if debug_mode:
		print("DialogueEngine: Stopped")
	
	is_running = false
	is_waiting = false
	current_data = null
	current_index = -1
	jump_depth = 0
	visited_indices.clear()
	context.clear()


## Get current node
func get_current_node() -> DialogueNodeData:
	if current_data == null or current_index < 0:
		return null
	return current_data.nodes[current_index]


## Get current index
func get_current_index() -> int:
	return current_index


## Check if dialogue is running
func get_is_running() -> bool:
	return is_running


## Check if waiting for input
func get_is_waiting() -> bool:
	return is_waiting


## Set a context variable (shorthand for context["variables"][key] = value)
func set_variable(name: String, value: Variant) -> void:
	if not context.has("variables"):
		context["variables"] = {}
	context["variables"][name] = value


## Get a context variable
func get_variable(name: String, default: Variant = null) -> Variant:
	if not context.has("variables"):
		return default
	return context["variables"].get(name, default)


# =====================
# Internal Processing
# =====================

func _process_current_node() -> void:
	if current_index < 0 or current_index >= current_data.nodes.size():
		push_error("DialogueEngine: Current index %d out of bounds" % current_index)
		_end_dialogue()
		return
	
	var node: DialogueNodeData = current_data.nodes[current_index]
	
	if debug_mode:
		print("DialogueEngine: Processing node %d (type: %s, label: %s)" % [
			current_index, 
			DialogueNodeData.NodeType.keys()[node.node_type],
			node.label if node.label != "" else "(none)"
		])
	
	# Execute enter actions
	_execute_actions(node.on_enter_actions, "on_enter")
	
	# Handle based on node type
	match node.node_type:
		DialogueNodeData.NodeType.STANDARD:
			# Display node and wait for next()
			node_displayed.emit(node, current_index, current_data)
			is_waiting = true
			
		DialogueNodeData.NodeType.CHOICE:
			# Filter choices by visibility conditions
			var visible_choices: Array[DialogueChoice] = []
			for choice in node.choices:
				if choice.is_visible_condition == "":
					visible_choices.append(choice)
				else:
					var is_visible: bool = DialogueRegistry.evaluate_condition(
						choice.is_visible_condition,
						choice.is_visible_args,
						context
					)
					if is_visible:
						visible_choices.append(choice)
			
			if visible_choices.is_empty():
				push_warning("DialogueEngine: CHOICE node has no visible choices - auto-advancing")
				next()
				return
			
			choices_available.emit(visible_choices)
			node_displayed.emit(node, current_index, current_data)
			is_waiting = true
			
		DialogueNodeData.NodeType.CONDITIONAL_BRANCH:
			# Evaluate branches in order
			var jumped: bool = false
			for branch in node.branches:
				if branch.condition_id == "":
					continue
				
				var result: bool = DialogueRegistry.evaluate_condition(
					branch.condition_id,
					branch.arguments,
					context
				)
				
				if debug_mode:
					print("DialogueEngine: Branch condition '%s' = %s" % [branch.condition_id, result])
				
				if result:
					# Condition true - jump to target
					jump_to(branch.jump_target)
					jumped = true
					break
			
			if not jumped:
				# No condition was true - handle default behavior
				if not node.branches.is_empty():
					var last_branch: DialogueBranch = node.branches[-1]
					match last_branch.on_false_behavior:
						DialogueBranch.FalseBehavior.JUMP:
							jump_to(last_branch.on_false_target)
							jumped = true
						DialogueBranch.FalseBehavior.END:
							_end_dialogue()
							return
						_:  # NEXT or default
							pass
				
				if not jumped:
					# Proceed to next node
					node_displayed.emit(node, current_index, current_data)
					is_waiting = true
			
		DialogueNodeData.NodeType.JUMP:
			# Immediately jump to target
			jump_to(node.jump_target)
			
		DialogueNodeData.NodeType.END:
			# End dialogue
			node_displayed.emit(node, current_index, current_data)
			_end_dialogue()


func _execute_actions(action_ids: Array[String], action_type: String) -> void:
	for action_id in action_ids:
		if action_id == "":
			continue
		
		# Parse action_id for arguments (format: "action_id:arg1:arg2:...")
		var parts: PackedStringArray = action_id.split(":")
		var id: String = parts[0]
		var args: Array = []
		
		if parts.size() > 1:
			for i in range(1, parts.size()):
				args.append(parts[i])
		
		if debug_mode:
			print("DialogueEngine: Executing %s action '%s' with args: %s" % [action_type, id, args])
		
		DialogueRegistry.execute_action(id, args, context)
		action_executed.emit(id, args)


func _end_dialogue() -> void:
	if debug_mode:
		print("DialogueEngine: Dialogue ended")
	
	is_running = false
	is_waiting = false
	
	dialogue_ended.emit(current_data)
	
	# Clear state
	current_data = null
	current_index = -1
	jump_depth = 0
	visited_indices.clear()
	context.clear()


# =====================
# Utility Methods
# =====================

## Register a custom condition at runtime (convenience wrapper)
func register_condition(condition_id: String, handler: Callable) -> void:
	DialogueRegistry.register_condition(condition_id, handler)


## Register a custom action at runtime (convenience wrapper)
func register_action(action_id: String, handler: Callable) -> void:
	DialogueRegistry.register_action(action_id, handler)


## Get visit history
func get_visit_history() -> Array[int]:
	return visited_indices.duplicate()


## Check if a node was visited
func was_visited(index: int) -> bool:
	return index in visited_indices


## Reset jump depth counter (useful for long dialogues with many jumps)
func reset_jump_depth() -> void:
	jump_depth = 0
