class_name FloatingText
extends Label

var _vel: Vector2 = Vector2(0.0, -42.0)
var _life: float = 0.55
var _max_life: float = 0.55


static func spawn(parent: Node, pos: Vector2, msg: String, color: Color, font_size: int = 12) -> void:
	if parent == null:
		return
	var ft := FloatingText.new()
	ft.text = msg
	ft.position = pos + Vector2(randf_range(-10.0, 10.0), -18.0)
	ft.z_index = 20
	ft.add_theme_color_override("font_color", color)
	ft.add_theme_font_size_override("font_size", font_size)
	ft._vel = Vector2(randf_range(-14.0, 14.0), -46.0)
	parent.add_child(ft)


func _process(delta: float) -> void:
	_life -= delta
	position += _vel * delta
	_vel.y += 30.0 * delta
	modulate.a = clampf(_life / _max_life, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
