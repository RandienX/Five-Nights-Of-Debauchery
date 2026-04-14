@tool
class_name DialogueData
extends Resource

## Simple RPG Maker-style dialogue system
## Data-driven, label-based navigation with built-in conditions

@export_group("Nodes (Dialogue Entries)")
@export var nodes: Array[DialogueNode] = []

@export_group("Settings")
@export var start_label: String = "start"
@export var auto_advance: bool = false
@export var auto_advance_delay: float = 2.0

func validate() -> Array[String]:
	var errors: Array[String] = []
	
	if nodes.is_empty():
		errors.append("Dialogue has no nodes")
		return errors
	
	# Check for duplicate labels
	var labels: Dictionary = {}
	for node in nodes:
		if not node or node.label.is_empty():
			errors.append("Found node with empty label")
			continue
		
		if labels.has(node.label):
			errors.append("Duplicate label: '%s'" % node.label)
		labels[node.label] = true
	
	# Validate jump targets
	for node in nodes:
		if not node:
			continue
		
		if not node.next_label.is_empty() and not labels.has(node.next_label):
			errors.append("Node '%s' jumps to missing label: '%s'" % [node.label, node.next_label])
		
		for branch in node.branches:
			if branch and not branch.target_label.is_empty() and not labels.has(branch.target_label):
				errors.append("Node '%s' branch jumps to missing label: '%s'" % [node.label, branch.target_label])
		
		for choice in node.choices:
			if choice and not choice.target_label.is_empty() and not labels.has(choice.target_label):
				errors.append("Node '%s' choice jumps to missing label: '%s'" % [node.label, choice.target_label])
	
	# Validate effects
	for node in nodes:
		if not node:
			continue
		for effect in node.on_enter_effects:
			if effect and effect.effect_type == DialogueEffect.EffectType.CUSTOM and effect.custom_script.is_empty():
				errors.append("Node '%s' has custom effect with no script path" % node.label)
	
	return errors

func get_node_by_label(label: String) -> DialogueNode:
	for node in nodes:
		if node and node.label == label:
			return node
	return null

func get_start_node() -> DialogueNode:
	return get_node_by_label(start_label)
