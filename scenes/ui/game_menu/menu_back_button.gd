extends Button

@export var id: int

func back() -> void:
	$"../../../..".visible = false
	$"../../../../../../..".stop_move = true
