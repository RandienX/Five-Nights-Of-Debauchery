extends Node
## QuestNotificationManager.gd
## Autoloaded singleton that manages global quest/achievement notifications
## using a scaled-down version of the existing QuestLogUI scene.

signal notification_shown(quest_name: String)

const QuestLogUIScene = preload("res://scenes/ui/game_menu/quests/quest_menu.tscn")
const MAX_VISIBLE_NOTIFICATIONS := 3
const NOTIFICATION_DURATION := 2.5
const SPAWN_OFFSET := Vector2(20, 20) # Top-right offset

var _notification_queue: Array[Dictionary] = []
var _active_notifications: Array[Node] = []
var _canvas_layer: CanvasLayer

func _ready() -> void:
		# Create a dedicated CanvasLayer for notifications so they appear over everything
		_canvas_layer = CanvasLayer.new()
		_canvas_layer.layer = 100 # High layer to be on top
		add_child(_canvas_layer)

		# Connect to QuestSystem and AchievementSystem signals
		if QuestSystem:
				QuestSystem.show_quest_notification_signal.connect(_on_quest_notification)
		if AchievementSystem:
				AchievementSystem.show_achievement_notification_overlay_signal.connect(_on_achievement_notification)

func _on_quest_notification(quest_name: String, point_name: String, progress_current: float, progress_target: float, state: int) -> void:
		# Get the quest resource to pass to the notification
		var quest_template = QuestSystem.get_quest_template(quest_name)
		show_quest_notification(quest_template, state)

func _on_achievement_notification(achievement_name: String, description: String, icon: Texture2D, is_secret: bool) -> void:
		# Find the achievement by name (or iterate to find matching)
		var achievement = null
		if AchievementSystem:
				# Try to find by iterating achievements
				for ach in AchievementSystem.get_all_achievements():
						if ach.achievement_name == achievement_name:
								achievement = ach
								break
		show_achievement_notification(achievement, true) # unlocked = true for notifications

func show_quest_notification(quest_data: Resource, state: int) -> void:
		var notif_data := {
				"type": "quest",
				"data": quest_data,
				"state": state,
				"title": quest_data.quest_name if quest_data else "Quest Update",
				"subtitle": _get_state_text(state),
				"color": _get_state_color(state)
		}
		_queue_notification(notif_data)

func show_achievement_notification(achievement_data: Resource, unlocked: bool) -> void:
		var notif_data := {
				"type": "achievement",
				"data": achievement_data,
				"state": 3 if unlocked else 0, # 3 = YES/Complete
				"title": "Achievement Unlocked!" if unlocked else "Achievement Update",
				"subtitle": achievement_data.achievement_name if achievement_data else "",
				"color": Color.GOLD if unlocked else Color.WHITE
		}
		_queue_notification(notif_data)

func _queue_notification(data: Dictionary) -> void:
		_notification_queue.push_back(data)
		_update_notifications()

func _update_notifications() -> void:
		# Fill up to MAX_VISIBLE
		while _active_notifications.size() < MAX_VISIBLE_NOTIFICATIONS and _notification_queue.size() > 0:
				var data = _notification_queue.pop_front()
				_spawn_notification(data)

func _spawn_notification(data: Dictionary) -> void:
		# Instantiate the QuestLogUI scene to reuse its visuals
		var popup_instance: Control = QuestLogUIScene.instantiate()
		_canvas_layer.add_child(popup_instance)

		# Configure as a mini-notification
		_configure_as_mini(popup_instance, data)

		_active_notifications.push_back(popup_instance)

		# Animate In
		var tween := create_tween()
		popup_instance.position = Vector2(get_viewport().get_visible_rect().size.x + 20, SPAWN_OFFSET.y + (_active_notifications.size() - 1) * 90)
		tween.tween_property(popup_instance, "position", Vector2(get_viewport().get_visible_rect().size.x - popup_instance.size.x - 20, SPAWN_OFFSET.y + (_active_notifications.size() - 1) * 90), 0.3).set_ease(Tween.EASE_OUT)

		# Schedule Removal
		await get_tree().create_timer(NOTIFICATION_DURATION).timeout
		_dismiss_notification(popup_instance)

func _dismiss_notification(popup: Node) -> void:
		if not is_instance_valid(popup):
				return

		var target_index := _active_notifications.find(popup)
		if target_index == -1:
				return

		# Animate Out
		var tween := create_tween()
		var start_pos = popup.position
		tween.tween_property(popup, "position", start_pos + Vector2(200, 0), 0.3).set_ease(Tween.EASE_IN)
		tween.tween_callback(popup.queue_free)

		_active_notifications.remove_at(target_index)

		# Shift remaining notifications down
		for i in range(target_index, _active_notifications.size()):
				var n := _active_notifications[i]
				if is_instance_valid(n):
						create_tween().tween_property(n, "position", n.position - Vector2(0, 90), 0.3)

		# Process queue
		_update_notifications()

func _configure_as_mini(popup: Control, data: Dictionary) -> void:
		popup.scale = Vector2(0.75, 0.75) # Scaled down size
		popup.size_flags_horizontal = Control.SIZE_EXPAND
		popup.size_flags_vertical = Control.SIZE_EXPAND

		# Try to find and use the NotificationOverlay if it exists
		var notification_overlay := popup.find_child("NotificationOverlay", true, false)
		if notification_overlay:
				notification_overlay.visible = true

				# Create or update notification label inside the overlay
				var notification: Label
				if notification_overlay.has_node("NotificationLabel"):
						notification = notification_overlay.get_node("NotificationLabel")
				else:
						notification = Label.new()
						notification.name = "NotificationLabel"
						notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						notification.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
						notification.add_theme_font_size_override("font_size", 18)
						notification.set_anchors_preset(Control.PRESET_FULL_RECT)
						notification_overlay.add_child(notification)

				# Set color based on state
				var state_color: Color = data["color"]
				notification.add_theme_color_override("font_color", state_color)
				notification.text = "[b]%s[/b]\n%s" % [data["title"], data["subtitle"]]
		else:
				# Fallback: Try to find labels by common names
				var title_label := popup.find_child("TitleLabel", true, false)
				var desc_label := popup.find_child("DescriptionLabel", true, false)
				var progress_bar := popup.find_child("ProgressBar", true, false)

				if title_label: title_label.text = data["title"]
				if desc_label: desc_label.text = data["subtitle"]
				if progress_bar:
						progress_bar.value = 1.0 if data["state"] == 3 else 0.5
						progress_bar.modulate = data["color"]

				# Change background color/modulate to match state
				popup.modulate = data["color"]

func _get_state_text(state: int) -> String:
		match state:
				1: return "Progress Updated"
				2: return "Quest Completed"
				3: return "Quest Finished"
				4: return "Quest Failed"
				_: return "Quest Updated"

func _get_state_color(state: int) -> Color:
		match state:
				1: return Color.WHITE # Progress
				2: return Color.GREEN # Done
				3: return Color.GOLD # Yes/Complete
				4: return Color.RED # Fail
				_: return Color.WHITE
