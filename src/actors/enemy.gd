class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy, position: Vector2, is_rare: bool)

const AGGRO_RADIUS: float = 360.0

var is_rare: bool = false
var monster_level: int = 1
var xp_reward: int = 25
var max_hp: float = 60.0
var hp: float = 60.0
var move_speed: float = 95.0
var attack_damage: float = 10.0
var armour: float = 20.0
var evasion: float = 10.0
var body_size: float = 18.0
var base_color: Color = Color(0.65, 0.22, 0.22)

var bleed_dps: float = 0.0
var bleed_timer: float = 0.0
var attack_cooldown: float = 0.0
var aggro: bool = false
var _seen_shot_groups: Dictionary = {}
var _visual: ColorRect
var _hp_bar: ColorRect
var _flash_timer: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4

	_setup_stats()
	# Monster level scaling (level 1 = base)
	var lv := float(maxi(monster_level, 1) - 1)
	max_hp *= 1.0 + 0.18 * lv
	attack_damage *= 1.0 + 0.12 * lv
	armour *= 1.0 + 0.1 * lv
	xp_reward = int(float(xp_reward) * (1.0 + 0.15 * lv))
	hp = max_hp

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_size, body_size)
	col.shape = rect
	add_child(col)

	_visual = ColorRect.new()
	_visual.size = Vector2(body_size, body_size)
	_visual.position = Vector2(-body_size * 0.5, -body_size * 0.5)
	_visual.color = base_color
	add_child(_visual)

	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(body_size + 6, 3)
	_hp_bar.position = Vector2(-(body_size + 6) * 0.5, -body_size * 0.5 - 7)
	_hp_bar.color = Color(0.9, 0.15, 0.15)
	add_child(_hp_bar)


## Override in subclasses to set base stats before level scaling.
func _setup_stats() -> void:
	if is_rare:
		max_hp = 220.0
		move_speed = 115.0
		attack_damage = 18.0
		armour = 60.0
		body_size = 24.0
		xp_reward = 90
		base_color = Color(0.85, 0.65, 0.15)


func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_visual.color = base_color

	if bleed_timer > 0.0:
		bleed_timer -= delta
		var moving_mult: float = 2.5 if velocity.length() > 10.0 else 1.0
		hp -= bleed_dps * moving_mult * delta
		_update_hp_bar()
		if hp <= 0.0:
			_die()
			return

	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return
	var to_player := player.global_position - global_position
	if not aggro:
		if to_player.length() > AGGRO_RADIUS:
			return
		aggro = true
	_ai(delta, player, to_player)


## Default melee chase AI. Bosses override this.
func _ai(_delta: float, player: Node2D, to_player: Vector2) -> void:
	if to_player.length() > 26.0:
		velocity = to_player.normalized() * move_speed
		move_and_slide()
	else:
		velocity = Vector2.ZERO
		if attack_cooldown <= 0.0 and player.has_method("take_damage"):
			attack_cooldown = 1.1
			player.take_damage(attack_damage)


func take_hit(hit_result: Dictionary, shot_group_id: int = 0) -> bool:
	if shot_group_id > 0:
		if _seen_shot_groups.has(shot_group_id):
			return false
		_seen_shot_groups[shot_group_id] = true

	aggro = true
	var dmg: float = float(hit_result.get("total_hit_damage", 10.0))
	hp -= dmg
	_visual.color = Color(1.0, 1.0, 1.0)
	_flash_timer = 0.09

	var incoming_bleed: float = float(hit_result.get("bleed_dps", 0.0))
	if incoming_bleed > bleed_dps:
		bleed_dps = incoming_bleed
		bleed_timer = 4.0

	_update_hp_bar()
	if hp <= 0.0:
		_die()
	return true


func _update_hp_bar() -> void:
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar.size.x = (body_size + 6.0) * ratio


func _die() -> void:
	if is_queued_for_deletion():
		return
	died.emit(self, global_position, is_rare)
	queue_free()
