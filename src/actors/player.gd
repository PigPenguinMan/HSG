class_name Player
extends CharacterBody2D

signal stats_changed(hp: float, max_hp: float, mana: float, max_mana: float, life_flask_charges: int, mana_flask_charges: int, level: int, xp: int, xp_next: int)
signal rpg_state_changed()
signal player_died()

const MAX_INVENTORY_SLOTS: int = 24
const BalanceDBScript := preload("res://src/core/balance_db.gd")

var _bal: Dictionary = {}
var base_hp: float = 100.0
var base_mana: float = 60.0
var base_armour: float = 50.0
var base_move_speed: float = 210.0
var base_str: float = 14.0
var base_dex: float = 24.0
var base_int: float = 10.0

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
var life_flask_charges: int = 3
var mana_flask_charges: int = 3
var ui_blocking_input: bool = false
var in_town: bool = false

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
var _cam: Camera2D
var _shake_intensity: float = 0.0
var _shake_timer: float = 0.0
var _hitstop_active: bool = false
var _hurt_flash_timer: float = 0.0
var _dash_hit_ids: Dictionary = {}
var _anim_timer: float = 0.0
var _life_flask_held: bool = false
var _mana_flask_held: bool = false

var skills_db: Dictionary = {}
var runes_db: Dictionary = {}
var skill_slots: Dictionary = {
	"LMB": {"skill_id": "crimson_flurry", "runes": []},
	"RMB": {"skill_id": "piercing_fang", "runes": []},
	"Q": {"skill_id": "bloodmoon_orb", "runes": []},
	"SPACE": {"skill_id": "shadow_dash", "runes": []},
}


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2 | 4

	_bal = BalanceDBScript.get_section("player")
	base_hp = float(_bal.get("base_hp", 100.0))
	base_mana = float(_bal.get("base_mana", 60.0))
	base_armour = float(_bal.get("base_armour", 50.0))
	base_move_speed = float(_bal.get("base_move_speed", 210.0))
	var b_attrs: Dictionary = _bal.get("base_attributes", {})
	base_str = float(b_attrs.get("str", 14.0))
	base_dex = float(b_attrs.get("dex", 24.0))
	base_int = float(b_attrs.get("int", 10.0))
	xp_to_next = int(_bal.get("xp_to_next_base", 100))
	passive_points = int(_bal.get("starting_passive_points", 2))

	passive_tree.load_from_json_file("res://data/passive_tree.json")
	item_gen.load_affixes_from_json_file("res://data/affixes.json")
	_load_skills_db()

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 10.0
	col.shape = circle
	add_child(col)

	_build_wolf_pixel_sprite()

	_cam = Camera2D.new()
	_cam.position_smoothing_enabled = true
	_cam.position_smoothing_speed = 8.0
	_cam.zoom = Vector2(1.4, 1.4)
	add_child(_cam)

	recalculate_stats()
	hp = max_hp
	mana = max_mana
	_emit_stats()


