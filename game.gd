extends Node2D

var cur_tja: TJAFile
var cur_chart: ChartData

@onready var audio: AudioStreamPlayer = $AudioStreamPlayer
@onready var judgePoint: Sprite2D = $JudgePoint
@onready var notes: NoteDrawer = $Notes
@onready var preamble: Timer = $Timer
@onready var don_chan: Chara = $Chara
@onready var soul_curve: Path2D = $BaseSoulCurve

@onready var taiko: TaikoDrum = $Taiko

var current_bpm: float = 0.0
var current_meter: float = 4.0
var current_scroll: Vector2 = Vector2.ZERO

var elapsed: float = 0.0
var combo: int = 0

var current_note_list: Array[Dictionary]

var autoplay: bool = true
var auto_don_side: int = 0
var auto_kat_side: int = 0

var beat: float = 0.0
var current_beat: float = 0.0

func _ready() -> void:
	get_viewport().get_window().files_dropped.connect(on_drop)

func on_drop(path: PackedStringArray):
	cur_chart = null
	don_chan.last_beat = 0
	don_chan.last_late_beat = 0
	don_chan.state = 0
	cur_tja = TJA.parse_tja(path[0])
	if cur_tja.chartinfo.size() == 0:
		print("No chart detected! Abort!")
		return
	audio.stream = cur_tja.wave
	print("Playing first oni/ura chart in chartinfo array...")
	for chart in cur_tja.chartinfo:
		if chart.course == 4:
			cur_chart = chart
			break
	if not cur_chart:
		for chart in cur_tja.chartinfo:
			if chart.course == 3:
				cur_chart = chart
				break
	current_bpm = cur_tja.start_bpm
	current_note_list.clear()
	current_note_list = cur_chart.notes
	elapsed = 0
	preamble.start()
	beat = (current_bpm / 60) * cur_tja.offset * 60
	$ColorRect/Title.text = cur_tja.alttitle
	# Yes this is deferred since the size doesnt change automatically lmao
	call_deferred("change_title")
	$Intro.horizontal_alignment = 0
	$Intro.text = \
	"Subtitle: %s
Maker: %s
	
Demostart: %.3f
Offset: %.3f" % [cur_tja.subtitle, cur_tja.maker, cur_tja.demo_start, cur_tja.offset]

func change_title():
	$ColorRect/Title.pivot_offset.x = $ColorRect/Title.size.x
	if cur_tja.alttitle.length() > 40:
		$ColorRect/Title.scale.x = 40.0 / cur_tja.alttitle.length()

func preamble_timeout() -> void:
	audio.play()

var rolling: bool = false
var roll_timer: int = 0.0

var current_balloon_note: Dictionary

func auto_roll():
	if not rolling: return
	if roll_timer % 4 == 0:
		taiko.taiko_input(0, auto_don_side, true)
		auto_don_side = wrapi(auto_don_side+1, 0, 2)
	roll_timer += 1

func auto_balloon():
	pass

var soul_effect: Texture2D = preload("res://gfx/soul/soul_effect.png")
var dai_frames: SpriteFrames = preload("res://gfx/effects/dai/dai_effect.tres")
var add_blend: CanvasItemMaterial = preload("res://gfx/effects/dai/dai_blend.tres")

# TODO not accurate
func spawn_gauge_effect():
	var spr: Sprite2D = Sprite2D.new()
	spr.texture = soul_effect
	spr.modulate = Color(Color.YELLOW, 0.8)
	spr.global_position = Vector2(600, 43)
	spr.scale = Vector2.ZERO
	spr.z_index = -1
	var tween: Tween = spr.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spr, "scale", Vector2.ONE, 0.3)
	tween.tween_property(spr, "modulate", Color(Color.ORANGE_RED, 0.8), 0.3)
	tween.tween_property(spr, "rotation_degrees", 60, 0.3)
	tween.tween_interval(0.3)
	tween.set_parallel(false)
	tween.tween_callback(spr.queue_free)
	add_child(spr)

enum JudgeType {
	GREAT,
	GOOD,
	BAD
}

var judge: Texture2D = preload("res://gfx/judgement.png")

