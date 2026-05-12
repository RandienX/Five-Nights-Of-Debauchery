extends Node
class_name QuestSystemClass

signal quest_updated(quest: Quest)
signal quest_completed(quest: Quest)
signal notification_requested(title: String, description: String)

var active_quests: Dictionary = {} # String ID -> Quest Instance
var _evaluation_timer: Timer = null

func _ready():
	_evaluation_timer = Timer.new()
	_evaluation_timer.wait_time = 1.0
	_evaluation_timer.timeout.connect(_on_evaluation_tick)
	add_child(_evaluation_timer)
	_evaluation_timer.start()

func _on_evaluation_tick():
	for quest_id in active_quests.keys():
		var quest = active_quests[quest_id]
		if quest.state == Quest.QuestState.DONE:
			# Auto-advance after a brief moment or wait for input? 
			# Spec says: YES -> Advance. Let's assume auto-advance for linear flow 
			# or external trigger. Here we just signal the UI to flash.
			pass 
		# Continuous evaluation handled by progress_condition calls mostly, 
		# but this tick checks for global state changes if needed.

func attach_to_scene(scene: Node):
	# Ensure signals are connected if the scene listens
	if not scene.is_connected("quest_progress_request", _on_progress_request):
		scene.connect("quest_progress_request", _on_progress_request)

func _on_progress_request(quest_id: String, condition_idx: int, amount: float):
	progress_condition(quest_id, condition_idx, amount)

func start_quest(quest_resource: Quest):
	if active_quests.has(quest_resource.quest_id):
		return # Already active
	var quest_instance = quest_resource.duplicate()
	quest_instance.initialize()
	active_quests[quest_instance.quest_id] = quest_instance
	quest_updated.emit(quest_instance)
	notification_requested.emit(quest_instance.quest_name, "Quest Started!")

func progress_condition(quest_id: String, condition_idx: int, amount: float = 1.0):
	if not active_quests.has(quest_id): return
	var quest = active_quests[quest_id]
	if quest._is_completed: return

	if quest.progress_condition(condition_idx, amount):
		quest_updated.emit(quest)
		
		if quest.state == Quest.QuestState.DONE:
			# Visual flash handled by UI listening to updated signal
			# Check if step is fully done to advance
			var step = quest.get_current_step()
			if step and step.evaluate()["complete"]:
				advance_quest(quest_id)

func advance_quest(quest_id: String):
	var quest = active_quests[quest_id]
	if quest.advance_step():
		quest_completed.emit(quest)
		notification_requested.emit(quest.quest_name, "Quest Completed!")
		# Optionally remove or keep as completed
	else:
		quest_updated.emit(quest)
		notification_requested.emit(quest.quest_name, "Step Completed!")

func get_quest(quest_id: String) -> Quest:
	return active_quests.get(quest_id)

func serialize() -> Array:
	var data = []
	for quest in active_quests.values():
		data.append(quest.get_save_data())
	return data

func deserialize(data: Array, quest_library: Dictionary):
	active_quests.clear()
	for entry in data:
		var q_id = entry.get("id")
		if quest_library.has(q_id):
			var res = quest_library[q_id]
			var instance = res.duplicate()
			instance.load_save_data(entry)
			active_quests[q_id] = instance
			quest_updated.emit(instance)
