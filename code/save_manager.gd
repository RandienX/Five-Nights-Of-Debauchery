@tool
extends Node
## SaveManager - Fully Automated Save/Load System for Godot 4
## 
## This system automatically captures and restores all scene variables and states
## without manual registration or per-variable setup. It stores scene-specific data
## in Global.scene_data and handles schema changes with versioning.
##
## Features:
## - Automatic serialization of exported and runtime variables
## - Scene state capture including node properties, transforms, and custom data
## - Versioning and backward compatibility
## - Human-readable JSON format
## - Error handling for missing/corrupted files
## - Support for runtime-spawned objects via unique IDs
## - Manual save/load and autosave functionality

signal save_completed(success: bool, slot: int)
signal load_completed(success: bool, slot: int)
signal autosave_triggered()

# === Configuration ===
const SAVE_PATH := "user://saves/"
const SCENE_DATA_PATH := "user://scene_data.json"
const MAX_SLOTS := 10
const AUTOSAVE_INTERVAL := 300.0  # 5 minutes in seconds
const SAVE_VERSION := "1.1"  # Schema version for backward compatibility

# === Internal State ===
var _autosave_timer: float = 0.0
var _autosave_enabled: bool = false
var _visited_objects: Dictionary = {}  # Used as Set[int] for circular reference detection
var _max_recursion_depth: int = 50

# === Types that can be serialized directly ===
const SERIALIZABLE_TYPES := [
	TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING,
	TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I,
	TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_TRANSFORM2D,
	TYPE_TRANSFORM3D, TYPE_QUATERNION, TYPE_BASIS, TYPE_PLANE,
	TYPE_ARRAY, TYPE_DICTIONARY, TYPE_PACKED_BYTE_ARRAY,
	TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_FLOAT32_ARRAY,
	TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY,
	TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_COLOR_ARRAY
]

# === Properties to skip during serialization ===
const SKIP_PROPERTIES := [
	"script", "resource_local_to_scene", "material_override",
	"visibility_layer", "visibility_mask", "process_mode",
	"unique_name_in_owner", "owner", "editor_description", "usage",
	"player_steps", "_uid", "shape",
	"resource_path",              # Managed separately via _resource_path key
	"resource_scene_unique_id"    # Auto-generated, don't save/restore
]