func auto_play():
	if not autoplay: return
	auto_roll()
	# In reverse to handle removing these within the loop
	for i in range(min(current_note_list.size()-1, 512), -1, -1):
		var note: Dictionary = current_note_list[i]
		# Look, we can't detect if we should hit if we don't have one.
		if not note.has("time"): continue
		if note.has("dummy"): continue
		var type: int = note["note"]
		var time: float = note["time"]
		# Do not include special notes from now on.
		if type >= 999: continue
		# Should we register a hit?
		if time >= elapsed: continue
		# Not a roll note
		if type < 5 or type == 10:
			combo += 1
			taiko.change_combo(combo)
			if combo > 0 and combo % 10 == 0 and don_chan.state != 1:
				don_chan.state = 2
			$CourseSymbol/HitEffect.modulate.a = 1.0
		match type:
			1:
				taiko.taiko_input(0, auto_don_side, true)
				auto_don_side = wrapi(auto_don_side+1, 0, 2)
			2:
				taiko.taiko_input(1, auto_kat_side, true)
				auto_kat_side = wrapi(auto_kat_side+1, 0, 2)
			3:
				taiko.taiko_input(0, 0, true)
				taiko.taiko_input(0, 1, true)
			4:
				taiko.taiko_input(1, 0, true)
				taiko.taiko_input(1, 1, true)
			5, 6:
				rolling = true
				roll_timer = 0
			8: 
				rolling = false
			ChartData.NoteType.SWAP:
				taiko.taiko_input(0, auto_don_side, true)
				taiko.taiko_input(1, auto_kat_side, true)
				auto_don_side = wrapi(auto_don_side+1, 0, 2)
				auto_kat_side = wrapi(auto_kat_side+1, 0, 2)
		# These two are fundamentally the same
		current_note_list.remove_at(i)
		var dr = cur_chart.note_draw_data.find(note)
		if dr != -1 and (type < 5 or type == 10): 
			if $Notes.note_sprites[type] != null and soul_curve.get_child_count() < 32:
				var spr: Sprite2D = Sprite2D.new()
				spr.texture = $Notes.note_sprites[type]
				if type == 3 or type == 4:
					var dai_effect: AnimatedSprite2D = AnimatedSprite2D.new()
					dai_effect.sprite_frames = dai_frames
					dai_effect.play(&"default")
					dai_effect.offset = Vector2(-8, 8)
					dai_effect.scale = Vector2.ONE * 1.25
					dai_effect.z_index = -1
					dai_effect.material = add_blend
					spr.add_child(dai_effect)
				var pathfind: PathFollow2D = PathFollow2D.new()
				pathfind.add_child(spr)
				pathfind.rotates = false
				var ptween = pathfind.create_tween()
				ptween.tween_property(pathfind, "progress_ratio", 1.0, 0.5)
				ptween.tween_callback(spawn_gauge_effect)
				ptween.tween_interval(0.3)
				ptween.tween_callback(pathfind.queue_free)
				soul_curve.add_child(pathfind)
				var note_boom: NoteSoulEffect = NoteSoulEffect.new()
				note_boom.note_type = type
				note_boom.global_position = notes.judgement_position
				note_boom.z_index = -1
				add_child(note_boom)
			cur_chart.note_draw_data.remove_at(dr)

