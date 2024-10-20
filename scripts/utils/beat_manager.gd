extends Node

var _beat_signals: Dictionary
# This class doesn't actually handle calculating the current beat
# That's done in game.gd
var current_beat: float
var negative_beat: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func beat_callback(length: float, offset: float, fn: Callable):
	_beat_signals[_beat_signals.size()] = {
		beat_length = length,
		beat_offset = offset,
		beat_fun = fn
	}

func clear_callbacks():
	_beat_signals.clear()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	for key in _beat_signals:
		var sg = _beat_signals[key]
		var current_interval = int(floor((current_beat + (-sg["beat_offset"] if negative_beat else sg["beat_offset"])) / sg["beat_length"]))
		if sg.get("last_interval", 0) != current_interval:
			sg["beat_fun"].call()
			sg["last_interval"] = current_interval
			