func recalculate_stats() -> void:
	stats.clear()
	# Wolf innate bonuses
	var innate: Dictionary = _bal.get("wolf_innate", {})
	stats.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, float(innate.get("physical_damage_increased", 25.0)), "wolf_innate"))
	stats.add_modifier(StatTypes.make_mod("BLEED_CHANCE", StatTypes.ModType.FLAT, float(innate.get("bleed_chance_flat", 40.0)), "wolf_innate"))
	stats.add_modifier(StatTypes.make_mod("AILMENT_DAMAGE", StatTypes.ModType.INCREASED, float(innate.get("ailment_damage_increased", 20.0)), "wolf_innate"))

	# Passive tree
	passive_tree.collect_modifiers(stats)

	# Equipped gear
	for slot_key in equipment.keys():
		var item: Variant = equipment[slot_key]
		if item is Dictionary:
			_collect_item_mods(item)

	var attrs := stats.compute_attributes(base_str, base_dex, base_int)
	var level_life := float(level - 1) * float(_bal.get("life_per_level", 12.0))
	max_hp = stats.get_stat("MAX_LIFE", base_hp + level_life + attrs["LIFE_FROM_STR"])
	if stats.has_flag("BLOODTHIRST"):
		max_mana = 0.0
		mana = 0.0
	else:
		max_mana = stats.get_stat("MAX_MANA", base_mana + attrs["MANA_FROM_INT"])
		mana = minf(mana, max_mana)

	hp = minf(hp, max_hp)
	armour = stats.get_stat("ARMOUR", base_armour)
	move_speed = stats.get_stat("MOVEMENT_SPEED", base_move_speed)

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

	var previous: Variant = equipment[target_key]
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
		mana = minf(max_mana, mana + float(_bal.get("mana_regen_per_sec", 8.0)) * delta)

	if ui_blocking_input:
		velocity = Vector2.ZERO
		return

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = _dash_dir * float(_bal.get("dash_speed", 620.0))
		move_and_slide()
		if not in_town:
			_shadow_dash_tick()
		return

	var move_x := Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	var move_y := Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	if move_x == 0.0:
		move_x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	if move_y == 0.0:
		move_y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	var input_dir := Vector2(move_x, move_y).normalized()

	velocity = input_dir * move_speed
	move_and_slide()

	if _body_node is Sprite2D:
		var spr := _body_node as Sprite2D
		_anim_timer += delta
		var interval := 0.16 if input_dir != Vector2.ZERO else 0.42
		if _anim_timer >= interval:
			_anim_timer = 0.0
			spr.frame = 1 - spr.frame

	var mouse_dir := (get_global_mouse_position() - global_position).normalized()
	if mouse_dir.x != 0.0:
		_body_node.scale.x = 1.0 if mouse_dir.x >= 0.0 else -1.0

	if Input.is_action_just_pressed("skill_dash") and _dash_cd <= 0.0:
		_dash_dir = mouse_dir if input_dir == Vector2.ZERO else input_dir
		_dash_timer = float(_bal.get("dash_duration", 0.16))
		_dash_cd = float(_bal.get("dash_cooldown", 1.2))
		_dash_hit_ids.clear()

	var atk_speed_mult: float = stats.get_stat("ATTACK_SPEED", 1.0)
	var cd_scale: float = 1.0 / maxf(0.5, atk_speed_mult)

	if not in_town and _attack_cd <= 0.0:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_trigger_slot("LMB", mouse_dir, cd_scale)
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			_trigger_slot("RMB", mouse_dir, cd_scale)
		elif Input.is_physical_key_pressed(KEY_Q):
			_trigger_slot("Q", mouse_dir, cd_scale)

	var k1_down: bool = Input.is_physical_key_pressed(KEY_1)
	if k1_down and not _life_flask_held and life_flask_charges > 0 and hp < max_hp:
		life_flask_charges -= 1
		hp = minf(max_hp, hp + float(_bal.get("flask_heal", 45.0)))
	_life_flask_held = k1_down

	var k2_down: bool = Input.is_physical_key_pressed(KEY_2)
	if k2_down and not _mana_flask_held and not stats.has_flag("BLOODTHIRST") and max_mana > 0.0 and mana < max_mana and mana_flask_charges > 0:
		mana_flask_charges -= 1
		mana = minf(max_mana, mana + float(_bal.get("mana_flask_restore", 40.0)))
	_mana_flask_held = k2_down

	_emit_stats()


func _load_skills_db() -> void:
	if not FileAccess.file_exists("res://data/skills.json"):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/skills.json"))
	if not parsed is Dictionary:
		return
	for s in parsed.get("active_skills", []):
		skills_db[str(s["id"])] = s
	for r in parsed.get("support_runes", []):
		runes_db[str(r["id"])] = r


func can_link_rune(skill_id: String, rune_id: String) -> bool:
	if not skills_db.has(skill_id) or not runes_db.has(rune_id):
		return false
	var stags: Array = skills_db[skill_id].get("tags", [])
	var reqs: Array = runes_db[rune_id].get("required_tags", [])
	for t in reqs:
		if stags.has(t):
			return true
	return false


