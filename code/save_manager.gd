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
var _registered_nodes: Dictionary = {}  # Maps unique IDs to nodes
var _node_id_counter: int = 0

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
	"player_steps"
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
	_register_scene_nodes(scene_root)
	print(Global.scene_data)

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
# NODE REGISTRATION & TRACKING
# ============================================================================

## Register a node for automatic state tracking
## Returns a unique ID for the node
func register_node(node: Node) -> String:
	if not node:
		return ""
	
	# Check if already registered
	for uid in _registered_nodes:
		if is_instance_valid(_registered_nodes[uid]) and _registered_nodes[uid] == node:
			return uid
	
	# Generate unique ID
	var uid := _generate_node_id(node)
	_registered_nodes[uid] = node
	
	# Connect to node's tree_exited to clean up
	if not node.tree_exited.is_connected(_on_node_removed.bind(uid)):
		node.tree_exited.connect(_on_node_removed.bind(uid))
	
	return uid

## Unregister a node from tracking
func unregister_node(node: Node) -> void:
	for uid in _registered_nodes:
		if is_instance_valid(_registered_nodes[uid]) and _registered_nodes[uid] == node:
			_unregister_node_by_id(uid)
			break

func _unregister_node_by_id(uid: String) -> void:
	if _registered_nodes.has(uid):
		var node = _registered_nodes[uid]
		if is_instance_valid(node) and node.tree_exited.is_connected(_on_node_removed.bind(uid)):
			node.tree_exited.disconnect(_on_node_removed.bind(uid))
		_registered_nodes.erase(uid)

func _on_node_removed(uid: String) -> void:
	_unregister_node_by_id(uid)

## Register all nodes in a scene recursively
func _register_scene_nodes(root: Node) -> void:
	if not root:
		return
	
	_register_node_recursive(root)

func _register_node_recursive(node: Node) -> void:
	# Register nodes that have an @export or custom state worth saving
	if _should_register_node(node):
		register_node(node)
	
	# Recurse through children
	for child in node.get_children():
		_register_node_recursive(child)

func _should_register_node(node: Node) -> bool:
	# Skip editor-only nodes
	if Engine.is_editor_hint():
		return false
	
	# Register nodes with scripts that have exportable properties
	if node.get_script() and node.get_script().get_script_property_list().size() > 0:
		return true
	
	# Register specific node types that commonly have state
	var node_type := node.get_class()
	return node_type in ["CharacterBody2D", "CharacterBody3D", "RigidBody2D", 
		"RigidBody3D", "Area2D", "Area3D", "Sprite2D", "Sprite3D", 
		"Label", "TextureRect", "ProgressBar", "AnimationPlayer"]

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
		"save_name": save_name if save_name != "" else "Save " + timestamp,
		"time_played": Global.time_played,
		"global_data": global_data,
		"scenes_data": scenes_data,
		"registered_nodes": _capture_registered_nodes()
	}

func _capture_global_data() -> Dictionary:
	var data := {
		"current_scene": Global.current_scene if Global.has_meta("current_scene") else "",
		"player_position": var_to_str(Global.player_position) if Global.has_meta("player_position") else "Vector2(0, 0)",
		"time_played": Global.time_played
	}
	
	# Capture PlayerStats data
	if is_instance_valid(PlayerStats):
		data["player_stats"] = _serialize_object_properties(PlayerStats)
	
	# Capture any other autoload singletons with save data
	data["singletons"] = _capture_singleton_data()
	
	return data

func _capture_singleton_data() -> Dictionary:
	var singletons_data := {}
	
	# Automatically discover all autoloads from ProjectSettings
	var autoload_names := _get_all_autoload_names()
	
	for singleton_name in autoload_names:
		if Engine.has_singleton(singleton_name):
			var singleton = Engine.get_singleton(singleton_name)
			if singleton:
				singletons_data[singleton_name] = _serialize_object_deep(singleton)
	
	return singletons_data

