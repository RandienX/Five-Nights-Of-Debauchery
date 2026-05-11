@icon("res://icon.svg")
extends Control
## QuestLogUI - Display and manage quests in the game menu
## 
## Attach this to a Control node in your game_menu scene.
## Expects structure:
## - QuestList (VBoxContainer) - List of quest items
## - QuestDetail (Panel) - Selected quest details
## - NotificationOverlay (Control) - For popup notifications

signal quest_selected(quest: Quest)
signal quest_tab_opened()
signal quest_tab_closed()

@export var quest_item_scene: PackedScene = null  ## Optional custom quest item scene

@onready var quest_list: VBoxContainer = %QuestList if has_node("%QuestList") else null
@onready var quest_detail: Panel = %QuestDetail if has_node("%QuestDetail") else null
@onready var notification_overlay: Control = %NotificationOverlay if has_node("%NotificationOverlay") else null

var _quest_items: Dictionary = {}  ## Maps quest unique_id -> UI item
var _selected_quest: Quest = null
var _notification_tween: Tween = null

func _ready() -> void:
	_connect_to_quest_system()
	_refresh_quest_list()

func _connect_to_quest_system() -> void:
	if QuestSystem:
		QuestSystem.quest_added.connect(_on_quest_added)
		QuestSystem.quest_removed.connect(_on_quest_removed)
		QuestSystem.quest_completed.connect(_on_quest_completed)
		QuestSystem.quest_progress_updated.connect(_on_quest_progress_updated)
		QuestSystem.quest_ui_notification.connect(_on_quest_notification)
		
		# Set reference for notifications
		QuestSystem.quest_log_ui = self

func _disconnect_from_quest_system() -> void:
	if QuestSystem:
		QuestSystem.quest_added.disconnect(_on_quest_added)
		QuestSystem.quest_removed.disconnect(_on_quest_removed)
		QuestSystem.quest_completed.disconnect(_on_quest_completed)
		QuestSystem.quest_progress_updated.disconnect(_on_quest_progress_updated)
		QuestSystem.quest_ui_notification.disconnect(_on_quest_notification)

func _refresh_quest_list() -> void:
	_clear_quest_list()
	
	if not quest_list:
		return
	
	for quest in QuestSystem.get_sorted_active_quests():
		_create_quest_item(quest)

func _clear_quest_list() -> void:
	if quest_list:
		for child in quest_list.get_children():
			child.queue_free()
	_quest_items.clear()

func _create_quest_item(quest: Quest) -> void:
	if not quest_list:
		return
	
	var item: Control
	
	if quest_item_scene:
		item = quest_item_scene.instantiate()
	else:
		item = _create_default_quest_item(quest)
	
	quest_list.add_child(item)
	_quest_items[quest.unique_id] = item
	
	# Store quest reference
	if item.has_meta("quest"):
		item.set_meta("quest", quest)
	
	# Connect selection
	if item is Button:
		item.pressed.connect(_on_quest_item_pressed.bind(quest))
	elif item.has_signal("gui_input"):
		item.gui_input.connect(_on_quest_item_gui_input.bind(quest, item))

func _create_default_quest_item(quest: Quest) -> Button:
	var button = Button.new()
	button.text = quest.quest_name
	button.name = "QuestItem_" + quest.quest_name.replace(" ", "_")
	
	# Add progress label
	var hbox = HBoxContainer.new()
	hbox.add_child(button)
	
	var progress_label = Label.new()
	progress_label.name = "ProgressLabel"
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hbox.add_child(progress_label)
	
	# Custom minimum size
	button.custom_minimum_size = Vector2(200, 40)
	
	return button

func _on_quest_item_pressed(quest: Quest) -> void:
	_select_quest(quest)

func _on_quest_item_gui_input(event: InputEvent, quest: Quest, item: Control) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_quest(quest)

func _select_quest(quest: Quest) -> void:
	_selected_quest = quest
	_update_quest_detail(quest)
	quest_selected.emit(quest)
	
	# Update visual selection
	for uid in _quest_items:
		var item = _quest_items[uid]
		if item and item.has_method("set_selected"):
			item.set_selected(item.get_meta("quest") == quest)

func _update_quest_detail(quest: Quest) -> void:
	if not quest_detail:
		return
	
	# Clear existing detail content
	for child in quest_detail.get_children():
		if child.name != "Background":  # Keep background
			child.queue_free()
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	quest_detail.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	# Quest name
	var name_label = Label.new()
	name_label.text = quest.quest_name
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)
	
	# Category
	var category_label = Label.new()
	category_label.text = "[%s]" % quest.category
	category_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(category_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = quest.description
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(desc_label)
	
	# Progress bar
	var progress_container = VBoxContainer.new()
	vbox.add_child(progress_container)
	
	var progress_label = Label.new()
	progress_label.text = "Progress: %.0f%%" % (quest.get_progress_ratio() * 100)
	progress_container.add_child(progress_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.value = quest.get_progress_ratio() * 100
	progress_bar.custom_minimum_size = Vector2(200, 20)
	progress_container.add_child(progress_bar)
	
	# Current step
	if quest.get_current_step():
		var step_label = Label.new()
		step_label.text = "Current: " + quest.get_current_step().step_name
		step_label.add_theme_color_override("font_color", Color.YELLOW)
		vbox.add_child(step_label)

## Show notification popup
func show_notification(quest: Quest, state: QuestPoint.QuestState, message: String) -> void:
	if not notification_overlay:
		return
	
	# Create or reuse notification label
	var notification: Label
	if notification_overlay.has_node("NotificationLabel"):
		notification = notification_overlay.get_node("NotificationLabel")
	else:
		notification = Label.new()
		notification.name = "NotificationLabel"
		notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		notification.add_theme_font_size_override("font_size", 20)
		notification_overlay.add_child(notification)
	
	# Set color based on state
	match state:
		QuestPoint.QuestState.PROGRESS:
			notification.add_theme_color_override("font_color", Color.WHITE)
		QuestPoint.QuestState.DONE:
			notification.add_theme_color_override("font_color", Color.LIME_GREEN)
		QuestPoint.QuestState.FAIL:
			notification.add_theme_color_override("font_color", Color.RED)
		QuestPoint.QuestState.YES:
			notification.add_theme_color_override("font_color", Color.GOLD)
	
	notification.text = "[b]%s[/b]\n%s" % [quest.quest_name, message]
	
	# Cancel existing tween
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	
	_notification_tween = create_tween()
	
	# Fade in, wait, fade out
	notification.modulate.a = 0
	_notification_tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	_notification_tween.tween_interval(2.0)
	_notification_tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	_notification_tween.tween_callback(notification.queue_free)

## Event handlers
func _on_quest_added(quest: Quest) -> void:
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
		if item and item.has_node("ProgressLabel"):
			item.get_node("ProgressLabel").text = "%.0f%%" % (quest.get_progress_ratio() * 100)
	
	# Update detail view if this is selected quest
	if _selected_quest and _selected_quest.unique_id == quest.unique_id:
		_update_quest_detail(quest)

func _on_quest_notification(quest: Quest, state: QuestPoint.QuestState, message: String) -> void:
	show_notification(quest, state, message)

## Open/close callbacks
func _on_tab_opened() -> void:
	_refresh_quest_list()
	quest_tab_opened.emit()

func _on_tab_closed() -> void:
	quest_tab_closed.emit()

func _exit_tree() -> void:
	_disconnect_from_quest_system()
