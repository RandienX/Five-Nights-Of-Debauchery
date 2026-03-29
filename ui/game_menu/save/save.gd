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
	if save_data["exists"] == true:
		$texture/margin/vbox/text/savename.text = save_data["name"]
		$texture/margin/vbox/text/time.text = Save.format_time(save_data["time"])
		if "current_scene" in save_data["global_data"].keys():
			if load(save_data["global_data"]["current_scene"]).instantiate().room_name:
				$texture/margin/vbox/roomname.text = load(save_data["global_data"]["current_scene"]).instantiate().room_name
		else:
			$texture/margin/vbox/roomname.text = "Err - Error"
