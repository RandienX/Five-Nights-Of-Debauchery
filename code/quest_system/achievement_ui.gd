@icon("res://icon.svg")
extends Control
## AchievementUI - Display achievements in the game menu
## 
## UI Layout: Icon (top) → ProgressBar (below) → Description (beside)

signal achievement_selected(achievement: Achievement)
signal achievement_tab_opened()
signal achievement_tab_closed()

@export var achievement_item_scene: PackedScene = null

@onready var achievement_list: VBoxContainer = %AchievementList if has_node("%AchievementList") else null
@onready var achievement_detail: Panel = %AchievementDetail if has_node("%AchievementDetail") else null
@onready var notification_overlay: Control = %NotificationOverlay if has_node("%NotificationOverlay") else null

var _achievement_items: Dictionary = {}  ## Maps unique_id -> UI item
var _selected_achievement: Achievement = null
var _notification_tween: Tween = null

func _ready() -> void:
	_connect_to_achievement_system()
	_refresh_achievement_list()

func _connect_to_achievement_system() -> void:
	if AchievementSystem:
		AchievementSystem.achievement_unlocked.connect(_on_achievement_unlocked)
		AchievementSystem.achievement_progress_updated.connect(_on_achievement_progress_updated)
		AchievementSystem.achievement_ui_notification.connect(_on_achievement_notification)
		
		# Set reference for notifications
		AchievementSystem.achievement_ui = self

func _disconnect_from_achievement_system() -> void:
	if AchievementSystem:
		AchievementSystem.achievement_unlocked.disconnect(_on_achievement_unlocked)
		AchievementSystem.achievement_progress_updated.disconnect(_on_achievement_progress_updated)
		AchievementSystem.achievement_ui_notification.disconnect(_on_achievement_notification)

func _refresh_achievement_list() -> void:
	_clear_achievement_list()
	
	if not achievement_list:
		return
	
	for achievement in AchievementSystem.get_all_achievements():
		_create_achievement_item(achievement)

func _clear_achievement_list() -> void:
	if achievement_list:
		for child in achievement_list.get_children():
			child.queue_free()
	_achievement_items.clear()

func _create_achievement_item(achievement: Achievement) -> void:
	if not achievement_list:
		return
	
	var item: Control
	
	if achievement_item_scene:
		item = achievement_item_scene.instantiate()
	else:
		item = _create_default_achievement_item(achievement)
	
	achievement_list.add_child(item)
	_achievement_items[achievement.unique_id] = item
	item.set_meta("achievement", achievement)
	
	# Connect selection
	if item is Button:
		item.pressed.connect(_on_achievement_item_pressed.bind(achievement))

func _create_default_achievement_item(achievement: Achievement) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.name = "AchievementItem_" + achievement.achievement_name.replace(" ", "_")
	hbox.custom_minimum_size = Vector2(300, 60)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(48, 48)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if achievement.icon:
		icon_rect.texture = achievement.icon
	elif achievement.is_unlocked:
		# Default unlocked icon
		icon_rect.modulate = Color.GOLD
	else:
		# Default locked icon (grayed)
		icon_rect.modulate = Color.GRAY
	
	hbox.add_child(icon_rect)
	
	# Info vbox
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)
	
	# Name
	var name_label = Label.new()
	name_label.text = achievement.get_display_info().get("name", "???")
	name_label.add_theme_font_size_override("font_size", 16)
	if not achievement.is_unlocked and achievement.hidden:
		name_label.add_theme_color_override("font_color", Color.GRAY)
	vbox.add_child(name_label)
	
	# Progress bar
	var progress_bar = ProgressBar.new()
	progress_bar.value = achievement.get_progress_ratio() * 100
	progress_bar.custom_minimum_size = Vector2(150, 16)
	vbox.add_child(progress_bar)
	
	return hbox

func _on_achievement_item_pressed(achievement: Achievement) -> void:
	_select_achievement(achievement)

func _select_achievement(achievement: Achievement) -> void:
	_selected_achievement = achievement
	_update_achievement_detail(achievement)
	achievement_selected.emit(achievement)

