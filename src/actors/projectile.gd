class_name Projectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var lifetime: float = 1.4
var shot_group_id: int = 0
var hit_result: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	add_child(shape)

	var visual := Polygon2D.new()
	visual.polygon = PackedVector2Array([
		Vector2(8, 0),
		Vector2(-5, -4),
		Vector2(-3, 0),
		Vector2(-5, 4),
	])
	visual.color = Color(0.85, 0.92, 1.0, 1.0)
	visual.rotation = direction.angle()
	add_child(visual)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_hit"):
		# Enforce anti-shotgun rule via shot_group_id
		var accepted: bool = body.take_hit(hit_result, shot_group_id)
		if accepted:
			queue_free()
