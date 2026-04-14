class_name DialogueRunner
extends Node

## Runtime dialogue executor
## Manages flow, evaluates conditions, emits signals for UI

signal dialogue_started(data: DialogueData)
signal node_entered(node: DialogueNode)
signal text_displayed(text: String)
signal choice_available(choice: DialogueChoice)
signal choice_selected(choice: DialogueChoice)
signal dialogue_ended(last_node: DialogueNode)

var data: DialogueData
var evaluator: DialogueConditionEvaluator
var current_node: DialogueNode
var current_label: String
var is_running: bool = false


func start(dialogue_data: DialogueData, dialogue_evaluator: DialogueConditionEvaluator) -> void:
	data = dialogue_data
	evaluator = dialogue_evaluator
	
	if not data:
		push_error("DialogueRunner: No dialogue data provided")
		return
	
	# Validate before starting
	var errors = data.validate()
	if not errors.is_empty():
		for err in errors:
			push_warning("Dialogue validation: %s" % err)
	
	current_label = data.start_label
	is_running = true
	
	dialogue_started.emit(data)
	_goto_label(current_label)


func _goto_label(label: String) -> void:
	var node = data.get_node_by_label(label)
	if not node:
		push_error("DialogueRunner: Node not found: '%s'" % label)
		end_dialogue()
		return
	
	current_node = node
	current_label = label
	
	# Run enter effects
	_run_effects(node.on_enter_effects)
	
	node_entered.emit(node)
	text_displayed.emit(node.text)
	
	# Emit choices
	if node.has_choices():
		for choice in node.choices:
			if choice.is_available(evaluator):
				choice_available.emit(choice)


func advance() -> void:
	if not is_running or not current_node:
		return
	
	# Run exit effects
	_run_effects(current_node.on_exit_effects)
	
	# Check branches first (conditional jumps)
	if current_node.has_branches():
		for branch in current_node.branches:
			if evaluator.evaluate(branch):
				_goto_label(branch.target_label)
				return
	
	# Then check if we have choices (wait for player)
	if current_node.has_choices():
		return  # Wait for choice selection
	
	# Otherwise go to next node
	if not current_node.next_label.is_empty():
		_goto_label(current_node.next_label)
	else:
		end_dialogue()


func select_choice(choice: DialogueChoice) -> void:
	if not is_running or not current_node:
		return
	
	choice_selected.emit(choice)
	_goto_label(choice.target_label)


func end_dialogue() -> void:
	if not is_running:
		return
	
	is_running = false
	var last_node = current_node
	current_node = null
	current_label = ""
	
	dialogue_ended.emit(last_node)


func _run_effects(effects: Array[DialogueEffect]) -> void:
	for effect in effects:
		if not effect:
			continue
		
		match effect.effect_type:
			DialogueEffect.EffectType.SET_VARIABLE:
				_effect_set_variable(effect.param_string, effect.param_value)
			
			DialogueEffect.EffectType.ADD_ITEM:
				_effect_add_item(effect.param_string, int(effect.param_value))
			
			DialogueEffect.EffectType.REMOVE_ITEM:
				_effect_remove_item(effect.param_string, int(effect.param_value))
			
			DialogueEffect.EffectType.ADD_STATUS:
				_effect_add_status(effect.param_string)
			
			DialogueEffect.EffectType.REMOVE_STATUS:
				_effect_remove_status(effect.param_string)
			
			DialogueEffect.EffectType.START_QUEST:
				_effect_start_quest(effect.param_string)
			
			DialogueEffect.EffectType.COMPLETE_QUEST:
				_effect_complete_quest(effect.param_string)
			
			DialogueEffect.EffectType.TRIGGER_EVENT:
				_effect_trigger_event(effect.param_string)
			
			DialogueEffect.EffectType.WAIT:
				_effect_wait(effect.wait_seconds)
			
			DialogueEffect.EffectType.CUSTOM:
				_effect_custom(effect)


func _effect_set_variable(var_name: String, value: float) -> void:
	if Global.get(var_name) != null:
		Global[var_name] = value
	if load(Global.current_scene).get(var_name) != null:
		load(Global.current_scene)[var_name] = value
	if Global.battle_ref != null:
		if Global.battle_ref.get(var_name) != null:
			Global.battle_ref[var_name] = value
	for i in Global.party:
		if i.get(var_name) != null:
			i[var_name] = value

func _effect_add_item(item_res_path: String, amount: int) -> void:
	var item = load(item_res_path)
	Global.add_item(item, amount)

func _effect_remove_item(item_res_path: String, amount: int) -> void:
	var item = load(item_res_path)
	Global.remove_item(item, amount)

func _effect_add_status(status_id: String) -> void:
	# Hook this to your status system
	pass

func _effect_remove_status(status_id: String) -> void:
	# Hook this to your status system
	pass

func _effect_start_quest(quest_id: String) -> void:
	# Hook this to your quest system
	pass

func _effect_complete_quest(quest_id: String) -> void:
	# Hook this to your quest system
	pass

func _effect_trigger_event(event_name: String) -> void:
	# Emit a signal or call a function
	pass

func _effect_wait(seconds: float) -> void:
	# Pause dialogue - UI should handle this
	pass

func _effect_custom(effect: DialogueEffect) -> void:
	if effect.custom_script.is_empty():
		push_error("DialogueRunner: Custom effect has no script path")
		return
	
	var script = load(effect.custom_script)
	if not script:
		push_error("DialogueRunner: Failed to load custom effect script: %s" % effect.custom_script)
		return
	
	if script.has_static_method("apply"):
		script.apply(effect, self)
	else:
		push_error("DialogueRunner: Custom effect script missing static apply() function: %s" % effect.custom_script)
