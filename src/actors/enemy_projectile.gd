class_name EnemyProjectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 280.0
var damage: float = 20.0
var lifetime: float = 1.6


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	col.shape = circle
	add_child(col)

	var vis := Sprite2D.new()
	vis.texture = load("res://assets/sprites/proj_blood.png")
	vis.rotation = direction.angle()
	add_child(vis)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
