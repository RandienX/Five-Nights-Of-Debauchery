extends Control

## Inventory UI - Displays items by category (Weapon, Armor, Consumable, Key)

enum ItemTypes { WEAPON = 0, ARMOR = 1, CONSUMABLE = 2, KEY = 3 }

@export var current_type: int = ItemTypes.WEAPON
@onready var item_box: GridContainer = $MarginContainer/VBoxContainer/GridContainer
@onready var menu: Control = $"../../../.."

var is_visible: bool = true
var selected_item: Item = null

func _ready() -> void:
refresh_inventory()

func _physics_process(_delta: float) -> void:
visible = is_visible

func refresh_inventory() -> void:
for child in item_box.get_children():
child.queue_free()

var items_to_display: Array[Dictionary] = []

for item_res in PlayerStats.inventory:
var amount = PlayerStats.inventory[item_res]

if not item_res or not is_instance_valid(item_res):
continue
if not (item_res is Item):
continue
if amount <= 0:
continue

var item: Item = item_res as Item
if item.type == current_type:
items_to_display.append({"item": item, "amount": amount})

for item_data in items_to_display:
var item_scene = load("res://scenes/ui/game_menu/inventory/inventory_item.tscn")
var inventory_item = item_scene.instantiate()
inventory_item.item = item_data.item
inventory_item.amount = item_data.amount
item_box.add_child(inventory_item)

func change_category(new_type: int) -> void:
current_type = new_type
refresh_inventory()

func display_party(item: Item) -> void:
if not item:
return

menu.layer_down += 1
selected_item = item

var party_menu_scene = load("res://scenes/ui/game_menu/party/party_menu.tscn")
var party_menu = party_menu_scene.instantiate()
party_menu.selected_item = selected_item
party_menu.special_mode = party_menu.special_modes.ITEM

$"..".add_child(party_menu)
party_menu.visible = true
