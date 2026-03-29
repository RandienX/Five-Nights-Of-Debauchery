extends Control

@onready var eq_items = $Eq_Items
@onready var party_member: Party = $"../../../../../..".party_member

func change_item_slot(type):
	var item_type
	match type: 
		0: item_type = "head"
		1: item_type = "body"
		2: item_type = "legs"
		3: item_type = "weapon_left"
		4: item_type = "weapon_right"
		5: item_type = "shield"
	
	for c in eq_items.get_children():
		c.queue_free()
	
	add_item_boxes(item_type)
	party_member.equip_stats_change()
	
func add_item_boxes(item_type):
	if item_type in ["weapon_left", "weapon_right"]:
		for i: Item in Global.inventory.keys():
			if i is Item:
				if i.type == 0:
					var kid = load("res://scenes/ui/game_menu/inventory/inventory_item.tscn").instantiate()
					kid.itemBox_type = 1
					kid.item_type = item_type
					kid.party_member = party_member
					eq_items.add_child(kid)
	else:
		for i: Item in Global.inventory.keys():
			if i is Item:
				if i.type == 1:
					var type: String
					match i.type:
						0: type = "head"
						1: type = "body"
						2: type = "legs"
						3: type = "shield"
						
					if type == item_type:
						var kid = load("res://scenes/ui/game_menu/inventory/inventory_item.tscn").instantiate()
						kid.itemBox_type = 1
						kid.item_type = item_type
						kid.item = i
						kid.party_member = party_member
						eq_items.add_child(kid)
				

func equip_item(item, item_type):
	for c in eq_items.get_children():
		c.queue_free()
		
	if item_type:
		if party_member.equipped[item_type] != null:
			party_member.equipped[item_type] = item
			Global.remove_item(item)
		else:
			var temp = party_member.equipped[item_type]
			party_member.equipped[item_type] = item
			Global.add_item(temp)
			Global.remove_item(item)
		party_member.equip_stats_change()
		

func drop_item_slot(type):
	var item_type
	match type: 
		0: item_type = "head"
		1: item_type = "body"
		2: item_type = "legs"
		3: item_type = "weapon_left"
		4: item_type = "weapon_right"
		5: item_type = "shield"
	
	Global.add_item(party_member.equipped[item_type])
	party_member.remove_item_stats_change(party_member.equipped[item_type])
	party_member.equipped[item_type] = null
