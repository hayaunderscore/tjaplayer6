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
var beat: int = 0
var gogo_beat: int = 0
var gogo2_beat: int = 0
var last_tween: Tween

var did_10combo_tween: bool = false

func each_half_beat():
	if state != 0: return
	hframes = idle_frames
	texture = idle_sprite
	did_10combo_tween = false
	beat = wrapi(beat+1, 0, idle_frames)

func each_beat():
	if state != 1: return
	hframes = 4
	texture = gogo_sprite
	match gogo_beat:
		0:
			frame = 0
		1:
			frame = 2
	gogo_beat = wrap(gogo_beat+1, 0, 2)
	gogo2_beat = wrap(gogo2_beat+1, 0, 2)

func each_beat_offset():
	if state != 1: return
	hframes = 4
	texture = gogo_sprite
	match gogo2_beat:
		0:
			frame = 1
		1:
			frame = 3
	#gogo2_beat = wrap(gogo2_beat+1, 0, 2)

#func gogo_anim():
	#if state != 1: return
	#hframes = 4
	#texture = gogo_sprite
	#if gogo2_beat < 15:
		#frame = 0
	#if gogo2_beat == 15:
		#frame = 1
	#if gogo2_beat > 15:
		#frame = 2
	#if gogo2_beat == 31:
		#frame = 3
	#gogo2_beat = wrap(gogo2_beat+1, 0, 32)

func _ready() -> void:
	BeatManager.beat_callback(0.5, 0, each_half_beat)
	BeatManager.beat_callback(1, 0, each_beat_offset)
	BeatManager.beat_callback(1, -0.1, each_beat)
	#rhythm_notifier.beats(1).connect(each_beat)
	#rhythm_notifier.beats(0.5).connect(each_half_beat)
	#rhythm_notifier.beats(1, true, -0.025).connect(each_beat_offset)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match state:
		0:
			hframes = idle_frames
			texture = idle_sprite
			frame = beat
		1:
			hframes = 4
			texture = gogo_sprite
		2: # 10 combo
			hframes = 1
			texture = combo_sprite
			if not did_10combo_tween:
				last_tween = create_tween()
				last_tween.tween_property(self, "position:y", 61-16, (30 / curbpm)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				last_tween.tween_property(self, "position:y", 61, (30 / curbpm)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
				last_tween.tween_property(self, "state", 0, 0)
			did_10combo_tween = true
