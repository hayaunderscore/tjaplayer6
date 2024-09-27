extends TextureRect

var timer: Timer = Timer.new()

func _ready() -> void:
	timer.wait_time = 3.0
	timer.one_shot = true
	timer.timeout.connect(stop_timer)
	add_child(timer)
	scale = Vector2.ZERO

func stop_timer():
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0, 0.25)
	tween.tween_property(self, "scale", Vector2.ZERO, 0)

func show_flower():
	modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	timer.start()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
