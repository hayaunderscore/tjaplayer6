extends Node2D

var curtja: TJAFile
var combo: int = 0
var combo_scale_add: float = 0.0
@onready var combo_text: Label = $Taiko/Control/Combo
@onready var soul_curve: Path2D = $BaseSoulCurve

var combo_fonts: Array[FontVariation] = [
	preload("res://gfx/number/combo_normal.tres"),
	preload("res://gfx/number/combo_medium.tres"),
	preload("res://gfx/number/combo_beeg.tres"),
]

var current_bpm: float = 0.0
var current_meter: float = 0.0

func _ready() -> void:
	get_viewport().files_dropped.connect(on_files_dropped)

func on_files_dropped(files):
	curtja = TJA.parse_tja(files[0])
	print("Should have been loaded! Playing song...")
	print(curtja.chartinfo.size())
	copied_notes = curtja.chartinfo[0].notes.duplicate(true)
	print(curtja.chartinfo[0].barline_data.size())
	curtja.chartinfo[0].barline_data.reverse()
	$Label2.text = "BPM: %.2f" % curtja.start_bpm
	$Label3.text = "TimeSig: 4"
	$Label4.text = "Scroll X: %.2f" % curtja.head_scroll
	$Label7.text = "Title: %s" % curtja.alttitle
	$Label8.text = "Subtitle: %s" % curtja.subtitle
	note_draw_list = curtja.chartinfo[0].note_draw_data.duplicate(true)
	note_draw_list.reverse()
	$Taiko/KaLeft.modulate.a = 0
	$Taiko/KaRight.modulate.a = 0
	$Taiko/DonLeft.modulate.a = 0
	$Taiko/DonRight.modulate.a = 0
	$Timer.start()
	$Chara.curbpm = curtja.start_bpm
	
var playednotes: Array[Dictionary]
var roll_speed: float = 0.05
var rolling: bool = false

var cur_notes: Array[Dictionary]
var copied_notes: Array[Dictionary]
var spr: Array[Sprite2D]
var note_spr: Texture2D = preload("res://gfx/note_placeholder.png")
var note_draw_list: Array[Dictionary]

var time: float = 0.0

func get_note_position(ms, pixels_per_frame):
	return int((640 * 1) + pixels_per_frame * 60 * (ms - time))

var zind: int = 0
func _physics_process(delta: float) -> void:
	$Label9.text = str(Engine.get_frames_per_second())
	if not curtja: return
	time = $AudioStreamPlayer.get_playback_position() + AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	time -= AudioServer.get_output_latency()
	time -= $Timer.time_left
	
	if (copied_notes.size() > 0 and cur_notes.size() < 1024 and time + 1000 >= copied_notes[copied_notes.size()-1]["load_ms"]):
		var note = copied_notes.pop_front()
		cur_notes.append(note)
		if (copied_notes.size() > 0 and copied_notes[copied_notes.size()-1]["note"] == 8):
			note = copied_notes.pop_front()
			cur_notes.append(note)
	
	$Notes.draw_list = note_draw_list
	$Notes.bar_list = curtja.chartinfo[0].barline_data
	$Notes.time = time

var roll_cont: float = 0

@onready var alph: Array[Sprite2D] = [
	$Taiko/KaLeft,
	$Taiko/KaRight,
	$Taiko/DonLeft,
	$Taiko/DonRight,
]

@onready var alph_delay: PackedFloat32Array = [
	0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0
]

var switch_ka: bool = false
var switch_don: bool = false
var small_roll: bool = true
var balloon: bool = false

func get_pixels_per_frame(bpm, fps, time_signature, distance):
	var beat_duration = fps / bpm
	var total_time = time_signature * beat_duration
	var total_frames = fps * total_time
	return (distance / total_frames) * (fps/60)

var screen_distance: float = (640 * 1) - 148