func _get_all_autoload_names() -> PackedStringArray:
	"""Automatically discover all registered autoload names from ProjectSettings"""
	var autoloads := PackedStringArray()
	
	# Get the autoload section from project settings
	var project_settings = ProjectSettings.get_property_list()
	for prop in project_settings:
		if prop["name"].begins_with("autoload/"):
			var parts = prop["name"].split("/")
			if parts.size() >= 2:
				var autoload_name = parts[1]
				if not autoload_name in autoloads:
					autoloads.append(autoload_name)
	
	# Fallback: Common autoload names if discovery fails
	if autoloads.is_empty():
		autoloads = PackedStringArray(["Global", "Save", "PlayerStats", "AutoSaveManager"])
	
	return autoloads

func _serialize_object_deep(obj: Object) -> Dictionary:
	"""
	Deep serialization that handles Resources with full property capture.
	This ensures Party resources save their HP, MP, level, equipment, etc.
	"""
	if obj == null:
		return {}
	
	var data : Dictionary = {}
	
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
			
			# Get and serialize the property value
			if obj.has_meta(prop_name) or prop_name in obj:
				var value = obj.get(prop_name)
				var serialized = _serialize_value(value, prop_type)
				if serialized != null:
					data[prop_name] = serialized
		
		return data
	
	# Handle Node-based autoloads (like PlayerStats)
	if obj is Node:
		return _serialize_object_properties(obj)
	
	# Handle other objects
	return _serialize_object_properties(obj)

func _capture_all_scenes_data() -> Dictionary:
	var scenes_data: Dictionary = {}
	
	# Capture current scene state
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		var scene_path: String = current_scene.scene_file_path
		if scene_path.is_empty():
			scene_path = "runtime_scene_" + str(current_scene.get_instance_id())
		
		scenes_data[scene_path] = _capture_scene_state(current_scene)
	
	# Merge with existing scene data from Global
	if Global.has_meta("scene_data"):
		for key in Global.scene_data:
			if not scenes_data.has(key):
				scenes_data[key] = Global.scene_data[key]
	
	return scenes_data

func _capture_scene_state(scene_root: Node) -> Dictionary:
	var state := {
		"nodes": {},
		"custom_data": {}
	}
	
	# Capture all relevant node states
	_capture_node_state_recursive(scene_root, state.nodes, scene_root)
	
	# Capture any scene-level custom data
	if scene_root.has_method("get_custom_scene_data"):
		state["custom_data"] = scene_root.get_custom_scene_data()
	
	return state

func _capture_node_state_recursive(node: Node, state_dict: Dictionary, root: Node, path_prefix: String = "") -> void:
	# Create a unique path for this node
	var node_path: String = str(path_prefix, node.name) if path_prefix else node.name
	var node_uid: String = register_node(node)
	
	# Capture node state
	var node_state := _serialize_node(node)
	if node_state.size() > 0:
		state_dict[node_path] = node_state
		state_dict[node_path]["_uid"] = node_uid
	
	# Recurse through children
	for child in node.get_children():
		# Skip editor-only or internal nodes
		if child.owner == null and child != root:
			continue
		_capture_node_state_recursive(child, state_dict, root, node_path + "/")

func _serialize_node(node: Node) -> Dictionary:
	var state: Dictionary= {}
	
	# Serialize transform for spatial nodes
	if node is Node2D:
		state["position"] = var_to_str(node.position)
		state["rotation"] = node.rotation
		state["scale"] = var_to_str(node.scale)
	elif node is Node3D:
		state["position"] = var_to_str(node.position)
		state["rotation"] = var_to_str(node.rotation_degrees)
		state["scale"] = var_to_str(node.scale)
	
	# Serialize properties
	var props: Dictionary = _serialize_object_properties(node)
	for key in props:
		if key not in state:
			state[key] = props[key]
	
	# Serialize component-like data (e.g., CollisionShape2D shape)
	_serialize_components(node, state)
	
	return state

func _serialize_object_properties(obj: Object) -> Dictionary:
	var data: Dictionary = {}
	
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
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		if usage & PROPERTY_USAGE_EDITOR:
			continue
		
		# Get property value
		var value = obj.get(prop_name) if obj.has_method("get") or prop_name in obj else null
		
		# Try to serialize the value
		var serialized = _serialize_value(value, prop_type)
		if serialized != null:
			data[prop_name] = serialized
	
	return data

