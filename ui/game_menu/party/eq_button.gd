extends TextureRect

@export_enum("head", "body", "legs", "weapon_left", "weapon_right", "shield") var type
@onready var party_member: Party = $"../../../../../../../..".party_member
var item_type

func _on_button_pressed() -> void:
	if $Item.texture == null:
		$"../..".change_item_slot(type)
	else:
		$"../..".drop_item_slot(type)
		
	
func _physics_process(delta: float) -> void:
	match type: 
		0: item_type = "head"
		1: item_type = "body"
		2: item_type = "legs"
		3: item_type = "weapon_left"
		4: item_type = "weapon_right"
		5: item_type = "shield"
		
	if $Item:
		if party_member.equipped[item_type] != null:
			$Item.texture = party_member.equipped[item_type].texture
		else:
			$Item.texture = null
		
		
