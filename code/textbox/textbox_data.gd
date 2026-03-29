extends Resource
class_name TextboxData
@export var texts: Array[String]
enum speaker_values {FREDDY, BONNIE, CHICA, FOXY}
@export var speakers: Array[speaker_values]
@export var has_swag: Array[bool]
@export var voices: Array[AudioStreamMP3]
@export var choices: Array[Array] #Array[step[Dictionary{"label: String,  target_step: int"}]]
@export var logic_script: GDScript
