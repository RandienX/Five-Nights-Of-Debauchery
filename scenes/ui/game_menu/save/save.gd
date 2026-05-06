extends Control

@export var id: int
@onready var save_name = $texture/margin/vbox/text/savename.text

var saving = true

func _ready() -> void:
		display()

func _process(delta: float) -> void:
	save_name = $texture/margin/vbox/text/savename.text
	if saving:
		$Button/NinePatchRect/SaveLoad.text = "Save"
	else:
		$Button/NinePatchRect/SaveLoad.text = "Load"

func _on_button_pressed() -> void:
	if saving:
		Save.save_game(id, save_name)
		display()
	else:
		Save.load_game(id)

func display():
	var save_data = Save.get_slot_info(id)
	if save_data.exists:
		$texture/margin/vbox/text/savename.text = save_data.save_name
		$texture/margin/vbox/text/time.text = Save.format_time(save_data["time_played"])
		var scene_path = save_data["current_scene"]
		if ResourceLoader.exists(scene_path):
			var scene = load(scene_path)
			if scene:
				$texture/margin/vbox/roomname.text = scene.instantiate().room_name
			else:
				$texture/margin/vbox/roomname.text = "Unknown Room"
		else:
			$texture/margin/vbox/roomname.text = "Unknown Room"
