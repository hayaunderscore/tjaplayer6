extends Node2D
class_name NoteDrawer

var draw_list: Array[Dictionary]
var bar_list: Array[Dictionary]
var time: float = 0.0

var note_spr: Texture2D = preload("res://gfx/note_placeholder.png")

var note_sprites: Array[Texture2D] = [
	null,
	preload("res://gfx/notes/don_1.png"),
	preload("res://gfx/notes/kat_1.png"),
	preload("res://gfx/notes/don_4.png"),
	preload("res://gfx/notes/kat_4.png"),
	preload("res://gfx/notes/roll_1.png"),
	preload("res://gfx/notes/roll_6.png"),
	preload("res://gfx/notes/geki_1.png"),
	preload("res://gfx/notes/roll_5.png"),
	preload("res://gfx/notes/geki_1.png"),
]
var balloon_end: Texture2D = preload("res://gfx/notes/geki_4.png")
var roll_ends: Array[Texture2D] = [
	null, null, null, null, null, 
	preload("res://gfx/notes/roll_5.png"),
	preload("res://gfx/notes/roll_9.png"),
	null, null
]
var roll_bodies: Array[Texture2D] = [
	null, null, null, null, null, 
	preload("res://gfx/notes/roll_4.png"),
	preload("res://gfx/notes/roll_8.png"),
	null, null
]
var combo50_anims: Array[Array] = [
	[null, null],
	[preload("res://gfx/notes/don_1.png"), preload("res://gfx/notes/don_2.png")],
	[preload("res://gfx/notes/kat_1.png"), preload("res://gfx/notes/kat_2.png")],
	[preload("res://gfx/notes/don_4.png"), preload("res://gfx/notes/don_5.png")],
	[preload("res://gfx/notes/kat_4.png"), preload("res://gfx/notes/kat_5.png")],
	[preload("res://gfx/notes/roll_1.png"), preload("res://gfx/notes/roll_2.png")],
	[preload("res://gfx/notes/roll_6.png"), preload("res://gfx/notes/roll_7.png")],
	[preload("res://gfx/notes/geki_1.png"), preload("res://gfx/notes/geki_2.png")],
	[null, null],
	[null, null],
]
var bar_line: Texture2D = preload("res://gfx/notes/line.png")

var current_beat: float = 0.0
var bemani_scroll: bool = false
var speed_multiplier: Vector2 = Vector2.ONE

# Thanks to IID/IepIweidieng from the TJADB discord!
# (note_x, note_y) = scroll_modifier × ((scroll_x_t, scroll_y_t) × (time_note - time_current) + (scroll_x_b, scroll_y_b) × (beat_note - beat_current))

# scroll_[x/y]_t = scroll_[x/y] × (px_width_note_field / 4) × (bpm_note / 60 (s))  (#NMSCROLL), or otherwise 0
func get_note_position(ms, bpm, scroll: Vector2, beat: float, dummy: bool = false, offset: float = 0):
	if bemani_scroll and ms >= time: 
		return get_note_hbscroll_position(scroll, beat, offset)
	return Vector2((scroll.x * speed_multiplier.x * (530/4) * (bpm / 60)) * (ms - time) + 148 - offset,
			(scroll.y * speed_multiplier.y * (530/4) * (bpm / 60)) * (ms - time) + 164)

# scroll_[x/y]_b = {scroll_[x/y] (#HBSCROLL) or [1/0] (#BMSCROLL)} × (px_width_note_field / 4) (#HBSCROLL/#BMSCROLL), or otherwise 0
func get_note_hbscroll_position(scroll: Vector2, beat: float, offset: float = 0):
	return Vector2((scroll.x * speed_multiplier.x * (530/4)) * (beat - current_beat) + 148 - offset,
			(scroll.y * speed_multiplier.y * (530/4)) * (beat - current_beat) + 164)

var cur_bpm: float = 0.0
var combo_anim: bool = false

var fon: Font = preload("res://gfx/font/OtomanopeeOne-Regular.ttf")
var roll_se: Texture2D = preload("res://gfx/notes/se/roll_m_3.png")

