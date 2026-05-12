extends Node
class_name QuestSystemClass

## QuestSystem - Central manager for all quests
##
## Handles quest tracking, progress updates, and notifications.
## Updates every second and manages quest UI notifications.

signal quest_added(quest: Quest)
signal quest_removed(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_progress_updated(quest: Quest, point_index: int)
signal quest_state_changed(quest: Quest, state: QuestPoint.QuestState)

# Singleton access
static var instance: QuestSystemClass = null

@export var update_interval: float = 1.0  # Seconds between quest updates

var quests: Dictionary = {}  # quest_id -> Quest
var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var failed_quests: Array[Quest] = []

# UI reference for notifications
var quest_log_ui: Control = null
var _notification_scene: PackedScene = null
var _update_timer: float = 0.0
var _last_update_time: float = 0.0

func _init():
	instance = self

func _ready() -> void:
	_notification_scene = load("res://scenes/ui/quest_notifications/quest_notification.tscn")
	set_process(true)

func _process(delta: float) -> void:
	_update_timer += delta
	
	# Update quests every second
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_all_quests()

## Add a quest to the system
func add_quest(quest: Quest) -> bool:
	if not quest or quest.quest_id.is_empty():
		push_error("[QuestSystem] Cannot add quest without valid ID")
		return false
	
	if quests.has(quest.quest_id):
		push_warning("[QuestSystem] Quest with ID '%s' already exists" % quest.quest_id)
		return false
	
	quest.initialize()
	quests[quest.quest_id] = quest
	active_quests.append(quest)
	
	quest_added.emit(quest)
	print("[QuestSystem] Added quest: %s" % quest.quest_name)
	
	return true

## Add a quest by resource path
func add_quest_by_path(path: String) -> bool:
	if not ResourceLoader.exists(path):
		push_error("[QuestSystem] Quest resource not found: %s" % path)
		return false
	
	var quest = load(path) as Quest
	if not quest:
		push_error("[QuestSystem] Failed to load quest from: %s" % path)
		return false
	
	return add_quest(quest)

## Add a quest by ID (searches common paths)
func add_quest_by_id(quest_id: String) -> bool:
	var paths = [
		"res://resources/quests/%s.tres" % quest_id,
		"res://resources/quests/%s.resource" % quest_id,
		"res://quests/%s.tres" % quest_id
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			return add_quest_by_path(path)
	
	push_error("[QuestSystem] Quest not found: %s" % quest_id)
	return false

## Remove a quest
func remove_quest(quest: Quest) -> void:
	if not quest:
		return
	
	if quest.quest_id in quests:
		quests.erase(quest.quest_id)
	
	active_quests.erase(quest)
	completed_quests.erase(quest)
	failed_quests.erase(quest)
	
	quest_removed.emit(quest)
	print("[QuestSystem] Removed quest: %s" % quest.quest_name)

## Complete a quest
func complete_quest(quest: Quest) -> void:
	if not quest or not quest.quest_id in quests:
		return
	
	quest.complete_quest()
	active_quests.erase(quest)
	completed_quests.append(quest)
	
	quest_completed.emit(quest)
	print("[QuestSystem] Completed quest: %s" % quest.quest_name)

## Fail a quest
func fail_quest(quest: Quest) -> void:
	if not quest or not quest.quest_id in quests:
		return
	
	quest.fail_quest()
	active_quests.erase(quest)
	failed_quests.append(quest)
	
	quest_removed.emit(quest)
	print("[QuestSystem] Failed quest: %s" % quest.quest_name)

## Update progress for all active quests based on condition type
func update_progress(type: QuestPointCondition.ConditionType, target_key: String, amount: float = 1.0) -> void:
	for quest in active_quests:
		var old_point = quest.current_point_index
		var state = quest.update_progress(type, target_key, amount)
		
		if state != QuestPoint.QuestState.NO:
			_notify_quest_progress(quest, state)
			
			# Emit signal if point changed
			if quest.current_point_index != old_point:
				quest_progress_updated.emit(quest, quest.current_point_index)

## Update all active quests
func _update_all_quests() -> void:
	for quest in active_quests:
		var state = quest.evaluate()
		
		match state:
			QuestPoint.QuestState.PROGRESS:
				_notify_quest_progress(quest, state)
			QuestPoint.QuestState.DONE:
				_notify_quest_progress(quest, state)
			QuestPoint.QuestState.YES:
				_notify_quest_progress(quest, state)
			QuestPoint.QuestState.FAIL:
				_notify_quest_progress(quest, state)

## Show notification for quest progress
func _notify_quest_progress(quest: Quest, state: QuestPoint.QuestState) -> void:
	quest_state_changed.emit(quest, state)
	
	# Create notification UI if we have a scene
	if _notification_scene and quest_log_ui:
		var notification = _notification_scene.instantiate()
		quest_log_ui.add_child(notification)
		
		if notification.has_method("initialize"):
			notification.initialize(quest, state)

## Get quest by ID
func get_quest(quest_id: String) -> Quest:
	if quest_id in quests:
		return quests[quest_id]
	return null

## Get all active quests sorted by priority
func get_sorted_active_quests() -> Array:
	var sorted = active_quests.duplicate()
	sorted.sort_custom(func(a, b): return a.priority > b.priority)
	return sorted

## Get all completed quests
func get_completed_quests() -> Array:
	return completed_quests

## Get all failed quests
func get_failed_quests() -> Array:
	return failed_quests

## Check if player has a specific quest
func has_quest(quest_id: String) -> bool:
	return quest_id in quests

## Check if quest is active
func is_quest_active(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	return quest != null and quest.is_active

## Check if quest is completed
func is_quest_completed(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	return quest != null and quest.is_complete

## Get save data for all quests
func get_save_data() -> Dictionary:
	var data := {
		"active_quests": [],
		"completed_quests": [],
		"failed_quests": []
	}
	
	for quest in active_quests:
		data["active_quests"].append(quest.get_save_data())
	
	for quest in completed_quests:
		data["completed_quests"].append(quest.get_save_data())
	
	for quest in failed_quests:
		data["failed_quests"].append(quest.get_save_data())
	
	return data

## Load quests from save data
func load_save_data(data: Dictionary) -> void:
	# Clear existing quests
	quests.clear()
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
	
	# This will be populated when quests are re-added
	if data.has("active_quests"):
		pass  # Quests need to be re-loaded from resources
	
	if data.has("completed_quests"):
		for quest_data in data["completed_quests"]:
			var quest_id = quest_data.get("quest_id", "")
			if not quest_id.is_empty():
				# Mark as completed but don't add to active list
				var quest = _load_quest_stub(quest_id)
				if quest:
					quest.load_save_data(quest_data)
					quests[quest_id] = quest
					completed_quests.append(quest)
	
	if data.has("failed_quests"):
		for quest_data in data["failed_quests"]:
			var quest_id = quest_data.get("quest_id", "")
			if not quest_id.is_empty():
				var quest = _load_quest_stub(quest_id)
				if quest:
					quest.load_save_data(quest_data)
					quests[quest_id] = quest
					failed_quests.append(quest)

func _load_quest_stub(quest_id: String) -> Quest:
	var paths = [
		"res://resources/quests/%s.tres" % quest_id,
		"res://resources/quests/%s.resource" % quest_id
	]
	
	for path in paths:
		if ResourceLoader.exists(path):
			var quest = load(path) as Quest
			if quest:
				return quest.duplicate()
	
	return null

## Reset all quests
func reset_all_quests() -> void:
	for quest in quests.values():
		quest.reset()
	
	quests.clear()
	active_quests.clear()
	completed_quests.clear()
	failed_quests.clear()
