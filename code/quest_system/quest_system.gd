@icon("res://icon.svg")
extends Node
## QuestSystem Autoload - Central manager for all quest operations
## 
## Features:
## - 1.0s evaluation loop (no _process polling)
## - Scene-agnostic trigger registration via signals
## - UI tween controller for quest notifications
## - Save/load integration

signal quest_added(quest: Quest)
signal quest_removed(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal quest_progress_updated(quest: Quest, step_index: int, point_index: int)
signal quest_ui_notification(quest: Quest, state: QuestPoint.QuestState, message: String)

# Custom condition/effect signals for extensibility
signal custom_condition_evaluated(condition: QuestPointCondition)
signal custom_effect_executed(effect: QuestEffect)
signal dialogue_requested(dialogue_id: String)
signal cutscene_requested(scene_path: String)
signal scene_change_requested(scene_path: String)
signal await_trigger(trigger_id: String)

const EVALUATION_INTERVAL := 1.0
const SAVE_KEY_QUESTS := "active_quests"
const SAVE_KEY_COMPLETED := "completed_quests"

var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var quest_templates: Dictionary = {}  ## Maps quest_name -> Resource path

var _evaluation_running := false
var _ui_tween: Tween = null
var _notification_queue: Array[Dictionary] = []
var _debug_mode := false

## Reference to quest log UI (set by game_menu)
var quest_log_ui: Control = null

func _ready() -> void:
	_start_evaluation_loop()
	_connect_scene_triggers()
	_print_debug("QuestSystem initialized")

func _start_evaluation_loop() -> void:
	_evaluation_running = true
	_evaluate_quests_loop()

func _evaluate_quests_loop() -> void:
	while _evaluation_running:
		await get_tree().create_timer(EVALUATION_INTERVAL).timeout
		_evaluate_all_quests()

func _evaluate_all_quests() -> void:
	var quests_to_complete: Array[Quest] = []
	
	for quest in active_quests:
		if not quest or not quest.is_active:
			continue
		
		var was_state = quest.state
		var is_complete = quest.evaluate()
		
		# Handle state transitions
		if quest.state != was_state:
			_on_quest_state_changed(quest, was_state, quest.state)
		
		if is_complete and not quest.is_completed:
			quests_to_complete.append(quest)
	
	# Complete quests after evaluation to avoid modification during iteration
	for quest in quests_to_complete:
		_complete_quest_internal(quest)

func _on_quest_state_changed(quest: Quest, old_state: QuestPoint.QuestState, new_state: QuestPoint.QuestState) -> void:
	match new_state:
		QuestPoint.QuestState.PROGRESS:
			_queue_ui_notification(quest, new_state, "Quest progressing...")
		QuestPoint.QuestState.DONE:
			_queue_ui_notification(quest, new_state, "Objective complete!")
		QuestPoint.QuestState.FAIL:
			_queue_ui_notification(quest, new_state, "Quest failed!")
		QuestPoint.QuestState.YES:
			if quest.is_completed:
				_queue_ui_notification(quest, new_state, "Quest complete!")
	
	quest_progress_updated.emit(quest, quest.current_step_index, 
		quest.get_current_step().current_point_index if quest.get_current_step() else 0)

func _queue_ui_notification(quest: Quest, state: QuestPoint.QuestState, message: String) -> void:
	_notification_queue.append({
		"quest": quest,
		"state": state,
		"message": message
	})
	_process_notification_queue()

func _process_notification_queue() -> void:
	if _notification_queue.is_empty():
		return
	
	# Only show one notification at a time
	var notif = _notification_queue.pop_front()
	_show_quest_notification(notif.quest, notif.state, notif.message)

func _show_quest_notification(quest: Quest, state: QuestPoint.QuestState, message: String) -> void:
	quest_ui_notification.emit(quest, state, message)
	
	# If quest_log_ui is set, it can handle displaying the notification
	if quest_log_ui and quest_log_ui.has_method("show_notification"):
		quest_log_ui.show_notification(quest, state, message)

## Add a quest to the active list
func add_quest(quest: Quest, from_save := false) -> bool:
	if not quest:
		push_error("[QuestSystem] Attempted to add null quest")
		return false
	
	# Check if already active
	for existing in active_quests:
		if existing.unique_id == quest.unique_id:
			_print_debug("Quest '%s' already active" % quest.quest_name)
			return false
	
	quest.initialize()
	active_quests.append(quest)
	
	_print_debug("Added quest: %s" % quest.quest_name)
	quest_added.emit(quest)
	
	return true

## Remove a quest (without completing)
func remove_quest(quest: Quest) -> void:
	if quest in active_quests:
		active_quests.erase(quest)
		quest_removed.emit(quest)
		_print_debug("Removed quest: %s" % quest.quest_name)

## Complete a quest
func complete_quest(quest: Quest) -> void:
	if quest in active_quests:
		_complete_quest_internal(quest)

func _complete_quest_internal(quest: Quest) -> void:
	quest.complete()
	active_quests.erase(quest)
	completed_quests.append(quest)
	_print_debug("Completed quest: %s" % quest.quest_name)

## Fail a quest
func fail_quest(quest: Quest) -> void:
	if quest in active_quests:
		quest.fail()
		active_quests.erase(quest)

## Get quest by unique ID
func get_quest_by_id(unique_id: String) -> Quest:
	for quest in active_quests:
		if quest.unique_id == unique_id:
			return quest
	for quest in completed_quests:
		if quest.unique_id == unique_id:
			return quest
	return null

## Get active quests filtered by category
func get_quests_by_category(category: String) -> Array[Quest]:
	var filtered: Array[Quest] = []
	for quest in active_quests:
		if quest.category == category:
			filtered.append(quest)
	return filtered

## Get all active quests sorted by priority
func get_sorted_active_quests() -> Array[Quest]:
	var sorted = active_quests.duplicate()
	sorted.sort_custom(func(a, b): return a.priority > b.priority)
	return sorted

## Register scene triggers - called by scenes to hook into quest system
func register_scene_triggers(trigger_map: Dictionary) -> void:
	## trigger_map format: { "trigger_name": Callable }
	## Scenes call this to register their custom triggers
	for trigger_name in trigger_map:
		_print_debug("Registered trigger: %s" % trigger_name)

## Progress a specific condition type - scene-agnostic update method
func progress_condition(type: QuestPointCondition.ConditionType, key: String, amount: float = 1.0) -> void:
	for quest in active_quests:
		if not quest.is_active:
			continue
		var step = quest.get_current_step()
		if not step:
			continue
		var point = step.get_current_point()
		if not point:
			continue
		
		for condition in point.conditions:
			if condition.type == type and condition.target_key == key:
				var old_ratio = condition.get_progress_ratio()
				condition.progress_current += amount
				var new_ratio = condition.get_progress_ratio()
				
				if new_ratio > old_ratio and new_ratio <= 1.0:
					_print_debug("Progressed %s [%s]: %.1f -> %.1f" % [
						QuestPointCondition.ConditionType.keys()[type], 
						key, 
						old_ratio * 100, 
						new_ratio * 100
					])

## Connect to global events for automatic progress tracking
func _connect_scene_triggers() -> void:
	# These would connect to your existing game systems
	# Example connections (adapt to your actual signals):
	
	# Item pickup
	if PlayerStats and PlayerStats.has_signal("item_added"):
		PlayerStats.item_added.connect(_on_item_added)
	
	# Battle completion
	if Global and Global.has_signal("battle_won"):
		Global.battle_won.connect(_on_battle_won)
	
	# Dialogue completion (implement in your dialogue system)
	# dialogue_system.dialogue_completed.connect(_on_dialogue_completed)

func _on_item_added(item: Item, count: int) -> void:
	if item and item.item_name:
		progress_condition(QuestPointCondition.ConditionType.HAS_ITEM, item.item_name, float(count))

func _on_battle_won(battle: Battle) -> void:
	if battle and battle.battle_name:
		progress_condition(QuestPointCondition.ConditionType.BATTLE_WON, battle.battle_name, 1.0)

## Save/Load Integration
func get_save_data() -> Dictionary:
	var active_data: Array[Dictionary] = []
	for quest in active_quests:
		active_data.append(quest.to_dict())
	
	var completed_data: Array[String] = []
	for quest in completed_quests:
		completed_data.append(quest.unique_id)
	
	return {
		SAVE_KEY_QUESTS: active_data,
		SAVE_KEY_COMPLETED: completed_data
	}

func load_save_data(data: Dictionary) -> void:
	# Clear existing
	active_quests.clear()
	completed_quests.clear()
	
	# Load completed quest IDs
	var completed_ids: Array[String] = data.get(SAVE_KEY_COMPLETED, [])
	for id in completed_ids:
		# Track as completed (full quest data not needed for completed)
		var dummy_quest = Quest.new()
		dummy_quest.unique_id = id
		dummy_quest.is_completed = true
		completed_quests.append(dummy_quest)
	
	# Load active quests
	var active_data: Array[Dictionary] = data.get(SAVE_KEY_QUESTS, [])
	for quest_data in active_data:
		var quest_name = quest_data.get("quest_name", "")
		
		# Find template resource
		var template = _find_quest_template(quest_name)
		if not template:
			_print_debug("Warning: Could not find template for quest '%s'" % quest_name)
			continue
		
		# Create instance and restore state
		var quest = template.duplicate()
		_restore_quest_state(quest, quest_data)
		active_quests.append(quest)
	
	_print_debug("Loaded %d active quests, %d completed" % [active_quests.size(), completed_quests.size()])

func _restore_quest_state(quest: Quest, data: Dictionary) -> void:
	quest.unique_id = data.get("unique_id", "")
	quest.is_active = data.get("is_active", false)
	quest.is_completed = data.get("is_completed", false)
	quest.current_step_index = data.get("current_step_index", 0)
	quest.times_completed = data.get("times_completed", 0)
	quest.state = data.get("state", QuestPoint.QuestState.NO)
	
	# Restore step/point/condition state
	var steps_data: Array = data.get("steps_data", [])
	for i in range(min(steps_data.size(), quest.steps.size())):
		var step_data = steps_data[i]
		var step = quest.steps[i]
		step.current_point_index = step_data.get("current_point_index", 0)
		
		# Restore condition progress
		var points_data: Array = step_data.get("points_data", [])
		for j in range(min(points_data.size(), step.points.size())):
			var point_data = points_data[j]
			var point = step.points[j]
			point.state = point_data.get("state", QuestPoint.QuestState.NO)
			
			var conditions_data: Array = point_data.get("conditions_data", [])
			for k in range(min(conditions_data.size(), point.conditions.size())):
				var cond_data = conditions_data[k]
				var condition = point.conditions[k]
				condition.progress_current = cond_data.get("progress_current", 0.0)
				condition.progress_target = cond_data.get("progress_target", 1.0)

func _find_quest_template(quest_name: String) -> Quest:
	# Search loaded templates first
	for key in quest_templates:
		if key == quest_name:
			var path = quest_templates[key]
			return load(path) as Quest
	
	# Try loading from standard path
	var path = "res://resources/quests/%s.tres" % quest_name.replace(" ", "_").to_lower()
	if ResourceLoader.exists(path):
		return load(path) as Quest
	
	return null

## Debug utilities
func set_debug_mode(enabled: bool) -> void:
	_debug_mode = enabled

func _print_debug(message: String) -> void:
	if _debug_mode:
		print("[QuestSystem] %s" % message)

func get_debug_info() -> Dictionary:
	return {
		"active_count": active_quests.size(),
		"completed_count": completed_quests.size(),
		"evaluation_running": _evaluation_running,
		"queued_notifications": _notification_queue.size()
	}

## Cleanup on scene change
func _notification_cleanup() -> void:
	if _ui_tween and _ui_tween.is_valid():
		_ui_tween.kill()
	_ui_tween = null

func _exit_tree() -> void:
	_evaluation_running = false
	_notification_cleanup()
