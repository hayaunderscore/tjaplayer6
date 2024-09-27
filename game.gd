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

func _ready() -> void:
	cur_tja = TJA.parse_tja("res://charts/Taiko Drum Monster.tja")
	if cur_tja.chartinfo.size() == 0:
		print("No chart detected! Abort!")
		return
	audio.stream = cur_tja.wave
	print("Playing first chart in chartinfo array...")
	cur_chart = cur_tja.chartinfo[0]
	current_bpm = cur_tja.start_bpm
	current_note_list.clear()
	preamble.start()

func preamble_timeout() -> void:
	audio.play()

func auto_play():
	if not autoplay: return
	# In reverse to handle removing these within the loop
	for i in range(current_note_list.size()-1, -1, -1):
		var note: Dictionary = current_note_list[i]
		# Look, we can't detect if we should hit if we don't have one.
		if not note.has("time"): continue
		var type: int = note["note"]
		var time: float = note["time"]
		# Handle special notes.
		if time < elapsed:
			match type:
				ChartData.NoteType.GOGOSTART:
					don_chan.state = 1
					don_chan.gogo_beat = 0
					current_note_list.remove_at(i)
				ChartData.NoteType.GOGOEND:
					don_chan.state = 0
					current_note_list.remove_at(i)
		# Do not include special notes from now on.
		if type >= 999: continue
		# Should we register a hit?
		if time >= elapsed: continue
		# Not a roll note
		if type < 5:
			combo += 1
			taiko.change_combo(combo)
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
		# These two are fundamentally the same
		current_note_list.remove_at(i)
		var dr = cur_chart.note_draw_data.find(note)
		if dr != -1 and type < 5: 
			if $Notes.note_sprites[type] != null:
				var spr: Sprite2D = Sprite2D.new()
				spr.texture = $Notes.note_sprites[type]
				var pathfind: PathFollow2D = PathFollow2D.new()
				pathfind.add_child(spr)
				pathfind.rotates = false
				pathfind.create_tween().tween_property(pathfind, "progress_ratio", 1.0, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				soul_curve.add_child(pathfind)
				if type < 5:
					var note_boom: NoteSoulEffect = NoteSoulEffect.new()
					note_boom.note_type = type
					note_boom.global_position = Vector2(148, 164)
					note_boom.z_index = -1
					add_child(note_boom)
			cur_chart.note_draw_data.remove_at(dr)

func _physics_process(delta: float) -> void:
	if not cur_chart: return
	elapsed = audio.get_playback_position() + AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	elapsed -= AudioServer.get_output_latency()
	# Apply preamble.
	elapsed -= preamble.time_left
	
	# DON CHAN #
	don_chan.curbpm = current_bpm
	# Negative values cause don-chan to not bop at the beginning
	don_chan.song_pos = elapsed + preamble.wait_time
	
	# The note list has a limited size of 1024 entries to prevent lag...
	# This should be enough...
	if cur_chart.notes.size() > 0 and current_note_list.size() < 1024 \
		and elapsed + 1000 >= cur_chart.notes[cur_chart.notes.size()-1]["load_ms"].x:
		var note = cur_chart.notes.pop_front()
		current_note_list.append(note)
	
	# TODO
	# notes.draw_list = cur_chart.note_draw_data
	# notes.bar_list = cur_chart.barline_data
	# notes.cur_bpm = current_bpm
	
	# Handle auto-play (enabled by default...)
	auto_play()
	
	# Soul curves
	for child in soul_curve.get_children():
		var path: PathFollow2D = child as PathFollow2D
		if path.progress_ratio >= 1.0:
			path.queue_free()
