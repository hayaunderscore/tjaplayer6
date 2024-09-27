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

var effect_layer: LiteSprite2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if judge == 0:
		modulate = Color.GOLD
	modulate.a = 0.5
	z_index = -1
	effect_layer = LiteSprite2D.new()
	effect_layer.z_index = 3
	add_child(effect_layer)
	effect_layer.global_position = global_position
	match note_type:
		1, 2:
			texture = note_small
			effect_table = effect_small
		3, 4:
			texture = note_big
			effect_table = effect_big
	effect_layer.texture = effect_table[judge]

func _draw() -> void:
	modulate.a = note_opacity
	draw_texture(texture, Vector2(-texture.get_width()/2, -texture.get_height()/2), modulate)

func _process(delta: float) -> void:
	queue_redraw()
	effect_delay = max(0, effect_delay-delta)
	note_delay = max(0, note_delay-delta)
	effect_layer.modulate.a = effect_opacity
	if effect_delay == 0:
		effect_delay = -1
		var tween = create_tween()
		tween.parallel().tween_property(self, "effect_opacity", 0.0, 0.83)
	if note_delay == 0:
		note_delay = -1
		var tween = create_tween()
		tween.parallel().tween_property(self, "note_opacity", 0.0, 0.132)
	if effect_opacity <= 0.02 and note_opacity <= 0.02:
		queue_free()