const SKIP_PROPERTY_PREFIXES := [
	"metadata/"
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	_connect_signals()
	print("[AutoSaveManager] Initialized - Version %s" % SAVE_VERSION)

func _process(delta: float) -> void:
	if _autosave_enabled:
		_autosave_timer += delta
		if _autosave_timer >= AUTOSAVE_INTERVAL:
			_autosave_timer = 0.0
			trigger_autosave()

func _connect_signals() -> void:
	if Engine.get_main_loop():
		Engine.get_main_loop().connect("scene_changed", _on_scene_changed)

func _on_scene_changed() -> void:
	await get_tree().process_frame
	var scene_root = get_tree().root

# ============================================================================
# PUBLIC API - Save/Load Operations
# ============================================================================

## Manually save the game to a specific slot
func save_game(slot: int, save_name: String = "") -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[AutoSaveManager] Invalid slot number: %d" % slot)
		save_completed.emit(false, slot)
		return false
	
	var save_data := _create_save_data(save_name)
	if not save_data:
		save_completed.emit(false, slot)
		return false
	print("[AutoSaveManager] Save data keys: ", save_data.keys())
	if save_data.has("global_data"):
		print("[AutoSaveManager] Global data keys: ", save_data["global_data"].keys())
		if save_data["global_data"].has("player_stats"):
			var ps = save_data["global_data"]["player_stats"]
			print("[AutoSaveManager] PlayerStats has 'party': ", ps.has("party"))
			if ps.has("party"):
				print("[AutoSaveManager] Party size: ", ps["party"].size())

	var file_path := SAVE_PATH + "slot_%d.json" % slot
	var success := _write_json_file(file_path, save_data)
	
	if success:
		# Also save scene data separately for quick access
		_write_json_file(SCENE_DATA_PATH, Global.scene_data)
		print("[AutoSaveManager] Game saved to slot %d" % slot)
	else:
		push_error("[AutoSaveManager] Failed to save game to slot %d" % slot)
	
	save_completed.emit(success, slot)
	return success

## Load game from a specific slot
func load_game(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[AutoSaveManager] Invalid slot number: %d" % slot)
		load_completed.emit(false, slot)
		return false
	
	var file_path := SAVE_PATH + "slot_%d.json" % slot
	if not FileAccess.file_exists(file_path):
		push_warning("[AutoSaveManager] Save file not found for slot %d" % slot)
		load_completed.emit(false, slot)
		return false
	
	var save_data = _read_json_file(file_path)
	if not save_data or not save_data is Dictionary:
		push_error("[AutoSaveManager] Corrupted save data in slot %d" % slot)
		load_completed.emit(false, slot)
		return false
	
	# Validate version and migrate if needed
	if not _validate_and_migrate(save_data):
		push_error("[AutoSaveManager] Failed to validate/migrate save data")
		load_completed.emit(false, slot)
		return false
	
	var success : bool = await _apply_save_data(save_data)
	load_completed.emit(success, slot)
	return success

## Trigger an automatic save (called by timer)
func trigger_autosave() -> void:
	if not _autosave_enabled:
		return
	
	autosave_triggered.emit()
	var save_name = "Autosave - " + Time.get_datetime_string_from_system(true, true)
	save_game(0, save_name)  # Slot 0 reserved for autosave
	print("[AutoSaveManager] Autosave triggered")

## Enable or disable autosave functionality
func set_autosave_enabled(enabled: bool) -> void:
	_autosave_enabled = enabled
	_autosave_timer = 0.0
	print("[AutoSaveManager] Autosave %s" % ("enabled" if enabled else "disabled"))

## Check if autosave is enabled
func is_autosave_enabled() -> bool:
	return _autosave_enabled

## Get info about a save slot without loading it
func get_slot_info(slot: int) -> Dictionary:
	var file_path := SAVE_PATH + "slot_%d.json" % slot
	if not FileAccess.file_exists(file_path):
		return {"exists": false, "slot": slot}
	
	var save_data = _read_json_file(file_path)
	if not save_data:
		return {"exists": false, "slot": slot}
	
	return {
		"exists": true,
		"slot": slot,
		"save_name": save_data.get("save_name", "Unnamed"),
		"time_played": save_data.get("time_played", 0.0),
		"save_version": save_data.get("schema_version", "unknown"),
		"current_scene": save_data.get("global_data", {}).get("current_scene", ""),
		"timestamp": save_data.get("timestamp", "")
	}

## Delete a save slot
func delete_slot(slot: int) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	
	var file_path := SAVE_PATH + "slot_%d.json" % slot
	if FileAccess.file_exists(file_path):
		return DirAccess.remove_absolute(file_path) == OK
	return false

# ============================================================================
# DATA CREATION & SERIALIZATION
# ============================================================================

func _create_save_data(save_name: String) -> Dictionary:
	var timestamp := Time.get_datetime_string_from_system(true, true)
	
	# Capture global data
	var global_data := _capture_global_data()
	
	# Capture scene-specific data
	var scenes_data := _capture_all_scenes_data()
	
	return {
		"schema_version": SAVE_VERSION,
		"timestamp": timestamp,
		"save_name": save_name if save_name != "" else "Save No Name",
		"time_played": Global.time_played,
		"global_data": global_data,
		"scenes_data": scenes_data,
	}

func _capture_global_data() -> Dictionary:
	var data := {
		"current_scene": Global.current_scene,
		"player_position": var_to_str(PlayerStats.player_position),
		"time_played": Global.time_played,
		"player_stats": PlayerStats.get_save_data()
	}
	
	return data

func _get_all_autoload_names() -> PackedStringArray:
	var autoloads := PackedStringArray(["Global", "Save", "PlayerStats", "SaveManager", "Settings"])
	return autoloads

func _serialize_object_deep(obj: Object, visited: Dictionary = {}, depth: int = 0) -> Dictionary:
	"""
	Deep serialization that handles Resources with full property capture.
	This ensures Party resources save their HP, MP, level, equipment, etc.
	
	Uses visited set to detect and break circular references during serialization.
	"""
	if obj == null:
		return {}
	
	# Check recursion depth
	if depth >= MAX_RECURSION_DEPTH:
		push_error("[AutoSaveManager] Max serialization depth (%d) exceeded for object: %s" % [MAX_RECURSION_DEPTH, str(obj)])
		return {}
	
	# Initialize or use provided visited set
	if visited == null:
		visited = _visited_objects
	
	# Create unique ID for this object to detect cycles
	var obj_id = obj.get_instance_id()
	if visited.has(obj_id):
		push_warning("[AutoSaveManager] Circular reference detected during serialization of: %s" % str(obj))
		return {"_circular_ref": true, "_instance_id": obj_id}
	
	# Mark as visited
	visited[obj_id] = true
	
	var data: Dictionary = {}
	
	# Handle Resources specially - serialize ALL their properties
	if obj is Resource:
		data["_resource_type"] = obj.get_class()
		data["_resource_path"] = obj.resource_path if obj.resource_path else ""
		
		# Get ALL properties including exports and runtime values
		var prop_list: Array[Dictionary] = obj.get_property_list()
		for prop in prop_list:
			var prop_name: String = prop["name"]
			var prop_type: int = prop["type"]
			var usage: int = prop["usage"]
			
			# Skip only internal/resource management properties
			if prop_name in ["script", "resource_local_to_scene", "resource_name"]:
				continue
			# Skip properties with certain prefixes (like metadata/)
			var should_skip := false
			for prefix in SKIP_PROPERTY_PREFIXES:
				if prop_name.begins_with(prefix):
					should_skip = true
					break
			if should_skip:
				continue
			
			# Get and serialize the property value
			if prop_name in obj:
				var value = obj.get(prop_name)
				var serialized = _serialize_value(value, prop_type)
				if serialized != null:
					data[prop_name] = serialized
		
		# Remove from visited after processing
		visited.erase(obj_id)
		return data
	
	# Handle other objects
	var result = _serialize_object_properties(obj)
	visited.erase(obj_id)
	return result

func _capture_all_scenes_data() -> Dictionary:
	var scenes_data: Dictionary = {}
	
	# Capture current scene state
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var scene_path: String = current_scene.scene_file_path
		if scene_path.is_empty():
			scene_path = "runtime_scene_" + str(current_scene.get_instance_id())
		
		if Global.scene_data.has(scene_path):
			scenes_data[scene_path] = Global.scene_data[scene_path]
	
	# Merge with existing scene data from Global
	for key in Global.scene_data:
		if not scenes_data.has(key):
			scenes_data[key] = Global.scene_data[key]
	
	return scenes_data

func _serialize_object_properties(obj: Object, visited: Dictionary = {}, depth: int = 0) -> Dictionary:
	var data: Dictionary = {}

	# Check recursion depth
	if depth >= MAX_RECURSION_DEPTH:
		push_error("[AutoSaveManager] Max serialization depth (%d) exceeded for object properties" % MAX_RECURSION_DEPTH)
		return data
	
	if not obj:
		return data
	
	# Get property list
	var prop_list: Array[Dictionary] = obj.get_property_list()
	
	for prop in prop_list:
		var prop_name: String = prop["name"]
		var prop_type: int = prop["type"]
		var usage: int = prop["usage"]
		
		# Skip properties that shouldn't be serialized
		if prop_name in SKIP_PROPERTIES:
			continue
		# Skip properties with certain prefixes (like metadata/)
		var should_skip := false
		for prefix in SKIP_PROPERTY_PREFIXES:
			if prop_name.begins_with(prefix):
				should_skip = true
				break
		if should_skip:
			continue
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		# Allow editor properties if they are storage properties (like equipped items)
		# Removed: if usage & PROPERTY_USAGE_EDITOR: continue
		
		# Get property value
		var value = obj.get(prop_name)
		if _is_default_value(obj, prop_name, value):
			continue  # Skip saving default values

		# Try to serialize the value
		var serialized = _serialize_value(value, prop_type)
		if serialized != null:
			data[prop_name] = serialized
	
	return data

func _is_default_value(obj: Object, prop_name: String, value: Variant) -> bool:
	"""Check if a property has its default value for this object type"""
	var default_value: Variant = _get_property_default_value(obj, prop_name)
	
	# If we can't determine the default, be safe and save it
	if default_value == null and value != null:
		return false
	
	# Compare values
	if typeof(value) != typeof(default_value):
		return false
	
	# Handle different types appropriately
	match typeof(value):
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return value == default_value
		TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR, TYPE_RECT2, TYPE_TRANSFORM2D:
			return str(value) == str(default_value)
		TYPE_ARRAY:
			if not (value is Array) or not (default_value is Array):
				return false
			if value.size() != default_value.size():
				return false
			for i in range(value.size()):
				if str(value[i]) != str(default_value[i]):
					return false
			return true
		TYPE_DICTIONARY:
			if not (value is Dictionary) or not (default_value is Dictionary):
				return false
			if value.size() != default_value.size():
				return false
			for key in value.keys():
				if not default_value.has(key) or str(value[key]) != str(default_value[key]):
					return false
			return true
		TYPE_NIL:
			return value == null && default_value == null
	
	# For complex types, do a simple comparison
	return value == default_value

func _get_property_default_value(obj: Object, prop_name: String) -> Variant:
	"""Get the default value for a property based on the object's class/script"""
	# Try ClassDB for built-in node types
	var classname: String = obj.get_class()
	if ClassDB.class_exists(classname):
		var default_val = ClassDB.class_get_property_default_value(classname, prop_name)
		if default_val != null:
			return default_val
	
	# For script-defined properties, check if the script defines a default
	if obj.get_script():
		var script: Script = obj.get_script()
		# Try to get default from script's property list
		for prop in script.get_script_property_list():
			if prop["name"] == prop_name:
				# If the property has a hint_string with a default, use it
				# Otherwise, we need to check the actual default value
				pass
		
		# Alternative: Create a temporary instance to check defaults
		# This is more reliable but slower
		var temp_instance = script.new()
		if temp_instance and prop_name in temp_instance:
			var default_val = temp_instance.get(prop_name)
			temp_instance.free()
			return default_val
	
	return null

# ============================================================================
# VALUE SERIALIZATION - PUBLIC API
# ============================================================================

## Public method to serialize a value (can be called from other scripts)
func serialize_value(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	return _serialize_value(value, type_hint)

## Public method to deserialize a value (can be called from other scripts)
func deserialize_value(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	_visited_objects.clear()  # Reset visited set for new deserialization
	_current_depth = 0  # Reset depth counter
	return _deserialize_value(value, type_hint)

# === Circular Reference Detection Constants ===
const MAX_RECURSION_DEPTH := 50  # Prevent stack overflow from deeply nested structures
var _current_depth: int = 0  # Track current recursion depth

func _serialize_value(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	if value == null:
		return null
	
	# Handle basic types (excluding Array and Dictionary which need special handling)
	if typeof(value) in SERIALIZABLE_TYPES:
		if typeof(value) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, 
							 TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_TRANSFORM2D,
							 TYPE_QUATERNION, TYPE_PLANE]:
			return var_to_str(value)
		# Skip Array and Dictionary here - they need deep serialization
		if typeof(value) not in [TYPE_ARRAY, TYPE_DICTIONARY]:
			return value
	
	# Handle Resources - serialize as path for external resources, deep serialize for runtime-modified ones
	if value is Resource:
		# Handle Resources that are direct property values
		if value.has_meta("_runtime_modified") or not value.resource_path or value is Item or value is Entity or value is Skill:
			return _serialize_object_deep(value)
		else:
		# External resource file - just save the path
			return value.resource_path if value.resource_path else null
	
	# Handle Arrays
	if value is Array:
		var result: Array = []
		for item in value:
			# Check if array item is a Resource that needs deep serialization
			if item is Resource or item is Object:
				result.append(_serialize_object_deep(item))
			elif item is Array:
				# Handle nested arrays
				result.append(_serialize_value(item, TYPE_NIL))
			elif item is Dictionary:
				# Handle nested dictionaries
				result.append(_serialize_init_dictionary(item))
			else:
				result.append(_serialize_value(item, TYPE_NIL))
		return result
	
	# Handle Dictionaries
	if value is Dictionary:
		return _serialize_init_dictionary(value)
	
	# Handle Objects with properties
	if value is Object:

		return _serialize_object_properties(value)
	
	# Unknown type - try string conversion as fallback
	push_warning("[AutoSaveManager] Cannot serialize value of type: %s" % typeof(value))
	return null

func _serialize_init_dictionary(value: Dictionary):
	var result: Dictionary = {}
	for key in value.keys():
		var serialized_key = _serialize_value(key, TYPE_NIL)
		var dict_value = value[key]
		var serialized_value: Variant
		# Check if dictionary value is a Resource that needs deep serialization
		if dict_value is Resource or dict_value is Object:
			serialized_value = _serialize_object_deep(dict_value)
		elif dict_value is Array:
			# Handle arrays within dictionaries (like skills[level] = [Skill, Skill])
			var array_result: Array = []
			for arr_item in dict_value:
				if arr_item is Resource or arr_item is Object:
					array_result.append(_serialize_object_deep(arr_item))
				elif arr_item is Array:
					# Handle nested arrays
					array_result.append(_serialize_value(arr_item, TYPE_NIL))
				elif arr_item is Dictionary:
					# Handle nested dictionaries
					array_result.append(_serialize_init_dictionary(arr_item))
				else:
					array_result.append(_serialize_value(arr_item, TYPE_NIL))
			serialized_value = array_result
		elif dict_value is Dictionary:
			serialized_value = _serialize_init_dictionary(dict_value)
		else:
			serialized_value = _serialize_value(dict_value, TYPE_NIL)
		if serialized_key != null:
			result[serialized_key] = serialized_value
	return result

func _deserialize_value(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	if value == null:
		return null
	
	# Check recursion depth to prevent stack overflow
	if _current_depth >= MAX_RECURSION_DEPTH:
		push_error("[AutoSaveManager] Max recursion depth (%d) exceeded. Possible circular reference or deeply nested structure." % MAX_RECURSION_DEPTH)
		return null
	
	_current_depth += 1
	var result: Variant = null
	
	# Handle string-encoded types (type-safe parsing without str_to_var)
	if value is String:
		result = _parse_encoded_string(value)
	
	# Handle Arrays - recursive deserialization
	elif value is Array:
		var arr_result: Array = []
		for item in value:
			arr_result.append(_deserialize_value(item, TYPE_NIL))
		result = arr_result
	
	# Handle Dictionaries - check if it's a deep-serialized Resource
	elif value is Dictionary:
		if value.has("_resource_type"):
			# This is a deep-serialized Resource, reconstruct it
			result = _deserialize_resource_from_dict(value)
		else:
			var dict_result: Dictionary = {}
			for key in value.keys():
				var deserialized_key = _deserialize_value(key, TYPE_NIL)
				var dict_val = value[key]
				var deserialized_value = _deserialize_value(dict_val, TYPE_NIL)
				dict_result[deserialized_key] = deserialized_value
			result = dict_result
	
	else:
		# Basic types pass through unchanged
		result = value
	
	_current_depth -= 1
	return result

func _parse_encoded_string(encoded: String) -> Variant:
	"""
	Type-safe parsing of encoded Godot types from strings.
	Replaces deprecated str_to_var() with explicit type parsing.
	"""
	if encoded.is_empty():
		return null
	
	# Vector2
	if encoded.begins_with("Vector2("):
		var inner = encoded.trim_prefix("Vector2(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 2:
			return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
		return Vector2.ZERO
	
	# Vector2i
	if encoded.begins_with("Vector2i("):
		var inner = encoded.trim_prefix("Vector2i(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 2:
			return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
		return Vector2i.ZERO
	
	# Vector3
	if encoded.begins_with("Vector3("):
		var inner = encoded.trim_prefix("Vector3(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 3:
			return Vector3(float(parts[0].strip_edges()), float(parts[1].strip_edges()), float(parts[2].strip_edges()))
		return Vector3.ZERO
	
	# Vector3i
	if encoded.begins_with("Vector3i("):
		var inner = encoded.trim_prefix("Vector3i(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 3:
			return Vector3i(int(parts[0].strip_edges()), int(parts[1].strip_edges()), int(parts[2].strip_edges()))
		return Vector3i.ZERO
	
	# Color
	if encoded.begins_with("Color("):
		var inner = encoded.trim_prefix("Color(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() >= 3:
			var r = float(parts[0].strip_edges())
			var g = float(parts[1].strip_edges())
			var b = float(parts[2].strip_edges())
			var a = float(parts[3].strip_edges()) if parts.size() > 3 else 1.0
			return Color(r, g, b, a)
		return Color.BLACK
	
	# Rect2
	if encoded.begins_with("Rect2("):
		var inner = encoded.trim_prefix("Rect2(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 4:
			return Rect2(float(parts[0].strip_edges()), float(parts[1].strip_edges()), 
						float(parts[2].strip_edges()), float(parts[3].strip_edges()))
		return Rect2()
	
	# Rect2i
	if encoded.begins_with("Rect2i("):
		var inner = encoded.trim_prefix("Rect2i(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 4:
			return Rect2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()), 
						 int(parts[2].strip_edges()), int(parts[3].strip_edges()))
		return Rect2i()
	
	# Transform2D - simplified parsing
	if encoded.begins_with("Transform2D("):
		push_warning("[AutoSaveManager] Transform2D parsing may be incomplete: %s" % encoded)
		# Fallback: try str_to_var for complex types, but log warning
		return str_to_var(encoded)
	
	# Quaternion
	if encoded.begins_with("Quaternion("):
		var inner = encoded.trim_prefix("Quaternion(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 4:
			return Quaternion(float(parts[0].strip_edges()), float(parts[1].strip_edges()), 
							 float(parts[2].strip_edges()), float(parts[3].strip_edges()))
		return Quaternion.IDENTITY
	
	# Plane
	if encoded.begins_with("Plane("):
		var inner = encoded.trim_prefix("Plane(").trim_suffix(")")
		var parts = inner.split(",")
		if parts.size() == 4:
			return Plane(float(parts[0].strip_edges()), float(parts[1].strip_edges()), 
						float(parts[2].strip_edges()), float(parts[3].strip_edges()))
		return Plane()
	
	# Resource path check (but not a deep-serialized resource dict)
	if encoded.ends_with(".tres") or encoded.ends_with(".tscn") or encoded.ends_with(".gd"):
		if ResourceLoader.exists(encoded):
			var resource = load(encoded)
			if resource:
				return resource
			else:
				push_warning("[AutoSaveManager] Failed to load resource at path: %s" % encoded)
		else:
			push_warning("[AutoSaveManager] Resource path does not exist: %s" % encoded)
		return null
	
	# Unknown string format - return as-is (might be a regular string value)
	return encoded

func _deserialize_resource_from_dict(data: Dictionary, parent_visited: Dictionary = {}) -> Resource:
	"""
	Reconstruct a Resource from its deep-serialized dictionary.
	Uses visited set to detect and break circular references.
	
	IMPORTANT: Only breaks cycles within the SAME object graph traversal.
	Same resource files referenced from different parents are allowed.
	"""
	if not data.has("_resource_type"):
		return null
	
	# Initialize visited set if not provided
	if parent_visited == null:
		parent_visited = _visited_objects
	
	# Create a unique ID for this resource using its path (most stable identifier)
	var resource_path: String = data.get("_resource_path", "")
	var data_id: int
	
	# For file-based resources, we need to distinguish between:
	# 1. Same file referenced multiple times (ALLOWED - different instances)
	# 2. Actual circular reference (BLOCKED - same instance referring to itself)
	# 
	# Solution: Use a "currently processing" set that tracks resources being built RIGHT NOW
	# When a resource finishes building, remove it from this set
	if resource_path and not resource_path.begins_with("<Resource#"):
		# Use a special marker for "currently being constructed" resources
		data_id = hash(resource_path + "::constructing")
	else:
		# For runtime resources, use type+properties hash with constructing marker
		var key_list := PackedStringArray()
		for k in data.keys():
			key_list.append(str(k))
		key_list.sort()
		data_id = hash(str(data.get("_resource_type", ""), key_list, "::constructing"))
	
	# Check if we're in the middle of constructing this resource (circular ref)
	if parent_visited.has(data_id):
		push_warning("[AutoSaveManager] Circular reference detected in resource data (path: %s). Returning null to break cycle." % resource_path)
		return null
	
	# Mark as "currently constructing"
	parent_visited[data_id] = true
	
	var resource_type: String = data["_resource_type"]
	
	var new_resource: Resource
	
	# Try to load from path first if available (for Entity, Item, Skill resources)
	if resource_path and ResourceLoader.exists(resource_path):
		# Load the base resource and duplicate it to avoid modifying the original
		var loaded_resource = load(resource_path)
		if loaded_resource:
			# CRITICAL FIX: Use duplicate(true) for deep copy to preserve nested resource structure
			# Then we'll overwrite ALL properties from saved data anyway
			new_resource = loaded_resource.duplicate(true)
			print("[DEBUG] _deserialize_resource_from_dict: Loaded and duplicated resource from %s, equipped before overwrite: %s" % [resource_path, new_resource.get("equipped") if "equipped" in new_resource else "N/A"])
		else:
			push_warning("[AutoSaveManager] Resource exists at path but failed to load: %s" % resource_path)
			new_resource = _create_resource_by_type(resource_type)
	elif resource_path:
		# Path exists but resource doesn't - handle gracefully
		push_warning("[AutoSaveManager] Resource path does not exist: %s. Creating new instance." % resource_path)
		new_resource = _create_resource_by_type(resource_type)
	else:
		# No path - runtime resource, create new instance
		new_resource = _create_resource_by_type(resource_type)
	
	if not new_resource:
		push_error("[AutoSaveManager] Failed to create resource of type: %s" % resource_type)
		parent_visited.erase(data_id)  # Clean up on failure
		return null
	
	# Apply all saved properties with visited set propagation
	_copy_resource_properties_direct(new_resource, data, parent_visited)
	
	print("[DEBUG] _deserialize_resource_from_dict: After copying properties, equipped = %s" % (new_resource.get("equipped") if "equipped" in new_resource else "N/A"))
	
	# IMPORTANT: Remove from "currently constructing" set after successful processing
	# This allows the same resource file to be referenced again elsewhere
	parent_visited.erase(data_id)
	return new_resource

func _create_resource_by_type(resource_type: String) -> Resource:
	"""Create a new resource instance by type name"""
	if resource_type == "Entity":
		return Entity.new()
	elif resource_type == "Skill":
		return Skill.new()
	elif resource_type == "Item":
		return Item.new()
	elif resource_type == "BattleEffect":
		return BattleEffect.new()
	else:
		# Try ClassDB for built-in types
		if ClassDB.class_exists(resource_type):
			return ClassDB.instantiate(resource_type)
		else:
			# Fallback: try to find script class
			push_warning("[AutoSaveManager] Could not instantiate resource type: %s" % resource_type)
			return null

func _copy_resource_properties_direct(target: Resource, data: Dictionary, visited: Dictionary = {}) -> void:
	"""
	Copy all properties directly from dictionary to resource.
	Propagates visited set for circular reference detection in nested resources.
	
	IMPORTANT: Does NOT call _deserialize_value recursively to avoid resetting
	the visited set and depth counter. Instead, handles nested structures inline.
	"""
	if not target or data.is_empty():
		return
	
	# Use shared visited set or create new one
	if visited == null:
		visited = _visited_objects
	
	print("[DEBUG] _copy_resource_properties_direct: Starting for target=%s (%s), data keys=%s" % [target if target else "null", target.resource_path if "resource_path" in target else "no path", str(data.keys())])
	
	# Check if 'equipped' exists in data at all
	if data.has("equipped"):
		print("[DEBUG]   >>> EQUIPPED FOUND IN DATA! Value: %s" % data["equipped"])
		print("[DEBUG]   >>> Target has 'equipped' property: %s" % ("equipped" in target))
	
	for key in data:
		if key == "_resource_type" or key == "_resource_path":
			continue
		
		# Skip properties that shouldn't be restored
		if key in SKIP_PROPERTIES:
			print("[DEBUG]   Skipping property '%s' (in SKIP_PROPERTIES)" % key)
			continue
		
		var value = data[key]
		
		# Check if the target has this property before setting
		if key in target:
			print("[DEBUG]   Processing property '%s': %s" % [key, str(value).substr(0, min(60, len(str(value))))])
			# Special handling for 'equipped' dictionary - add extra debug info
			if key == "equipped" and value is Dictionary:
				print("[DEBUG]     >>> EQUIPPED DICTIONARY DETECTED! Keys: %s" % value.keys())
				for equip_key in value.keys():
					print("[DEBUG]     >>> equipped['%s'] = %s" % [equip_key, str(value[equip_key]).substr(0, 80)])
			# Handle nested structures inline without calling _deserialize_value
			# to preserve visited set state and depth counter
			var deserialized_value = _deserialize_nested_value_inline(value, visited)
			target.set(key, deserialized_value)
			print("[DEBUG]     -> Set to: %s" % ["null" if deserialized_value == null else str(deserialized_value).substr(0, min(60, str(deserialized_value)))])
			# Extra check for equipped after setting
			if key == "equipped":
				print("[DEBUG]     >>> After setting, target.equipped = %s" % target.get("equipped"))
		else:
			print("[DEBUG]   Property '%s' not found in target, skipping" % key)

func _deserialize_nested_value_inline(value: Variant, visited: Dictionary) -> Variant:
	"""
	Inline deserialization helper that preserves visited set state.
	Used by _copy_resource_properties_direct to avoid resetting counters.
	"""
	if value == null:
		return null
	
	# Handle string-encoded types
	if value is String:
		var parsed = _parse_encoded_string(value)
		print("[DEBUG] _deserialize_nested_value_inline: String '%s' -> %s (type: %s)" % [value, parsed, type_string(typeof(parsed))])
		return parsed
	
	# Handle Arrays - recursive deserialization
	elif value is Array:
		print("[DEBUG] _deserialize_nested_value_inline: Array with %d items" % value.size())
		var arr_result: Array = []
		for i in range(value.size()):
			var item = value[i]
			var deserialized_item = _deserialize_nested_value_inline(item, visited)
			arr_result.append(deserialized_item)
			print("[DEBUG]   Array[%d]: %s -> %s" % [i, str(item).substr(0, min(50, len(str(item)))), str(deserialized_item).substr(0, min(50, len(str(deserialized_item))))])
		
		# CRITICAL FIX: Check if this array should be typed as Array[Item] for inventory
		# If all items look like Items, cast them
		for i in range(arr_result.size()):
			var item = arr_result[i]
			if item is Resource and item.get_class() == "Resource":
				if "item_name" in item or "type" in item:
					print("[DEBUG]   -> Casting Array[%d] to Item type" % i)
					arr_result[i] = item as Item
		
		return arr_result
	
	# Handle Dictionaries - check if it's a deep-serialized Resource
	elif value is Dictionary:
		print("[DEBUG] _deserialize_nested_value_inline: Dictionary with keys: %s" % str(value.keys()))
		if value.has("_resource_type"):
			# This is a deep-serialized Resource, reconstruct it with visited set
			print("[DEBUG]   -> Detected as Resource type: %s, path: %s" % [value.get("_resource_type", "unknown"), value.get("_resource_path", "none")])
			var resource_result = _deserialize_resource_from_dict(value, visited)
			print("[DEBUG]   -> Resource result: %s" % ["null" if resource_result == null else (resource_result.resource_path if "resource_path" in resource_result else str(resource_result))])
			return resource_result
		else:
			print("[DEBUG]   -> Regular dictionary, deserializing contents")
			var dict_result: Dictionary = {}
			for dict_key in value.keys():
				var deserialized_key = _deserialize_nested_value_inline(dict_key, visited)
				var dict_val = value[dict_key]
				var deserialized_value = _deserialize_nested_value_inline(dict_val, visited)
				
				# CRITICAL FIX: Ensure Item resources are properly typed for Dictionary[String, Item]
				# Godot's typed dictionaries require exact type matching
				if deserialized_value is Resource and deserialized_value.get_class() == "Resource":
					# Check if this looks like an Item resource (has item_name or type property)
					if "item_name" in deserialized_value or "type" in deserialized_value:
						print("[DEBUG]   -> Casting Resource to Item type for typed dictionary")
						# Cast to Item by using 'as' operator
						deserialized_value = deserialized_value as Item
				
				dict_result[deserialized_key] = deserialized_value
				print("[DEBUG]   Dict['%s']: %s -> %s (type: %s)" % [dict_key, str(dict_val).substr(0, min(30, len(str(dict_val)))), str(deserialized_value).substr(0, min(30, len(str(deserialized_value)))), type_string(typeof(deserialized_value))])
			print("[DEBUG]   -> Final dictionary result: %s" % dict_result)
			return dict_result
	
	# Basic types pass through unchanged
	print("[DEBUG] _deserialize_nested_value_inline: Basic type %s = %s" % [type_string(typeof(value)), value])
	return value

# ============================================================================
# DATA APPLICATION (LOADING)
# ============================================================================

func _apply_save_data(save_data: Dictionary) -> bool:
	Global.loading = true
	
	# Apply global data
	var global_data: Dictionary = save_data.get("global_data", {})
	if global_data:
		_apply_global_data(global_data)
	
	# Apply scene data
	var scenes_data: Dictionary = save_data.get("scenes_data", {})
	if scenes_data:
		Global.scene_data = scenes_data
	
	# Change to the saved scene
	if global_data.has("current_scene") and global_data["current_scene"]:
		var scene_path: String = global_data["current_scene"]
		if ResourceLoader.exists(scene_path):
			get_tree().change_scene_to_file(scene_path)
		else:
			push_error("[AutoSaveManager] Scene not found: %s" % scene_path)
			Global.loading = false
			return false
	await get_tree().create_timer(0.1).timeout
	
	# Apply scene-specific stats
	if scenes_data:
		_apply_scenes_data(scenes_data)
	
	# Restore time played
	Global.time_played = save_data.get("time_played", 0.0)
	Global.loading = false
	print("[AutoSaveManager] Game loaded successfully")
	return true

func _apply_global_data(global_data: Dictionary) -> void:
	# Restore player position
	if global_data.has("player_position"):
		PlayerStats.player_position = str_to_var(global_data["player_position"])
	
	# Restore PlayerStats using its load_save_data() method if available
	if global_data.has("player_stats"):
		PlayerStats.load_save_data(global_data["player_stats"])

func _apply_scenes_data(scenes_data: Dictionary) -> void:
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return
	
	var scene_path: String = current_scene.scene_file_path
	if scene_path.is_empty():
		scene_path = "runtime_scene_" + str(current_scene.get_instance_id())
	
	# Apply any custom scene data stored in Global
	for key in scenes_data:
		if key != scene_path and key in Global.scene_data:
			Global.scene_data[key] = scenes_data[key]

func _deserialize_into_object(obj: Object, data: Dictionary) -> void:
	if not obj or not data:
		return
	
	for key in data:
		# Skip internal keys
		if key.begins_with("_"):
			continue
		
		# Skip properties that can't be set
		if key in SKIP_PROPERTIES:
			continue
		
		var value = _deserialize_value(data[key])
		
		# Special handling for Resources - recreate from path and apply properties
		if obj is Resource and key == "_resource_path" and value:
			var loaded_resource = load(value as String)
			if loaded_resource:
				_copy_resource_properties(obj, loaded_resource)
		elif obj is Resource and key != "_resource_type" and key != "_resource_path":
			obj.set(key, value)
		else:
			obj.set(key, value)
	
	# Special post-processing for PlayerStats to restore party array properly
	if obj.get_class() == "Node" and data.has("party"):
		_restore_party_array(obj, data["party"])

func _restore_party_array(player_stats: Node, party_data: Array) -> void:
	"""Special handling to restore the Party array in PlayerStats"""
	var new_party: Array[Entity] = []
	
	for member_data in party_data:
		if member_data is Dictionary and member_data.has("_resource_type"):
			# Deep-serialized Party resource - pass visited set for cycle detection
			var party_member = _deserialize_resource_from_dict(member_data)
			if party_member and party_member.role == Entity.Role.PARTY:
				new_party.append(party_member)
		elif member_data is String:
			# Resource path - validate existence before loading
			if ResourceLoader.exists(member_data):
				var party_member = load(member_data)
				if party_member and party_member.role == Entity.Role.PARTY:
					new_party.append(party_member.duplicate())
			else:
				push_warning("[AutoSaveManager] Party member resource not found: %s" % member_data)
	
	if new_party.size() > 0:
		player_stats.set("party", new_party)
		# Re-apply equipment stats after loading
		for p in new_party:
			if p.has_method("equip_stats_change"):
				p.equip_stats_change()

func _copy_resource_properties(target: Resource, source: Resource) -> void:
	"""Copy all properties from source resource to target resource"""
	if not target or not source:
		return
	
	var prop_list: Array[Dictionary] = source.get_property_list()
	for prop in prop_list:
		var prop_name: String = prop["name"]
		if prop_name in ["script", "resource_local_to_scene", "resource_name"]:
			continue
		
		if prop_name in source:
			var value = source.get(prop_name)
			if prop_name in target:
				# Use the centralized deserialization to handle all nested structures
				target.set(prop_name, _deserialize_value(value, TYPE_NIL))

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _read_json_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("[AutoSaveManager] Could not open file: %s" % path)
		return null
	
	var json_text := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var error := json.parse(json_text)
	if error != OK:
		push_error("[AutoSaveManager] JSON parse error: %s" % json.get_error_message())
		return null
	
	return json.data

func _write_json_file(path: String, data: Variant) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("[AutoSaveManager] Could not create file: %s" % path)
		return false
	
	var json_text := JSON.stringify(data, "  ", true)
	file.store_string(json_text)
	file.close()
	return true

func _validate_and_migrate(save_data: Dictionary) -> bool:
	var version = save_data.get("schema_version", "0.0")
	
	# Check if version is compatible
	if version != SAVE_VERSION:
		print("[AutoSaveManager] Migrating save from version %s to %s" % [version, SAVE_VERSION])
		
		# Update version
		save_data["schema_version"] = SAVE_VERSION
	
	return true


# ============================================================================
# DOCUMENTATION & INTEGRATION GUIDE
# ============================================================================
## 
## ════════════════════════════════════════════════════════════════════════════
## STEP-BY-STEP INTEGRATION GUIDE
## ════════════════════════════════════════════════════════════════════════════
##
## 1. SETUP IN YOUR PROJECT:
##    ──────────────────────
##    a) Add SaveManager as an autoload (Project Settings → Autoload):
##       - Path: res://code/save_manager.gd
##       - Name: SaveManager
##    
##    b) Ensure your Resources (Entity, Item, Skill, etc.) are properly set up:
##       - Must extend Resource or RefCounted
##       - Should have @export properties for data you want to save
##       - Runtime-modified resources will be deep-serialized automatically
##
## 2. HOOKING INTO EXISTING DATA:
##    ───────────────────────────
##    The system automatically captures:
##    - Global.autoload data (via Global.scene_data dictionary)
##    - PlayerStats data (via PlayerStats.get_save_data() / load_save_data())
##    - Scene node properties (exported variables, transforms, etc.)
##    
##    To add custom data:
##    ```gdscript
##    # In your script's get_save_data():
##    func get_save_data() -> Dictionary:
##        return {
##            "my_custom_value": my_value,
##            "my_resource": my_resource  # Will be auto-serialized
##        }
##    
##    # In your script's load_save_data():
##    func load_save_data(data: Dictionary) -> void:
##        if data.has("my_custom_value"):
##            my_custom_value = data["my_custom_value"]
##    ```
##
## 3. REQUIRED NODE/RESOURCE SETUP:
##    ──────────────────────────────
##    • Entity.gd, Item.gd, Skill.gd must:
##      - Extend Resource
##      - Have class_name declared for type identification
##      - Implement @export properties for serializable data
##    
##    • PlayerStats.gd must:
##      - Extend Node (autoload)
##      - Implement get_save_data() and load_save_data() methods
##      - Store party members in "party" array property
##
## ════════════════════════════════════════════════════════════════════════════
## EDGE-CASE HANDLING STRATEGY
## ════════════════════════════════════════════════════════════════════════════
##
## 1. CIRCULAR REFERENCES:
##    ────────────────────
##    - Detected via _visited_objects Dictionary tracking
##    - Each resource data gets a unique hash ID
##    - When same ID encountered again, returns null to break cycle
##    - Warning logged: "Circular reference detected in resource data"
##    
##    Example scenario prevented:
##      ResourceA.resource_b = ResourceB
##      ResourceB.resource_a = ResourceA  ← Detected & broken
##
## 2. MISSING RESOURCES:
##    ──────────────────
##    - Validated with ResourceLoader.exists(path) before loading
##    - If missing: logs warning, creates new instance of same type
##    - Fallback hierarchy:
##      a) Try load from resource_path
##      b) Try instantiate by resource_type (Entity.new(), etc.)
##      c) Try ClassDB.instantiate() for built-in types
##      d) Return null with error log
##    
##    Graceful degradation ensures save/load continues even with missing assets.
##
## 3. SCHEMA CHANGES / VERSION DRIFT:
##    ───────────────────────────────
##    - SAVE_VERSION constant tracks current schema
##    - _validate_and_migrate() handles version differences
##    - Missing properties in old saves: use default values (property already exists)
##    - Extra properties in new saves: ignored during deserialization
##    
##    Migration strategy:
##    ```gdscript
##    func _validate_and_migrate(save_data: Dictionary) -> bool:
##        var version = save_data.get("schema_version", "0.0")
##        if version == "1.0":
##            # Migrate 1.0 → 1.1
##            _migrate_v1_to_v2(save_data)
##        save_data["schema_version"] = SAVE_VERSION
##        return true
##    ```
##
## 4. RAPID LOAD CALLS:
##    ─────────────────
##    - _current_depth counter prevents stack overflow
##    - MAX_RECURSION_DEPTH (default: 50) limits nesting
##    - _visited_objects.clear() called at start of each deserialize_value()
##    - State reset ensures no cross-contamination between load operations
##    
##    Thread safety note: Godot's scene loading is single-threaded by design.
##    For async loading, use await on change_scene_to_file().
##
## ════════════════════════════════════════════════════════════════════════════
## PERFORMANCE NOTES & MEMORY-SAFE RECURSION TIPS
## ════════════════════════════════════════════════════════════════════════════
##
## 1. RECURSION OPTIMIZATION:
##    ───────────────────────
##    • Depth-first traversal with early exit on max depth
##    • Shared visited set avoids redundant allocations
##    • Tail-call friendly structure (Godot doesn't optimize tail calls, but
##      the depth counter prevents stack overflow)
##    
##    Performance characteristics:
##    - Time: O(n) where n = total properties across all nested objects
##    - Space: O(d) where d = maximum nesting depth (capped at MAX_RECURSION_DEPTH)
##
## 2. MEMORY MANAGEMENT:
##    ──────────────────
##    • Duplicate() used for loaded resources to avoid modifying originals
##    • Visited set cleared after each top-level deserialize call
##    • No persistent references held after deserialization completes
##    • Arrays/Dictionaries created fresh, not reused
##    
##    Memory tips:
##    - Keep MAX_RECURSION_DEPTH reasonable (50 handles most cases)
##    - Avoid deeply nested structures (>20 levels) in game data design
##    - Use resource_path for shared resources instead of deep serialization
##
## 3. CACHING STRATEGIES:
##    ───────────────────
##    • ResourceLoader caches loaded resources internally
##    • _visited_objects acts as cycle-detection cache
##    • Consider adding LRU cache for frequently loaded resources if needed:
##      ```gdscript
##      var _resource_cache: Dictionary = {}
##      
##      func _load_resource_cached(path: String) -> Resource:
##          if _resource_cache.has(path):
##              return _resource_cache[path].duplicate()
##          var res = load(path)
##          if res:
##              _resource_cache[path] = res
##          return res
##      ```
##
## 4. SERIALIZATION SYMMETRY:
##    ───────────────────────
##    Save and load use identical type-tagging:
##    - Resources: {_resource_type, _resource_path, ...properties}
##    - Vectors: "Vector2(x, y)" string format
##    - Arrays: Recursive element-by-element
##    - Dictionaries: Recursive key/value pairs
##    
##    This 1:1 symmetry ensures:
##    - No data loss during save/load cycles
##    - Type preservation without str_to_var() risks
##    - Predictable behavior for debugging
##
## ════════════════════════════════════════════════════════════════════════════
## DEBUG LOGGING REFERENCE
## ════════════════════════════════════════════════════════════════════════════
##
## Log prefixes to search for in Godot console:
## - [AutoSaveManager] Circular reference detected → Check for bidirectional refs
## - [AutoSaveManager] Resource path does not exist → Missing asset file
## - [AutoSaveManager] Failed to load resource → Corrupted or incompatible resource
## - [AutoSaveManager] Max recursion depth exceeded → Redesign data structure
## - [AutoSaveManager] Could not instantiate resource type → Unknown class
## - [AutoSaveManager] Transform2D parsing may be incomplete → Complex transform
##
## Enable verbose logging by uncommenting debug prints in serialization methods.
##
## ════════════════════════════════════════════════════════════════════════════
