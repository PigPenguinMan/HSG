class_name Player
extends CharacterBody2D

signal stats_changed(hp: float, max_hp: float, mana: float, max_mana: float, flask_charges: int, level: int, xp: int, xp_next: int)
signal rpg_state_changed()
signal player_died()

const MAX_INVENTORY_SLOTS: int = 24
const BASE_HP: float = 100.0
const BASE_MANA: float = 60.0
const BASE_ARMOUR: float = 50.0
const BASE_MOVE_SPEED: float = 210.0

var stats := StatAggregator.new()
var passive_tree := PassiveTreeGraph.new()
var item_gen := ItemGenerator.new()

var level: int = 1
var xp: int = 0
var xp_to_next: int = 100
var passive_points: int = 2

var max_hp: float = 120.0
var hp: float = 120.0
var max_mana: float = 60.0
var mana: float = 60.0
var armour: float = 80.0
var move_speed: float = 210.0
var flask_charges: int = 3
var ui_blocking_input: bool = false

var equipment: Dictionary = {
	"WEAPON": null,
	"ARMOUR": null,
	"BOOTS": null,
	"RING_1": null,
	"RING_2": null,
	"AMULET": null,
}
var inventory: Array = []
var currency_pouch: Dictionary = {
	StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT: 2,
	StatTypes.CurrencyType.BLOODSTONE_OF_FORGE: 2,
	StatTypes.CurrencyType.BLOODSTONE_OF_RUIN: 2,
	StatTypes.CurrencyType.BLOODSTONE_OF_PURGE: 1,
	StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH: 1,
}

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

	passive_tree.load_from_json_file("res://data/passive_tree.json")
	item_gen.load_affixes_from_json_file("res://data/affixes.json")

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

	recalculate_stats()
	hp = max_hp
	mana = max_mana
	_emit_stats()


func recalculate_stats() -> void:
	stats.clear()
	# Wolf innate bonuses
	stats.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 25.0, "wolf_innate"))
	stats.add_modifier(StatTypes.make_mod("BLEED_CHANCE", StatTypes.ModType.FLAT, 40.0, "wolf_innate"))
	stats.add_modifier(StatTypes.make_mod("AILMENT_DAMAGE", StatTypes.ModType.INCREASED, 20.0, "wolf_innate"))

	# Passive tree
	passive_tree.collect_modifiers(stats)

	# Equipped gear
	for slot_key in equipment.keys():
		var item = equipment[slot_key]
		if item is Dictionary:
			_collect_item_mods(item)

	var attrs := stats.compute_attributes(14.0, 24.0, 10.0)
	var level_life := float(level - 1) * 12.0
	max_hp = stats.get_stat("MAX_LIFE", BASE_HP + level_life + attrs["LIFE_FROM_STR"])
	if stats.has_flag("BLOODTHIRST"):
		max_mana = 0.0
		mana = 0.0
	else:
		max_mana = stats.get_stat("MAX_MANA", BASE_MANA + attrs["MANA_FROM_INT"])
		mana = minf(mana, max_mana)

	hp = minf(hp, max_hp)
	armour = stats.get_stat("ARMOUR", BASE_ARMOUR)
	move_speed = stats.get_stat("MOVEMENT_SPEED", BASE_MOVE_SPEED)

	_emit_stats()
	rpg_state_changed.emit()


func _collect_item_mods(item: Dictionary) -> void:
	var uid: String = str(item.get("uid", "gear"))
	for mod_list_key in ["prefixes", "suffixes"]:
		for m in item.get(mod_list_key, []):
			var mtype := StatTypes.ModType.FLAT
			if str(m.get("modType", "FLAT")) == "INCREASED":
				mtype = StatTypes.ModType.INCREASED
			stats.add_modifier(StatTypes.make_mod(
				str(m.get("stat", "")),
				mtype,
				float(m.get("value", 0.0)),
				uid
			))


func add_item_to_inventory(item: Dictionary) -> bool:
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	inventory.append(item)
	rpg_state_changed.emit()
	return true


func add_currency(currency_type: int, amount: int = 1) -> void:
	currency_pouch[currency_type] = int(currency_pouch.get(currency_type, 0)) + amount
	rpg_state_changed.emit()


