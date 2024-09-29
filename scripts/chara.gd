extends Sprite2D
class_name Chara

@export var idle_sprite: Texture2D
@export var gogo_sprite: Texture2D
@export var combo_sprite: Texture2D
var curbpm: float = 0.0
var last_beat: float = 0
var last_late_beat: float = 0
@export var idle_frames: int = 1
var song_pos: float = 0.0

var state: int = 0
var gogo_beat: int = 0
var gogo2_beat: int = 0
var last_tween: Tween

var did_10combo_tween: bool = false

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match state:
		0:
			hframes = idle_frames
			texture = idle_sprite
			did_10combo_tween = false
			if song_pos > last_beat + (30 / curbpm):
				frame = wrapi(frame+1, 0, idle_frames)
				last_beat = song_pos
		1: # gogotime
			if is_instance_valid(last_tween):
				last_tween.stop()
				position.y = 72
			hframes = 4
			texture = gogo_sprite
			if (song_pos + 0.016) > last_beat + (60 / curbpm):
				match gogo_beat:
					0:
						frame = 1
					1:
						frame = 3
				gogo_beat = wrap(gogo_beat+1, 0, 2)
			if song_pos > last_beat + (60 / curbpm):
				match gogo2_beat:
					0:
						frame = 0
					1:
						frame = 2
				gogo2_beat = wrap(gogo2_beat+1, 0, 2)
				last_beat = song_pos
		2: # 10 combo
			hframes = 1
			texture = combo_sprite
			if not did_10combo_tween:
				last_tween = create_tween()
				last_tween.tween_property(self, "position:y", 72-32, (30 / curbpm)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				last_tween.tween_property(self, "position:y", 72, (30 / curbpm)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
				last_tween.tween_property(self, "state", 0, 0)
			did_10combo_tween = true
