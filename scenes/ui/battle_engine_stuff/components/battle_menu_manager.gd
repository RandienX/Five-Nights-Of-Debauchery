class_name BattleMenuManager
extends Node

## Manages battle menu UI state and transitions
## Handles action selection, skill/item menu navigation via mouse

signal action_selected(action_type: BattleTypes.ActionType)
signal menu_state_changed(state: MenuState)
signal cancel_requested()

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
var selected_skill_index: int = 0
var selected_item_index: int = 0

# UI References
var action_buttons: Dictionary = {}
var skills_container: Control = null
var items_container: Control = null

func _ready():
	pass

func init_manager(root: Node2D):
	battle_root = root
	_setup_ui_references()

func _setup_ui_references():
	if not battle_root or not is_instance_valid(battle_root):
		return
	
	# Get action buttons
	var actions_path = "Control/gui/HBoxContainer2/actions"
	var actions_node = battle_root.get_node_or_null(actions_path)
	
	if actions_node:
		for child in actions_node.get_children():
			if child is Button:
				action_buttons[child.name.to_lower().replace("button", "")] = child
	
	# Get containers
	skills_container = battle_root.get_node_or_null("Control/gui/HBoxContainer2/skills_container")
	items_container = battle_root.get_node_or_null("Control/gui/HBoxContainer2/items_container")
	
	# Hide all menus initially
	_hide_all_menus()

func _hide_all_menus():
	if skills_container:
		skills_container.visible = false
	if items_container:
		items_container.visible = false
	
	# Enable/disable action buttons based on state
	_set_action_buttons_enabled(true)

func _set_action_buttons_enabled(enabled: bool):
	for key in action_buttons:
		var btn: Button = action_buttons[key]
		if btn and is_instance_valid(btn):
			btn.disabled = not enabled

## Opens the skills menu
func open_skills_menu():
	_hide_all_menus()
	if skills_container:
		skills_container.visible = true
	current_state = MenuState.SKILLS_MENU
	menu_state_changed.emit(current_state)
	_set_action_buttons_enabled(false)

## Closes the skills menu
func close_skills_menu():
	if skills_container:
		skills_container.visible = false
	current_state = MenuState.ACTION_MENU
	menu_state_changed.emit(current_state)
	_set_action_buttons_enabled(true)

## Opens the items menu
func open_items_menu():
	_hide_all_menus()
	if items_container:
		items_container.visible = true
	current_state = MenuState.ITEMS_MENU
	menu_state_changed.emit(current_state)
	_set_action_buttons_enabled(false)

## Closes the items menu
func close_items_menu():
	if items_container:
		items_container.visible = false
	current_state = MenuState.ACTION_MENU
	menu_state_changed.emit(current_state)
	_set_action_buttons_enabled(true)

## Handles fight button press
func on_fight_pressed():
	if current_state != MenuState.ACTION_MENU:
		return
	action_selected.emit(BattleTypes.ActionType.ATTACK)

## Handles skills button press
func on_skills_pressed():
	if current_state != MenuState.ACTION_MENU:
		return
	open_skills_menu()

## Handles defend button press
func on_defend_pressed():
	if current_state != MenuState.ACTION_MENU:
		return
	action_selected.emit(BattleTypes.ActionType.DEFEND)

## Handles item button press
func on_item_pressed():
	if current_state != MenuState.ACTION_MENU:
		return
	open_items_menu()

## Handles run button press
func on_run_pressed():
	if current_state != MenuState.ACTION_MENU:
		return
	action_selected.emit(BattleTypes.ActionType.RUN)

## Handles skill selection from SkillBox
func on_skill_selected(skill: Skill, index: int):
	selected_skill_index = index
	# Signal to battle engine to start target selection or execute
	if battle_root and battle_root.has_method("_on_skill_confirmed"):
		battle_root._on_skill_confirmed(skill)

## Handles item selection from ItemBox
func on_item_selected(item: Resource, index: int):
	selected_item_index = index
	# Signal to battle engine to start target selection or execute
	if battle_root and battle_root.has_method("_on_item_confirmed"):
		battle_root._on_item_confirmed(item)

## Handles cancel/back action
func on_cancel():
	match current_state:
		MenuState.SKILLS_MENU:
			close_skills_menu()
		MenuState.ITEMS_MENU:
			close_items_menu()
		_:
			cancel_requested.emit()

## Sets the current party member being planned for
func set_current_party_member(member: Resource):
	current_party_member = member
	# Refresh available skills/items for this member
	_refresh_available_options()

func _refresh_available_options():
	# This would refresh skill/item lists based on current party member
	# For now, just emit signal for battle engine to handle
	if battle_root and battle_root.has_method("_refresh_skill_item_lists"):
		battle_root._refresh_skill_item_lists()

## Scrolls skill list up
func scroll_skills_up():
	if skills_container:
		var scroll = skills_container.get_node_or_null("ScrollContainer")
		if scroll:
			scroll.scroll_vertical = max(0, scroll.scroll_vertical - 100)

## Scrolls skill list down
func scroll_skills_down():
	if skills_container:
		var scroll = skills_container.get_node_or_null("ScrollContainer")
		if scroll:
			scroll.scroll_vertical = min(scroll.get_v_scroll_bar().max_value, scroll.scroll_vertical + 100)

## Scrolls item list up
func scroll_items_up():
	if items_container:
		var scroll = items_container.get_node_or_null("ScrollContainer")
		if scroll:
			scroll.scroll_vertical = max(0, scroll.scroll_vertical - 100)

## Scrolls item list down
func scroll_items_down():
	if items_container:
		var scroll = items_container.get_node_or_null("ScrollContainer")
		if scroll:
			scroll.scroll_vertical = min(scroll.get_v_scroll_bar().max_value, scroll.scroll_vertical + 100)
