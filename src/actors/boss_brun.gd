class_name BossBrun
extends Enemy

signal hp_changed(hp: float, max_hp: float)

enum State { CHASE, TELEGRAPH_SLAM, ENRAGE_CHARGE }

var _state: int = State.CHASE
var _state_timer: float = 0.0
var _slam_cd: float = 2.5
var _wave_cd: float = 3.2
var _charge_cd: float = 4.5
var _target_pos: Vector2 = Vector2.ZERO
var _charge_dir: Vector2 = Vector2.ZERO
var _telegraph_node: Polygon2D


func _setup_stats() -> void:
	max_hp = 900.0
	move_speed = 92.0
	attack_damage = 24.0
	armour = 90.0
	body_size = 38.0
	xp_reward = 300
	knockback_resist = 0.85
	sprite_path = "res://assets/sprites/boss_brun.png"
	sprite_scale = 1.1
	base_color = Color(0.55, 0.14, 0.18)


func _ready() -> void:
	super._ready()
	aggro = false
	hp_changed.emit(hp, max_hp)


func take_hit(hit_result: Dictionary, shot_group_id: int = 0) -> bool:
	var ok := super.take_hit(hit_result, shot_group_id)
	if ok:
		hp_changed.emit(maxf(0.0, hp), max_hp)
	return ok


func _ai(delta: float, player: Node2D, to_player: Vector2) -> void:
	var enraged := hp <= max_hp * 0.5
	var cd_rate := 1.35 if enraged else 1.0
	_slam_cd = maxf(0.0, _slam_cd - delta * cd_rate)
	_wave_cd = maxf(0.0, _wave_cd - delta * cd_rate)
	_charge_cd = maxf(0.0, _charge_cd - delta * cd_rate)

	match _state:
		State.TELEGRAPH_SLAM:
			velocity = Vector2.ZERO
			_state_timer -= delta
			if _state_timer <= 0.0:
				_execute_leap_slam(player)
				_state = State.CHASE
			return

		State.ENRAGE_CHARGE:
			_state_timer -= delta
			velocity = _charge_dir * 420.0
			move_and_slide()
			if global_position.distance_to(player.global_position) < 34.0 and attack_cooldown <= 0.0:
				attack_cooldown = 0.6
				if player.has_method("take_damage"):
					player.take_damage(attack_damage * 1.35)
			if _state_timer <= 0.0:
				_state = State.CHASE
			return

	# State.CHASE
	if _slam_cd <= 0.0 and to_player.length() < 260.0:
		_start_leap_slam(player.global_position)
		return

	if enraged and _charge_cd <= 0.0 and to_player.length() > 90.0:
		_charge_cd = 5.0
		_charge_dir = to_player.normalized()
		_state = State.ENRAGE_CHARGE
		_state_timer = 0.45
		return

	if _wave_cd <= 0.0 and to_player.length() < 340.0:
		_wave_cd = 3.6
		_fire_blood_shockwave(to_player.normalized())

	var spd := move_speed * (1.25 if enraged else 1.0)
	if to_player.length() > 34.0:
		velocity = to_player.normalized() * spd
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if attack_cooldown <= 0.0 and player.has_method("take_damage"):
			attack_cooldown = 1.15
			player.take_damage(attack_damage)


func _start_leap_slam(target: Vector2) -> void:
	_slam_cd = 4.2
	_state = State.TELEGRAPH_SLAM
	_state_timer = 0.95
	_target_pos = target

	_telegraph_node = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in range(24):
		var a := TAU * float(i) / 24.0
		pts.append(Vector2.from_angle(a) * 76.0)
	_telegraph_node.polygon = pts
	_telegraph_node.color = Color(0.95, 0.15, 0.15, 0.32)
	get_parent().add_child(_telegraph_node)
	_telegraph_node.global_position = _target_pos


func _execute_leap_slam(player: Node2D) -> void:
	if is_instance_valid(_telegraph_node):
		_telegraph_node.queue_free()
		_telegraph_node = null
	global_position = _target_pos
	if player is Player:
		(player as Player).shake(8.0, 0.22)
	if global_position.distance_to(player.global_position) <= 80.0 and player.has_method("take_damage"):
		player.take_damage(attack_damage * 1.8)


func _fire_blood_shockwave(dir: Vector2) -> void:
	for offset in [-0.32, 0.0, 0.32]:
		var proj := EnemyProjectile.new()
		proj.direction = dir.rotated(offset)
		proj.damage = attack_damage * 0.95
		get_parent().add_child(proj)
		proj.global_position = global_position + proj.direction * 20.0


func _die() -> void:
	if is_instance_valid(_telegraph_node):
		_telegraph_node.queue_free()
		_telegraph_node = null
	super._die()
