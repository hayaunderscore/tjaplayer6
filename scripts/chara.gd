extends Sprite2D
class_name Chara

@export var idle_sprite: Texture2D
@export var gogo_sprite: Texture2D
@export var combo_sprite: Texture2D
var curbpm: float = 0.0
var last_beat: float = 0
var last_late_beat: float = 0
@export var idle_frames: int = 1
@export var rhythm_notifier: RhythmNotifier
var song_pos: float = 0.0

var state: int = 0
var gogo_beat: int = 0
var gogo2_beat: int = 0
var last_tween: Tween

var did_10combo_tween: bool = false

func each_half_beat(_count):
	if state != 0: return
	hframes = idle_frames
	texture = idle_sprite
	did_10combo_tween = false
	frame = wrapi(frame+1, 0, idle_frames)

func each_beat(_count):
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

func each_beat_offset(_count):
	if state != 1: return
	hframes = 4
	texture = gogo_sprite
	match gogo2_beat:
		0:
			frame = 1
		1:
			frame = 3
	#gogo2_beat = wrap(gogo2_beat+1, 0, 2)

func _ready() -> void:
	rhythm_notifier.beat.connect(each_beat)
	rhythm_notifier.beats(0.5).connect(each_half_beat)
	rhythm_notifier.beats(1, true, -0.025).connect(each_beat_offset)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match state:
		2: # 10 combo
			hframes = 1
			texture = combo_sprite
			if not did_10combo_tween:
				last_tween = create_tween()
				last_tween.tween_property(self, "position:y", 61-16, (30 / curbpm)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
				last_tween.tween_property(self, "position:y", 61, (30 / curbpm)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
				last_tween.tween_property(self, "state", 0, 0)
			did_10combo_tween = true
