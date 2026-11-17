extends Node2D

@onready var hud_layer: CanvasLayer = $HUD
@onready var hud_label: Label = $HUD/MarginContainer/VBoxContainer/StatsLabel
@onready var loot_log_label: Label = $HUD/MarginContainer/VBoxContainer/LootLogLabel

var _player: Player
var _item_gen := ItemGenerator.new()
var _zones: Dictionary = {}
var _zone_root: Node2D
var _current_zone_id: String = "town"
var _respawn_zone: String = "town"
var _respawn_pos: Vector2 = Vector2(640, 620)
var _discovered_waypoints: Dictionary = {"town": true}

var _kills: int = 0
var _loot_seed: int = 1000
var _loot_lines: Array[String] = []
var _portal_lock: float = 0.0
var _boss_defeated: bool = false
var _hor_reward_claimed: bool = false

var _near_npc: Dictionary = {}
var _near_waypoint: bool = false

var _inv_panel: InventoryPanel
var _tree_panel: PassiveTreePanel
var _prompt_label: Label
var _dialog_panel: PanelContainer
var _dialog_title: Label
var _dialog_body: Label
var _dialog_buttons: VBoxContainer
var _boss_bar_box: VBoxContainer
var _boss_hp_bar: ColorRect


func _ready() -> void:
	_item_gen.load_affixes_from_json_file("res://data/affixes.json")
	_load_zones()

	_zone_root = Node2D.new()
	add_child(_zone_root)

	_player = Player.new()
	_player.stats_changed.connect(_on_player_stats_changed)
	_player.player_died.connect(_on_player_died)
	add_child(_player)

	_build_ui()

	var test_results := Phase0Tests.run_all()
	for line in test_results:
		print(line)

	_enter_zone("town", Vector2(640, 620))


func _load_zones() -> void:
	var text := FileAccess.get_file_as_string("res://data/act1_zones.json")
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		_zones = parsed.get("zones", {})


func _build_ui() -> void:
	var btn_bar := HBoxContainer.new()
	btn_bar.anchor_left = 1.0
	btn_bar.anchor_right = 1.0
	btn_bar.offset_left = -280
	btn_bar.offset_top = 12
	btn_bar.offset_right = -16
	btn_bar.offset_bottom = 48
	btn_bar.add_theme_constant_override("separation", 8)
	hud_layer.add_child(btn_bar)

	var inv_btn := Button.new()
	inv_btn.text = "인벤토리 (I)"
	inv_btn.pressed.connect(_toggle_inventory)
	btn_bar.add_child(inv_btn)

	var tree_btn := Button.new()
	tree_btn.text = "패시브 트리 (P)"
	tree_btn.pressed.connect(_toggle_passive_tree)
	btn_bar.add_child(tree_btn)

	# Boss HP bar (top-center)
	_boss_bar_box = VBoxContainer.new()
	_boss_bar_box.anchor_left = 0.5
	_boss_bar_box.anchor_right = 0.5
	_boss_bar_box.offset_left = -180
	_boss_bar_box.offset_right = 180
	_boss_bar_box.offset_top = 58
	_boss_bar_box.visible = false
	hud_layer.add_child(_boss_bar_box)

	var boss_name := Label.new()
	boss_name.text = "타락한 대족장, 철갑 브룬"
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_name.add_theme_color_override("font_color", Color(1.0, 0.45, 0.4))
	_boss_bar_box.add_child(boss_name)

	var bar_bg := ColorRect.new()
	bar_bg.custom_minimum_size = Vector2(360, 14)
	bar_bg.color = Color(0.15, 0.08, 0.08, 0.9)
	_boss_bar_box.add_child(bar_bg)

	_boss_hp_bar = ColorRect.new()
	_boss_hp_bar.size = Vector2(360, 14)
	_boss_hp_bar.color = Color(0.85, 0.16, 0.16)
	bar_bg.add_child(_boss_hp_bar)

	# Bottom interaction prompt
	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -200
	_prompt_label.offset_right = 200
	_prompt_label.offset_top = -52
	_prompt_label.offset_bottom = -20
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.45))
	_prompt_label.visible = false
	hud_layer.add_child(_prompt_label)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(center)

	_inv_panel = InventoryPanel.new()
	center.add_child(_inv_panel)
	_inv_panel.bind_player(_player)
	_inv_panel.visibility_changed.connect(_sync_ui_block)

	_tree_panel = PassiveTreePanel.new()
	center.add_child(_tree_panel)
	_tree_panel.bind_player(_player)
	_tree_panel.visibility_changed.connect(_sync_ui_block)

	_dialog_panel = PanelContainer.new()
	_dialog_panel.custom_minimum_size = Vector2(400, 220)
	_dialog_panel.visible = false
	_dialog_panel.visibility_changed.connect(_sync_ui_block)
	center.add_child(_dialog_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_dialog_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_dialog_title = Label.new()
	_dialog_title.add_theme_font_size_override("font_size", 16)
	_dialog_title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
	vbox.add_child(_dialog_title)

	_dialog_body = Label.new()
	_dialog_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_dialog_body)

	_dialog_buttons = VBoxContainer.new()
	_dialog_buttons.add_theme_constant_override("separation", 6)
	vbox.add_child(_dialog_buttons)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_P:
			_toggle_passive_tree()
		elif event.keycode == KEY_E:
			_try_interact()
		elif event.keycode == KEY_ESCAPE:
			_close_all_panels()


