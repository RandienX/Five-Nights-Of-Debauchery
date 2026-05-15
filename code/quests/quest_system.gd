extends Node
class_name QuestSystemClass
##
## Handles quest tracking, progress updates, and notifications.
## Updates every second and manages quest UI notifications.
## Based on DialogueRunner pattern for consistency.

signal quest_added(quest: Quest)
signal quest_removed(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_progress_updated(quest: Quest, point_index: int)
signal quest_state_changed(quest: Quest, state: QuestPoint.QuestState)

static var instance: QuestSystemClass = null

@export var update_interval: float = 1.0  # Seconds between quest updates

var quests: Dictionary = {}  # quest_id -> Quest
var active_quests: Array[Quest] = []
var completed_quests: Array[Quest] = []
var failed_quests: Array[Quest] = []

var evaluator: QuestConditionEvaluator

# UI reference for notifications
var quest_log_ui: Control = null
var _notification_scene: PackedScene = null
var _update_timer: float = 0.0
var _last_update_time: float = 0.0

func _init():
	instance = self

func _ready() -> void:
	_notification_scene = load("res://scenes/ui/quest_notifications/quest_notification.tscn")
	# Initialize evaluator with game state hooks
	evaluator = QuestConditionEvaluator.new()
	_setup_evaluator_hooks()

func _setup_evaluator_hooks() -> void:
	# Connect evaluator to game systems (similar to DialogueRunner)
	evaluator.has_item_func = _check_has_item
	evaluator.has_status_func = _check_has_status
	evaluator.is_quest_complete_func = _is_quest_completed
	evaluator.is_quest_active_func = _is_quest_active
	evaluator.has_done_dialogue_func = _has_done_dialogue
	evaluator.has_talked_to_npc_func = _has_talked_to_npc
	evaluator.has_won_battle_func = _has_won_battle
	evaluator.has_visited_location_func = _has_visited_location
	evaluator.has_done_thing_func = _has_done_thing

func _process(delta: float) -> void:
	_update_timer += delta

	# Update quests every second
	if _update_timer >= update_interval:
		_update_timer = 0.0
		_update_all_quests()

## Setup evaluator hooks to connect to game systems
func _check_has_item(item_id: String, amount: int) -> bool:
	var player_stats = PlayerStats
	if player_stats and player_stats.has_method("has_item_by_id"):
		var item_resource = _load_resource_by_id(item_id)
		if item_resource:
			return player_stats.has_item_by_id(item_resource, amount)
	return false

func _check_has_status(status_id: String) -> bool:
	# Hook to your status system
	return false

func _is_quest_completed(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	return quest != null and quest.is_complete

func _is_quest_active(quest_id: String) -> bool:
	var quest = get_quest(quest_id)
	return quest != null and quest.is_active

func _has_done_dialogue(dialogue_id: String) -> bool:
	# Hook to dialogue system
	return evaluator.custom_data.get("completed_dialogues", []).has(dialogue_id)

func _has_talked_to_npc(npc_id: String) -> bool:
	# Hook to NPC interaction system
	return evaluator.custom_data.get("talked_npcs", []).has(npc_id)

func _has_won_battle(battle_id: String) -> bool:
	# Hook to battle system
	print("AAAAAAAAAAA")
	return evaluator.custom_data.get("won_battles", []).has(battle_id)

func _has_visited_location(location_id: String) -> bool:
	# Hook to location tracking
	return evaluator.custom_data.get("visited_locations", []).has(location_id)

func _has_done_thing(thing_id: String) -> bool:
	return evaluator.custom_data.get("done_things", {}).get(thing_id, false)

func _load_resource_by_id(resource_id: String) -> Resource:
	var paths = [
	"res://resources/items/%s.tres" % resource_id,
	"res://resources/items/%s.resource" % resource_id,
	"res://items/%s.tres" % resource_id
	]

	for path in paths:
		if ResourceLoader.exists(path):
			return load(path)

	return null

## Add a quest to the system
func add_quest(quest: Quest) -> bool:
	if not quest or quest.quest_id.is_empty():
		push_error("[QuestSystem] Cannot add quest without valid ID")
		return false

	if quests.has(quest.quest_id):
		push_warning("[QuestSystem] Quest with ID '%s' already exists" % quest.quest_id)
		return false

	# Initialize quest with evaluator
	quest.initialize(evaluator)
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

	## Update all active quests using evaluator
func _update_all_quests() -> void:
	# Update evaluator with current game state
	_update_evaluator_state()

	for quest in active_quests:
		var old_point = quest.current_point_index
		var state = quest.evaluate(evaluator)

		match state:
			QuestPoint.QuestState.PROGRESS:
				_notify_quest_progress(quest, state)
			QuestPoint.QuestState.DONE:
				_notify_quest_progress(quest, state)
			QuestPoint.QuestState.YES:
				_notify_quest_progress(quest, state)
			QuestPoint.QuestState.FAIL:
				_notify_quest_progress(quest, state)

		# Emit signal if point changed (auto-advance happened)
		if quest.current_point_index != old_point:
			quest_progress_updated.emit(quest, quest.current_point_index)

## Update evaluator with current game state
func _update_evaluator_state() -> void:
	# Get enemies killed from Global
	evaluator.enemies_killed = Global.get("enemies_killed")

	# Get battle_won from Global (same pattern as enemies_killed)
	evaluator.battle_won = Global.get("battles_won")

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
	if data.has("active_quests"):
		for quest_data in data["active_quests"]:
			var quest_id = quest_data.get("quest_id")
			if not quest_id.is_empty():
				var quest = _load_quest_stub(quest_id)
				if quest:
					quest.initialize_without_reset(evaluator)  # Set up evaluator without resetting state
					quest.load_save_data(quest_data)  # Then overwrite with saved data
					quest.initialize(evaluator)
					quests[quest_id] = quest
					active_quests.append(quest)

	if data.has("completed_quests"):
		for quest_data in data["completed_quests"]:
			var quest_id = quest_data.get("quest_id")
			if not quest_id.is_empty():
				var quest = _load_quest_stub(quest_id)
				if quest:
					quest.initialize_without_reset(evaluator)
					quest.load_save_data(quest_data)
					quests[quest_id] = quest
					completed_quests.append(quest)

	if data.has("failed_quests"):
		for quest_data in data["failed_quests"]:
			var quest_id = quest_data.get("quest_id")
			if not quest_id.is_empty():
				var quest = _load_quest_stub(quest_id)
				if quest:
					quest.initialize_without_reset(evaluator)
					quest.load_save_data(quest_data)
					quests[quest_id] = quest
					failed_quests.append(quest)

func _load_quest_stub(quest_id: String) -> Quest:
	const quest_path = "res://resources/quests/"
	
	var path = "/%s.tres" % [quest_id]
	var quest_folders = DirAccess.get_directories_at(quest_path)
	
	for folder in quest_folders:
		var full_path = quest_path + folder + path
		if ResourceLoader.exists(full_path):
			var quest = load(full_path) as Quest
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
