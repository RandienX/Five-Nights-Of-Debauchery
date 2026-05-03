@tool
extends Node
## SingletonSaveManager - Low-Maintenance Save/Load for Global, PlayerStats, and Settings
## 
## This system automatically discovers and serializes all exported variables
## from the three main singleton autoloads without manual registration.
## When you add or remove variables from Global, PlayerStats, or Settings,
## they are automatically included/excluded from saves.
##
## Features:
## - Zero configuration - just works
## - Automatically adapts to variable additions/removals
## - Deep serialization for Resources (equipment, party members, etc.)
## - Version-tolerant (missing variables don't break loads)
## - Human-readable JSON format
## - Separate file storage per singleton for modularity

signal save_completed(success: bool)
signal load_completed(success: bool)

# === Configuration ===
const SAVE_PATH := "user://saves/"
const SAVE_VERSION := "1.0"
const MAX_SLOTS := 10

# === Singleton References ===
var _global: Node = null
var _player_stats: Node = null
var _settings: Node = null

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
	"unique_name_in_owner", "owner", "editor_description", "usage"
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	_initialize_singleton_references()
	print("[SingletonSaveManager] Initialized - Version %s" % SAVE_VERSION)


func _initialize_singleton_references() -> void:
	"""Cache references to the three main singletons"""
	if Engine.has_singleton("Global"):
		_global = Engine.get_singleton("Global")
	if Engine.has_singleton("PlayerStats"):
		_player_stats = Engine.get_singleton("PlayerStats")
	if Engine.has_singleton("Settings"):
		_settings = Engine.get_singleton("Settings")


# ============================================================================
# PUBLIC API - Save/Load Operations with Slot Support
# ============================================================================

