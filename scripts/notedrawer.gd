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
var bar_line: Texture2D = preload("res://gfx/notes/line.png")

var current_beat: float = 0.0
var bemani_scroll: bool = false

func get_note_position(ms, pixels_per_frame, scroll: Vector2, beat: float):
	if bemani_scroll: return get_note_hbscroll_position(scroll, beat)
	return int((640) + pixels_per_frame * 60 * (ms - time))

func get_note_hbscroll_position(scroll: Vector2, beat: float):
	return (scroll.x * (530/4)) * (beat - current_beat) + 152

func get_note_position_y(ms, pixels_per_frame):
	return int((480) + pixels_per_frame * 60 * (ms - time))

const scrolly_conv: float = 0.6366197723695659
var cur_bpm: float = 0.0

func _draw() -> void:
	for i in range(0, bar_list.size(), 1):
		var note: Dictionary = bar_list[i]
		var pos = get_note_position(note["load_ms"].x, note["ppf"].x, note["scroll"], note["beat_position"])
		var yoffs: float = 164.0
		draw_texture_rect(bar_line, Rect2(Vector2(pos, yoffs-bar_line.get_height()/2), Vector2(bar_line.get_width(), bar_line.get_height())),
			false)
	
	for i in range(min(draw_list.size()-1, 512), -1, -1):
		var note: Dictionary = draw_list[i]
		if note["note"] >= 999: continue
		var col: Color = Color.WHITE
		var note_scale: Vector2 = Vector2(1, 1)
		var pos = get_note_position(note["load_ms"].x, note["ppf"].x, note["scroll"], note["beat_position"])
		if pos > 640+80 and note["note"] != 8: continue
		if (note["note"] < note_sprites.size() and note_sprites[note["note"]] != null) or note["note"] == 999:
			var spr: Texture2D
			if note["note"] < 999: spr = note_sprites[note["note"]]
			var yoffs: float = 164.0
			# Handle y scroll...
			if note.get("scroll").y != 0:
				yoffs = 164+8 + get_note_position_y(note["load_ms"].y, note["ppf"].y)
			match note["note"]:
				_:
					draw_texture_rect(spr, Rect2(Vector2(pos, yoffs) - (Vector2(spr.get_width()/2, spr.get_height()/2) * note_scale), Vector2(spr.get_width(), spr.get_height()) * note_scale),
						false, col)
			if note["note"] == ChartData.NoteType.BALLOON:
				draw_texture_rect(balloon_end, Rect2(Vector2(pos + 80, yoffs) - (Vector2(spr.get_width()/2, spr.get_height()/2) * note_scale), Vector2(spr.get_width(), spr.get_height()) * note_scale),
					false, col)

func _process(delta: float) -> void:
	queue_redraw()
