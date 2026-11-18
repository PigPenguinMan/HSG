class_name Enemy
extends CharacterBody2D

signal died(enemy: Enemy, position: Vector2, is_rare: bool)

const BalanceDBScript := preload("res://src/core/balance_db.gd")

var _enemy_bal: Dictionary = {}
var aggro_radius: float = 360.0
var attack_cd_base: float = 1.1

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
var sprite_path: String = "res://assets/sprites/enemy_feral.png"
var sprite_scale: float = 1.0
var knockback_resist: float = 0.0

var bleed_dps: float = 0.0
var bleed_timer: float = 0.0
var ignite_dps: float = 0.0
var ignite_timer: float = 0.0
var attack_cooldown: float = 0.0
var aggro: bool = false
var _seen_shot_groups: Dictionary = {}
var _visual: Sprite2D
var _hp_bar: ColorRect
var _flash_timer: float = 0.0
var _knockback_vel: Vector2 = Vector2.ZERO
var _anim_timer: float = 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 2 | 4

	_enemy_bal = BalanceDBScript.get_section("enemies")
	aggro_radius = float(_enemy_bal.get("aggro_radius", 360.0))

	_setup_stats()
	# Monster level scaling (level 1 = base)
	var scaling: Dictionary = _enemy_bal.get("level_scaling", {})
	var lv := float(maxi(monster_level, 1) - 1)
	max_hp *= 1.0 + float(scaling.get("hp_per_level", 0.18)) * lv
	attack_damage *= 1.0 + float(scaling.get("damage_per_level", 0.12)) * lv
	armour *= 1.0 + float(scaling.get("armour_per_level", 0.10)) * lv
	xp_reward = int(float(xp_reward) * (1.0 + float(scaling.get("xp_per_level", 0.15)) * lv))
	hp = max_hp

	var col := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(body_size, body_size)
	col.shape = rect
	add_child(col)

	_visual = Sprite2D.new()
	_visual.texture = load(sprite_path)
	_visual.hframes = 2
	_visual.scale = Vector2(sprite_scale, sprite_scale)
	add_child(_visual)

	_hp_bar = ColorRect.new()
	_hp_bar.size = Vector2(body_size + 6, 3)
	_hp_bar.position = Vector2(-(body_size + 6) * 0.5, -body_size * 0.5 - 7)
	_hp_bar.color = Color(0.9, 0.15, 0.15)
	add_child(_hp_bar)


## Override in subclasses to set base stats before level scaling.
func _setup_stats() -> void:
	var tier_key: String = "rare" if is_rare else "normal"
	var cfg: Dictionary = _enemy_bal.get(tier_key, {})
	if is_rare:
		max_hp = float(cfg.get("max_hp", 220.0))
		move_speed = float(cfg.get("move_speed", 115.0))
		attack_damage = float(cfg.get("attack_damage", 18.0))
		armour = float(cfg.get("armour", 60.0))
		evasion = float(cfg.get("evasion", 10.0))
		body_size = 24.0
		xp_reward = int(cfg.get("xp_reward", 90))
		knockback_resist = float(cfg.get("knockback_resist", 0.5))
		attack_cd_base = float(cfg.get("attack_cooldown", 1.1))
		sprite_path = "res://assets/sprites/enemy_rare.png"
		sprite_scale = 1.05
		base_color = Color(0.85, 0.65, 0.15)
	else:
		max_hp = float(cfg.get("max_hp", 60.0))
		move_speed = float(cfg.get("move_speed", 95.0))
		attack_damage = float(cfg.get("attack_damage", 10.0))
		armour = float(cfg.get("armour", 20.0))
		evasion = float(cfg.get("evasion", 10.0))
		xp_reward = int(cfg.get("xp_reward", 25))
		knockback_resist = float(cfg.get("knockback_resist", 0.0))
		attack_cd_base = float(cfg.get("attack_cooldown", 1.1))


