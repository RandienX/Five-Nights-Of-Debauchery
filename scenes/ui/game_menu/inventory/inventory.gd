extends Control

enum item_types {Weapon, Armor, Consumable, key}
var item_type = 0
@onready var item_box = $MarginContainer/VBoxContainer/GridContainer

var is_visible: bool = true

func _ready() -> void:
	init_children()
	
func _physics_process(delta: float) -> void:
	visible = is_visible
	
func init_children():
	var items: Dictionary
	for c in item_box.get_children():
		c.queue_free()
	
	for i in range(len(Global.inventory)):
		if Global.inventory.keys()[i] is Item:
			if Global.inventory.keys()[i].type == item_type:
				items.merge({Global.inventory.keys()[i]: Global.inventory[Global.inventory.keys()[i]]})
			
	for i in range(len(items)):
		var kid = load("res://scenes/ui/game_menu/inventory/inventory_item.tscn").instantiate()
		kid.item = items.keys()[i]
		kid.amount = items[items.keys()[i]]
		item_box.add_child(kid)

func change_category(b_item_type):
	item_type = b_item_type
	init_children()

var selected_item: Item = null

func display_party(item):
	$"../../../..".layer_down += 1
	
	selected_item = item
	var party_menu = load("res://scenes/ui/game_menu/party/party_menu.tscn").instantiate()
	party_menu.selected_item = selected_item
	party_menu.special_mode = party_menu.special_modes.ITEM
	$"..".add_child(party_menu)
	party_menu.visible = true
	
