extends Resource
class_name TextboxDataSimple

@export var text: String = ""
@export var speaker: int = 0  # 0: FREDDY, 1: BONNIE, 2: CHICA, 3: FOXY
@export var has_swag: bool = false
@export var voice: AudioStreamMP3

# Helper function to convert to full TextboxData
func to_full_data() -> TextboxData:
	var full = TextboxData.new()
	full.texts = [text]
	full.speakers = [speaker]
	full.has_swag = [has_swag]
	full.voices = [voice] if voice else []
	full.choices = []
	return full