func set_slot_skill(slot_key: String, skill_id: String) -> bool:
	if not skill_slots.has(slot_key) or not skills_db.has(skill_id):
		return false
	var slot: Dictionary = skill_slots[slot_key]
	slot["skill_id"] = skill_id
	var valid_runes: Array = []
	for rid in slot["runes"]:
		if can_link_rune(skill_id, str(rid)):
			valid_runes.append(rid)
	slot["runes"] = valid_runes
	rpg_state_changed.emit()
	return true


func toggle_rune(slot_key: String, rune_id: String) -> bool:
	if not skill_slots.has(slot_key):
		return false
	var slot: Dictionary = skill_slots[slot_key]
	var runes: Array = slot["runes"]
	if runes.has(rune_id):
		runes.erase(rune_id)
		rpg_state_changed.emit()
		return true
	if runes.size() >= 3 or not can_link_rune(str(slot["skill_id"]), rune_id):
		return false
	runes.append(rune_id)
	rpg_state_changed.emit()
	return true


func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
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


func _build_skill_context(skill_def: Dictionary, rune_ids: Array) -> Dictionary:
	var skill_stats := stats.clone()
	var extra_proj: int = 0
	var aoe_mult: float = 1.0
	var leech_pct: float = 0.0
	var sid := str(skill_def.get("id", ""))

	for rid in rune_ids:
		if not can_link_rune(sid, str(rid)):
			continue
		var r: Dictionary = runes_db[str(rid)]
		if r.has("extra_projectiles"):
			extra_proj += int(r["extra_projectiles"])
		if r.has("damage_more"):
			skill_stats.add_modifier(StatTypes.make_mod("GLOBAL_DAMAGE", StatTypes.ModType.MORE, float(r["damage_more"]), str(rid)))
		if r.has("phys_more"):
			skill_stats.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.MORE, float(r["phys_more"]), str(rid)))
		if bool(r.get("cannot_non_phys", false)):
			skill_stats.add_modifier(StatTypes.make_mod("CANNOT_DEAL_NON_PHYSICAL", StatTypes.ModType.FLAG, 1.0, str(rid)))
		if r.has("aoe_mult"):
			aoe_mult *= float(r["aoe_mult"])
		if r.has("leech_pct"):
			leech_pct += float(r["leech_pct"])

	return {
		"stats": skill_stats,
		"extra_proj": extra_proj,
		"aoe_mult": aoe_mult,
		"leech_pct": leech_pct,
	}


func _to_pipeline_skill(skill_def: Dictionary) -> Dictionary:
	var src := StatTypes.DamageSource.ATTACK_HIT
	if str(skill_def.get("damage_source", "ATTACK_HIT")) == "SPELL_HIT":
		src = StatTypes.DamageSource.SPELL_HIT
	return {
		"damage_source": src,
		"tags": skill_def.get("tags", []),
		"base_physical": float(skill_def.get("base_physical", 0.0)),
		"base_fire": float(skill_def.get("base_fire", 0.0)),
		"damage_effectiveness": float(skill_def.get("damage_effectiveness", 1.0)),
	}


func _trigger_slot(slot_key: String, aim_dir: Vector2, cd_scale: float) -> void:
	var slot: Dictionary = skill_slots.get(slot_key, {})
	var sid := str(slot.get("skill_id", ""))
	if not skills_db.has(sid):
		return
	var sdef: Dictionary = skills_db[sid]
	var cost := float(sdef.get("mana_cost", 4.0))
	if not _try_spend_resource(cost):
		return
	_attack_cd = float(sdef.get("cooldown", 0.34)) * cd_scale
	var ctx := _build_skill_context(sdef, slot.get("runes", []))
	match sid:
		"crimson_flurry":
			_exec_melee_cone(sdef, ctx, aim_dir, Color(0.85, 0.12, 0.18, 0.55), 0.35)
		"crushing_slam":
			_exec_melee_cone(sdef, ctx, aim_dir, Color(0.9, 0.55, 0.2, 0.55), 0.0)
		"piercing_fang":
			_exec_projectiles(sdef, ctx, aim_dir, Color(0.85, 0.92, 1.0), 520.0, 0.0)
		"bloodmoon_orb":
			var aoe := float(sdef.get("aoe_radius", 68.0)) * float(ctx["aoe_mult"])
			_exec_projectiles(sdef, ctx, aim_dir, Color(1.0, 0.35, 0.15), 400.0, aoe)


