extends Node
## Settings - Autoload singleton for managing game settings
## Handles audio, controls, and gameplay settings with save/load functionality

signal settings_changed(category: String, key: String, value: Variant)

# === Audio Settings ===
var master_volume: float = 1.0
var music_volume: float = 1.0
var sfx_volume: float = 1.0
var voice_volume: float = 1.0

# === Display Settings ===
var fullscreen: bool = false
var vsync_enabled: bool = true
var screen_resolution: Vector2i = Vector2i(864, 648)

# === Gameplay Settings ===
var battle_speed: float = 1.0
var text_speed: float = 1.0
var encounter_rate: float = 1.0
var show_damage_numbers: bool = true
var battle_animations: bool = true
var skip_cutscenes: bool = false

# === Control Settings (stored as strings for key mappings) ===
var control_mappings: Dictionary = {
	"left": "Left",
	"up": "Up", 
	"down": "Down",
	"right": "Right",
	"run": "Shift",
	"use": "Z",
	"cancel": "X",
	"menu": "Escape"
}

const SETTINGS_FILE := "user://settings.json"

func _ready() -> void:
	load_settings()
	_apply_audio_settings()
	_apply_display_settings()

func _apply_audio_settings() -> void:
	var master_bus = AudioServer.get_bus_index("Master")
	if master_bus >= 0:
		AudioServer.set_bus_volume_db(master_bus, linear_to_db(master_volume))
	
	var music_bus = AudioServer.get_bus_index("Music")
	if music_bus >= 0:
		AudioServer.set_bus_volume_db(music_bus, linear_to_db(music_volume))
	
	var sfx_bus = AudioServer.get_bus_index("SFX")
	if sfx_bus >= 0:
		AudioServer.set_bus_volume_db(sfx_bus, linear_to_db(sfx_volume))
	
	var voice_bus = AudioServer.get_bus_index("Voice")
	if voice_bus >= 0:
		AudioServer.set_bus_volume_db(voice_bus, linear_to_db(voice_volume))

func _apply_display_settings() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync_enabled else DisplayServer.VSYNC_DISABLED)
	if not fullscreen:
		DisplayServer.window_set_size(screen_resolution)

# ============================================================================
# PUBLIC API - Get/Set Settings
# ============================================================================

## Set master volume (0.0 to 1.0)
func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	settings_changed.emit("audio", "master_volume", master_volume)

## Set music volume (0.0 to 1.0)
func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	settings_changed.emit("audio", "music_volume", music_volume)

## Set SFX volume (0.0 to 1.0)
func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	settings_changed.emit("audio", "sfx_volume", sfx_volume)

## Set voice volume (0.0 to 1.0)
func set_voice_volume(value: float) -> void:
	voice_volume = clamp(value, 0.0, 1.0)
	_apply_audio_settings()
	settings_changed.emit("audio", "voice_volume", voice_volume)

## Toggle fullscreen mode
func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_apply_display_settings()
	settings_changed.emit("display", "fullscreen", fullscreen)

## Toggle VSync
func set_vsync_enabled(value: bool) -> void:
	vsync_enabled = value
	_apply_display_settings()
	settings_changed.emit("display", "vsync_enabled", vsync_enabled)

## Set screen resolution
func set_resolution(value: Vector2i) -> void:
	screen_resolution = value
	if not fullscreen:
		_apply_display_settings()
	settings_changed.emit("display", "resolution", screen_resolution)

## Set battle speed multiplier
func set_battle_speed(value: float) -> void:
	battle_speed = clamp(value, 0.5, 3.0)
	settings_changed.emit("gameplay", "battle_speed", battle_speed)

## Set text speed multiplier
func set_text_speed(value: float) -> void:
	text_speed = clamp(value, 0.5, 5.0)
	settings_changed.emit("gameplay", "text_speed", text_speed)

## Set encounter rate multiplier
func set_encounter_rate(value: float) -> void:
	encounter_rate = clamp(value, 0.0, 2.0)
	settings_changed.emit("gameplay", "encounter_rate", encounter_rate)

## Toggle damage numbers display
func set_show_damage_numbers(value: bool) -> void:
	show_damage_numbers = value
	settings_changed.emit("gameplay", "show_damage_numbers", show_damage_numbers)

## Toggle battle animations
func set_battle_animations(value: bool) -> void:
	battle_animations = value
	settings_changed.emit("gameplay", "battle_animations", battle_animations)

