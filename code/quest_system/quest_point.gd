extends Resource
class_name QuestPoint
## A quest point contains conditions that must be met using logic gates

enum LogicGate {
	AND,  ## All conditions must be true
	OR,   ## At least one condition must be true
	NOT,  ## All conditions must be false (inverted)
}

@export_group("Point Definition")
@export var point_name: String = "Quest Point"
@export var description: String = ""  ## Displayed in UI

@export_group("Conditions & Logic")
@export var conditions: Array[QuestPointCondition] = []
@export var logic_gate: LogicGate = LogicGate.AND
@export var depends_on: Array[String] = []  ## Names of other points that must be completed first

@export_group("State")
var state: QuestState = QuestState.NO  ## Current evaluation state

enum QuestState {
	NO,       ## No progression trigger detected
	PROGRESS, ## Conditions advancing; update progress bars
	DONE,     ## Flash progress bar green↔yellow
	FAIL,     ## Quest failed; flash NOT condition red
	YES       ## Advance to next step or complete quest
}

## Evaluate all conditions with the logic gate
func evaluate() -> QuestState:
	if conditions.is_empty():
		state = QuestState.YES
		return state
	
	var results: Array[bool] = []
	for condition in conditions:
		results.append(condition.evaluate())
	
	match logic_gate:
		LogicGate.AND:
			var all_true = true
			var any_progressing = false
			for i in results.size():
				if not results[i]:
					all_true = false
					# Check if this condition is making progress
					if conditions[i].get_progress_ratio() > 0:
						any_progressing = true
			
			if all_true:
				state = QuestState.YES
			elif any_progressing:
				state = QuestState.PROGRESS
			else:
				state = QuestState.NO
		
		LogicGate.OR:
			var any_true = false
			for result in results:
				if result:
					any_true = true
					break
			
			if any_true:
				state = QuestState.YES
			else:
				# Check if any are progressing
				var any_progressing = false
				for condition in conditions:
					if condition.get_progress_ratio() > 0:
						any_progressing = true
						break
				
				if any_progressing:
					state = QuestState.PROGRESS
				else:
					state = QuestState.NO
		
		LogicGate.NOT:
			var all_false = true
			for result in results:
				if result:
					all_false = false
					break
			
			if all_false:
				state = QuestState.YES
			else:
				state = QuestState.FAIL
	
	return state

## Get overall progress ratio for UI (0.0 to 1.0)
func get_progress_ratio() -> float:
	if conditions.is_empty():
		return 1.0
	
	var total_progress = 0.0
	for condition in conditions:
		total_progress += condition.get_progress_ratio()
	
	return total_progress / float(conditions.size())

## Check if a specific point name is in dependencies
func depends_on_point(point_name: String) -> bool:
	return point_name in depends_on

## Reset all conditions
func reset():
	state = QuestState.NO
	for condition in conditions:
		condition.reset_progress()

## Get visible conditions for UI (excludes hidden ones)
func get_visible_conditions() -> Array[QuestPointCondition]:
	var visible: Array[QuestPointCondition] = []
	for condition in conditions:
		if not condition.hide_in_ui:
			visible.append(condition)
	return visible
