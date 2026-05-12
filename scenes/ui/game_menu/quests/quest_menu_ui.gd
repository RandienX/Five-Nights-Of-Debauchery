extends Control
class_name QuestMenuUI
## QuestMenuUI - Main container for quest display in game_menu
##
## This script manages the quest menu tab, instantiating quest items
## and connecting to QuestSystem signals.

signal quest_tab_opened()
signal quest_tab_closed()

@onready var quest_container: VBoxContainer = %QuestContainer if has_node("%QuestContainer") else null

var _quest_items: Dictionary = {}  ## Maps unique_id -> UI item
var _is_initialized := false

func _ready() -> void:
	_connect_to_quest_system()

func _connect_to_quest_system() -> void:
	if QuestSystem:
		QuestSystem.quest_added.connect(_on_quest_added)
		QuestSystem.quest_removed.connect(_on_quest_removed)
		QuestSystem.quest_completed.connect(_on_quest_completed)
		QuestSystem.quest_progress_updated.connect(_on_quest_progress_updated)

		# Set reference for notifications
		if not QuestSystem.quest_log_ui:
				QuestSystem.quest_log_ui = self

func _disconnect_from_quest_system() -> void:
	if QuestSystem:
		if QuestSystem.quest_added.is_connected(_on_quest_added):
			QuestSystem.quest_added.disconnect(_on_quest_added)
		if QuestSystem.quest_removed.is_connected(_on_quest_removed):
			QuestSystem.quest_removed.disconnect(_on_quest_removed)
		if QuestSystem.quest_completed.is_connected(_on_quest_completed):
			QuestSystem.quest_completed.disconnect(_on_quest_completed)
		if QuestSystem.quest_progress_updated.is_connected(_on_quest_progress_updated):
			QuestSystem.quest_progress_updated.disconnect(_on_quest_progress_updated)

## Refresh the quest list - call when tab opens
func refresh_quest_list() -> void:
	_clear_quest_list()

	if not quest_container:
		return

	for quest in QuestSystem.get_sorted_active_quests():
		_create_quest_item(quest)

	quest_tab_opened.emit()

func _clear_quest_list() -> void:
	if quest_container:
		for child in quest_container.get_children():
			child.queue_free()
	_quest_items.clear()

func _create_quest_item(quest: Quest) -> void:
	if not quest_container:
		return

	# Load the quest item scene
	var quest_item_scene = load("res://scenes/ui/game_menu/quests/quest.tscn")
	if not quest_item_scene:
		push_error("[QuestMenuUI] Failed to load quest.tscn")
		return

	var item = quest_item_scene.instantiate()
	quest_container.add_child(item)
	_quest_items[quest.unique_id] = item

	# Initialize the quest item with data
	if item.has_method("initialize"):
		item.initialize(quest)

	# Store quest reference
	item.set_meta("quest", quest)

## Event handlers
func _on_quest_added(quest: Quest) -> void:
	if is_visible_in_tree():
		_create_quest_item(quest)

func _on_quest_removed(quest: Quest) -> void:
	if quest.unique_id in _quest_items:
		var item = _quest_items[quest.unique_id]
		if item:
			item.queue_free()
		_quest_items.erase(quest.unique_id)

func _on_quest_completed(quest: Quest) -> void:
	_on_quest_removed(quest)

func _on_quest_progress_updated(quest: Quest, step_index: int, point_index: int) -> void:
	if quest.unique_id in _quest_items:
		var item = _quest_items[quest.unique_id]
		if item and item.has_method("update_progress"):
			item.update_progress(quest, step_index, point_index)

func _on_tab_opened() -> void:
	refresh_quest_list()

func _on_tab_closed() -> void:
	quest_tab_closed.emit()

func _exit_tree() -> void:
	_disconnect_from_quest_system()