## Toggle cutscene skipping
func set_skip_cutscenes(value: bool) -> void:
	skip_cutscenes = value
	settings_changed.emit("gameplay", "skip_cutscenes", skip_cutscenes)

## Update a control mapping
func set_control_mapping(action: String, key_name: String) -> void:
	control_mappings[action] = key_name
	settings_changed.emit("controls", action, key_name)

## Get all settings as a dictionary for saving
func get_save_data() -> Dictionary:
	return {
		"audio": {
			"master_volume": master_volume,
			"music_volume": music_volume,
			"sfx_volume": sfx_volume,
			"voice_volume": voice_volume
		},
		"display": {
			"fullscreen": fullscreen,
			"vsync_enabled": vsync_enabled,
			"resolution": {"x": screen_resolution.x, "y": screen_resolution.y}
		},
		"gameplay": {
			"battle_speed": battle_speed,
			"text_speed": text_speed,
			"encounter_rate": encounter_rate,
			"show_damage_numbers": show_damage_numbers,
			"battle_animations": battle_animations,
			"skip_cutscenes": skip_cutscenes
		},
		"controls": control_mappings.duplicate()
	}

## Load settings from a dictionary
func load_from_data(data: Dictionary) -> void:
	# Audio
	if data.has("audio"):
		var audio = data["audio"]
		master_volume = audio.get("master_volume", master_volume)
		music_volume = audio.get("music_volume", music_volume)
		sfx_volume = audio.get("sfx_volume", sfx_volume)
		voice_volume = audio.get("voice_volume", voice_volume)
	
	# Display
	if data.has("display"):
		var display = data["display"]
		fullscreen = display.get("fullscreen", fullscreen)
		vsync_enabled = display.get("vsync_enabled", vsync_enabled)
		if display.has("resolution"):
			screen_resolution = Vector2i(display["resolution"].get("x", 864), display["resolution"].get("y", 648))
	
	# Gameplay
	if data.has("gameplay"):
		var gameplay = data["gameplay"]
		battle_speed = gameplay.get("battle_speed", battle_speed)
		text_speed = gameplay.get("text_speed", text_speed)
		encounter_rate = gameplay.get("encounter_rate", encounter_rate)
		show_damage_numbers = gameplay.get("show_damage_numbers", show_damage_numbers)
		battle_animations = gameplay.get("battle_animations", battle_animations)
		skip_cutscenes = gameplay.get("skip_cutscenes", skip_cutscenes)
	
	# Controls
	if data.has("controls"):
		for key in data["controls"]:
			control_mappings[key] = data["controls"][key]
	
	_apply_audio_settings()
	_apply_display_settings()

## Save settings to file
func save_settings() -> bool:
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.WRITE)
	if not file:
		push_error("[Settings] Failed to open settings file for writing")
		return false
	
	var data = get_save_data()
	file.store_string(JSON.stringify(data, "  "))
	file.close()
	print("[Settings] Settings saved")
	return true

## Load settings from file
func load_settings() -> bool:
	if not FileAccess.file_exists(SETTINGS_FILE):
		print("[Settings] No settings file found, using defaults")
		return false
	
	var file = FileAccess.open(SETTINGS_FILE, FileAccess.READ)
	if not file:
		push_error("[Settings] Failed to open settings file for reading")
		return false
	
	var json = JSON.parse_string(file.get_as_text())
	file.close()
	
	if not json or not json is Dictionary:
		push_error("[Settings] Corrupted settings file")
		return false
	
	load_from_data(json)
	print("[Settings] Settings loaded")
	return true

## Reset all settings to defaults
func reset_to_defaults() -> void:
	master_volume = 1.0
	music_volume = 1.0
	sfx_volume = 1.0
	voice_volume = 1.0
	fullscreen = false
	vsync_enabled = true
	screen_resolution = Vector2i(864, 648)
	battle_speed = 1.0
	text_speed = 1.0
	encounter_rate = 1.0
	show_damage_numbers = true
	battle_animations = true
	skip_cutscenes = false
	control_mappings = {
		"left": "Left",
		"up": "Up", 
		"down": "Down",
		"right": "Right",
		"run": "Shift",
		"use": "Z",
		"cancel": "X",
		"menu": "Escape"
	}
	_apply_audio_settings()
	_apply_display_settings()
	settings_changed.emit("all", "reset", null)