func _serialize_components(node: Node, state: Dictionary) -> void:
	# Handle special component data
	if node is CollisionShape2D and node.shape:
		state["_collision_shape"] = {
			"type": node.shape.get_class(),
			"data": _serialize_shape(node.shape)
		}
	elif node is CollisionShape3D and node.shape:
		state["_collision_shape"] = {
			"type": node.shape.get_class(),
			"data": _serialize_shape(node.shape)
	}

func _serialize_shape(shape: Shape2D) -> Dictionary:
	var data := {"class": shape.get_class()}
	
	if shape is RectangleShape2D:
		data["size"] = var_to_str(shape.size)
	elif shape is CircleShape2D:
		data["radius"] = shape.radius
	elif shape is CapsuleShape2D:
		data["radius"] = shape.radius
		data["height"] = shape.height
	
	return data

# ============================================================================
# VALUE SERIALIZATION
# ============================================================================

func _serialize_value(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	if value == null:
		return null
	
	# Handle basic types
	if typeof(value) in SERIALIZABLE_TYPES:
		if typeof(value) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, 
							 TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_TRANSFORM2D,
							 TYPE_QUATERNION, TYPE_PLANE]:
			return var_to_str(value)
		return value
	
	# Handle Resources - serialize as path for external resources, deep serialize for runtime-modified ones
	if value is Resource:
		# For Resources that have been modified at runtime (like Party), we need to save their state
		# Check if it's a custom resource with runtime modifications
		if value.has_meta("_runtime_modified") or not value.resource_path:
			return _serialize_object_deep(value)
		else:
			# External resource file - just save the path
			return value.resource_path if value.resource_path else null
	
	# Handle Arrays
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_serialize_value(item, TYPE_NIL))
		return result
	
	# Handle Dictionaries
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value.keys():
			var serialized_key = _serialize_value(key, TYPE_NIL)
			var serialized_value = _serialize_value(value[key], TYPE_NIL)
			if serialized_key != null:
				result[serialized_key] = serialized_value
		return result
	
	# Handle Objects with properties
	if value is Object:
		return _serialize_object_properties(value)
	
	# Unknown type - try string conversion as fallback
	push_warning("[AutoSaveManager] Cannot serialize value of type: %s" % typeof(value))
	return null

func _deserialize_value(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	if value == null:
		return null
	
	# Handle string-encoded types
	if value is String:
		if value.begins_with("Vector2(") or value.begins_with("Vector2i("):
			return str_to_var(value)
		if value.begins_with("Vector3(") or value.begins_with("Vector3i("):
			return str_to_var(value)
		if value.begins_with("Color("):
			return str_to_var(value)
		if value.begins_with("Rect2(") or value.begins_with("Rect2i("):
			return str_to_var(value)
		if value.begins_with("Transform2D("):
			return str_to_var(value)
		if value.begins_with("Quaternion("):
			return str_to_var(value)
		if value.begins_with("Plane("):
			return str_to_var(value)
		# Check if it's a resource path (but not a deep-serialized resource dict)
		if value.ends_with(".tres") or value.ends_with(".tscn") or value.ends_with(".gd"):
			var resource = load(value)
			if resource:
				return resource
	
	# Handle Arrays
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_deserialize_value(item, TYPE_NIL))
		return result
	
	# Handle Dictionaries - check if it's a deep-serialized Resource
	if value is Dictionary:
		if value.has("_resource_type"):
			# This is a deep-serialized Resource, reconstruct it
			return _deserialize_resource_from_dict(value)
		
		var result: Dictionary = {}
		for key in value.keys():
			var deserialized_key = _deserialize_value(key, TYPE_NIL)
			var deserialized_value = _deserialize_value(value[key], TYPE_NIL)
			result[deserialized_key] = deserialized_value
		return result
	
	return value

