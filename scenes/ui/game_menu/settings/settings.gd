extends Control

@onready var master_slider = $MarginContainer/VBoxContainer/TabContainer/Audio/MasterVolume/Slider
@onready var music_slider = $MarginContainer/VBoxContainer/TabContainer/Audio/MusicVolume/Slider
@onready var sfx_slider = $MarginContainer/VBoxContainer/TabContainer/Audio/SFXVolume/Slider
@onready var voice_slider = $MarginContainer/VBoxContainer/TabContainer/Audio/VoiceVolume/Slider

@onready var master_value_label = $MarginContainer/VBoxContainer/TabContainer/Audio/MasterVolume/ValueLabel
@onready var music_value_label = $MarginContainer/VBoxContainer/TabContainer/Audio/MusicVolume/ValueLabel
@onready var sfx_value_label = $MarginContainer/VBoxContainer/TabContainer/Audio/SFXVolume/ValueLabel
@onready var voice_value_label = $MarginContainer/VBoxContainer/TabContainer/Audio/VoiceVolume/ValueLabel

@onready var battle_speed_slider = $MarginContainer/VBoxContainer/TabContainer/Gameplay/BattleSpeed/Slider
@onready var text_speed_slider = $MarginContainer/VBoxContainer/TabContainer/Gameplay/TextSpeed/Slider

@onready var battle_speed_value_label = $MarginContainer/VBoxContainer/TabContainer/Gameplay/BattleSpeed/ValueLabel
@onready var text_speed_value_label = $MarginContainer/VBoxContainer/TabContainer/Gameplay/TextSpeed/ValueLabel

@onready var show_damage_checkbox = $MarginContainer/VBoxContainer/TabContainer/Gameplay/ShowDamageNumbers/CheckBox
@onready var battle_anim_checkbox = $MarginContainer/VBoxContainer/TabContainer/Gameplay/BattleAnimations/CheckBox
@onready var skip_cutscenes_checkbox = $MarginContainer/VBoxContainer/TabContainer/Gameplay/SkipCutscenes/CheckBox

func _ready() -> void:
	_load_settings_to_ui()

func _load_settings_to_ui() -> void:
	if not Settings:
		return

	var settings = Settings
	master_slider.value = settings.master_volume
	music_slider.value = settings.music_volume
	sfx_slider.value = settings.sfx_volume
	voice_slider.value = settings.voice_volume

	battle_speed_slider.value = settings.battle_speed
	text_speed_slider.value = settings.text_speed
	show_damage_checkbox.button_pressed = settings.show_damage_numbers
	battle_anim_checkbox.button_pressed = settings.battle_animations
	skip_cutscenes_checkbox.button_pressed = settings.skip_cutscenes

	_update_value_labels()

func _update_value_labels() -> void:
	master_value_label.text = str(round(master_slider.value * 100)) + "%"
	music_value_label.text = str(round(music_slider.value * 100)) + "%"
	sfx_value_label.text = str(round(sfx_slider.value * 100)) + "%"
	voice_value_label.text = str(round(voice_slider.value * 100)) + "%"
	battle_speed_value_label.text = str(battle_speed_slider.value) + "x"
	text_speed_value_label.text = str(text_speed_slider.value*30) + "/s"

func _on_master_volume_changed(value: float) -> void:
	if Settings:
		Settings.set_master_volume(value)
	_update_value_labels()

func _on_music_volume_changed(value: float) -> void:
	if Settings:
		Settings.set_music_volume(value)
	_update_value_labels()

func _on_sfx_volume_changed(value: float) -> void:
	if Settings:
		Settings.set_sfx_volume(value)
	_update_value_labels()

func _on_voice_volume_changed(value: float) -> void:
	if Settings:
		Settings.set_voice_volume(value)
	_update_value_labels()

func _on_battle_speed_changed(value: float) -> void:
	if Settings:
		Settings.set_battle_speed(value)
	_update_value_labels()

func _on_text_speed_changed(value: float) -> void:
	if Settings:
		Settings.set_text_speed(value*30)
	_update_value_labels()

func _on_show_damage_toggled(toggled_on: bool) -> void:
	if Settings:
		Settings.set_show_damage_numbers(toggled_on)

func _on_battle_animations_toggled(toggled_on: bool) -> void:
	if Settings:
		Settings.set_battle_animations(toggled_on)

func _on_skip_cutscenes_toggled(toggled_on: bool) -> void:
	if Settings:
		Settings.set_skip_cutscenes(toggled_on)

func _on_save_pressed() -> void:
	if Settings:
		Settings.save_settings()
		print("[Settings UI] Settings saved successfully!")
