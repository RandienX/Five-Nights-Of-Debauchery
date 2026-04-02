class_name BattleUIManager
extends Node

## Manages all battle UI interactions via mouse
## Handles action buttons, skill/item selection, scrolling, and targeting

signal action_button_pressed(action_type: BattleTypes.ActionType)
signal skill_selected(skill: Skill, index: int)
signal item_selected(item: Resource, index: int)
signal target_confirmed(target: BattleTypes.BattleActor)
signal cancel_pressed()
signal scroll_requested(direction: String, menu_type: String)

enum MenuState {
	HIDDEN,
	ACTION_MENU,
	SKILLS_MENU,
	ITEMS_MENU,
	TARGET_SELECT
}

var current_state: MenuState = MenuState.HIDDEN
var battle_root: Node2D = null
var current_party_member: Resource = null

# Selection state
var selected_skill_index: int = -1
var selected_item_index: int = -1
var hovered_skill_box: SkillBox = null
var hovered_item_box: ItemBox = null

# Scroll state
var skill_scroll_position: int = 0
var item_scroll_position: int = 0
var max_visible_skills: int = 8
var max_visible_items: int = 8

# UI References (auto-populated)
var action_buttons: Dictionary = {}
var skills_scroll: ScrollContainer = null
var items_scroll: ScrollContainer = null
var skill_grid: GridContainer = null
var item_grid: GridContainer = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root
	_setup_ui_references()
	_connect_button_signals()

func _setup_ui_references():
	if not battle_root or not is_instance_valid(battle_root):
		return
	
	# Get action buttons container
	var actions_path = "Control/gui/HBoxContainer2/actions"
	var actions_node = battle_root.get_node_or_null(actions_path)
	
	if actions_node:
		for child in actions_node.get_children():
			if child is Button:
				var btn_name = child.name.to_lower().replace("button", "")
				action_buttons[btn_name] = child
	
	# Get skills container and scroll
	var skills_container = battle_root.get_node_or_null("Control/gui/HBoxContainer2/skills_container")
	if skills_container:
		skills_scroll = skills_container.get_node_or_null("ScrollContainer")
		if skills_scroll:
			skill_grid = skills_scroll.get_node_or_null("SkillGrid")
	
	# Get items container and scroll  
	var items_container = battle_root.get_node_or_null("Control/gui/HBoxContainer2/items_container")
	if items_container:
		items_scroll = items_container.get_node_or_null("ScrollContainer")
		if items_scroll:
			item_grid = items_scroll.get_node_or_null("ItemGrid")
	
	# Initialize state
	_hide_all_menus()

func _connect_button_signals():
	# Connect action button signals
	if action_buttons.has("fight"):
		action_buttons["fight"].pressed.connect(_on_fight_button_pressed)
	if action_buttons.has("skills"):
		action_buttons["skills"].pressed.connect(_on_skills_button_pressed)
	if action_buttons.has("defend"):
		action_buttons["defend"].pressed.connect(_on_defend_button_pressed)
	if action_buttons.has("item"):
		action_buttons["item"].pressed.connect(_on_item_button_pressed)
	if action_buttons.has("run"):
		action_buttons["run"].pressed.connect(_on_run_button_pressed)

func _hide_all_menus():
	if skills_scroll and skills_scroll.get_parent():
		skills_scroll.get_parent().visible = false
	if items_scroll and items_scroll.get_parent():
		items_scroll.get_parent().visible = false
	
	_set_action_buttons_enabled(true)
	current_state = MenuState.ACTION_MENU

func _set_action_buttons_enabled(enabled: bool):
	for key in action_buttons:
		var btn: Button = action_buttons[key]
		if btn and is_instance_valid(btn):
			btn.disabled = not enabled

## Shows skills menu
func show_skills_menu():
	_hide_all_menus()
	if skills_scroll and skills_scroll.get_parent():
		skills_scroll.get_parent().visible = true
	current_state = MenuState.SKILLS_MENU
	_set_action_buttons_enabled(false)

## Shows items menu
func show_items_menu():
	_hide_all_menus()
	if items_scroll and items_scroll.get_parent():
		items_scroll.get_parent().visible = true
	current_state = MenuState.ITEMS_MENU
	_set_action_buttons_enabled(false)

## Returns to action menu from skills/items
func return_to_action_menu():
	_hide_all_menus()

## Scrolls skill list
func scroll_skills(amount: int):
	if not skills_scroll:
		return
	skills_scroll.scroll_vertical = clamp(skills_scroll.scroll_vertical + amount, 0, skills_scroll.get_v_scroll_bar().max_value)

## Scrolls item list
func scroll_items(amount: int):
	if not items_scroll:
		return
	items_scroll.scroll_vertical = clamp(items_scroll.scroll_vertical + amount, 0, items_scroll.get_v_scroll_bar().max_value)

## Called when a skill box is clicked
func on_skill_box_clicked(skill: Skill, index: int):
	selected_skill_index = index
	skill_selected.emit(skill, index)

## Called when an item box is clicked
func on_item_box_clicked(item: Resource, index: int):
	selected_item_index = index
	item_selected.emit(item, index)

## Confirms target selection
func confirm_target(target: BattleTypes.BattleActor):
	target_confirmed.emit(target)

## Handles cancel/back
func handle_cancel():
	match current_state:
		MenuState.SKILLS_MENU, MenuState.ITEMS_MENU:
			return_to_action_menu()
			cancel_pressed.emit()
		_:
			cancel_pressed.emit()

# Button event handlers
func _on_fight_button_pressed():
	if current_state == MenuState.ACTION_MENU:
		action_button_pressed.emit(BattleTypes.ActionType.ATTACK)

func _on_skills_button_pressed():
	if current_state == MenuState.ACTION_MENU:
		show_skills_menu()

func _on_defend_button_pressed():
	if current_state == MenuState.ACTION_MENU:
		action_button_pressed.emit(BattleTypes.ActionType.DEFEND)

func _on_item_button_pressed():
	if current_state == MenuState.ACTION_MENU:
		show_items_menu()

func _on_run_button_pressed():
	if current_state == MenuState.ACTION_MENU:
		action_button_pressed.emit(BattleTypes.ActionType.RUN)

## Sets the current party member being planned for
func set_current_party_member(member: Resource):
	current_party_member = member

## Gets current menu state
func get_menu_state() -> MenuState:
	return current_state

## Checks if in target select mode
func is_targeting() -> bool:
	return current_state == MenuState.TARGET_SELECT

## Checks if skills menu is open
func is_in_skills_menu() -> bool:
	return current_state == MenuState.SKILLS_MENU

## Checks if items menu is open
func is_in_items_menu() -> bool:
	return current_state == MenuState.ITEMS_MENU