func _deserialize_resource_from_dict(data: Dictionary) -> Resource:
	"""Reconstruct a Resource from its deep-serialized dictionary"""
	if not data.has("_resource_type"):
		return null
	
	var resource_type: String = data["_resource_type"]
	var resource_path: String = data.get("_resource_path", "")
	
	var new_resource: Resource
	
	# Try to load from path first if available
	if resource_path and ResourceLoader.exists(resource_path):
		new_resource = load(resource_path).duplicate()
	else:
		# Create a new instance of the resource type
		var class_type = ClassDB.class_exists(resource_type)
		if class_type:
			new_resource = ClassDB.instantiate(resource_type)
		else:
			# Fallback: try to find script class
			push_warning("[AutoSaveManager] Could not instantiate resource type: %s" % resource_type)
			return null
	
	# Apply all saved properties
	_copy_resource_properties(new_resource, _dict_to_resource(data))
	return new_resource

func _dict_to_resource(data: Dictionary) -> Resource:
	"""Helper to create a temporary resource from dict for property copying"""
	var temp = Resource.new()
	for key in data:
		if key != "_resource_type" and key != "_resource_path":
			temp.set_meta(key, data[key])
	return temp

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
	
	# Apply registered node states
	var registered_nodes: Dictionary = save_data.get("registered_nodes", {})
	_apply_registered_nodes(registered_nodes)
	
	# Restore time played
	Global.time_played = save_data.get("time_played", 0.0)
	Global.loading = false
	print("[AutoSaveManager] Game loaded successfully")
	return true

func _apply_global_data(global_data: Dictionary) -> void:
	# Restore player position
	if global_data.has("player_position"):
		Global.player_position = str_to_var(global_data["player_position"])
	
	# Restore PlayerStats (will be included in singletons too, but keep for backwards compat)
	if global_data.has("player_stats"):
		_deserialize_into_object(PlayerStats, global_data["player_stats"])
	
	# Restore all singletons (includes PlayerStats with full party data)
	if global_data.has("singletons"):
		for name in global_data["singletons"]:
			if Engine.has_singleton(name):
				var singleton = Engine.get_singleton(name)
				if singleton:
					_deserialize_into_object(singleton, global_data["singletons"][name])

func _apply_scenes_data(scenes_data: Dictionary) -> void:
	var current_scene: Node = get_tree().current_scene
	if not current_scene:
		return
	
	var scene_path: String = current_scene.scene_file_path
	if scene_path.is_empty():
		scene_path = "runtime_scene_" + str(current_scene.get_instance_id())
	
	if scenes_data.has(scene_path):
		var scene_state: Dictionary = scenes_data[scene_path]
		_apply_scene_state(current_scene, scene_state)
	
	# Apply any custom scene data stored in Global
	for key in scenes_data:
		if key != scene_path and key in Global.scene_data:
			Global.scene_data[key] = scenes_data[key]

func _apply_scene_state(scene_root: Node, state: Dictionary) -> void:
	if state.has("nodes"):
		_apply_node_states(scene_root, state["nodes"])
	
	if state.has("custom_data") and scene_root.has_method("set_custom_scene_data"):
		scene_root.set_custom_scene_data(state["custom_data"])


func _apply_node_states(root: Node, states: Dictionary) -> void:
	for node_path in states:
		var node_state: Dictionary = states[node_path]
		
		# Skip internal metadata
		if node_path.begins_with("_"):
			continue
		
		# Try to find the node
		var node: Node = root.get_node_or_null(node_path)
		if not node:
			# Node might be runtime-spawned, try to find by UID
			node = _find_node_by_uid(node_state.get("_uid", ""))
		
		if node:
			_apply_node_state(node, node_state)
		else:
			push_warning("[AutoSaveManager] Could not find node at path: %s" % node_path)

func _apply_node_state(node: Node, state: Dictionary) -> void:
	# Restore transform
	if node is Node2D:
		if state.has("position"):
			node.position = str_to_var(state["position"])
		if state.has("rotation"):
			node.rotation = state["rotation"]
		if state.has("scale"):
			node.scale = str_to_var(state["scale"])
	elif node is Node3D:
		if state.has("position"):
			node.position = str_to_var(state["position"])
		if state.has("rotation"):
			node.rotation_degrees = str_to_var(state["rotation"])
		if state.has("scale"):
			node.scale = str_to_var(state["scale"])
	
	# Restore properties
	_deserialize_into_object(node, state)
	
	# Restore components
	if state.has("_collision_shape"):
		_restore_collision_shape(node, state["_collision_shape"])

