extends RefCounted

func check_entry(index: int, textbox: Control) -> bool:
	if index == 0:
		return true
	
	if index == 1:
		var flag = Global.tb_get_flag("item_done", false)
		if flag:
			return Global.tb_has_item("res://resources/items/consumables/attack_item.tres", 1)
		return false
	
	if index == 2:
		var flag = Global.tb_get_flag("item_not_done", false)
		if flag:
			return true
		return false
	
	return true

func get_choice_target(index: int, choice_index: int, textbox: Control) -> int:
	if index == 0:
		if choice_index == 0 and not Global.tb_has_item("res://resources/items/consumables/attack_item.tres", 1):
			return 2
		return 1
	return index + 1

func set_choice_flags(index: int, choice_index: int, textbox: Control) -> void:
	if index == 0:
		if choice_index == 0:
			if Global.tb_has_item("res://resources/items/consumables/attack_item.tres", 1):
				Global.tb_set_flag("item_done", true)
				Global.tb_set_flag("item_not_done", false)
			else:
				Global.tb_set_flag("item_done", false)
				Global.tb_set_flag("item_not_done", true)
		if choice_index == 1:
			Global.tb_set_flag("item_done", false)
			Global.tb_set_flag("item_not_done", true)

func on_entry_show(index: int, textbox: Control) -> void:
	if index == 1:
		Global.tb_remove_item("res://resources/items/consumables/attack_item.tres", 1)
		