func _close_all_panels() -> void:
	_inv_panel.visible = false
	_tree_panel.visible = false
	_dialog_panel.visible = false
	_sync_ui_block()


func _toggle_inventory() -> void:
	_inv_panel.visible = not _inv_panel.visible
	if _inv_panel.visible:
		_tree_panel.visible = false
		_dialog_panel.visible = false
		_inv_panel.refresh()
	_sync_ui_block()


func _toggle_passive_tree() -> void:
	_tree_panel.visible = not _tree_panel.visible
	if _tree_panel.visible:
		_inv_panel.visible = false
		_dialog_panel.visible = false
		_tree_panel.refresh()
	_sync_ui_block()


func _sync_ui_block() -> void:
	if _player != null:
		_player.ui_blocking_input = _inv_panel.visible or _tree_panel.visible or _dialog_panel.visible


func _process(delta: float) -> void:
	if _portal_lock > 0.0:
		_portal_lock -= delta


func _enter_zone(zone_id: String, spawn_pos: Vector2) -> void:
	if not _zones.has(zone_id):
		return
	for child in _zone_root.get_children():
		child.queue_free()

	_current_zone_id = zone_id
	_portal_lock = 0.6
	_near_npc = {}
	_near_waypoint = false
	_prompt_label.visible = false
	_close_all_panels()

	var z: Dictionary = _zones[zone_id]
	_player.in_town = bool(z.get("is_town", false))
	_player.global_position = spawn_pos

	var sz := Vector2(float(z["size"][0]), float(z["size"][1]))
	var g := z["ground"]
	_build_ground(sz, Color(float(g[0]), float(g[1]), float(g[2])))
	_build_walls(sz)

	if z.has("waypoint"):
		var wp := Vector2(float(z["waypoint"][0]), float(z["waypoint"][1]))
		_discovered_waypoints[zone_id] = true
		_build_waypoint(wp)

	for cp in z.get("checkpoints", []):
		_build_checkpoint(Vector2(float(cp[0]), float(cp[1])))

	for ex in z.get("exits", []):
		_build_exit(ex)

	for npc in z.get("npcs", []):
		_build_npc(npc)

	var mlvl := int(z.get("monster_level", 1))
	var pack_count := int(z.get("packs", 0))
	var rare_chance := float(z.get("rare_chance", 0.2))
	if pack_count > 0:
		_spawn_zone_packs(sz, spawn_pos, pack_count, rare_chance, mlvl)

	_boss_bar_box.visible = false
	if zone_id == "boss" and not _boss_defeated and z.has("boss_pos"):
		var bpos := Vector2(float(z["boss_pos"][0]), float(z["boss_pos"][1]))
		_spawn_boss(bpos, mlvl)

	_push_log("[%s] 입장" % str(z.get("name", zone_id)))
	_player._emit_stats()


