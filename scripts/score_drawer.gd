@tool
extends Node2D

var font: Font = preload("res://gfx/number/score.tres")
var score: int = 621311251521 
var _score_string: String = "0000000000000"
var _score_tweens: Array[Tween] = [null]
var _score_scales: Array[float] = [0]
var processed: bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _draw() -> void:
	# Sneaky hack to prevent a stupid out of range error
	if not processed: return
	for i in range(0, _score_string.length(), 1):
		# print(i)
		draw_set_transform(Vector2((i*20)-_score_string.length()*20, 0-(_score_scales[i]*16)-16), 0, Vector2(1, 1+_score_scales[i]))
		draw_string(font, Vector2.ZERO, _score_string[i])

# Score scale change logic
# I am a stickler
func _process(delta: float) -> void:
	processed = true
	var last_string: String = _score_string
	_score_string = str(score)
	_score_tweens.resize(_score_string.length())
	_score_scales.resize(_score_string.length())
	# We have a new number
	if last_string.length() != _score_string.length():
		for i in range(0, _score_string.length()-last_string.length()):
			_score_tweens.push_front(null)
			_score_scales.push_front(0)
		# For every single character to possibly occupy
		for j in range(0, _score_string.length()-2):
			_score_tweens[j] = create_tween()
			_score_scales[j] = 0.15
			_score_tweens[j].tween_method(func(val):
				_score_scales[j] = val
			, 0.15, 0, 0.15)
	var change_last_zero: bool = false
	for i in range(0, _score_string.length(), 1):
		if (i < last_string.length() and last_string.unicode_at(i) != _score_string.unicode_at(i)) \
		or (change_last_zero and i >= _score_string.length()-3):
			_score_tweens[i] = create_tween()
			_score_scales[i] = 0.15
			_score_tweens[i].tween_method(func(val):
				_score_scales[i] = val
			, 0.15, 0, 0.15)
			change_last_zero = true
	queue_redraw()
