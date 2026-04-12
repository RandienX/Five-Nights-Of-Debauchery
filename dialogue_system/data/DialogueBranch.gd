class_name DialogueBranch
extends Resource

## Represents a conditional branch in the dialogue flow.
## Used in CONDITIONAL_BRANCH node types to define condition-based jumps.

@export_group("Condition")
@export var condition_id: String = ""  ## Condition ID registered in DialogueRegistry
@export var arguments: Array = []       ## Arguments passed to the condition

@export_group("Jump Target (if true)")
@export var jump_target: String = ""   ## Target index or label to jump to if condition is true

@export_group("Behavior (if false)")
enum FalseBehavior {
	NEXT,      ## Proceed to next node in sequence
	JUMP,      ## Jump to specific target
	END        ## End dialogue
}
@export var on_false_behavior: FalseBehavior = FalseBehavior.NEXT
@export var on_false_target: String = ""  ## Target if on_false_behavior is JUMP


func _init(
	p_condition_id: String = "",
	p_arguments: Array = [],
	p_jump_target: String = "",
	p_on_false_behavior: FalseBehavior = FalseBehavior.NEXT,
	p_on_false_target: String = ""
):
	condition_id = p_condition_id
	arguments = p_arguments
	jump_target = p_jump_target
	on_false_behavior = p_on_false_behavior
	on_false_target = p_on_false_target


## Creates a copy of this branch
func duplicate() -> DialogueBranch:
	var new_branch := DialogueBranch.new()
	new_branch.condition_id = condition_id
	new_branch.arguments = arguments.duplicate()
	new_branch.jump_target = jump_target
	new_branch.on_false_behavior = on_false_behavior
	new_branch.on_false_target = on_false_target
	return new_branch


## Returns a string representation for debugging
func _to_string() -> String:
	return "DialogueBranch(condition=%s, args=%s, target=%s, on_false=%s)" % [
		condition_id, str(arguments), jump_target, FalseBehavior.keys()[on_false_behavior]
	]
