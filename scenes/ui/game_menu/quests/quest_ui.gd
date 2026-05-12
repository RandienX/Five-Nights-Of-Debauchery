extends Control
class_name QuestItemUI
## QuestItemUI - Individual quest display item
##
## Displays a single quest with name, step info, and condition list.
## Handles navigation between steps and visual feedback for progress.

@export var quest_name_label: Label = %QuestName if has_node("%QuestName") else null
@export var step_label: Label = %StepLabel if has_node("%StepLabel") else null
@export var condition_container: VBoxContainer = %ConditionCon if has_node("%ConditionCon") else null
@export var list_backward: Button = %ListBackward if has_node("%ListBackward") else null
@export var list_forward: Button = %ListForward if has_node("%ListForward") else null

var _quest: Quest = null
var _current_step_index: int = 0
var _condition_items: Array[Control] = []
var _flash_tween: Tween = null

func _ready() -> void:
	if list_backward:
		list_backward.pressed.connect(_on_backward_pressed)
	if list_forward:
		list_forward.pressed.connect(_on_forward_pressed)

## Initialize this quest item with quest data
func initialize(quest: Quest) -> void:
	_quest = quest
	update_display()

## Update the display with current quest state
func update_display() -> void:
	if not _quest:
		return

	# Update quest name
	if quest_name_label:
		quest_name_label.text = _quest.quest_name

	# Update step label
	if step_label:
		var total_steps = _quest.steps.size()
		var current_step = _quest.get_current_step()
		if current_step:
			step_label.text = "Step %d/%d: %s" % [_quest.current_step_index + 1, total_steps, current_step.step_name]
		else:
			step_label.text = "Step %d/%d: Complete!" % [total_steps, total_steps]

	# Update conditions
	_update_conditions()

	# Update button states
	_update_buttons()

func _update_conditions() -> void:
	# Clear existing conditions
	for item in _condition_items:
		if is_instance_valid(item):
			item.queue_free()
	_condition_items.clear()

	if not condition_container:
		return

	var current_step = _quest.get_current_step()
	if not current_step:
		return

	var current_point = current_step.get_current_point()
	if not current_point:
		return

	# Create condition items for each condition
	for condition in current_point.conditions:
		_create_condition_item(condition, current_point)

func _create_condition_item(condition: QuestCondition, point: QuestPoint) -> void:
	if not condition_container:
		return

	# Load condition scene
	var condition_scene = load("res://scenes/ui/game_menu/quests/quest_condition.tscn")
	if not condition_scene:
		push_error("[QuestItemUI] Failed to load quest_condition.tscn")
		return

	var item = condition_scene.instantiate()
	condition_container.add_child(item)
	_condition_items.append(item)

	# Initialize the condition item
	if item.has_method("initialize"):
		item.initialize(condition, point)

	# Store reference
	item.set_meta("condition", condition)

func _update_buttons() -> void:
		if not _quest:
				return

		var current_step = _quest.get_current_step()
		if not current_step:
				# Quest complete - disable navigation
				if list_backward:
						list_backward.disabled = true
				if list_forward:
						list_forward.disabled = true
				return

		# Enable/disable based on step navigation possibility
		if list_backward:
				list_backward.disabled = _quest.current_step_index <= 0
		if list_forward:
				list_forward.disabled = _quest.current_step_index >= _quest.steps.size() - 1

func _on_backward_pressed() -> void:
	if _quest and _quest.current_step_index > 0:
		_quest.current_step_index -= 1
		update_display()

func _on_forward_pressed() -> void:
	if _quest and _quest.current_step_index < _quest.steps.size() - 1:
		_quest.current_step_index += 1
		update_display()

## Update progress from external source
func update_progress(quest: Quest, step_index: int, point_index: int) -> void:
	if quest.unique_id != _quest.unique_id:
		return

	_current_step_index = step_index
	update_display()

## Flash condition progress bar for DONE state
func flash_condition_done(condition_item: Control, color_from: Color, color_to: Color, duration: float = 1.5) -> void:
	if not condition_item or not is_instance_valid(condition_item):
		return

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.set_loops()

	var progress_bar = _find_progress_bar(condition_item)
	if progress_bar:
		_flash_tween.tween_property(progress_bar, "theme_override_styles/fill:bg_color", color_from, duration / 4.0)
		_flash_tween.tween_property(progress_bar, "theme_override_styles/fill:bg_color", color_to, duration / 4.0)
		_flash_tween.tween_property(progress_bar, "theme_override_styles/fill:bg_color", color_from, duration / 4.0)
		_flash_tween.tween_property(progress_bar, "theme_override_styles/fill:bg_color", color_to, duration / 4.0)

func _find_progress_bar(node: Node) -> ProgressBar:
	if node is ProgressBar:
		return node
	for child in node.get_children():
		var result = _find_progress_bar(child)
		if result:
			return result
	return null

## Set state-based visual feedback
func set_state_feedback(state: QuestPoint.QuestState) -> void:
	match state:
		QuestPoint.QuestState.DONE:
			# Flash green ↔ yellow
			for item in _condition_items:
				if is_instance_valid(item):
					flash_condition_done(item, Color.LIME_GREEN, Color.YELLOW)
		QuestPoint.QuestState.FAIL:
			# Flash red for NOT condition violation
			for item in _condition_items:
				if is_instance_valid(item):
					flash_condition_done(item, Color.RED, Color.DARK_RED)
		QuestPoint.QuestState.YES:
				# Brief gold flash
			for item in _condition_items:
				if is_instance_valid(item):
					flash_condition_done(item, Color.GOLD, Color.WHITE, 0.5)

func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
