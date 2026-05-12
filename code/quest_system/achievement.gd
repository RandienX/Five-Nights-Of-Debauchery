class_name Achievement
extends Resource

@export var achievement_id: String = ""
@export var achievement_name: String = ""
@export var description: String = ""
@export var condition: QuestCondition = null

var _current_progress: float = 0.0

func initialize():
	_current_progress = 0.0

func progress_condition(idx: int, amount: float) -> bool:
	if not condition: return false
	_current_progress = min(_current_progress + amount, condition.progress_target)
	return true

func is_complete() -> bool:
	if not condition: return false
	return _current_progress >= condition.progress_target

func get_progress() -> float:
	if not condition or condition.progress_target == 0: return 1.0
	return _current_progress / condition.progress_target
