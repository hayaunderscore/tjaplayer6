extends Node2D
class_name LiteSprite2D

var texture: Texture2D

func _draw() -> void:
	draw_texture(texture, Vector2(-texture.get_width()/2, -texture.get_height()/2), modulate)
		
func _process(delta: float) -> void:
	queue_redraw()
