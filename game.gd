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
@onready var voice: AudioStreamPlayer = $Voice

@onready var rhythm_notifier: RhythmNotifier = $RhythmNotifier

var current_bpm: float = 0.0
var current_meter: float = 4.0
var current_scroll: Vector2 = Vector2.ZERO

var elapsed: float = 0.0
var combo: int = 0

var current_note_list: Array[Dictionary]

var autoplay: bool = false
var auto_don_side: int = 0
var auto_kat_side: int = 0

var beat: float = 0.0
var current_beat: float = 0.0

var score: int = 0
@onready var score_text: Label = $Score

func _ready() -> void:
	get_viewport().get_window().files_dropped.connect(on_drop)
	if OS.has_feature("android"):
		autoplay = true
		on_drop(["res://charts/soflan-chan_short.tja"])

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
	voice.play()
	score = 0
	$ScoreDrawer.score = 0
	score_text.text = "0"
	$Intro.visible = false
	$Diffilcut.visible = true

func find_chart_and_play(diff: int):
	for chart in cur_tja.chartinfo:
		if chart.course == diff:
			cur_chart = chart
			break
	if not cur_chart: return
	ScoreManager.score_mode = cur_chart.scoremode
	ScoreManager.score_init = cur_chart.scoreinit[0]
	ScoreManager.score_diff = cur_chart.scorediff
	print(ScoreManager.calc_max_score_and_combo(cur_chart.notes))
	# autoplay = false
	current_bpm = cur_tja.start_bpm
	$RhythmNotifier.bpm = current_bpm
	$RhythmNotifier.running = true
	current_note_list.clear()
	current_note_list = cur_chart.notes
	elapsed = 0
	preamble.start()
	beat = (current_bpm / 60) * cur_tja.offset * 60
	$Intro.visible = true
	$Diffilcut.visible = false
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
var roll_mmm: int = 0

var current_balloon_note: Dictionary

func auto_roll():
	if not rolling: return
	if roll_timer % 4 == 0:
		taiko.taiko_input(0, auto_don_side, true)
		auto_don_side = wrapi(auto_don_side+1, 0, 2)
		if not last_roll_note.is_empty():
			if last_roll_note["roll_note_type"] == 5:
				remove_note_and_add_to_arc(last_roll_note, JudgeType.GREAT, true, 1)
				handle_score_animation(ScoreManager.calc_roll(score, 2, gogo_time_active))
			elif last_roll_note["roll_note_type"] == 6:
				remove_note_and_add_to_arc(last_roll_note, JudgeType.GREAT,true, 3)
				handle_score_animation(ScoreManager.calc_roll(score, 3, gogo_time_active))
			if last_roll_note["roll_color_mod"] != Color.RED:
				last_roll_note["roll_color_mod"].r = lerpf(1, Color.RED.r, 0.25*roll_mmm)
				last_roll_note["roll_color_mod"].g = lerpf(1, Color.RED.g, 0.25*roll_mmm)
				last_roll_note["roll_color_mod"].b = lerpf(1, Color.RED.b, 0.25*roll_mmm)
		roll_mmm += 1
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
	spr.scale = Vector2.ONE * 0.25
	spr.z_index = -1
	var tween: Tween = spr.create_tween()
	tween.set_parallel(true)
	tween.tween_property(spr, "scale", Vector2.ONE, 0.3)
	tween.tween_property(spr, "modulate", Color(Color.html("#FF4A29"), 0.8), 0.25).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(spr, "rotation_degrees", 60, 0.3)
	tween.tween_interval(0.3)
	tween.set_parallel(false)
	tween.tween_callback(spr.queue_free)
	add_child(spr)

enum JudgeType {
	GREAT,
	GOOD,
	BAD,
	INVALID,
	ROLL
}

@onready var judge_score: Sprite2D = $JudegScore
var judge_tween: Tween

var JUDGEMENT_GREAT = 0.042
var JUDGEMENT_GOOD = 0.075
var JUDGEMENT_BAD = 0.108

var drumrolls: Array[bool] = [false, false, false, false, false, true, true, true, true, true, false, false, true, false]
var last_roll_note: Dictionary

var visual_score: int = 0

@onready var base_position: Vector2 = score_text.global_position