func _draw() -> void:
	for i in range(0, bar_list.size(), 1):
		var note: Dictionary = bar_list[i]
		var pos = get_note_position(note["time"], note["bpm"], note["scroll"], note["beat_position"])
		draw_set_transform(pos, pos.angle_to_point(Vector2(148, 164)))
		draw_texture_rect(bar_line, Rect2(Vector2(0, -bar_line.get_height()/2), Vector2(bar_line.get_width(), bar_line.get_height())),
			false)
	
	for i in range(min(draw_list.size()-1, 512), -1, -1):
		var note: Dictionary = draw_list[i]
		if note["note"] >= 999: continue
		var col: Color = Color.WHITE
		var note_scale: Vector2 = Vector2(1, 1)
		var pos = get_note_position(note["time"], note["bpm"], note["scroll"], note["beat_position"], note.has("dummy"), note.get("dummy_offset", 0))
		if pos.x > 640+80 and note["note"] != 8: continue
		if (note["note"] < note_sprites.size() and note_sprites[note["note"]] != null) or note["note"] == 999:
			var spr: Texture2D
			if note["note"] < 999: spr = note_sprites[note["note"]]
			if combo_anim and combo50_anims[note["note"]] != null:
				spr = combo50_anims[note["note"]][abs(floori(current_beat*4))%combo50_anims[note["note"]].size()]
			if note["note"] == ChartData.NoteType.BALLOON:
				draw_texture_rect(balloon_end, Rect2(pos + Vector2(80, 0) - (Vector2(spr.get_width()/2, spr.get_height()/2) * note_scale), Vector2(spr.get_width(), spr.get_height()) * note_scale),
					false, col)
			match note["note"]:
				ChartData.NoteType.END_ROLL:
					var last_note: Dictionary = note["roll_note"]
					var last_type: int = last_note["note"]
					if last_type == ChartData.NoteType.BALLOON:
						continue
					# I think it's probably best we precalculate these
					# Doing this is not accurate to how TaikoJiro's rolls work
					# See: Oshama Scramble complex number chart
					var last_pos: Vector2 = get_note_position(last_note["time"], last_note["bpm"], last_note["scroll"], last_note["beat_position"], false, note.get("dummy_offset", 0))
					draw_set_transform(last_pos, last_pos.angle_to_point(pos))
					var dist: float = last_pos.distance_to(pos)
					# Draw tail body
					if roll_bodies[last_type] != null:
						var rect: Rect2 = Rect2(-Vector2(0, roll_bodies[last_type].get_height()/2), Vector2(dist+1, roll_bodies[last_type].get_height())).abs()
						draw_texture_rect(roll_bodies[last_type], rect, true, col)
					# Draw tail end
					if roll_ends[last_type] != null:
						var rect: Rect2 = Rect2(Vector2(dist, -roll_ends[last_type].get_height()/2), Vector2(roll_ends[last_type].get_width(), roll_ends[last_type].get_height())).abs()
						draw_texture_rect(roll_ends[last_type], rect, true, col)
					# Draw se note
					var rect = Rect2(-Vector2(-roll_ends[last_type].get_width()/4, -36*sign(last_note["scroll"].x)), Vector2(dist, roll_se.get_height())).abs()
					draw_texture_rect(roll_se, rect, true, col)
					# Reset when done >:(
					draw_set_transform(Vector2.ZERO)
				_:
					draw_set_transform(Vector2.ZERO)
					draw_texture_rect(spr, Rect2(pos - (Vector2(spr.get_width()/2, spr.get_height()/2) * note_scale), Vector2(spr.get_width(), spr.get_height()) * note_scale),
						false, col)
					var se_note: Texture2D = note["senote"]
					draw_texture_rect(se_note, Rect2(pos - (Vector2(se_note.get_width()/2, -36) * note_scale), Vector2(se_note.get_width(), se_note.get_height()) * note_scale),
						false, col)

func _process(delta: float) -> void:
	queue_redraw()
