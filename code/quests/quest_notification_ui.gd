extends Control
class_name QuestNotification

## QuestNotification - Popup notification for quest progress
##
## Appears on screen when quest progress is made, then slides out of view.

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel if has_node("MarginContainer/VBoxContainer/TitleLabel") else null
@onready var quest_name_label: Label = $MarginContainer/VBoxContainer/QuestNameLabel if has_node("MarginContainer/VBoxContainer/QuestNameLabel") else null
@onready var progress_label: Label = $MarginContainer/VBoxContainer/ProgressLabel if has_node("MarginContainer/VBoxContainer/ProgressLabel") else null

var _quest: Quest = null
var _state: QuestPoint.QuestState = QuestPoint.QuestState.NO
var _slide_tween: Tween = null
var _display_duration: float = 3.0

func _ready() -> void:
	# Start off-screen (above visible area)
	position.y = -size.y
	
	# Set up auto-dismiss timer
	var timer = get_tree().create_timer(_display_duration)
	timer.timeout.connect(_on_timer_timeout)

## Initialize notification with quest data and state
func initialize(quest: Quest, state: QuestPoint.QuestState) -> void:
	_quest = quest
	_state = state
	
	if title_label:
		title_label.text = _get_state_title()
	
	if quest_name_label and _quest:
		quest_name_label.text = _quest.quest_name
	
	if progress_label:
		progress_label.text = _get_state_description()
	
	# Slide into view
	_slide_in()

func _get_state_title() -> String:
	match _state:
		QuestPoint.QuestState.PROGRESS:
			return "Quest Progress!"
		QuestPoint.QuestState.DONE:
			return "Objective Complete!"
		QuestPoint.QuestState.YES:
			return "Quest Advanced!"
		QuestPoint.QuestState.FAIL:
			return "Quest Failed!"
		_:
			return "Quest Update!"

func _get_state_description() -> String:
	if not _quest:
		return ""
	
	match _state:
		QuestPoint.QuestState.PROGRESS:
			return "Making progress on: %s" % _quest.get_current_objective()
		QuestPoint.QuestState.DONE:
			return "Completed: %s" % _quest.get_current_objective()
		QuestPoint.QuestState.YES:
			return "Advanced to new objective!"
		QuestPoint.QuestState.FAIL:
			return "Failed: %s" % _quest.quest_name
		_:
			return _quest.get_current_objective()

func _slide_in() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	
	_slide_tween = create_tween()
	_slide_tween.tween_property(self, "position:y", 20, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _slide_out() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
	
	_slide_tween = create_tween()
	_slide_tween.tween_property(self, "position:y", -size.y - 20, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_slide_tween.tween_callback(queue_free)

func _on_timer_timeout() -> void:
	_slide_out()

func _exit_tree() -> void:
	if _slide_tween and _slide_tween.is_valid():
		_slide_tween.kill()
