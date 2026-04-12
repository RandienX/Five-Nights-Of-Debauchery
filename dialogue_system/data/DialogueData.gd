class_name DialogueData
extends Resource

## Container resource holding the complete dialogue tree.
## Designers create this in the inspector, add nodes, and save as .tres file.

@export var title: String = "Untitled Dialogue"
@export var description: String = ""
@export var version: String = "1.0"

## Array of all dialogue nodes in order (index-based navigation)
@export var nodes: Array[DialogueNodeData] = []

## Optional: Explicit entry point (by label). If empty, starts at index 0.
@export var entry_point: String = ""

## Global variables that can be referenced/modified during dialogue
@export var variables: Dictionary = {}

## Metadata for designers (tags, categories, etc.)
@export var metadata: Dictionary = {}


## Validate the dialogue data structure
## Returns true if valid, pushes errors/warnings if not
func validate() -> bool:
	var is_valid: bool = true
	
	if nodes.is_empty():
		push_error("DialogueData '%s': No nodes defined!" % title)
		return false
	
	# Check for duplicate labels
	var labels: Dictionary = {}
	for i in range(nodes.size()):
		var node: DialogueNodeData = nodes[i]
		
		# Auto-assign node_id if not set
		if node.node_id == -1:
			node.node_id = i
		
		# Check for duplicate labels
		if node.label != "":
			if labels.has(node.label):
				push_error("DialogueData '%s': Duplicate label '%s' found at indices %d and %d" % [title, node.label, labels[node.label], i])
				is_valid = false
			else:
				labels[node.label] = i
	
	# Validate branches and jump targets
	for i in range(nodes.size()):
		var node: DialogueNodeData = nodes[i]
		
		# Validate branches
		for branch in node.branches:
			if branch.condition_id == "":
				push_warning("DialogueData '%s' node %d: Branch has empty condition_id" % [title, i])
			
			# Validate jump target format
			if not _is_valid_target(branch.jump_target):
				push_error("DialogueData '%s' node %d: Invalid jump_target '%s' in branch" % [title, i, branch.jump_target])
				is_valid = false
			
			if branch.on_false_behavior not in ["NEXT", "JUMP"]:
				push_error("DialogueData '%s' node %d: Invalid on_false_behavior '%s'" % [title, i, branch.on_false_behavior])
				is_valid = false
			
			if branch.on_false_behavior == "JUMP" and not _is_valid_target(branch.on_false_target):
				push_error("DialogueData '%s' node %d: Invalid on_false_target '%s'" % [title, i, branch.on_false_target])
				is_valid = false
		
		# Validate jump target for JUMP nodes
		if node.node_type == DialogueNodeData.NodeType.JUMP:
			if node.jump_target == "":
				push_error("DialogueData '%s' node %d: JUMP node has empty jump_target" % [title, i])
				is_valid = false
			elif not _is_valid_target(node.jump_target):
				push_error("DialogueData '%s' node %d: Invalid jump_target '%s'" % [title, i, node.jump_target])
				is_valid = false
		
		# Validate choices
		for choice in node.choices:
			if choice.text == "":
				push_warning("DialogueData '%s' node %d: Choice has empty text" % [title, i])
			if not _is_valid_target(choice.target):
				push_error("DialogueData '%s' node %d: Invalid choice target '%s'" % [title, i, choice.target])
				is_valid = false
	
	# Validate entry point
	if entry_point != "" and not _is_valid_target(entry_point):
		push_error("DialogueData '%s': Invalid entry_point '%s'" % [title, entry_point])
		is_valid = false
	
	return is_valid


## Resolve a target string to an actual index
## Supports: numeric strings ("3"), labels ("greeting_start"), or direct indices
func resolve_target(target: String, current_index: int = -1) -> int:
	if target == "":
		return current_index + 1
	
	# Try parsing as integer
	if target.is_valid_int():
		var idx: int = target.to_int()
		if idx >= 0 and idx < nodes.size():
			return idx
		else:
			push_error("DialogueData: Target index %d out of bounds (0-%d)" % [idx, nodes.size() - 1])
			return -1
	
	# Search by label
	for i in range(nodes.size()):
		if nodes[i].label == target:
			return i
	
	push_error("DialogueData: Could not resolve target '%s' - no matching label or valid index" % target)
	return -1


## Get the entry point index
func get_entry_index() -> int:
	if entry_point != "":
		var idx: int = resolve_target(entry_point)
		if idx >= 0:
			return idx
	
	return 0  # Default to first node


## Check if target is valid format (numeric or non-empty string for label lookup)
func _is_valid_target(target: String) -> bool:
	if target == "":
		return false
	
	# Numeric indices are always valid (bounds checked later)
	if target.is_valid_int():
		return true
	
	# Non-empty strings are treated as labels (validated at runtime)
	return true