func _exec_melee_cone(sdef: Dictionary, ctx: Dictionary, aim_dir: Vector2, col: Color, dot_min: float) -> void:
	var radius: float = float(sdef.get("aoe_radius", 64.0)) * float(ctx["aoe_mult"])
	var slash := Polygon2D.new()
	var base_angle := aim_dir.angle()
	var pts := PackedVector2Array([Vector2.ZERO])
	var half_steps := 5 if dot_min <= 0.1 else 4
	for i in range(-half_steps, half_steps + 1):
		var a := base_angle + float(i) * (0.22 if dot_min <= 0.1 else 0.14)
		pts.append(Vector2.from_angle(a) * radius * 0.9)
	slash.polygon = pts
	slash.color = col
	get_parent().add_child(slash)
	slash.global_position = global_position
	get_tree().create_timer(0.12).timeout.connect(slash.queue_free)

	var p_stats: StatAggregator = ctx["stats"]
	var leech := float(ctx["leech_pct"])
	var pskill := _to_pipeline_skill(sdef)
	var base_crit: float = float(_bal.get("base_crit_chance", 0.15))
	var crit_chance: float = clampf(base_crit * p_stats.get_stat("CRIT_CHANCE", 1.0), 0.0, 1.0)

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null:
			continue
		var to_e := enemy.global_position - global_position
		if to_e.length() <= radius and to_e.normalized().dot(aim_dir) >= dot_min:
			var is_crit := randf() < crit_chance
			var res := DamagePipeline.calculate_hit(p_stats, {"armour": enemy.armour, "evasion": enemy.evasion}, pskill, is_crit)
			if enemy.take_hit(res, 0) and leech > 0.0:
				heal(float(res.get("total_hit_damage", 0.0)) * leech)


func _exec_projectiles(sdef: Dictionary, ctx: Dictionary, aim_dir: Vector2, col: Color, spd: float, aoe: float) -> void:
	_shot_group_counter += 1
	var group_id := _shot_group_counter
	var p_stats: StatAggregator = ctx["stats"]
	var pskill := _to_pipeline_skill(sdef)
	var base_crit: float = float(_bal.get("base_crit_chance", 0.15))
	var crit_chance: float = clampf(base_crit * p_stats.get_stat("CRIT_CHANCE", 1.0), 0.0, 1.0)
	var res := DamagePipeline.calculate_hit(p_stats, {"armour": 15.0, "evasion": 0.0}, pskill, randf() < crit_chance)

	var count: int = int(sdef.get("projectiles", 1)) + int(ctx["extra_proj"])
	var spread := 0.16
	for i in range(count):
		var offset := (float(i) - float(count - 1) * 0.5) * spread
		var proj := Projectile.new()
		proj.direction = aim_dir.rotated(offset)
		proj.speed = spd
		proj.color = col
		proj.aoe_radius = aoe
		proj.leech_pct = float(ctx["leech_pct"])
		proj.owner_player = self
		proj.shot_group_id = group_id
		proj.hit_result = res
		get_parent().add_child(proj)
		proj.global_position = global_position + proj.direction * 14.0