func _build_ground(sz: Vector2, base_col: Color) -> void:
	var bg := ColorRect.new()
	bg.size = sz
	bg.color = base_col
	bg.z_index = -12
	_zone_root.add_child(bg)

	var step := 128.0
	for x in range(0, int(sz.x), int(step)):
		for y in range(0, int(sz.y), int(step)):
			if ((x / int(step)) + (y / int(step))) % 2 == 0:
				var patch := ColorRect.new()
				patch.size = Vector2(step - 4, step - 4)
				patch.position = Vector2(x + 2, y + 2)
				patch.color = Color(base_col.r + 0.02, base_col.g + 0.02, base_col.b + 0.02)
				patch.z_index = -11
				_zone_root.add_child(patch)


func _build_walls(sz: Vector2) -> void:
	var thickness := 32.0
	var rects := [
		Rect2(-thickness, -thickness, sz.x + thickness * 2, thickness),
		Rect2(-thickness, sz.y, sz.x + thickness * 2, thickness),
		Rect2(-thickness, 0, thickness, sz.y),
		Rect2(sz.x, 0, thickness, sz.y),
	]
	for r in rects:
		var wall := StaticBody2D.new()
		wall.collision_layer = 4
		wall.collision_mask = 0
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		col.shape = shape
		wall.position = r.position + r.size * 0.5
		wall.add_child(col)
		_zone_root.add_child(wall)

		var vis := ColorRect.new()
		vis.size = r.size
		vis.position = -r.size * 0.5
		vis.color = Color(0.05, 0.05, 0.06)
		wall.add_child(vis)


func _build_exit(ex: Dictionary) -> void:
	var pos := Vector2(float(ex["pos"][0]), float(ex["pos"][1]))
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 28.0
	col.shape = circle
	area.add_child(col)

	var vis := ColorRect.new()
	vis.size = Vector2(36, 36)
	vis.position = Vector2(-18, -18)
	vis.color = Color(0.3, 0.7, 0.95, 0.7)
	area.add_child(vis)

	var lbl := Label.new()
	lbl.text = str(ex.get("label", "이동"))
	lbl.position = Vector2(-70, -44)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.92, 1.0))
	area.add_child(lbl)

	var to_id := str(ex["to"])
	var arrive := Vector2(float(ex["arrive"][0]), float(ex["arrive"][1]))
	area.body_entered.connect(func(body: Node) -> void:
		if body == _player and _portal_lock <= 0.0:
			call_deferred("_enter_zone", to_id, arrive)
	)
	_zone_root.add_child(area)


func _build_checkpoint(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 26.0
	col.shape = circle
	area.add_child(col)

	var vis := ColorRect.new()
	vis.size = Vector2(22, 22)
	vis.position = Vector2(-11, -11)
	vis.color = Color(0.5, 0.5, 0.55)
	area.add_child(vis)

	var lbl := Label.new()
	lbl.text = "체크포인트"
	lbl.position = Vector2(-34, -34)
	area.add_child(lbl)

	area.body_entered.connect(func(body: Node) -> void:
		if body == _player:
			_respawn_zone = _current_zone_id
			_respawn_pos = pos
			vis.color = Color(1.0, 0.85, 0.25)
			_push_log("체크포인트 저장됨")
	)
	_zone_root.add_child(area)


func _build_waypoint(pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	col.shape = circle
	area.add_child(col)

	var vis := ColorRect.new()
	vis.size = Vector2(28, 28)
	vis.position = Vector2(-14, -14)
	vis.color = Color(0.45, 0.85, 1.0, 0.85)
	area.add_child(vis)

	var lbl := Label.new()
	lbl.text = "거점 이동진"
	lbl.position = Vector2(-38, -38)
	lbl.add_theme_color_override("font_color", Color(0.6, 0.92, 1.0))
	area.add_child(lbl)

	area.body_entered.connect(func(body: Node) -> void:
		if body == _player:
			_near_waypoint = true
			_refresh_prompt()
	)
	area.body_exited.connect(func(body: Node) -> void:
		if body == _player:
			_near_waypoint = false
			_refresh_prompt()
	)
	_zone_root.add_child(area)


func _build_npc(npc: Dictionary) -> void:
	var pos := Vector2(float(npc["pos"][0]), float(npc["pos"][1]))
	var c := npc["color"]
	var area := Area2D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1

	var col := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 36.0
	col.shape = circle
	area.add_child(col)

	var vis := ColorRect.new()
	vis.size = Vector2(22, 26)
	vis.position = Vector2(-11, -13)
	vis.color = Color(float(c[0]), float(c[1]), float(c[2]))
	area.add_child(vis)

	var lbl := Label.new()
	lbl.text = "%s (%s)" % [npc["name"], npc["role"]]
	lbl.position = Vector2(-56, -38)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))
	area.add_child(lbl)

	area.body_entered.connect(func(body: Node) -> void:
		if body == _player:
			_near_npc = npc
			_refresh_prompt()
	)
	area.body_exited.connect(func(body: Node) -> void:
		if body == _player and _near_npc.get("id") == npc.get("id"):
			_near_npc = {}
			_refresh_prompt()
	)
	_zone_root.add_child(area)


