extends VBoxContainer
class_name QuestPointConditionUI
## QuestPointConditionUI - Individual quest condition display
##
## Shows a single condition with icon, description, and progress bar.
## Handles visual feedback for progress and completion states.

@export var texture_rect: TextureRect = $HBoxContainer/TextureRect if has_node("HBoxContainer/TextureRect") else null
@export var condition_label: Label = $HBoxContainer/VBoxContainer/Condition if has_node("HBoxContainer/VBoxContainer/Condition") else null
@export var progress_bar: ProgressBar = $HBoxContainer/VBoxContainer/ProgressBar if has_node("HBoxContainer/VBoxContainer/ProgressBar") else null
@export var logic_label: Label = $Label if has_node("Label") else null

var _condition: QuestPointCondition = null
var _point: QuestPoint = null
var _flash_tween: Tween = null

## Initialize this condition item with data
func initialize(condition: QuestPointCondition, point: QuestPoint) -> void:
	_condition = condition
	_point = point
	update_display()

## Update the display with current condition state
func update_display() -> void:
	if not _condition:
		return
		
	# For KILLED_ENEMY conditions, get fresh progress from Global
	if _condition.type == QuestPointCondition.ConditionType.KILLED_ENEMY:
		if Global.has_method("get_enemies_killed"):
			var enemies_killed = Global.get_enemies_killed()
			var kill_progress = _condition.get_kill_progress(enemies_killed)
			_condition.progress_current = kill_progress
	# Update condition text
	if condition_label:
		condition_label.text = _get_condition_description()

	# Update progress bar
	if progress_bar:
		progress_bar.max_value = _condition.progress_target
		progress_bar.value = _condition.progress_current
		progress_bar.show_percentage = false

	# Update icon (placeholder - can be customized per condition type)
	if texture_rect:
		texture_rect.texture = _get_condition_icon()

	# Update logic gate label
	if logic_label and _point:
		logic_label.text = _get_logic_gate_string()
		logic_label.visible = logic_label.text.length() > 0

func _get_condition_description() -> String:
	if not _condition:
		return ""

	# Use custom description if set
	if not _condition.description.is_empty():
		return _condition.description

	# Generate description based on type and target
	match _condition.type:
		QuestPointCondition.ConditionType.HAS_ITEM:
			return "Collect %d %s" % [_condition.progress_target, _condition.target_key]
		QuestPointCondition.ConditionType.KILLED_ENEMY:
			return "Defeat %d %s" % [_condition.progress_target, _condition.target_key]
		QuestPointCondition.ConditionType.DONE_DIALOGUE:
			return "Complete dialogue: %s" % _condition.target_key
		QuestPointCondition.ConditionType.TALKED_TO_NPC:
			return "Talk to %s" % _condition.target_key
		QuestPointCondition.ConditionType.BATTLE_WON:
			return "Win battle: %s" % _condition.target_key
		QuestPointCondition.ConditionType.HAS_STATUS:
			return "Have status: %s" % _condition.target_key
		QuestPointCondition.ConditionType.DONE_THING:
			return "Complete: %s" % _condition.target_key
		QuestPointCondition.ConditionType.CUSTOM:
			return "Custom: %s" % _condition.target_key

	return _condition.target_key

func _get_condition_icon() -> Texture2D:
	if not _condition:
		return null

	# Return appropriate icon based on condition type
	# This is a placeholder - you can customize with actual textures
	match _condition.type:
		QuestPointCondition.ConditionType.HAS_ITEM:
			# Try to load item icon
			var item = _find_item_resource(_condition.target_key)
			if item and item.has_method("get_icon"):
				return item.get_icon()
		QuestPointCondition.ConditionType.KILLED_ENEMY:
			pass  # Could load enemy icon

	# Default icon (pizza placeholder from scene)
	return texture_rect.texture if texture_rect else null

func _find_item_resource(key: String) -> Resource:
	if key.begins_with("res://"):
		return load(key)

	# Try to find in items folder
	var item_path = "res://resources/items/%s.tres" % key.replace(" ", "_").to_lower()
	if ResourceLoader.exists(item_path):
		return load(item_path)

	return null

func _get_logic_gate_string() -> String:
	if not _point:
		return ""

	# Only show logic gate if there are multiple conditions or it's NOT
	if _point.conditions.size() <= 1 and _point.logic_gate != QuestPoint.LogicGate.NOT:
		return ""

	match _point.logic_gate:
		QuestPoint.LogicGate.AND:
			return "------------------------------- AND ------------------------------"
		QuestPoint.LogicGate.OR:
			return "------------------------------- OR -------------------------------"
		QuestPoint.LogicGate.NOT:
			return "------------------------------- NOT ------------------------------ "

	return ""

## Update progress from external source
func update_progress(current: float, target: float) -> void:
	if progress_bar:
		progress_bar.max_value = target
		progress_bar.value = current

	if _condition:
		_condition.progress_current = current
		_condition.progress_target = target

## Flash progress bar for specific states
func flash_progress(color_from: Color, color_to: Color, duration: float = 1.5) -> void:
	if not progress_bar or not _condition:
		return

	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	_flash_tween.set_loops()

	# Get current fill style
	var fill_style = progress_bar.theme_override_styles.get("fill")
	if fill_style:
		_flash_tween.tween_property(fill_style, "bg_color", color_from, duration / 4.0)
		_flash_tween.tween_property(fill_style, "bg_color", color_to, duration / 4.0)
		_flash_tween.tween_property(fill_style, "bg_color", color_from, duration / 4.0)
		_flash_tween.tween_property(fill_style, "bg_color", color_to, duration / 4.0)

## Set visual state based on condition evaluation
func set_state(state: QuestPoint.QuestState) -> void:
	match state:
		QuestPoint.QuestState.DONE:
			flash_progress(Color.LIME_GREEN, Color.YELLOW)
		QuestPoint.QuestState.FAIL:
			flash_progress(Color.RED, Color.DARK_RED)
		QuestPoint.QuestState.YES:
			flash_progress(Color.GOLD, Color.WHITE, 0.5)
		QuestPoint.QuestState.PROGRESS:
			# Just update progress bar normally
			update_display()
		QuestPoint.QuestState.NO:
			# Reset to default
			update_display()

func _exit_tree() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