func _restore_collision_shape(node: Node, shape_data: Dictionary) -> void:
	if not (node is CollisionShape2D or node is CollisionShape3D):
		return
	
	var shape_type = shape_data.get("class", "")
	var shape: Shape2D = null
	
	match shape_type:
		"RectangleShape2D":
			shape = RectangleShape2D.new()
			if shape_data.has("size"):
				shape.size = str_to_var(shape_data["size"])
		"CircleShape2D":
			shape = CircleShape2D.new()
			if shape_data.has("radius"):
				shape.radius = shape_data["radius"]
		"CapsuleShape2D":
			shape = CapsuleShape2D.new()
			if shape_data.has("radius"):
				shape.radius = shape_data["radius"]
			if shape_data.has("height"):
				shape.height = shape_data["height"]
	
	if shape:
		if node is CollisionShape2D:
			node.shape = shape
		elif node is CollisionShape3D:
			# Would need 3D equivalent
			pass

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
	if obj.get_class() == "Node" and obj.has_meta("party") and data.has("party"):
		_restore_party_array(obj, data["party"])

func _restore_party_array(player_stats: Node, party_data: Array) -> void:
	"""Special handling to restore the Party array in PlayerStats"""
	if not player_stats.has_meta("party"):
		return
	
	var new_party: Array[Entity] = []
	
	for member_data in party_data:
		if member_data is Dictionary and member_data.has("_resource_type"):
			# Deep-serialized Party resource
			var party_member = _deserialize_resource_from_dict(member_data)
			if party_member and party_member.role == Entity.Role.PARTY:
				new_party.append(party_member)
		elif member_data is String:
			# Resource path
			var party_member = load(member_data)
			if party_member and party_member.role == Entity.Role.PARTY:
				new_party.append(party_member.duplicate())
	
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
		
		if source.has_meta(prop_name) or prop_name in source:
			var value = source.get(prop_name)
			if target.has_meta(prop_name) or prop_name in target:
				target.set(prop_name, value)

func _capture_registered_nodes() -> Dictionary:
	var captured := {}
	
	for uid in _registered_nodes:
		var node = _registered_nodes[uid]
		if is_instance_valid(node):
			captured[uid] = {
				"class": node.get_class(),
				"path": node.get_path(),
				"state": _serialize_node(node)
			}
	
	return captured

func _apply_registered_nodes(captured: Dictionary) -> void:
	for uid in captured:
		var node_data: Dictionary = captured[uid]
		var node = _find_node_by_path(node_data.get("path", ""))
		
		if node and is_instance_valid(node):
			_apply_node_state(node, node_data.get("state", {}))

func _find_node_by_uid(uid: String) -> Node:
	if _registered_nodes.has(uid):
		var node = _registered_nodes[uid]
		if is_instance_valid(node):
			return node
	return null

func _find_node_by_path(path: String) -> Node:
	if path.is_empty():
		return null
	
	var current_scene := get_tree().current_scene
	if current_scene:
		return current_scene.get_node_or_null(path)
	return null

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

func _generate_node_id(node: Node) -> String:
	_node_id_counter += 1
	var base_id := "%s_%d_%d" % [node.get_class(), node.get_instance_id(), _node_id_counter]
	return base_id.md5_text().substr(0, 12)

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
		
		# Add migration logic here for future versions
		# Example: if version == "0.9": _migrate_from_09(save_data)
		
		# Update version
		save_data["schema_version"] = SAVE_VERSION
	
	return true

# ============================================================================
# DEBUG & INSPECTION
# ============================================================================

## Print debug info about registered nodes
func print_debug_info() -> void:
	print("=== AutoSaveManager Debug Info ===")
	print("Schema Version: %s" % SAVE_VERSION)
	print("Autosave Enabled: %s" % _autosave_enabled)
	print("Registered Nodes: %d" % _registered_nodes.size())
	print("Scene Data Keys: %d" % Global.scene_data.size())
	
	for uid in _registered_nodes:
		var node = _registered_nodes[uid]
		if is_instance_valid(node):
			print("  - [%s] %s at %s" % [uid, node.get_class(), node.get_path()])
		else:
			print("  - [%s] <invalid>" % uid)
