extends Control

## Modern Inventory System - Full item management with categories, details, and usage

signal item_selected(item: Item, amount: int)
signal item_used(item: Item)

enum ItemTypes { WEAPON = 0, ARMOR = 1, CONSUMABLE = 2, KEY = 3, ACCESSORY = 4 }

@onready var category_tabs: TabContainer = $MarginContainer/VBoxContainer/CategoryTabs
@onready var items_grid: VBoxContainer = $MarginContainer/VBoxContainer/HSplitContainer/ItemsPanel/ItemsGrid/VBoxContainer
@onready var item_detail_panel: Panel = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel
@onready var item_icon: TextureRect = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemIcon
@onready var item_name_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemNameLabel
@onready var item_type_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemTypeLabel
@onready var item_description: TextEdit = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemDescription
@onready var item_amount_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemAmountLabel
@onready var item_stats_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/ItemStatsLabel
@onready var use_button: Button = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/UseButton
@onready var no_item_label: Label = $MarginContainer/VBoxContainer/HSplitContainer/DetailPanel/VBoxContainer/NoItemLabel

var current_category: int = ItemTypes.WEAPON
var inventory_items: Dictionary = {}  # Item resource -> amount
var selected_item: Item = null
var selected_item_amount: int = 0
var item_buttons: Array[Control] = []

const CATEGORY_TABS = ["Weapons", "Armor", "Consumables", "KeyItems", "Accessories"]
const INVENTORY_ITEM_SCENE = preload("res://scenes/ui/game_menu/inventory/inventory_item.tscn")
const INVENTORY_ITEM_CONFIG = preload("res://resources/items/inventory_item.tres")

func _ready() -> void:
	_setup_category_tabs()
	_refresh_inventory()
	_update_detail_panel()

func _setup_category_tabs() -> void:
	current_category = 0
	_refresh_inventory()

func _on_tab_changed(tab_index: int) -> void:
	current_category = tab_index
	_refresh_inventory()
	_update_detail_panel()

func _refresh_inventory() -> void:
	for btn in item_buttons:
		btn.queue_free()
	item_buttons.clear()
	
	inventory_items = PlayerStats.get_inventory()
	
	if inventory_items.is_empty():
		return
	
	for item_res in inventory_items.keys():
		var amount = inventory_items[item_res]
		
		if not item_res or not is_instance_valid(item_res):
			continue
		if amount <= 0:
			continue
		
		var item: Item = item_res as Item
		if item.type != current_category:
			continue
		
		var item_node = INVENTORY_ITEM_SCENE.instantiate()
		item_node.name = "ItemBtn" + item.item_name
		item_node.config = INVENTORY_ITEM_CONFIG
		item_node.item = item
		item_node.amount = amount
		item_node.itemBox_type = item_node.itemBox_types.Null

		items_grid.add_child(item_node)
		
		item_buttons.append(item_node)

func on_item_button_pressed(item: Item, amount: int) -> void:
	selected_item = item
	selected_item_amount = amount
	_update_detail_panel()
	item_selected.emit(item, amount)

func _update_detail_panel() -> void:
	if not selected_item:
		no_item_label.visible = true
		item_icon.visible = false
		item_name_label.visible = false
		item_type_label.visible = false
		item_description.visible = false
		item_amount_label.visible = false
		item_stats_label.visible = false
		use_button.visible = false
		return
	
	no_item_label.visible = false
	item_icon.visible = true
	item_name_label.visible = true
	item_type_label.visible = true
	item_description.visible = true
	item_amount_label.visible = true
	item_stats_label.visible = true
	use_button.visible = true
	
	var item: Item = selected_item as Item
	
	if item.icon:
		item_icon.texture = item.icon
	else:
		item_icon.texture = null
	
	item_name_label.text = item.item_name
	var type_names = ["Weapon", "Armor", "Consumable", "Key Item", "Accessory"]
	item_type_label.text = type_names[item.type] if item.type < type_names.size() else "Unknown"
	
	item_description.text = item.description if item.description else "No description available."
	item_amount_label.text = "Quantity: x" + str(selected_item_amount)
	
	var stats_text = ""
	if not item.item_bonuses.is_empty():
		stats_text = "Stats:\n"
		for stat in item.item_bonuses:
			var value = item.item_bonuses[stat]
			if value != 0:
				var sign = "+" if value > 0 else ""
				stats_text += "  " + stat.to_upper() + ": " + sign + str(value) + "\n"
	item_stats_label.text = stats_text if not stats_text.is_empty() else "No stat bonuses"
	
	if item.type == ItemTypes.CONSUMABLE:
		use_button.text = "Use"
		use_button.visible = item.can_use_outside_battle
	else:
		use_button.visible = false

func _on_use_button_pressed() -> void:
	if not selected_item:
		return
	
	var item: Item = selected_item as Item
	
	if item.type == ItemTypes.CONSUMABLE:
		if item.can_use_outside_battle:
			$"../../../..".open_party_for_item(item)
	elif item.type == ItemTypes.WEAPON or item.type == ItemTypes.ARMOR or item.type == ItemTypes.ACCESSORY:
		pass

func refresh() -> void:
	_refresh_inventory()
	_update_detail_panel()
