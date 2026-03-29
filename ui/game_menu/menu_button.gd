extends Button

@export var menu_path: String
@onready var display = $"../../display_category"
@export var id: int

func change_menu() -> void:
	$"../../../..".layer_down = 1
	
	for c in display.get_children():
		c.queue_free()
			
	if menu_path != "":
		display.add_child(load(menu_path).instantiate())

			
