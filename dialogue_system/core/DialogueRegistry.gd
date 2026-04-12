## Built-in conditions and actions registry
## 95% of cases: use these directly in Inspector (no code)
## 5% of cases: register custom ones via code

static var _conditions: Dictionary = {}
static var _actions: Dictionary = {}

static func _init() -> void:
	_register_builtin_conditions()
	_register_builtin_actions()

# ==================== BUILTIN CONDITIONS ====================

static func _register_builtin_conditions() -> void:
	# Check if player has item
	_conditions["has_item"] = func(args: Array) -> bool:
		if args.size() < 1: return false
		var item_id = args[0]
		var required = args[1] if args.size() > 1 else 1
		return _has_item(item_id, required)
	
	# Check variable with operator
	_conditions["check_variable"] = func(args: Array) -> bool:
		if args.size() < 3: return false
		var var_name = args[0]
		var op = args[1]
		var value = args[2]
		return _check_variable(var_name, op, value)
	
	# Random chance (0-100)
	_conditions["random_chance"] = func(args: Array) -> bool:
		if args.size() < 1: return false
		var percent = args[0]
		return randf() * 100.0 < percent
	
	# Check status effect
	_conditions["has_status"] = func(args: Array) -> bool:
		if args.size() < 1: return false
		return _has_status(args[0])
	
	# Check party member level
	_conditions["party_level"] = func(args: Array) -> bool:
		if args.size() < 2: return false
		var member = args[0]
		var min_level = args[1]
		return _get_party_level(member) >= min_level

# ==================== BUILTIN ACTIONS ====================

static func _register_builtin_actions() -> void:
	# Set variable
	_actions["set_variable"] = func(args: Array) -> void:
		if args.size() >= 2:
			_set_variable(args[0], args[1])
	
	# Modify variable (+/-)
	_actions["modify_variable"] = func(args: Array) -> void:
		if args.size() >= 2:
			var val = args[1] if args.size() > 1 else 1
			_modify_variable(args[0], val)
	
	# Give item
	_actions["give_item"] = func(args: Array) -> void:
		if args.size() >= 1:
			var amount = args[1] if args.size() > 1 else 1
			_give_item(args[0], amount)
	
	# Trigger event (custom signal)
	_actions["trigger_event"] = func(args: Array) -> void:
		if args.size() >= 1:
			_trigger_event(args[0], args.slice(1))

# ==================== GAME HOOKS (Override these!) ====================
## These are stubs - override in your game's init script

static var on_has_item: Callable = func(_item: String, _amount: int) -> bool: return true
static var on_check_variable: Callable = func(_name: String, _op: String, _val) -> bool: return true
static var on_has_status: Callable = func(_effect) -> bool: return false
static var on_get_party_level: Callable = func(_member) -> int: return 1
static var on_set_variable: Callable = func(_name: String, _val) -> void: pass
static var on_modify_variable: Callable = func(_name: String, _delta) -> void: pass
static var on_give_item: Callable = func(_item: String, _amount: int) -> void: pass
static var on_trigger_event: Callable = func(_event: String, _args: Array) -> void: pass

# Internal wrappers
static func _has_item(item: String, amount: int) -> bool: return on_has_item.call(item, amount)
static func _check_variable(name: String, op: String, value) -> bool: return on_check_variable.call(name, op, value)
static func _has_status(effect) -> bool: return on_has_status.call(effect)
static func _get_party_level(member) -> int: return on_get_party_level.call(member)
static func _set_variable(name: String, value) -> void: on_set_variable.call(name, value)
static func _modify_variable(name: String, delta) -> void: on_modify_variable.call(name, delta)
static func _give_item(item: String, amount: int) -> void: on_give_item.call(item, amount)
static func _trigger_event(event: String, args: Array) -> void: on_trigger_event.call(event, args)

# ==================== CUSTOM REGISTRATION ====================

static func register_condition(id: String, callable: Callable) -> void:
	_conditions[id] = callable

static func register_action(id: String, callable: Callable) -> void:
	_actions[id] = callable

static func evaluate_condition(id: String, args: Array) -> bool:
	if id.is_empty(): return true
	if not _conditions.has(id):
		push_warning("DialogueRegistry: Unknown condition '%s'" % id)
		return true  # Fail open
	return _conditions[id].call(args)

static func execute_action(id: String, args: Array) -> void:
	if id.is_empty(): return
	if not _actions.has(id):
		push_warning("DialogueRegistry: Unknown action '%s'" % id)
		return
	_actions[id].call(args)