func _update_achievement_detail(achievement: Achievement) -> void:
	if not achievement_detail:
		return
	
	# Clear existing
	for child in achievement_detail.get_children():
		if child.name != "Background":
			child.queue_free()
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	achievement_detail.add_child(margin)
	
	var hbox = HBoxContainer.new()
	margin.add_child(hbox)
	
	var info = achievement.get_display_info()
	
	# Left side - Icon and progress
	var left_vbox = VBoxContainer.new()
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(left_vbox)
	
	# Icon
	var icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(96, 96)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	if info.has("icon") and info["icon"]:
		icon_rect.texture = info["icon"]
	elif achievement.is_unlocked:
		icon_rect.modulate = Color.GOLD
	else:
		icon_rect.modulate = Color.GRAY
	
	left_vbox.add_child(icon_rect)
	
	# Progress bar
	var progress_label = Label.new()
	progress_label.text = "%.0f%%" % info.get("progress", 0.0)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(progress_label)
	
	var progress_bar = ProgressBar.new()
	progress_bar.value = info.get("progress", 0.0)
	progress_bar.custom_minimum_size = Vector2(120, 24)
	left_vbox.add_child(progress_bar)
	
	# Right side - Description
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_vbox)
	
	# Name
	var name_label = Label.new()
	name_label.text = info.get("name", "Unknown")
	name_label.add_theme_font_size_override("font_size", 24)
	if info.get("is_hidden", false) or info.get("is_secret", false):
		name_label.add_theme_color_override("font_color", Color.GRAY)
	right_vbox.add_child(name_label)
	
	# Category
	var category_label = Label.new()
	category_label.text = "[%s]" % info.get("category", "General")
	category_label.add_theme_color_override("font_color", Color.GRAY)
	right_vbox.add_child(category_label)
	
	# Description
	var desc_label = Label.new()
	desc_label.text = info.get("description", "???")
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	right_vbox.add_child(desc_label)
	
	# Unlock time (if unlocked)
	if achievement.is_unlocked and info.has("unlock_time"):
		var unlock_label = Label.new()
		var datetime = Time.get_datetime_dict_from_unix_time(int(info["unlock_time"]))
		unlock_label.text = "Unlocked: %04d-%02d-%02d" % [datetime.year, datetime.month, datetime.day]
		unlock_label.add_theme_color_override("font_color", Color.LIME_GREEN)
		right_vbox.add_child(unlock_label)

## Show notification popup
func show_notification(achievement: Achievement, message: String) -> void:
	if not notification_overlay:
		return
	
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
	
	notification.add_theme_color_override("font_color", Color.GOLD)
	notification.text = "[b]🏆 Achievement Unlocked![/b]\n%s\n%s" % [achievement.achievement_name, message]
	
	if _notification_tween and _notification_tween.is_valid():
		_notification_tween.kill()
	
	_notification_tween = create_tween()
	
	notification.modulate.a = 0
	_notification_tween.tween_property(notification, "modulate:a", 1.0, 0.3)
	_notification_tween.tween_interval(3.0)  # Longer for achievements
	_notification_tween.tween_property(notification, "modulate:a", 0.0, 0.5)
	_notification_tween.tween_callback(notification.queue_free)

## Event handlers
func _on_achievement_unlocked(achievement: Achievement) -> void:
	# Refresh list to show updated state
	_refresh_achievement_list()
	
	# Update detail if selected
	if _selected_achievement and _selected_achievement.unique_id == achievement.unique_id:
		_update_achievement_detail(achievement)

func _on_achievement_progress_updated(achievement: Achievement, progress: float) -> void:
	if achievement.unique_id in _achievement_items:
		var item = _achievement_items[achievement.unique_id]
		if item:
			# Update progress bar in item
			for child in item.get_children():
				if child is VBoxContainer:
					for subchild in child.get_children():
						if subchild is ProgressBar:
							subchild.value = progress * 100

func _on_achievement_notification(achievement: Achievement, message: String) -> void:
	show_notification(achievement, message)

func _on_tab_opened() -> void:
	_refresh_achievement_list()
	achievement_tab_opened.emit()

func _on_tab_closed() -> void:
	achievement_tab_closed.emit()

func _exit_tree() -> void:
	_disconnect_from_achievement_system()
