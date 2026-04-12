class_name DialogueChoice
extends Resource

## Represents a player choice in a CHOICE node.
## Players can select from multiple choices to branch the dialogue.

@export_group("Display")
@export var text: String = ""  ## The text shown to the player for this choice

@export_group("Target")
@export var target: String = ""  ## Index or label to jump to when selected

@export_group("Visibility Condition (Optional)")
@export var is_visible_condition: String = ""  ## Condition ID to check visibility
@export var is_visible_args: Array = []        ## Arguments for visibility condition

@export_group("Metadata")
@export var tags: Array[String] = []           ## For filtering/categorization
@export var metadata: Dictionary = {}          ## Custom data


func _init(
	p_text: String = "",
	p_target: String = "",
	p_is_visible_condition: String = "",
	p_is_visible_args: Array = [],
	p_tags: Array[String] = [],
	p_metadata: Dictionary = {}
):
	text = p_text
	target = p_target
	is_visible_condition = p_is_visible_condition
	is_visible_args = p_is_visible_args
	tags = p_tags
	metadata = p_metadata


## Creates a copy of this choice
func duplicate() -> DialogueChoice:
	var new_choice := DialogueChoice.new()
	new_choice.text = text
	new_choice.target = target
	new_choice.is_visible_condition = is_visible_condition
	new_choice.is_visible_args = is_visible_args.duplicate()
	new_choice.tags = tags.duplicate()
	new_choice.metadata = metadata.duplicate()
	return new_choice


## Checks if this choice should be visible based on the visibility condition
func is_visible(registry: Object) -> bool:
	if is_visible_condition.is_empty():
		return true  # No condition means always visible
	
	if not registry.has_method("evaluate_condition"):
		push_warning("DialogueChoice: Registry does not have evaluate_condition method")
		return true
	
	return registry.evaluate_condition(is_visible_condition, is_visible_args)


## Returns a string representation for debugging
func _to_string() -> String:
	return "DialogueChoice(text=\"%s\", target=%s, visible_cond=%s)" % [
		text, target, is_visible_condition if not is_visible_condition.is_empty() else "always"
	]
