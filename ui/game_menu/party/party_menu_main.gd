extends Control

var party = Global.party
@onready var party_members_box = $CenterContainer/party
@onready var menu = $"../../../.."
var unlocked_buttons = [true, false, false, false]

enum special_modes {NONE, ITEM, EQUIP}
var special_mode = special_modes.NONE
#--ITEM MODE--
var selected_item: Item

func _ready() -> void:
	for p in party:
		for c in range(len(party_members_box.get_children())):
			
			if p.name == party_members_box.get_children()[c].party_name and party_members_box.get_children()[c] is NinePatchRect:
				
				party_members_box.get_children()[c].party_member = p
				unlocked_buttons[c] = true
				break
				
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("back"):
		menu.layer_down -= 1
		if special_mode == special_modes.ITEM:
			$"../inventory".is_visible = true
		
		queue_free()
				
func party_member_clicked(party_member) -> void:
	if menu.layer_down == 1 and special_mode == special_modes.NONE:
		var memberStats = load("res://scenes/ui/game_menu/party/display_member_stats.tscn").instantiate()
		memberStats.party_member = party_member
		$CenterContainer.add_child(memberStats)
		party_members_box.visible = false
		menu.layer_down = 2
		
	if menu.layer_down == 2 and special_mode == special_modes.ITEM:
		Global.use_item(selected_item, party_member)
		