## Save all three singletons to separate files for a specific slot
func save_all(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[SingletonSaveManager] Invalid slot number: %d" % slot)
		return false
	
	var success = true
	
	# Save each singleton independently with slot-specific filenames
	if _global:
		success = _save_singleton(_global, "global_slot_%d.json" % slot) and success
	if _player_stats:
		success = _save_singleton(_player_stats, "player_stats_slot_%d.json" % slot) and success
	if _settings:
		success = _save_singleton(_settings, "settings_slot_%d.json" % slot) and success
	
	save_completed.emit(success)
	return success


## Load all three singletons from files for a specific slot
func load_all(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		push_error("[SingletonSaveManager] Invalid slot number: %d" % slot)
		return false
	
	var success = true
	
	# Load each singleton independently with slot-specific filenames
	if _global:
		success = _load_singleton(_global, "global_slot_%d.json" % slot) and success
	if _player_stats:
		success = _load_singleton(_player_stats, "player_stats_slot_%d.json" % slot) and success
	if _settings:
		success = _load_singleton(_settings, "settings_slot_%d.json" % slot) and success
	
	load_completed.emit(success)
	return success


## Save only Global data for a specific slot
func save_global(slot: int = 0) -> bool:
	if not _global:
		push_error("[SingletonSaveManager] Global singleton not found")
		return false
	return _save_singleton(_global, "global_slot_%d.json" % slot)


## Load only Global data from a specific slot
func load_global(slot: int = 0) -> bool:
	if not _global:
		push_error("[SingletonSaveManager] Global singleton not found")
		return false
	return _load_singleton(_global, "global_slot_%d.json" % slot)


## Save only PlayerStats data for a specific slot
func save_player_stats(slot: int = 0) -> bool:
	if not _player_stats:
		push_error("[SingletonSaveManager] PlayerStats singleton not found")
		return false
	return _save_singleton(_player_stats, "player_stats_slot_%d.json" % slot)


## Load only PlayerStats data from a specific slot
func load_player_stats(slot: int = 0) -> bool:
	if not _player_stats:
		push_error("[SingletonSaveManager] PlayerStats singleton not found")
		return false
	return _load_singleton(_player_stats, "player_stats_slot_%d.json" % slot)


## Save only Settings data for a specific slot
func save_settings(slot: int = 0) -> bool:
	if not _settings:
		push_error("[SingletonSaveManager] Settings singleton not found")
		return false
	return _save_singleton(_settings, "settings_slot_%d.json" % slot)


## Load only Settings data from a specific slot
func load_settings(slot: int = 0) -> bool:
	if not _settings:
		push_error("[SingletonSaveManager] Settings singleton not found")
		return false
	return _load_singleton(_settings, "settings_slot_%d.json" % slot)


## Check if a save exists for a specific slot
func has_save(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	
	# Check if at least one singleton file exists for this slot
	var global_path = SAVE_PATH + "global_slot_%d.json" % slot
	var player_stats_path = SAVE_PATH + "player_stats_slot_%d.json" % slot
	var settings_path = SAVE_PATH + "settings_slot_%d.json" % slot
	
	return FileAccess.file_exists(global_path) or \
	       FileAccess.file_exists(player_stats_path) or \
	       FileAccess.file_exists(settings_path)


## Get save info for a specific slot
func get_slot_info(slot: int = 0) -> Dictionary:
	if slot < 0 or slot >= MAX_SLOTS:
		return {"exists": false}
	
	# Try to load Global metadata for time_played info
	var global_path = SAVE_PATH + "global_slot_%d.json" % slot
	if FileAccess.file_exists(global_path):
		var data = _read_json_file(global_path)
		if data:
			return {
				"exists": true,
				"slot": slot,
				"timestamp": data.get("timestamp", ""),
				"schema_version": data.get("schema_version", "unknown"),
				"time_played": _extract_time_played(data)
			}
	
	return {"exists": false}


## Extract time_played from Global save data
func _extract_time_played(global_data: Dictionary) -> float:
	var properties = global_data.get("properties", {})
	return properties.get("time_played", 0.0)


## Delete all save files for a specific slot
func delete_slot(slot: int = 0) -> bool:
	if slot < 0 or slot >= MAX_SLOTS:
		return false
	
	var success = true
	var files = [
		"global_slot_%d.json" % slot,
		"player_stats_slot_%d.json" % slot,
		"settings_slot_%d.json" % slot
	]
	
	for filename in files:
		var file_path = SAVE_PATH + filename
		if FileAccess.file_exists(file_path):
			if DirAccess.remove_absolute(file_path) != OK:
				success = false
	
	return success


## Delete all saves across all slots
func delete_all_saves() -> bool:
	var success = true
	
	for slot in range(MAX_SLOTS):
		if not delete_slot(slot):
			success = false
	
	return success


# ============================================================================
# INTERNAL - Save/Load Implementation
# ============================================================================

func _save_singleton(singleton: Node, filename: String) -> bool:
	var save_data = _capture_singleton_data(singleton)
	if not save_data:
		return false
	
	var file_path = SAVE_PATH + filename
	var success = _write_json_file(file_path, save_data)
	
	if success:
		print("[SingletonSaveManager] Saved %s" % filename)
	else:
		push_error("[SingletonSaveManager] Failed to save %s" % filename)
	
	return success


func _load_singleton(singleton: Node, filename: String) -> bool:
	var file_path = SAVE_PATH + filename
	if not FileAccess.file_exists(file_path):
		print("[SingletonSaveManager] No save file found for %s, skipping" % filename)
		return true  # Not an error - first time load
	
	var save_data = _read_json_file(file_path)
	if not save_data or not save_data is Dictionary:
		push_error("[SingletonSaveManager] Corrupted save data in %s" % filename)
		return false
	
	_apply_singleton_data(singleton, save_data)
	print("[SingletonSaveManager] Loaded %s" % filename)
	return true


# ============================================================================
# DATA CAPTURE & SERIALIZATION
# ============================================================================

func _capture_singleton_data(singleton: Object) -> Dictionary:
	"""
	Automatically capture all serializable properties from a singleton.
	This uses reflection to discover @export and regular variables.
	"""
	var data = {
		"schema_version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(true, true),
		"class_name": singleton.get_class(),
		"properties": {}
	}
	
	# Get all properties via reflection
	var prop_list: Array[Dictionary] = singleton.get_property_list()
	
	for prop in prop_list:
		var prop_name: String = prop["name"]
		var prop_type: int = prop["type"]
		var usage: int = prop["usage"]
		
		# Skip properties that shouldn't be serialized
		if prop_name in SKIP_PROPERTIES:
			continue
		
		# Only serialize properties with STORAGE usage (excludes computed/virtual properties)
		# But also include EDITOR properties if they have STORAGE (for exported vars)
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		
		# Skip editor-only properties without storage
		if (usage & PROPERTY_USAGE_EDITOR) and not (usage & PROPERTY_USAGE_STORAGE):
			continue
		
		# Get property value
		var value = null
		if singleton.has_method("get"):
			value = singleton.get(prop_name)
		elif prop_name in singleton:
			value = singleton[prop_name]
		
		# Serialize the value using deep serialization
		var serialized = _serialize_value_deep(value, prop_type)
		if serialized != null:
			data["properties"][prop_name] = serialized
	
	return data


func _serialize_value_deep(value: Variant, type_hint: int = TYPE_NIL) -> Variant:
	"""
	Deep serialization that handles nested Resources, Arrays, and Dictionaries.
	This ensures equipment, party members, and other complex objects are fully saved.
	"""
	if value == null:
		return null
	
	# Handle basic serializable types
	if typeof(value) in SERIALIZABLE_TYPES:
		# Convert complex types to strings for JSON compatibility
		if typeof(value) in [TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, 
							TYPE_COLOR, TYPE_RECT2, TYPE_RECT2I, TYPE_TRANSFORM2D,
							TYPE_QUATERNION, TYPE_PLANE, TYPE_TRANSFORM3D, TYPE_BASIS]:
			return var_to_str(value)
		return value
	
	# Handle Resources - ALWAYS deep serialize to capture full state
	if value is Resource:
		return _serialize_resource_deep(value)
	
	# Handle Arrays - recursively deep serialize each item
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_serialize_value_deep(item, TYPE_NIL))
		return result
	
	# Handle Dictionaries - recursively deep serialize keys and values
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value.keys():
			var dict_value = value[key]
			var serialized_key = _serialize_value_deep(key, TYPE_NIL)
			var serialized_value: Variant = null
			
			# Special handling for Resource values in dictionaries (e.g., equipped items)
			if dict_value is Resource:
				serialized_value = _serialize_resource_deep(dict_value)
			else:
				serialized_value = _serialize_value_deep(dict_value, TYPE_NIL)
			
			if serialized_key != null:
				result[serialized_key] = serialized_value
		return result
	
	# Handle Objects with properties
	if value is Object:
		return _serialize_object_properties(value)
	
	# Unknown type - try string conversion as fallback
	push_warning("[SingletonSaveManager] Cannot serialize value of type: %s" % typeof(value))
	return null


func _serialize_resource_deep(resource: Resource) -> Dictionary:
	"""
	Deep serialize a Resource including all its properties.
	This captures HP, MP, level, equipment, skills, effects, etc.
	"""
	if resource == null:
		return {}
	
	# Get the actual script class name for scripted resources
	var resource_type: String = ""
	if resource.get_script():
		resource_type = resource.get_script().get_global_name()
	if resource_type.is_empty():
		resource_type = resource.get_class()
	
	var data = {
		"_resource_type": resource_type,
		"_resource_path": resource.resource_path if resource.resource_path else ""
	}
	
	# Get ALL properties including exports and runtime values
	var prop_list: Array[Dictionary] = resource.get_property_list()
	for prop in prop_list:
		var prop_name: String = prop["name"]
		var prop_type: int = prop["type"]
		var usage: int = prop["usage"]
		
		# Skip internal/resource management properties
		if prop_name in ["script", "resource_local_to_scene", "resource_name"]:
			continue
		
		# Skip properties without storage usage
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		
		# Get and serialize the property value
		if resource.has_meta(prop_name) or prop_name in resource:
			var value = resource.get(prop_name)
			var serialized = _serialize_value_deep(value, prop_type)
			if serialized != null:
				data[prop_name] = serialized
	
	return data


func _serialize_object_properties(obj: Object) -> Dictionary:
	"""Serialize all properties of an object"""
	var data = {}
	
	if not obj:
		return data
	
	var prop_list: Array[Dictionary] = obj.get_property_list()
	
	for prop in prop_list:
		var prop_name: String = prop["name"]
		var prop_type: int = prop["type"]
		var usage: int = prop["usage"]
		
		if prop_name in SKIP_PROPERTIES:
			continue
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		
		var value = null
		if obj.has_method("get"):
			value = obj.get(prop_name)
		elif prop_name in obj:
			value = obj[prop_name]
		
		var serialized = _serialize_value_deep(value, prop_type)
		if serialized != null:
			data[prop_name] = serialized
	
	return data


# ============================================================================
# DATA APPLICATION (LOADING)
# ============================================================================

func _apply_singleton_data(singleton: Object, data: Dictionary) -> void:
	"""Apply saved data back to a singleton, handling missing/new properties gracefully"""
	if not singleton or not data:
		return
	
	var properties = data.get("properties", {})
	
	for key in properties:
		# Skip internal keys
		if key.begins_with("_"):
			continue
		
		# Skip if the property doesn't exist on the singleton (version mismatch - new variable removed)
		if not key in singleton:
			print("[SingletonSaveManager] Skipping unknown property '%s' (may have been removed)" % key)
			continue
		
		var value = _deserialize_value(properties[key])
		
		# Set the property
		if singleton.has_method("set"):
			singleton.set(key, value)
		else:
			singleton[key] = value
	
	# Special post-processing for specific singletons
	_post_process_singleton(singleton, data)


func _post_process_singleton(singleton: Object, data: Dictionary) -> void:
	"""Handle special cases after loading data"""
	# Re-equip stats for party members after loading PlayerStats
	if singleton == _player_stats and singleton.has_method("equip_stats_change"):
		var party = singleton.party if "party" in singleton else []
		for member in party:
			if member and member.has_method("equip_stats_change"):
				member.equip_stats_change()


func _deserialize_value(value: Variant) -> Variant:
	"""Deserialize a value, handling string-encoded types and Resources"""
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
		if value.begins_with("Transform3D("):
			return str_to_var(value)
		# Check if it's a simple resource path (not a deep-serialized dict)
		if value.ends_with(".tres") or value.ends_with(".tscn") or value.ends_with(".gd"):
			var resource = load(value)
			if resource:
				return resource
	
	# Handle Arrays
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_deserialize_value(item))
		return result
	
	# Handle Dictionaries - check if it's a deep-serialized Resource
	if value is Dictionary:
		if value.has("_resource_type"):
			# This is a deep-serialized Resource, reconstruct it
			return _deserialize_resource_from_dict(value)
		
		var result: Dictionary = {}
		for key in value.keys():
			var deserialized_key = _deserialize_value(key)
			var deserialized_value = _deserialize_value(value[key])
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
		if ClassDB.class_exists(resource_type):
			new_resource = ClassDB.instantiate(resource_type)
		else:
			# Try to find script class by searching for scripts with matching class_name
			new_resource = _instantiate_script_class(resource_type)
			if not new_resource:
				push_warning("[SingletonSaveManager] Could not instantiate resource type: %s" % resource_type)
				return null
	
	# Apply all saved properties
	_apply_resource_properties(new_resource, data)
	return new_resource


func _instantiate_script_class(class_name: String) -> Resource:
	"""Find and instantiate a script class by its class_name"""
	# Common script class paths to check - auto-discover from standard locations
	var script_paths := {
		"Entity": "res://code/battle/entity.gd",
		"Skill": "res://code/battle/skill.gd",
		"BattleEffect": "res://code/battle/battle_effect.gd",
		"Item": "res://code/player/item.gd",
		"InventoryItemConfig": "res://code/player/inventory_item_config.gd",
		"ShopItem": "res://code/shop/shop_item.gd",
		"BattleItemDrop": "res://code/battle/battle_item_drop.gd",
	}
	
	# Direct lookup by class_name
	if script_paths.has(class_name):
		var path = script_paths[class_name]
		if ResourceLoader.exists(path):
			var script = load(path)
			if script and script is GDScript:
				return script.new() as Resource
	
	# Fallback: iterate through all scripts
	for pair in script_paths:
		var path = script_paths[pair]
		if ResourceLoader.exists(path):
			var script = load(path)
			if script and script is GDScript:
				var global_name = script.get_global_name()
				if global_name == class_name:
					return script.new() as Resource
	
	# Try to instantiate directly using global class name
	if ClassDB.class_exists(class_name):
		return ClassDB.instantiate(class_name) as Resource
	
	# Last resort: search all .gd files in common directories for matching class_name
	var search_dirs = ["res://code/", "res://resources/"]
	for search_dir in search_dirs:
		if DirAccess.dir_exists_absolute(search_dir):
			var found_path = _find_script_by_class_name(class_name, search_dir)
			if found_path:
				var script = load(found_path)
				if script and script is GDScript:
					return script.new() as Resource
	
	return null


func _find_script_by_class_name(class_name: String, search_dir: String) -> String:
	"""Recursively search for a script with matching class_name"""
	var dir = DirAccess.open(search_dir)
	if not dir:
		return ""
	
	dir.list_dir_begin()
	var file_name = dir.get_next()
	
	while file_name != "":
		var full_path = search_dir.trim_suffix("/") + "/" + file_name
		
		if dir.current_is_dir():
			# Recurse into subdirectory
			var result = _find_script_by_class_name(class_name, full_path)
			if result:
				dir.list_dir_end()
				return result
		elif file_name.ends_with(".gd"):
			# Check if this script has the matching class_name
			var file = FileAccess.open(full_path, FileAccess.READ)
			if file:
				var content = file.get_as_text()
				file.close()
				# Look for class_name declaration (handles various formatting)
				var pattern := "class_name " + class_name
				if content.begins_with(pattern) or \
				   content.find(pattern + "\n") != -1 or \
				   content.find(pattern + "\r") != -1 or \
				   content.find(pattern + " ") != -1:
					dir.list_dir_end()
					return full_path
		
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return ""


func _apply_resource_properties(resource: Resource, data: Dictionary) -> void:
	"""Apply saved properties to a resource, handling nested Resources and Dictionaries with Resource values"""
	if not resource or not data:
		return
	
	for key in data:
		# Skip internal keys
		if key.begins_with("_"):
			continue
		
		# Skip if property doesn't exist
		if not key in resource:
			continue
		
		var value = _deserialize_value(data[key])
		
		# Special handling for nested Resources in properties
		if resource.get(key) is Resource and value is Resource:
			# Copy properties from the loaded resource to the existing one
			_copy_resource_properties(resource.get(key), value)
		# Special handling for Dictionaries that may contain Resource values (e.g., equipment dictionary)
		elif resource.get(key) is Dictionary and value is Dictionary:
			var target_dict: Dictionary = resource.get(key)
			# Update the dictionary with deserialized values
			for dict_key in value.keys():
				var dict_value = value[dict_key]
				# If the dictionary value is a Resource, we need to properly assign it
				if dict_value is Resource:
					target_dict[dict_key] = dict_value
				else:
					target_dict[dict_key] = dict_value
		else:
			resource.set(key, value)


func _copy_resource_properties(target: Resource, source: Resource) -> void:
	"""Copy all properties from source resource to target resource"""
	if not target or not source:
		return
	
	var prop_list: Array[Dictionary] = source.get_property_list()
	for prop in prop_list:
		var prop_name: String = prop["name"]
		var usage: int = prop["usage"]
		
		if prop_name in ["script", "resource_local_to_scene", "resource_name"]:
			continue
		if not (usage & PROPERTY_USAGE_STORAGE):
			continue
		
		if prop_name in target:
			var value = source.get(prop_name)
			
			# Deep copy for nested Resources
			if value is Resource:
				var target_value = target.get(prop_name)
				if target_value is Resource:
					_copy_resource_properties(target_value, value)
				else:
					target.set(prop_name, value.duplicate() if value.has_method("duplicate") else value)
			else:
				target.set(prop_name, value)


# ============================================================================
# FILE I/O UTILITIES
# ============================================================================

func _write_json_file(file_path: String, data: Dictionary) -> bool:
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("[SingletonSaveManager] Failed to open file for writing: %s" % file_path)
		return false
	
	var json_string = JSON.stringify(data, "  ")
	file.store_string(json_string)
	file.close()
	return true


func _read_json_file(file_path: String) -> Variant:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("[SingletonSaveManager] Failed to open file for reading: %s" % file_path)
		return null
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.parse_string(json_string)
	if not json:
		push_error("[SingletonSaveManager] Failed to parse JSON: %s" % file_path)
		return null
	
	return json


# ============================================================================
# UTILITY FUNCTIONS (Legacy - kept for backwards compatibility)
# ============================================================================

## Check if a save file exists for a specific singleton (legacy, use has_save() instead)
func has_save_for(singleton_name: String) -> bool:
	var filename = ""
	match singleton_name:
		"Global", "global":
			filename = "global.json"
		"PlayerStats", "player_stats":
			filename = "player_stats.json"
		"Settings", "settings":
			filename = "settings.json"
		_:
			return false
	
	return FileAccess.file_exists(SAVE_PATH + filename)


## Delete all save files (legacy, use delete_all_saves() instead)
func _delete_all_saves_legacy() -> bool:
	var success = true
	var files = ["global.json", "player_stats.json", "settings.json"]
	
	for filename in files:
		var file_path = SAVE_PATH + filename
		if FileAccess.file_exists(file_path):
			if DirAccess.remove_absolute(file_path) != OK:
				success = false
	
	return success


## Get save metadata (legacy, use get_slot_info() instead)
func _get_save_info_legacy(singleton_name: String) -> Dictionary:
	var filename = ""
	match singleton_name:
		"Global", "global":
			filename = "global.json"
		"PlayerStats", "player_stats":
			filename = "player_stats.json"
		"Settings", "settings":
			filename = "settings.json"
		_:
			return {"exists": false}
	
	var file_path = SAVE_PATH + filename
	if not FileAccess.file_exists(file_path):
		return {"exists": false}
	
	var data = _read_json_file(file_path)
	if not data:
		return {"exists": false, "error": "corrupted"}
	
	return {
		"exists": true,
		"schema_version": data.get("schema_version", "unknown"),
		"timestamp": data.get("timestamp", ""),
		"class_name": data.get("class_name", "")
	}


# ============================================================================
# BACKWARDS COMPATIBILITY ALIASES
# ============================================================================

# Alias old method names to new slot-based methods for backwards compatibility
func delete_all_saves_legacy() -> bool:
	return _delete_all_saves_legacy()

func get_save_info_legacy(singleton_name: String) -> Dictionary:
	return _get_save_info_legacy(singleton_name)
