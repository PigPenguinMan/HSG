class_name Projectile
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 520.0
var lifetime: float = 1.4
var shot_group_id: int = 0
var hit_result: Dictionary = {}
var color: Color = Color(0.85, 0.92, 1.0, 1.0)
var aoe_radius: float = 0.0
var leech_pct: float = 0.0
var owner_player: Player = null


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 8.0 if aoe_radius > 0.0 else 6.0
	shape.shape = circle
	add_child(shape)

	var visual := Sprite2D.new()
	visual.texture = load("res://assets/sprites/proj_orb.png" if aoe_radius > 0.0 else "res://assets/sprites/proj_fang.png")
	visual.rotation = direction.angle()
	add_child(visual)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node) -> void:
	if not body.has_method("take_hit"):
		return
	var accepted: bool = body.take_hit(hit_result, shot_group_id)
	if not accepted:
		return

	var dmg := float(hit_result.get("total_hit_damage", 0.0))
	if leech_pct > 0.0 and is_instance_valid(owner_player):
		owner_player.heal(dmg * leech_pct)

	if aoe_radius > 0.0:
		_explode_aoe(body)
	queue_free()


func _explode_aoe(direct_target: Node) -> void:
	var parent := get_parent()
	if parent != null:
		var ring := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in range(20):
			pts.append(Vector2.from_angle(TAU * float(i) / 20.0) * aoe_radius)
		ring.polygon = pts
		ring.color = Color(color.r, color.g, color.b, 0.4)
		ring.global_position = global_position
		parent.add_child(ring)
		var tw := ring.create_tween()
		tw.tween_property(ring, "modulate:a", 0.0, 0.16)
		tw.finished.connect(ring.queue_free)

	var dmg := float(hit_result.get("total_hit_damage", 0.0))
	for node in get_tree().get_nodes_in_group("enemies"):
		if node == direct_target or not is_instance_valid(node):
			continue
		if node.global_position.distance_to(global_position) <= aoe_radius and node.has_method("take_hit"):
			if node.take_hit(hit_result, 0) and leech_pct > 0.0 and is_instance_valid(owner_player):
				owner_player.heal(dmg * leech_pct)