func _process(delta: float) -> void:
	if curtja:
		time = $AudioStreamPlayer.get_playback_position() + AudioServer.get_time_since_last_mix()
		# Compensate for output latency.
		time -= AudioServer.get_output_latency()
		time -= $Timer.time_left
		$Label.text = str(time)
		$Chara.song_pos = time+$Timer.wait_time
		
		for i in range(0, 4, 1):
			var spr: Sprite2D = alph[i]
			alph_delay[i] = max(0, alph_delay[i]-delta)
			if alph_delay[i] <= 0:
				spr.modulate.a = move_toward(spr.modulate.a, 0, 0.25)
		
		for i in range(4, alph_delay.size(), 1):
			alph_delay[i] = max(0, alph_delay[i]-delta)
			if alph_delay[i] > 0: continue
			match i:
				4:
					$Taiko/SFieldEffects/SfieldHit.modulate.a = move_toward($Taiko/SFieldEffects/SfieldHit.modulate.a, 0, 0.15)
				5:
					$Taiko/SFieldEffects/SfieldRed.modulate.a = move_toward($Taiko/SFieldEffects/SfieldRed.modulate.a, 0, 0.15)
				6:
					$Taiko/SFieldEffects/SfieldBlue.modulate.a = move_toward($Taiko/SFieldEffects/SfieldBlue.modulate.a, 0, 0.15)
		
		for i in range(cur_notes.size()-1, -1, -1):
			var note: Dictionary = cur_notes[i]
			if note.has("time") and (note["time"] <= time):
				match note["note"]:
					ChartData.NoteType.GOGOSTART:
						$Chara.state = 1
						$Chara.gogo_beat = 0
						cur_notes.remove_at(i)
						continue
					ChartData.NoteType.GOGOEND:
						$Chara.state = 0
						cur_notes.remove_at(i)
						continue
			if note["note"] >= 999: continue
			if note.has("time") and (note["time"] < time):
				$Taiko/SFieldEffects/SfieldHit.modulate.a = 0.5
				alph_delay[4] = 0.1+delta
				match note["note"]:
					1, 3:
						$Don.play()
						switch_don = !switch_don
						alph[2+int(switch_don)].modulate.a = 1
						$Taiko/SFieldEffects/SfieldBlue.modulate.a = 0
						$Taiko/SFieldEffects/SfieldRed.modulate.a = 0.5
						alph_delay[2+int(switch_don)] = 0.1
						alph_delay[5] = 0.1+delta
						combo += 1
						combo_scale_add = 0.35
					2, 4:
						$Kat.play()
						switch_ka = !switch_ka
						alph[int(switch_ka)].modulate.a = 1
						$Taiko/SFieldEffects/SfieldBlue.modulate.a = 0.5
						$Taiko/SFieldEffects/SfieldRed.modulate.a = 0
						alph_delay[int(switch_ka)] = 0.1
						alph_delay[6] = 0.1+delta
						combo += 1
						combo_scale_add = 0.35
					5, 6, 7, 9:
						roll_cont = 0
						rolling = true
					8:
						rolling = false
				match note["note"]:
					3:
						alph[2].modulate.a = 1
						alph[3].modulate.a = 1
						alph_delay[2] = 0.1
						alph_delay[3] = 0.1
					4:
						alph[0].modulate.a = 1
						alph[1].modulate.a = 1
						alph_delay[0] = 0.1
						alph_delay[1] = 0.1
				balloon = false
				match note["note"]:
					5: small_roll = true
					6: small_roll = false
					7: balloon = true
				cur_notes.remove_at(i)
				if combo < 50:
					combo_text.set("theme_override_fonts/font", combo_fonts[0])
				elif combo >= 50 and combo < 100:
					combo_text.set("theme_override_fonts/font", combo_fonts[1])
				else:
					combo_text.set("theme_override_fonts/font", combo_fonts[2])
				if (combo % 100 == 0) and combo >= 100:
					$Taiko/Control/ComboFlower.show_flower()
				var dr = note_draw_list.find(note)
				if dr != -1 and note["note"] < 5: 
					if $Notes.note_sprites[note["note"]] != null:
						var spr: Sprite2D = Sprite2D.new()
						spr.texture = $Notes.note_sprites[note["note"]]
						var pathfind: PathFollow2D = PathFollow2D.new()
						pathfind.add_child(spr)
						pathfind.rotates = false
						pathfind.create_tween().tween_property(pathfind, "progress_ratio", 1.0, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
						soul_curve.add_child(pathfind)
						if note["note"] < 5:
							var note_boom: NoteSoulEffect = NoteSoulEffect.new()
							note_boom.note_type = note["note"]
							note_boom.global_position = Vector2(148, 164)
							note_boom.z_index = -1
							add_child(note_boom)
					note_draw_list.remove_at(dr)
		for note in curtja.chartinfo[0].command_log:
			if note.has("time") and (note["time"] > time - delta and note["time"] < time + delta):
				match note["com"]:
					ChartData.CommandType.BPMCHANGE:
						$Label2.text = "BPM: %.2f" % note["val1"]
						var lastbpm = $Chara.curbpm
						$Chara.curbpm = note["val1"]
						var bpmchangemul = $Chara.curbpm / lastbpm
						# Recalculate loadms and ppf
						# BPM CHANGE 0 causes issues...
						if curtja.chartinfo[0].bemani_scroll:
							print("bemani scroll! change ppf NOW")
							for n in cur_notes:
								if n["note"] < 999:
									var old = n["time"]
									n["time"] = note["time"] + (n["time"] - note["time"]) / bpmchangemul
									n["ppf"] = n["ppf"] * bpmchangemul
									n["load_ms"] = n["time"] - (screen_distance / n["ppf"] / 60)
									n["time"] = old
							for n in note_draw_list:
								if n["note"] < 999:
									var old = n["time"]
									n["time"] = note["time"] + (n["time"] - note["time"]) / bpmchangemul
									n["ppf"] = n["ppf"] * bpmchangemul
									n["load_ms"] = n["time"] - (screen_distance / n["ppf"] / 60)
									n["time"] = old
					ChartData.CommandType.MEASURE:
						$Label3.text = "TimeSig: %.2f" % note["val1"]
					ChartData.CommandType.SCROLL:
						$Label4.text = "Scroll X: %.2f" % note["val1"]
						if note.has("val2"):
							$Label5.text = "Scroll Y: %.2f" % note["val2"]
				# print(note["com"], " COMMAND AT: ", note["time"], " WITH VALUE1: ", note["val1"], " WITH VALUE2: ", note.get("val2", 0))
		if rolling:
			if roll_cont > roll_speed:
				roll_cont = 0
			if roll_cont <= 0:
				switch_don = !switch_don
				alph_delay[2+int(switch_don)] = 0.1
				$Taiko/SFieldEffects/SfieldHit.modulate.a = 0.5
				alph_delay[4] = 0.1+delta
				alph[2+int(switch_don)].modulate.a = 1
				$Taiko/SFieldEffects/SfieldBlue.modulate.a = 0
				$Taiko/SFieldEffects/SfieldRed.modulate.a = 0.5
				$Don.play()
				if not balloon:
					var spr: Sprite2D = Sprite2D.new()
					spr.texture = $Notes.note_sprites[(1 if small_roll else 3)]
					var pathfind: PathFollow2D = PathFollow2D.new()
					pathfind.add_child(spr)
					pathfind.rotates = false
					pathfind.create_tween().tween_property(pathfind, "progress_ratio", 1.0, 0.65).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					soul_curve.add_child(pathfind)
			roll_cont += delta
		
		for child in soul_curve.get_children():
			var path: PathFollow2D = child as PathFollow2D
			if path.progress_ratio >= 1.0:
				path.queue_free()
		
		if combo >= 10:
			combo_text.get_parent().visible = true
			combo_text.text = str(combo)
			combo_text.scale.y = 2.5 + combo_scale_add
			if combo_text.text.length() > 2:
				combo_text.scale.x = (3.0 / (combo_text.text.length())) * 2.5
			combo_scale_add = max(0, combo_scale_add - delta*3)

func _on_timer_timeout() -> void:
	$AudioStreamPlayer.stream = curtja.wave
	$AudioStreamPlayer.play()
