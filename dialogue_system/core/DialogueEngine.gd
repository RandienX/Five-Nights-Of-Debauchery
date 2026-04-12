## Ultra-minimalist dialogue engine
## Signals for UI, data-driven flow, zero code for 95% of cases

class_name DialogueEngine
extends Node

signal text_displayed(text: String, speaker: String)
signal dialogue_started()
signal dialogue_ended()
signal action_triggered(action_id: String, args: Array)

var _data: DialogueData = null
var _current_index: int = -1
var _jump_count: int = 0
const MAX_JUMPS = 100  # Loop protection

func start(data: DialogueData, start_index: int = 0) -> void:
	_data = data
	_current_index = start_index
	_jump_count = 0
	
	if not _data or _data.nodes.is_empty():
		push_error("DialogueEngine: Invalid or empty dialogue data")
		return
	
	_run_current_node()

func next() -> void:
	if _current_index < 0 or _current_index >= _data.nodes.size():
		end_dialogue()
		return
	
	var node = _data.nodes[_current_index]
	_current_index = node.next_index if node.next_index >= 0 else -1
	
	if _current_index >= 0:
		_run_current_node()
	else:
		end_dialogue()

func jump_to(index: int) -> void:
	if index < 0 or index >= _data.nodes.size():
		push_warning("DialogueEngine: Invalid jump index %d" % index)
		end_dialogue()
		return
	
	_jump_count += 1
	if _jump_count > MAX_JUMPS:
		push_error("DialogueEngine: Loop detected! Aborting.")
		end_dialogue()
		return
	
	_current_index = index
	_run_current_node()

func end_dialogue() -> void:
	_data = null
	_current_index = -1
	_jump_count = 0
	dialogue_ended.emit()

func _run_current_node() -> void:
	var node = _data.nodes[_current_index]
	
	# Check condition
	if not node.condition_id.is_empty():
		var result = DialogueRegistry.evaluate_condition(node.condition_id, node.condition_args)
		if not result:
			if node.jump_if_false_index >= 0:
				jump_to(node.jump_if_false_index)
				return
			else:
				next()
				return
	
	# Execute action
	if not node.action_id.is_empty():
		DialogueRegistry.execute_action(node.action_id, node.action_args)
		action_triggered.emit(node.action_id, node.action_args)
	
	# Display text
	text_displayed.emit(node.text, node.speaker_name)
	dialogue_started.emit()
