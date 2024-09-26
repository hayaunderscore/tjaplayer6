extends Node2D
class_name NoteSoulEffect

var note_type: int = 0
var judge: int = 0

var effect_small: Array[Texture2D] = [
	preload("res://gfx/effects/effect_1.png"),
	preload("res://gfx/effects/effect_2.png"),
	null,
]

var effect_big: Array[Texture2D] = [
	preload("res://gfx/effects/effect_3.png"),
	preload("res://gfx/effects/effect_4.png"),
	null,
]

var note_small: Texture2D = preload("res://gfx/effects/effect_note_1.png")
var note_big: Texture2D = preload("res://gfx/effects/effect_note_2.png")

var effect_table: Array[Texture2D]
var effect_delay: float = 0.1
var note_delay: float = 0.2333
var effect_opacity: float = 0.5
var note_opacity: float = 1.0

var tween: Tween
var texture: Texture2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if judge == 0:
		modulate = Color.GOLD
	modulate.a = 0.5
	z_index = -1
	match note_type:
		1, 2:
			texture = note_small
			effect_table = effect_small
		3, 4:
			texture = note_big
			effect_table = effect_big

func _draw() -> void:
	modulate.a = note_opacity
	draw_texture(texture, Vector2(-texture.get_width()/2, -texture.get_height()/2), modulate)
	draw_texture(effect_table[judge], Vector2(-effect_table[judge].get_width()/2, -effect_table[judge].get_height()/2),
		Color(1, 1, 1, effect_opacity))

func _process(delta: float) -> void:
	queue_redraw()
	effect_delay = max(0, effect_delay-delta)
	note_delay = max(0, note_delay-delta)
	if effect_delay == 0:
		effect_delay = -1
		var tween = create_tween()
		tween.parallel().tween_property(self, "effect_opacity", 0.0, 0.132)
	if note_delay == 0:
		note_delay = -1
		var tween = create_tween()
		tween.parallel().tween_property(self, "note_opacity", 0.0, 0.083)
	if effect_opacity <= 0 and note_opacity <= 0:
		queue_free()
