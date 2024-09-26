extends Sprite2D
class_name Chara

@export var idle_sprite: Texture2D
@export var gogo_sprite: Texture2D
var curbpm: float = 0.0
var last_beat: float = 0
@export var idle_frames: int = 1
var song_pos: float = 0.0

var state: int = 0
var gogo_beat: int = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match state:
		0:
			hframes = idle_frames
			texture = idle_sprite
			if song_pos > last_beat + (30 / curbpm):
				frame = wrapi(frame+1, 0, idle_frames)
				last_beat = song_pos
		1: # gogotime
			hframes = 4
			texture = gogo_sprite
			if song_pos > last_beat + (60/4 / curbpm):
				match gogo_beat:
					0, 1, 2:
						frame = 0
					3:
						frame = 1
					4, 5, 6:
						frame = 2
					7:
						frame = 3
				gogo_beat = wrap(gogo_beat+1, 0, 8)
				last_beat = song_pos