func equip_from_inventory(inv_index: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	var item: Dictionary = inventory[inv_index]
	var slot_name: String = str(item.get("slot", ""))
	var target_key := slot_name
	if slot_name == "RING":
		target_key = "RING_1" if equipment["RING_1"] == null else ("RING_2" if equipment["RING_2"] == null else "RING_1")
	if not equipment.has(target_key):
		return false

	var previous = equipment[target_key]
	equipment[target_key] = item
	if previous is Dictionary:
		inventory[inv_index] = previous
	else:
		inventory.remove_at(inv_index)

	recalculate_stats()
	return true


func unequip_slot(slot_key: String) -> bool:
	if not equipment.has(slot_key) or equipment[slot_key] == null:
		return false
	if inventory.size() >= MAX_INVENTORY_SLOTS:
		return false
	inventory.append(equipment[slot_key])
	equipment[slot_key] = null
	recalculate_stats()
	return true


func apply_currency_to_inventory(inv_index: int, currency_type: int) -> bool:
	if inv_index < 0 or inv_index >= inventory.size():
		return false
	if int(currency_pouch.get(currency_type, 0)) <= 0:
		return false
	var item: Dictionary = inventory[inv_index]
	if not item_gen.apply_currency(item, currency_type):
		return false
	currency_pouch[currency_type] = int(currency_pouch[currency_type]) - 1
	rpg_state_changed.emit()
	return true


func allocate_passive(node_id: String) -> bool:
	if passive_points <= 0:
		return false
	if passive_tree.allocate(node_id):
		passive_points -= 1
		recalculate_stats()
		return true
	return false


func refund_passive(node_id: String) -> bool:
	if passive_tree.refund(node_id):
		passive_points += 1
		recalculate_stats()
		return true
	return false


func _physics_process(delta: float) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	if not stats.has_flag("BLOODTHIRST"):
		mana = minf(max_mana, mana + 8.0 * delta)

	if ui_blocking_input:
		velocity = Vector2.ZERO
		return

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

	var atk_speed_mult: float = stats.get_stat("ATTACK_SPEED", 1.0)
	var cd_scale: float = 1.0 / maxf(0.5, atk_speed_mult)

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and _attack_cd <= 0.0:
		if _try_spend_resource(4.0):
			_use_crimson_flurry(mouse_dir, cd_scale)
	elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and _attack_cd <= 0.0:
		if _try_spend_resource(8.0):
			_use_piercing_fang(mouse_dir, cd_scale)

	if Input.is_key_pressed(KEY_1) and flask_charges > 0 and hp < max_hp:
		flask_charges -= 1
		hp = minf(max_hp, hp + 45.0)

	_emit_stats()


func _try_spend_resource(cost: float) -> bool:
	if stats.has_flag("BLOODTHIRST"):
		# Safety rule: cannot fatally spend life
		if hp <= cost:
			return false
		hp -= cost
		return true
	if mana < cost:
		return false
	mana -= cost
	return true


func _use_crimson_flurry(aim_dir: Vector2, cd_scale: float) -> void:
	_attack_cd = 0.34 * cd_scale
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

	var crit_chance: float = clampf(0.15 * stats.get_stat("CRIT_CHANCE", 1.0), 0.0, 1.0)
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var to_e := enemy.global_position - global_position
		if to_e.length() <= 64.0 and to_e.normalized().dot(aim_dir) >= 0.35:
			var is_crit := randf() < crit_chance
			var res := DamagePipeline.calculate_hit(stats, {"armour": enemy.armour, "evasion": enemy.evasion}, skill, is_crit)
			enemy.take_hit(res, 0)


func _use_piercing_fang(aim_dir: Vector2, cd_scale: float) -> void:
	_attack_cd = 0.30 * cd_scale
	_shot_group_counter += 1
	var group_id := _shot_group_counter

	var skill := {
		"damage_source": StatTypes.DamageSource.ATTACK_HIT,
		"tags": ["ATTACK", "PROJECTILE", "PHYSICAL"],
		"base_physical": 22.0,
		"damage_effectiveness": 0.9,
	}
	var crit_chance: float = clampf(0.15 * stats.get_stat("CRIT_CHANCE", 1.0), 0.0, 1.0)
	var res := DamagePipeline.calculate_hit(stats, {"armour": 15.0, "evasion": 0.0}, skill, randf() < crit_chance)

	for offset in [-0.18, 0.0, 0.18]:
		var proj := Projectile.new()
		proj.direction = aim_dir.rotated(offset)
		proj.shot_group_id = group_id
		proj.hit_result = res
		get_parent().add_child(proj)
		proj.global_position = global_position + proj.direction * 14.0


func on_enemy_killed(is_rare: bool) -> void:
	flask_charges = mini(5, flask_charges + (2 if is_rare else 1))
	var gained_xp := 90 if is_rare else 25
	xp += gained_xp
	while xp >= xp_to_next and level < 20:
		xp -= xp_to_next
		level += 1
		passive_points += 1
		xp_to_next = int(float(xp_to_next) * 1.45)
		recalculate_stats()
		hp = max_hp
		mana = max_mana
	_emit_stats()
	rpg_state_changed.emit()


func take_damage(raw_phys: float) -> void:
	var dr := DamagePipeline.calculate_armour_dr(armour, raw_phys)
	var taken_mult := stats.get_stat("DAMAGE_TAKEN", 1.0)
	hp -= raw_phys * (1.0 - dr) * taken_mult
	if hp <= 0.0:
		hp = max_hp
		mana = max_mana
		global_position = Vector2.ZERO
		player_died.emit()
	_emit_stats()


func _emit_stats() -> void:
	stats_changed.emit(hp, max_hp, mana, max_mana, flask_charges, level, xp, xp_to_next)


func _build_wolf_pixel_sprite() -> void:
	_body_node = Node2D.new()
	add_child(_body_node)

	var torso := ColorRect.new()
	torso.size = Vector2(16, 18)
	torso.position = Vector2(-8, -9)
	torso.color = Color(0.55, 0.58, 0.65)
	_body_node.add_child(torso)

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

	var eye := ColorRect.new()
	eye.size = Vector2(3, 2)
	eye.position = Vector2(3, -5)
	eye.color = Color(0.95, 0.25, 0.25)
	_body_node.add_child(eye)

	var tail := ColorRect.new()
	tail.size = Vector2(7, 4)
	tail.position = Vector2(-14, 2)
	tail.color = Color(0.45, 0.48, 0.55)
	_body_node.add_child(tail)