func handle_play_events():
	for i in range(cur_chart.command_log.size()-1, -1, -1):
		var event: Dictionary = cur_chart.command_log[i]
		# Look, we can't detect if we should hit if we don't have one.
		if not event.has("time"): continue
		var type: int = event["com"]
		var time: float = event["time"]
		if time >= elapsed: continue
		match type:
			ChartData.CommandType.BPMCHANGE:
				current_bpm = event["val1"]
			ChartData.CommandType.SPEED:
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				match event["ease"]:
					"LINEAR":
						pass
					"SINE":
						tween.set_trans(Tween.TRANS_SINE)
					"EXPO":
						tween.set_trans(Tween.TRANS_EXPO)
					"CUBIC":
						tween.set_trans(Tween.TRANS_CUBIC)
					"ELASTIC":
						tween.set_trans(Tween.TRANS_ELASTIC)
					"QUAD":
						tween.set_trans(Tween.TRANS_QUAD)
				tween.tween_property(notes, "speed_multiplier", event["val1"], event["val2"])
			ChartData.CommandType.REVERSE:
				var tween = create_tween()
				tween.set_ease(Tween.EASE_IN_OUT)
				match event["ease"]:
					"LINEAR":
						pass
					"SINE":
						tween.set_trans(Tween.TRANS_SINE)
					"EXPO":
						tween.set_trans(Tween.TRANS_EXPO)
					"CUBIC":
						tween.set_trans(Tween.TRANS_CUBIC)
					"ELASTIC":
						tween.set_trans(Tween.TRANS_ELASTIC)
					"QUAD":
						tween.set_trans(Tween.TRANS_QUAD)
				tween.set_parallel(true)
				var soul_pos: Vector2 = soul_curve.curve.get_point_position(0)
				var fuck: Callable = func(val): soul_curve.curve.set_point_position(0, val)
				tween.tween_method(fuck, soul_pos, Vector2(lerp(148, 602, event["val1"]/100), soul_pos.y), event["val2"])
				tween.tween_property(notes, "reverse_flip", lerp(1, -1, event["val1"]/100), event["val2"])
				tween.tween_property(judgePoint, "global_position:x", lerp(148, 602, event["val1"]/100), event["val2"])
				tween.tween_property(notes, "judgement_position:x", lerp(148, 602, event["val1"]/100), event["val2"])
		cur_chart.command_log.remove_at(i)
	for i in range(cur_chart.specil.size()-1, -1, -1):
		var event: Dictionary = cur_chart.specil[i]
		# Look, we can't detect if we should hit if we don't have one.
		if not event.has("time"): continue
		var type: int = event["note"]
		var time: float = event["time"]
		# Handle special notes.
		if time < elapsed:
			match type:
				ChartData.NoteType.GOGOSTART:
					don_chan.state = 1
					don_chan.gogo_beat = 0
					don_chan.gogo2_beat = 0
					var tween = create_tween()
					tween.set_parallel(true)
					tween.tween_property($GogoEffect, "modulate:a", 0.5, 0.1)
					tween.tween_property($Taiko/SFieldEffects/SfieldGogo, "scale:y", 1.0, 0.1)
				ChartData.NoteType.GOGOEND:
					don_chan.state = 0
					var tween = create_tween()
					tween.set_parallel(true)
					tween.tween_property($GogoEffect, "modulate:a", 0.0, 0.1)
					tween.tween_property($Taiko/SFieldEffects/SfieldGogo, "scale:y", 0.0, 0.1)
			cur_chart.specil.remove_at(i)

var last_current_beat: float = 0.0

func _physics_process(delta: float) -> void:
	$FPS.text = str(Engine.get_frames_per_second())
	
	if not cur_chart: return
	elapsed = audio.get_playback_position() + AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	elapsed -= AudioServer.get_output_latency()
	# Apply preamble.
	elapsed -= preamble.time_left
	
	handle_play_events()
	
	last_current_beat = current_beat
	current_beat = TJA.calculate_beat_from_ms(elapsed, cur_chart.bpm_log)
	$CurrentBeatLabel.text = "Current beat: %.3f\nCurrent time: %.3f" % [current_beat, elapsed]
	
	$CourseSymbol/HitEffect.modulate.a = max(0, $CourseSymbol/HitEffect.modulate.a-delta*3)
	
	# DON CHAN #
	don_chan.curbpm = max(0, current_bpm)
	# Negative values cause don-chan to not bop at the beginning
	don_chan.song_pos = elapsed + preamble.wait_time
	
	# TODO
	notes.draw_list = cur_chart.note_draw_data
	notes.bar_list = cur_chart.barline_data
	notes.cur_bpm = current_bpm
	notes.time = elapsed
	notes.current_beat = current_beat
	notes.bemani_scroll = cur_chart.bemani_scroll
	notes.combo_anim = (combo >= 50)
	
	# Handle auto-play (enabled by default...)
	auto_play()
	
	# Soul curves
	#for child in soul_curve.get_children():
		#var path: PathFollow2D = child as PathFollow2D
		#if path.progress_ratio >= 1.0:
			#path.queue_free()