func _physics_process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			_visual.modulate = Color.WHITE

	_anim_timer += delta
	if _anim_timer >= 0.22:
		_anim_timer = 0.0
		_visual.frame = 1 - _visual.frame
	if absf(velocity.x) > 5.0:
		_visual.flip_h = velocity.x < 0.0

	_knockback_vel = _knockback_vel.move_toward(Vector2.ZERO, 950.0 * delta)

	if bleed_timer > 0.0:
		bleed_timer -= delta
		var moving_mult: float = 2.5 if velocity.length() > 10.0 else 1.0
		hp -= bleed_dps * moving_mult * delta
		_update_hp_bar()
		if hp <= 0.0:
			_die()
			return

	if ignite_timer > 0.0:
		ignite_timer -= delta
		hp -= ignite_dps * delta
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
		if to_player.length() > aggro_radius:
			return
		aggro = true
	_ai(delta, player, to_player)


## Default melee chase AI. Bosses override this.
func _ai(_delta: float, player: Node2D, to_player: Vector2) -> void:
	if to_player.length() > 26.0:
		velocity = to_player.normalized() * move_speed + _knockback_vel
		move_and_slide()
	else:
		velocity = _knockback_vel
		if _knockback_vel.length() > 5.0:
			move_and_slide()
		if attack_cooldown <= 0.0 and player.has_method("take_damage"):
			attack_cooldown = attack_cd_base
			player.take_damage(attack_damage)


func take_hit(hit_result: Dictionary, shot_group_id: int = 0) -> bool:
	if shot_group_id > 0:
		if _seen_shot_groups.has(shot_group_id):
			return false
		_seen_shot_groups[shot_group_id] = true

	aggro = true
	var dmg: float = float(hit_result.get("total_hit_damage", 10.0))
	var is_crit: bool = bool(hit_result.get("is_crit", false))
	hp -= dmg
	_visual.modulate = Color(2.5, 2.5, 2.5)
	_flash_timer = 0.09

	var dmg_text := "%d!" % int(roundf(dmg)) if is_crit else "%d" % int(roundf(dmg))
	var txt_col := Color(1.0, 0.85, 0.2) if is_crit else Color(0.95, 0.95, 0.95)
	FloatingText.spawn(get_parent(), global_position, dmg_text, txt_col, 16 if is_crit else 12)
	_spawn_hit_sparks(is_crit)

	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null:
		var push_dir := (global_position - player.global_position).normalized()
		_knockback_vel = push_dir * (185.0 if is_crit else 120.0) * (1.0 - knockback_resist)
		if hp <= 0.0:
			player.shake(4.0, 0.14)
			player.trigger_hitstop(0.045)
		elif is_crit:
			player.shake(3.0, 0.11)
			player.trigger_hitstop(0.032)
		else:
			player.shake(1.6, 0.08)

	var ailments: Dictionary = _enemy_bal.get("ailment_duration", {})
	var incoming_bleed: float = float(hit_result.get("bleed_dps", 0.0))
	if incoming_bleed > bleed_dps:
		bleed_dps = incoming_bleed
		bleed_timer = float(ailments.get("bleed", 4.0))

	var incoming_ignite: float = float(hit_result.get("ignite_dps", 0.0))
	if incoming_ignite > ignite_dps:
		ignite_dps = incoming_ignite
		ignite_timer = float(ailments.get("ignite", 4.0))

	_update_hp_bar()
	if hp <= 0.0:
		_die()
	return true


func _spawn_hit_sparks(is_crit: bool) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var count := 5 if is_crit else 3
	for _i in range(count):
		var spark := ColorRect.new()
		spark.size = Vector2(4, 4)
		spark.position = global_position - Vector2(2, 2)
		spark.color = Color(1.0, 0.85, 0.25) if is_crit else Color(1.0, 0.45, 0.35)
		spark.z_index = 15
		parent.add_child(spark)
		var dir := Vector2.from_angle(randf() * TAU) * randf_range(18.0, 38.0)
		var tw := spark.create_tween()
		tw.set_parallel(true)
		tw.tween_property(spark, "position", spark.position + dir, 0.14)
		tw.tween_property(spark, "modulate:a", 0.0, 0.14)
		tw.finished.connect(spark.queue_free)


func _update_hp_bar() -> void:
	var ratio := clampf(hp / max_hp, 0.0, 1.0)
	_hp_bar.size.x = (body_size + 6.0) * ratio


func _die() -> void:
	if is_queued_for_deletion():
		return
	died.emit(self, global_position, is_rare)
	queue_free()
