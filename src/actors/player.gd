class_name Player
extends CharacterBody2D

signal stats_changed(hp: float, max_hp: float, mana: float, max_mana: float, flask_charges: int)
signal player_died()

var stats := StatAggregator.new()
var max_hp: float = 120.0
var hp: float = 120.0
var max_mana: float = 60.0
var mana: float = 60.0
var armour: float = 80.0
var move_speed: float = 210.0
var flask_charges: int = 3

var _attack_cd: float = 0.0
var _dash_cd: float = 0.0
var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO
var _shot_group_counter: int = 1
var _body_node: Node2D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	add_child(col)

	_build_wolf_pixel_sprite()

	var cam := Camera2D.new()
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(1.4, 1.4)
	add_child(cam)

	_init_starter_stats()
	_emit_stats()


func _init_starter_stats() -> void:
	stats.clear()
	stats.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 25.0, "wolf_innate"))
	stats.add_modifier(StatTypes.make_mod("BLEED_CHANCE", StatTypes.ModType.FLAT, 40.0, "wolf_innate"))
	stats.add_modifier(StatTypes.make_mod("AILMENT_DAMAGE", StatTypes.ModType.INCREASED, 20.0, "wolf_innate"))


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	mana = minf(max_mana, mana + 8.0 * delta)

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * 620.0
		move_and_slide()
		return

	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	).normalized()

	velocity = input_dir * move_speed
	move_and_slide()

	var mouse_dir := (get_global_mouse_position() - global_position).normalized()
	if mouse_dir.x != 0.0:
		_body_node.scale.x = 1.0 if mouse_dir.x >= 0.0 else -1.0

	if Input.is_action_just_pressed("skill_dash") and _dash_cd <= 0.0:
		_dash_dir = mouse_dir if input_dir == Vector2.ZERO else input_dir
		_dash_timer = 0.16
		_dash_cd = 1.2

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _attack_cd <= 0.0:
		_use_crimson_flurry(mouse_dir)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _attack_cd <= 0.0 and mana >= 8.0:
		_use_piercing_fang(mouse_dir)

	if Input.is_key_pressed(KEY_1) and flask_charges > 0 and hp < max_hp:
		flask_charges -= 1
		hp = minf(max_hp, hp + 45.0)

	_emit_stats()


func _use_crimson_flurry(aim_dir: Vector2) -> void:
	_attack_cd = 0.34
	var slash := Polygon2D.new()
	var base_angle := aim_dir.angle()
	var pts := PackedVector2Array([Vector2.ZERO])
	for i in range(-4, 5):
		var a := base_angle + float(i) * 0.14
		pts.append(Vector2.from_angle(a) * 56.0)
	slash.polygon = pts
	slash.color = Color(0.85, 0.12, 0.18, 0.55)
	get_parent().add_child(slash)
	slash.global_position = global_position
	get_tree().create_timer(0.11).timeout.connect(slash.queue_free)

	var skill := {
		"damage_source": StatTypes.DamageSource.ATTACK_HIT,
		"tags": ["ATTACK", "MELEE", "AOE", "PHYSICAL", "BLEED"],
		"base_physical": 26.0,
		"damage_effectiveness": 1.1,
	}

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var to_e := enemy.global_position - global_position
		if to_e.length() <= 64.0 and to_e.normalized().dot(aim_dir) >= 0.35:
			var is_crit := randf() < 0.25
			var res := DamagePipeline.calculate_hit(stats, {"armour": enemy.armour, "evasion": enemy.evasion}, skill, is_crit)
			enemy.take_hit(res, 0)


func _use_piercing_fang(aim_dir: Vector2) -> void:
	_attack_cd = 0.30
	mana -= 8.0
	_shot_group_counter += 1
	var group_id := _shot_group_counter

	var skill := {
		"damage_source": StatTypes.DamageSource.ATTACK_HIT,
		"tags": ["ATTACK", "PROJECTILE", "PHYSICAL"],
		"base_physical": 22.0,
		"damage_effectiveness": 0.9,
	}
	var res := DamagePipeline.calculate_hit(stats, {"armour": 15.0, "evasion": 0.0}, skill, randf() < 0.25)

	for offset in [-0.18, 0.0, 0.18]:
		var proj := Projectile.new()
		proj.direction = aim_dir.rotated(offset)
		proj.shot_group_id = group_id
		proj.hit_result = res
		get_parent().add_child(proj)
		proj.global_position = global_position + proj.direction * 14.0


func on_enemy_killed(is_rare: bool) -> void:
	flask_charges = mini(5, flask_charges + (2 if is_rare else 1))
	_emit_stats()


func take_damage(raw_phys: float) -> void:
	var dr := DamagePipeline.calculate_armour_dr(armour, raw_phys)
	hp -= raw_phys * (1.0 - dr)
	if hp <= 0.0:
		hp = max_hp
		mana = max_mana
		global_position = Vector2.ZERO
		player_died.emit()
	_emit_stats()


func _emit_stats() -> void:
	stats_changed.emit(hp, max_hp, mana, max_mana, flask_charges)


func _build_wolf_pixel_sprite() -> void:
	_body_node = Node2D.new()
	add_child(_body_node)

	# Wolf body (dark silver pixel silhouette)
	var torso := ColorRect.new()
	torso.size = Vector2(16, 18)
	torso.position = Vector2(-8, -9)
	torso.color = Color(0.55, 0.58, 0.65)
	_body_node.add_child(torso)

	# Pointed wolf ears
	var ear_l := ColorRect.new()
	ear_l.size = Vector2(4, 5)
	ear_l.position = Vector2(-7, -14)
	ear_l.color = Color(0.42, 0.45, 0.52)
	_body_node.add_child(ear_l)

	var ear_r := ColorRect.new()
	ear_r.size = Vector2(4, 5)
	ear_r.position = Vector2(3, -14)
	ear_r.color = Color(0.42, 0.45, 0.52)
	_body_node.add_child(ear_r)

	# Glowing crimson eyes
	var eye := ColorRect.new()
	eye.size = Vector2(3, 2)
	eye.position = Vector2(3, -5)
	eye.color = Color(0.95, 0.25, 0.25)
	_body_node.add_child(eye)

	# Wolf tail
	var tail := ColorRect.new()
	tail.size = Vector2(7, 4)
	tail.position = Vector2(-14, 2)
	tail.color = Color(0.45, 0.48, 0.55)
	_body_node.add_child(tail)