func handle_score_animation(addscore: int):
	var oldscore: int = score
	score = addscore
	var tween: Tween = create_tween()
	var addlabel: Label = Label.new()
	addlabel.set("theme_override_fonts/font", score_text.get("theme_override_fonts/font"))
	addlabel.set("theme_override_colors/font_color", Color.ORANGE_RED)
	addlabel.horizontal_alignment = score_text.horizontal_alignment
	addlabel.global_position = base_position + Vector2(-8, -32)
	addlabel.text = str(addscore-oldscore)
	addlabel.size = score_text.size
	addlabel.modulate.a = 0
	$AddScores.add_child(addlabel)
	tween.set_parallel(true)
	tween.tween_property(addlabel, "modulate:a", 1, 0.2).set_trans(Tween.TRANS_EXPO)
	tween.tween_property(addlabel, "position:x", base_position.x, 0.25).set_trans(Tween.TRANS_EXPO)
	tween.set_parallel(false)
	tween.tween_interval(0.15)
	tween.set_parallel(true)
	tween.tween_property(addlabel, "position:y", base_position.y, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(addlabel, "modulate:a", 0, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	#tween.tween_interval(-0.15)
	tween.set_parallel(false)
	tween.tween_callback(func():
		visual_score = addscore
		score_text.text = str(visual_score)
		score_text.scale.y = 1.25
		$ScoreDrawer.score = visual_score
	)
	tween.tween_property(score_text, "scale:y", 1, 0.2).from(1.4)
	tween.tween_interval(0.15)
	tween.tween_callback(addlabel.queue_free)

func hit_note(type: int, time: float):
	if drumrolls[type]: return JudgeType.ROLL
	# Not a roll note
	var judgetype: int = JudgeType.BAD
	if time - JUDGEMENT_GREAT <= elapsed and elapsed <= (time + JUDGEMENT_GREAT):
		judgetype = JudgeType.GREAT
	elif time - JUDGEMENT_GOOD <= elapsed and elapsed <= (time + JUDGEMENT_GOOD):
		judgetype = JudgeType.GOOD
	if type < 5 or type == 10:
		if judgetype != JudgeType.BAD:
			combo += 1
			taiko.change_combo(combo)
			var j = 2-judgetype
			if (type == 3 or type == 4 or type == 10) and judgetype != JudgeType.BAD:
				j += 1
			handle_score_animation(ScoreManager.calc_score(score, combo, j, gogo_time_active)[0])
		else:
			combo = 0
			taiko.drop_combo()
		if combo > 0 and combo % 10 == 0 and don_chan.state != 1:
			don_chan.state = 2
		if judgetype != JudgeType.BAD:
			$CourseSymbol/HitEffect.modulate.a = 1.0
		judge_score.modulate.a = 0
		judge_score.position.y = 116
		var tex: AtlasTexture = judge_score.texture as AtlasTexture
		tex.region.position.y = 40*judgetype
		if is_instance_valid(judge_tween):
			judge_tween.stop()
		judge_tween = create_tween()
		judge_tween.set_parallel(true)
		judge_tween.tween_property(judge_score, "modulate:a", 1, 0.05)
		judge_tween.tween_property(judge_score, "position:y", 104, 0.1)
		judge_tween.set_parallel(false)
		judge_tween.tween_interval(0.2)
		judge_tween.tween_property(judge_score, "modulate:a", 0, 0.1)
	return judgetype

@onready var tint_shader: Shader = preload("res://shaders/tint.gdshader")

func remove_note_and_add_to_arc(note: Dictionary, result: int, roll: bool = false, roll_type: int = 1):
	var dr = cur_chart.note_draw_data.find(note)
	var type: int = note["note"]
	if dr != -1: 
		if $Notes.note_sprites[type] != null and soul_curve.get_child_count() < 32 and result != JudgeType.BAD:
			var spr: Sprite2D = Sprite2D.new()
			spr.texture = $Notes.note_sprites[type]
			spr.material = ShaderMaterial.new()
			spr.material.shader = tint_shader
			spr.material.set_shader_parameter("color", Color.WHITE)
			if roll:
				spr.texture = $Notes.note_sprites[roll_type]
			if (type == 3 or type == 4):
				var dai_effect: AnimatedSprite2D = AnimatedSprite2D.new()
				dai_effect.sprite_frames = dai_frames
				dai_effect.play(str(result))
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
			ptween.tween_method(func(val):
				spr.material.set_shader_parameter("mixture", val)
			, 0.0, 1.0, 0.3)
			ptween.set_parallel(true)
			ptween.tween_callback(spawn_gauge_effect)
			ptween.set_parallel(false)
			ptween.tween_interval(0.1)
			ptween.tween_method(func(val):
				spr.material.set_shader_parameter("alpha", val)
			, 1.0, 0.0, 0.2)
			ptween.tween_callback(pathfind.queue_free)
			soul_curve.add_child(pathfind)
			if not roll:
				var note_boom: NoteSoulEffect = NoteSoulEffect.new()
				note_boom.note_type = type
				note_boom.global_position = notes.judgement_position
				note_boom.z_index = -1
				note_boom.judge = result
				add_child(note_boom)
		if not roll:
			cur_chart.note_draw_data.remove_at(dr)
	
func auto_play():
	if not autoplay: return
	auto_roll()
	# It really is that shrimple
	if current_note_list.size() <= 0: return
	while current_note_list.size() > 0 and current_note_list[0]["time"] < elapsed:
		var note: Dictionary = current_note_list.pop_front()
		# Look, we can't detect if we should hit if we don't have one.
		if not note.has("time"): continue
		if note.has("dummy"): continue
		var type: int = note["note"]
		var time: float = note["time"]
		# Do not include special notes from now on.
		if type >= 999: continue
		# Should we register a hit?
		if time >= elapsed: continue
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
				last_roll_note = cur_chart.note_draw_data[cur_chart.note_draw_data.find(note)+1]
				rolling = true
				roll_timer = 0
				roll_mmm = 0
			8: 
				rolling = false
			ChartData.NoteType.SWAP:
				taiko.taiko_input(0, auto_don_side, true)
				taiko.taiko_input(1, auto_kat_side, true)
				auto_don_side = wrapi(auto_don_side+1, 0, 2)
				auto_kat_side = wrapi(auto_kat_side+1, 0, 2)
		var result = hit_note(type, time)
		if result == JudgeType.INVALID: continue
		#if type == 5 or type == 6 or type == 7 or type == 8: continue
		# These two are fundamentally the same
		if result == JudgeType.ROLL: continue
		remove_note_and_add_to_arc(note, result)
		# This manual break is fucking needed.
		if current_note_list.size() <= 0:
			break

func handle_input():
	if autoplay: return
	if (Input.is_action_just_pressed("don_left") or Input.is_action_just_pressed("don_right")) and not rolling:
		var hit = check_note(1)
		if Input.is_action_just_pressed("don_left"):
			taiko.taiko_input(0, 0, hit)
		if Input.is_action_just_pressed("don_right"):
			taiko.taiko_input(0, 1, hit)
	if (Input.is_action_just_pressed("ka_left") or Input.is_action_just_pressed("ka_right")) and not rolling:
		var hit = check_note(2)
		if Input.is_action_just_pressed("ka_left"):
			taiko.taiko_input(1, 0, hit)
		if Input.is_action_just_pressed("ka_right"):
			taiko.taiko_input(1, 1, hit)
	if ((Input.is_action_just_pressed("don_left") or Input.is_action_just_pressed("don_right")) and \
	(Input.is_action_just_pressed("ka_left") or Input.is_action_just_pressed("ka_right"))) and not rolling:
		var hit = check_note(10)
		if Input.is_action_just_pressed("don_left"):
			taiko.taiko_input(0, 0, hit)
		if Input.is_action_just_pressed("don_right"):
			taiko.taiko_input(0, 1, hit)
		if Input.is_action_just_pressed("ka_left"):
			taiko.taiko_input(1, 0, hit)
		if Input.is_action_just_pressed("ka_right"):
			taiko.taiko_input(1, 1, hit)
	if (Input.is_action_just_pressed("don_left") or Input.is_action_just_pressed("don_right")) or \
	(Input.is_action_just_pressed("ka_left") or Input.is_action_just_pressed("ka_right")):
		if rolling and not last_roll_note.is_empty():
			if Input.is_action_just_pressed("don_left"):
				taiko.taiko_input(0, 0, true, true)
			if Input.is_action_just_pressed("don_right"):
				taiko.taiko_input(0, 1, true, true)
			if Input.is_action_just_pressed("ka_left"):
				taiko.taiko_input(1, 0, true, true)
			if Input.is_action_just_pressed("ka_right"):
				taiko.taiko_input(1, 1, true, true)
			if last_roll_note["roll_note_type"] == 5:
				var dummy_type: int = 1
				if (Input.is_action_just_pressed("ka_left") or Input.is_action_just_pressed("ka_right")):
					dummy_type = 2
				remove_note_and_add_to_arc(last_roll_note, JudgeType.GREAT, true, dummy_type)
				handle_score_animation(ScoreManager.calc_roll(score, 2, gogo_time_active))
			elif last_roll_note["roll_note_type"] == 6:
				var dummy_type: int = 3
				if (Input.is_action_just_pressed("ka_left") or Input.is_action_just_pressed("ka_right")):
					dummy_type = 4
				remove_note_and_add_to_arc(last_roll_note, JudgeType.GREAT, true, dummy_type)
				handle_score_animation(ScoreManager.calc_roll(score, 3, gogo_time_active))
			if last_roll_note["roll_color_mod"] != Color.RED:
				last_roll_note["roll_color_mod"].r = lerpf(1, Color.RED.r, 0.25*roll_mmm)
				last_roll_note["roll_color_mod"].g = lerpf(1, Color.RED.g, 0.25*roll_mmm)
				last_roll_note["roll_color_mod"].b = lerpf(1, Color.RED.b, 0.25*roll_mmm)
			roll_mmm += 1
	var fucked: PackedInt64Array
	# Check for unpressed lmao
	for i in range(0, min(current_note_list.size(), 512)):
		var note: Dictionary = current_note_list[i]
		# Look, we can't detect if we should hit if we don't have one.
		if not note.has("time"): continue
		if note.has("dummy"): continue
		var type: int = note["note"]
		var time: float = note["time"]
		# Do not include special notes from now on.
		if type >= 999: continue
		if (type == 5 or type == 6) and time < elapsed:
			rolling = true
			roll_mmm = 0
			last_roll_note = cur_chart.note_draw_data[cur_chart.note_draw_data.find(note)+1]
		if type == 8 and time < elapsed:
			rolling = false
			last_roll_note = {}
		if time > elapsed - JUDGEMENT_BAD: continue
		var result = hit_note(type, time)
		if result == JudgeType.INVALID: continue
		# These two are fundamentally the same
		fucked.append(i)
		if result == JudgeType.ROLL: continue
		remove_note_and_add_to_arc(note, result)
	# Remove offending notes
	if fucked.size() > 0:
		for fuck in fucked:
			current_note_list.remove_at(fuck)

func check_note(check_type: int):
	var hit: bool = false
	var fucked: PackedInt64Array
	for i in range(0, min(current_note_list.size(), 512)):
		var note: Dictionary = current_note_list[i]
		# Look, we can't detect if we should hit if we don't have one.
		if not note.has("time"): continue
		if note.has("dummy"): continue
		var type: int = note["note"]
		var time: float = note["time"]
		# Do not include special notes from now on.
		if type >= 999: continue
		if time > elapsed + JUDGEMENT_BAD: continue
		var old_type: int = type
		match check_type:
			1:
				if type == 3:
					type = 1
			2:
				if type == 4:
					type = 2
		if type != check_type: continue
		var result = hit_note(type, time)
		type = old_type
		if result == JudgeType.INVALID: continue
		# These two are fundamentally the same
		fucked.append(i)
		if result == JudgeType.ROLL: continue
		remove_note_and_add_to_arc(note, result)
		hit = true
		break
	# Remove offending notes
	if fucked.size() > 0:
		for fuck in fucked:
			current_note_list.remove_at(fuck)
	return hit

var gogo_time_active: bool = false

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
				$RhythmNotifier.bpm = current_bpm
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
					gogo_time_active = true
				ChartData.NoteType.GOGOEND:
					don_chan.state = 0
					var tween = create_tween()
					tween.set_parallel(true)
					tween.tween_property($GogoEffect, "modulate:a", 0.0, 0.1)
					tween.tween_property($Taiko/SFieldEffects/SfieldGogo, "scale:y", 0.0, 0.1)
					gogo_time_active = false
			cur_chart.specil.remove_at(i)

var last_current_beat: float = 0.0

func _physics_process(delta: float) -> void:
	$FPS.text = str(Engine.get_frames_per_second())
	
	if Input.is_action_just_pressed("autoplay"):
		autoplay = !autoplay
		$Autoplay.visible = autoplay
	
	if not cur_chart: return
	elapsed = audio.get_playback_position() + AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	elapsed -= AudioServer.get_output_latency()
	# Apply preamble.
	elapsed -= preamble.time_left
	
	handle_play_events()
	handle_input()
	
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

func _on_easy_pressed() -> void:
	find_chart_and_play(0)

func _on_normal_pressed() -> void:
	find_chart_and_play(1)

func _on_hard_pressed() -> void:
	find_chart_and_play(2)

func _on_oni_pressed() -> void:
	find_chart_and_play(3)

func _on_edit_pressed() -> void:
	find_chart_and_play(4)