func _refresh_prompt() -> void:
	if not _near_npc.is_empty():
		_prompt_label.text = "[E] %s와 대화" % _near_npc["name"]
		_prompt_label.visible = true
	elif _near_waypoint:
		_prompt_label.text = "[E] 거점 이동진 사용"
		_prompt_label.visible = true
	else:
		_prompt_label.visible = false


func _try_interact() -> void:
	if _dialog_panel.visible:
		_dialog_panel.visible = false
		return
	if not _near_npc.is_empty():
		_open_npc_dialog(_near_npc)
	elif _near_waypoint:
		_open_waypoint_dialog()


func _clear_dialog_buttons() -> void:
	for c in _dialog_buttons.get_children():
		c.queue_free()


func _add_dialog_btn(text: String, cb: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.pressed.connect(cb)
	_dialog_buttons.add_child(btn)


func _open_npc_dialog(npc: Dictionary) -> void:
	_inv_panel.visible = false
	_tree_panel.visible = false
	_clear_dialog_buttons()

	var nid := str(npc["id"])
	_dialog_title.text = "%s (%s)" % [npc["name"], npc["role"]]

	match nid:
		"bram":
			_dialog_body.text = "쓸모없는 일반/마법 장비는 분해해서 혈석으로 만들어 주지."
			_add_dialog_btn("일반·마법 장비 일괄 분해 → 변이의 혈석", func() -> void:
				var gained := 0
				for i in range(_player.inventory.size() - 1, -1, -1):
					var it: Dictionary = _player.inventory[i]
					if int(it.get("rarity", 0)) != StatTypes.Rarity.RARE:
						_player.inventory.remove_at(i)
						gained += 1
				if gained > 0:
					_player.add_currency(StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT, gained)
					_dialog_body.text = "장비 %d개를 분해해 변이의 혈석 %d개를 얻었다." % [gained, gained]
				else:
					_dialog_body.text = "분해할 일반/마법 장비가 없군."
			)
			_add_dialog_btn("초보자 무기/방어구 지원받기", func() -> void:
				_loot_seed += 1
				var slots := ["WEAPON", "ARMOUR", "BOOTS"]
				var slot: String = slots[_loot_seed % slots.size()]
				var item := _item_gen.create_normal_item("base_wolf_" + slot.to_lower(), slot, _player.level + 1, _loot_seed)
				if _player.add_item_to_inventory(item):
					_dialog_body.text = "%s (일반)을 건네주었다." % slot
				else:
					_dialog_body.text = "가방이 가득 찼군."
			)
		"ria":
			_dialog_body.text = "피에 굶주린 땅에서는 물약과 혈석이 목숨줄이지."
			_add_dialog_btn("물약 전부 충전 (무료)", func() -> void:
				_player.flask_charges = 5
				_player._emit_stats()
				_dialog_body.text = "물약을 5/5로 채웠어요."
			)
			_add_dialog_btn("변이의 혈석 2개 → 단조의 혈석 1개 교환", func() -> void:
				var shift_cnt := int(_player.currency_pouch.get(StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT, 0))
				if shift_cnt >= 2:
					_player.currency_pouch[StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT] = shift_cnt - 2
					_player.add_currency(StatTypes.CurrencyType.BLOODSTONE_OF_FORGE, 1)
					_dialog_body.text = "단조의 혈석 1개로 교환했어요."
				else:
					_dialog_body.text = "변이의 혈석이 2개 이상 필요해요."
			)
		"hor":
			if not _boss_defeated:
				_dialog_body.text = "진흙 늪 너머 무너진 곰 부족의 성채에서 '타락한 대족장, 철갑 브룬'을 쓰러뜨려라."
			elif not _hor_reward_claimed:
				_dialog_body.text = "브룬을 쓰러뜨렸군! 약속대로 보상을 내리겠네."
				_add_dialog_btn("퀘스트 보상 받기 (패시브 +2 & 희귀 무기)", func() -> void:
					_hor_reward_claimed = true
					_player.passive_points += 2
					_loot_seed += 1
					var reward := _item_gen.create_normal_item("base_wolf_weapon", "WEAPON", _player.level + 3, _loot_seed)
					_item_gen.apply_currency(reward, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
					_player.add_item_to_inventory(reward)
					_player._emit_stats()
					_dialog_body.text = "패시브 포인트 +2와 희귀 무기를 받았다! (Act 1 수직 슬라이스 완료)"
				)
			else:
				_dialog_body.text = "Act 1 시련을 모두 마쳤네. 사냥터를 더 돌며 빌드를 시험해 보게."

	_add_dialog_btn("닫기 (Esc)", func() -> void: _dialog_panel.visible = false)
	_dialog_panel.visible = true


func _open_waypoint_dialog() -> void:
	_inv_panel.visible = false
	_tree_panel.visible = false
	_clear_dialog_buttons()
	_dialog_title.text = "거점 이동진"
	_dialog_body.text = "발견한 거점으로 즉시 이동합니다."

	for zid in _discovered_waypoints.keys():
		if zid == _current_zone_id or not _zones.has(zid):
			continue
		var z: Dictionary = _zones[zid]
		var wp := Vector2(float(z["waypoint"][0]), float(z["waypoint"][1]))
		var target_id: String = str(zid)
		_add_dialog_btn("%s(으)로 이동" % z["name"], func() -> void:
			_enter_zone(target_id, wp + Vector2(0, 48))
		)

	_add_dialog_btn("닫기 (Esc)", func() -> void: _dialog_panel.visible = false)
	_dialog_panel.visible = true


func _spawn_zone_packs(sz: Vector2, safe_pos: Vector2, pack_count: int, rare_chance: float, mlvl: int) -> void:
	for _p in range(pack_count):
		var center := Vector2(randf_range(180, sz.x - 180), randf_range(160, sz.y - 160))
		if center.distance_to(safe_pos) < 340.0:
			center.x = clampf(center.x + 420.0, 180, sz.x - 180)
		var with_rare := randf() < rare_chance
		for i in range(4):
			var enemy := Enemy.new()
			enemy.is_rare = with_rare and i == 0
			enemy.monster_level = mlvl
			enemy.position = center + Vector2(randf_range(-36, 36), randf_range(-36, 36))
			enemy.add_to_group("enemies")
			enemy.died.connect(_on_enemy_died)
			_zone_root.add_child(enemy)


func _spawn_boss(pos: Vector2, mlvl: int) -> void:
	var boss := BossBrun.new()
	boss.is_rare = true
	boss.monster_level = mlvl
	boss.position = pos
	boss.add_to_group("enemies")
	boss.hp_changed.connect(func(cur: float, mx: float) -> void:
		_boss_hp_bar.size.x = 360.0 * clampf(cur / maxf(1.0, mx), 0.0, 1.0)
	)
	boss.died.connect(_on_boss_died)
	_zone_root.add_child(boss)
	_boss_bar_box.visible = true
	_boss_hp_bar.size.x = 360.0


func _on_boss_died(_enemy: Enemy, pos: Vector2, _is_rare: bool) -> void:
	_boss_defeated = true
	_boss_bar_box.visible = false
	_kills += 1
	_player.on_enemy_killed(true, 300)
	_player.add_currency(StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH, 1)
	_player.add_currency(StatTypes.CurrencyType.BLOODSTONE_OF_FORGE, 2)
	_drop_item(pos, true)
	_push_log("철갑 브룬 처치! 야영지의 호르에게 돌아가세요.")


func _on_enemy_died(enemy: Enemy, pos: Vector2, is_rare: bool) -> void:
	_kills += 1
	_player.on_enemy_killed(is_rare, enemy.xp_reward)

	if is_rare or randf() < 0.25:
		var currencies := [
			StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT,
			StatTypes.CurrencyType.BLOODSTONE_OF_FORGE,
			StatTypes.CurrencyType.BLOODSTONE_OF_RUIN,
			StatTypes.CurrencyType.BLOODSTONE_OF_PURGE,
			StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH,
		]
		_player.add_currency(currencies[randi() % currencies.size()], 1)

	if is_rare or randf() < 0.45:
		_drop_item(pos, is_rare)


func _drop_item(pos: Vector2, force_rare: bool) -> void:
	_loot_seed += 1
	var slots := ["WEAPON", "ARMOUR", "BOOTS", "RING", "AMULET"]
	var slot: String = slots[_loot_seed % slots.size()]
	var item := _item_gen.create_normal_item("base_wolf_" + slot.to_lower(), slot, _player.level + 2, _loot_seed)
	if force_rare:
		_item_gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
	elif randf() < 0.6:
		_item_gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT)

	var drop := LootDrop.new()
	drop.item_data = item
	drop.position = pos
	drop.picked_up.connect(_on_loot_picked_up)
	_zone_root.call_deferred("add_child", drop)


func _on_loot_picked_up(item: Dictionary) -> void:
	var added := _player.add_item_to_inventory(item)
	var mod_texts: Array[String] = []
	for p in item.get("prefixes", []):
		mod_texts.append("%s +%s" % [p["stat"], p["value"]])
	for s in item.get("suffixes", []):
		mod_texts.append("%s +%s" % [s["stat"], s["value"]])
	var prefix_note := "" if added else "[가방 가득참] "
	_push_log("%s%s (%s)" % [prefix_note, item.get("baseId", "item"), ", ".join(mod_texts) if not mod_texts.is_empty() else "일반"])


func _push_log(msg: String) -> void:
	_loot_lines.push_front(msg)
	if _loot_lines.size() > 4:
		_loot_lines.resize(4)
	loot_log_label.text = "최근 기록:\n" + "\n".join(_loot_lines)


func _on_player_died() -> void:
	_push_log("쓰러졌습니다! 체크포인트로 복귀합니다 (Act 1 경험치 손실 0%).")
	call_deferred("_enter_zone", _respawn_zone, _respawn_pos)


func _on_player_stats_changed(hp: float, max_hp: float, mana: float, max_mana: float, flask: int, lv: int, cur_xp: int, next_xp: int) -> void:
	var zname := str(_zones.get(_current_zone_id, {}).get("name", _current_zone_id))
	var pts_text := "  |  [패시브 포인트: %d]" % _player.passive_points if _player.passive_points > 0 else ""
	hud_label.text = "[%s] Lv.%d (XP %d/%d)%s  |  HP: %d/%d  |  Mana: %d/%d  |  물약(1): %d/5  |  처치: %d\n[WASD] 이동  [좌/우클릭] 스킬  [Space] 질주  [E] 대화/이동진  [I] 인벤토리  [P] 패시브" % [
		zname, lv, cur_xp, next_xp, pts_text, int(hp), int(max_hp), int(mana), int(max_mana), flask, _kills
	]