func _shadow_dash_tick() -> void:
	if not skills_db.has("shadow_dash"):
		return
	var sdef: Dictionary = skills_db["shadow_dash"]
	var slot: Dictionary = skill_slots.get("SPACE", {})
	var ctx := _build_skill_context(sdef, slot.get("runes", []))
	var p_stats: StatAggregator = ctx["stats"]
	var leech := float(ctx["leech_pct"])
	var pskill := _to_pipeline_skill(sdef)
	var base_crit: float = float(_bal.get("base_crit_chance", 0.15))
	var crit_chance: float = clampf(base_crit * p_stats.get_stat("CRIT_CHANCE", 1.0), 0.0, 1.0)

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or _dash_hit_ids.has(enemy.get_instance_id()):
			continue
		if enemy.global_position.distance_to(global_position) <= 28.0:
			_dash_hit_ids[enemy.get_instance_id()] = true
			var res := DamagePipeline.calculate_hit(p_stats, {"armour": enemy.armour, "evasion": enemy.evasion}, pskill, randf() < crit_chance)
			if enemy.take_hit(res, 0) and leech > 0.0:
				heal(float(res.get("total_hit_damage", 0.0)) * leech)


func on_enemy_killed(is_rare: bool, xp_override: int = -1) -> void:
	var max_life_flask: int = int(_bal.get("flask_max_charges", 5))
	var max_mana_flask: int = int(_bal.get("mana_flask_max_charges", 5))
	var gain: int = 2 if is_rare else 1
	life_flask_charges = mini(max_life_flask, life_flask_charges + gain)
	mana_flask_charges = mini(max_mana_flask, mana_flask_charges + gain)
	var gained_xp := xp_override if xp_override >= 0 else (90 if is_rare else 25)
	xp += gained_xp
	var max_lv: int = int(_bal.get("max_level", 20))
	var xp_mult: float = float(_bal.get("xp_level_multiplier", 1.45))
	while xp >= xp_to_next and level < max_lv:
		xp -= xp_to_next
		level += 1
		passive_points += 1
		xp_to_next = int(float(xp_to_next) * xp_mult)
		recalculate_stats()
		hp = max_hp
		mana = max_mana
	_emit_stats()
	rpg_state_changed.emit()


func _process(delta: float) -> void:
	if _hurt_flash_timer > 0.0:
		_hurt_flash_timer -= delta
		if _hurt_flash_timer <= 0.0 and is_instance_valid(_body_node):
			_body_node.modulate = Color.WHITE

	if _shake_timer > 0.0 and is_instance_valid(_cam):
		_shake_timer -= delta
		var strength := _shake_intensity * clampf(_shake_timer / 0.14, 0.0, 1.0)
		_cam.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		if _shake_timer <= 0.0:
			_cam.offset = Vector2.ZERO


func shake(intensity: float, duration: float = 0.14) -> void:
	_shake_intensity = maxf(_shake_intensity, intensity)
	_shake_timer = maxf(_shake_timer, duration)


func trigger_hitstop(duration: float = 0.04) -> void:
	if _hitstop_active or not is_inside_tree():
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	get_tree().create_timer(duration, true, false, true).timeout.connect(func() -> void:
		Engine.time_scale = 1.0
		_hitstop_active = false
	)


func take_damage(raw_phys: float) -> void:
	var dr := DamagePipeline.calculate_armour_dr(armour, raw_phys)
	var taken_mult := stats.get_stat("DAMAGE_TAKEN", 1.0)
	var final_dmg := raw_phys * (1.0 - dr) * taken_mult
	hp -= final_dmg
	if is_instance_valid(_body_node):
		_body_node.modulate = Color(1.0, 0.35, 0.35)
		_hurt_flash_timer = 0.12
	shake(4.5, 0.14)
	FloatingText.spawn(get_parent(), global_position, "-%d" % int(roundf(final_dmg)), Color(1.0, 0.3, 0.3), 14)
	if hp <= 0.0:
		hp = max_hp
		mana = max_mana
		life_flask_charges = int(_bal.get("flask_max_charges", 5))
		mana_flask_charges = int(_bal.get("mana_flask_max_charges", 5))
		player_died.emit()
	_emit_stats()


func _emit_stats() -> void:
	stats_changed.emit(hp, max_hp, mana, max_mana, life_flask_charges, mana_flask_charges, level, xp, xp_to_next)


func _build_wolf_pixel_sprite() -> void:
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/sprites/wolf_player.png")
	spr.hframes = 2
	spr.scale = Vector2(1.0, 1.0)
	add_child(spr)
	_body_node = spr
