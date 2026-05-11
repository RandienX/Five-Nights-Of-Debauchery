@icon("res://icon.svg")
class_name QuestStep
extends Resource
## A quest step contains multiple points that must be completed in sequence

@export_group("Step Definition")
@export var step_name: String = "Quest Step"
@export var description: String = ""  ## Displayed in UI

@export_group("Points")
@export var points: Array[QuestPoint] = []  ## Points to complete (in order)

@export_group("State")
var current_point_index: int = 0  ## Index of the active point

## Get the current active point
func get_current_point() -> QuestPoint:
	if current_point_index < 0 or current_point_index >= points.size():
		return null
	return points[current_point_index]

## Evaluate the current step - returns true if step is complete
func evaluate() -> bool:
	if points.is_empty():
		return true
	
	var current_point = get_current_point()
	if not current_point:
		return true
	
	# Evaluate current point
	current_point.evaluate()
	
	# If current point is YES, advance to next
	if current_point.state == QuestPoint.QuestState.YES:
		current_point_index += 1
		# Check if all points are done
		if current_point_index >= points.size():
			return true
	
	return false

## Get overall step progress (0.0 to 1.0)
func get_progress_ratio() -> float:
	if points.is_empty():
		return 1.0
	
	# Each point contributes equally to step progress
	var completed_points = current_point_index
	var current_point_progress = 0.0
	
	if current_point_index < points.size():
		current_point_progress = points[current_point_index].get_progress_ratio()
	
	return (float(completed_points) + current_point_progress) / float(points.size())

## Get current state for UI feedback
func get_state() -> QuestPoint.QuestState:
	if points.is_empty():
		return QuestPoint.QuestState.YES
	
	var current_point = get_current_point()
	if not current_point:
		return QuestPoint.QuestState.YES
	
	return current_point.state

## Reset the step
func reset():
	current_point_index = 0
	for point in points:
		point.reset()

## Check if step is complete
func is_complete() -> bool:
	return current_point_index >= points.size()
