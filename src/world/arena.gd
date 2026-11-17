extends Node2D

@onready var hud_layer: CanvasLayer = $HUD
@onready var hud_label: Label = $HUD/MarginContainer/VBoxContainer/StatsLabel
@onready var loot_log_label: Label = $HUD/MarginContainer/VBoxContainer/LootLogLabel

var _player: Player
var _item_gen := ItemGenerator.new()
var _kills: int = 0
var _spawn_timer: float = 1.0
var _loot_seed: int = 1000
var _loot_lines: Array[String] = []

var _inv_panel: InventoryPanel
var _tree_panel: PassiveTreePanel


func _ready() -> void:
	_item_gen.load_affixes_from_json_file("res://data/affixes.json")
	_build_ground_grid()

	_player = Player.new()
	_player.position = Vector2.ZERO
	_player.stats_changed.connect(_on_player_stats_changed)
	add_child(_player)

	_build_phase2_ui()

	# Run Phase 0 unit tests in console on startup
	var test_results := Phase0Tests.run_all()
	for line in test_results:
		print(line)

	_spawn_pack(false)


func _build_phase2_ui() -> void:
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

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(center)

	_inv_panel = InventoryPanel.new()
	_inv_panel.bind_player(_player)
	_inv_panel.visibility_changed.connect(_sync_ui_block)
	center.add_child(_inv_panel)

	_tree_panel = PassiveTreePanel.new()
	_tree_panel.bind_player(_player)
	_tree_panel.visibility_changed.connect(_sync_ui_block)
	center.add_child(_tree_panel)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I:
			_toggle_inventory()
		elif event.keycode == KEY_P:
			_toggle_passive_tree()
		elif event.keycode == KEY_ESCAPE:
			_inv_panel.visible = false
			_tree_panel.visible = false
			_sync_ui_block()


func _toggle_inventory() -> void:
	_inv_panel.visible = not _inv_panel.visible
	if _inv_panel.visible:
		_tree_panel.visible = false
		_inv_panel.refresh()
	_sync_ui_block()


func _toggle_passive_tree() -> void:
	_tree_panel.visible = not _tree_panel.visible
	if _tree_panel.visible:
		_inv_panel.visible = false
		_tree_panel.refresh()
	_sync_ui_block()


func _sync_ui_block() -> void:
	if _player != null:
		_player.ui_blocking_input = _inv_panel.visible or _tree_panel.visible


func _process(delta: float) -> void:
	if _player.ui_blocking_input:
		return
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and get_tree().get_nodes_in_group("enemies").size() < 12:
		_spawn_timer = 4.5
		_spawn_pack(randf() < 0.25)


func _spawn_pack(with_rare: bool) -> void:
	var angle := randf() * TAU
	var center := _player.global_position + Vector2.from_angle(angle) * 260.0
	var count := 4
	for i in range(count):
		var enemy := Enemy.new()
		enemy.is_rare = with_rare and i == 0
		enemy.position = center + Vector2(randf_range(-36, 36), randf_range(-36, 36))
		enemy.add_to_group("enemies")
		enemy.died.connect(_on_enemy_died)
		add_child(enemy)


func _on_enemy_died(_enemy: Enemy, pos: Vector2, is_rare: bool) -> void:
	_kills += 1
	_player.on_enemy_killed(is_rare)

	# Chance to drop Bloodstone currency
	if is_rare or randf() < 0.25:
		var currencies := [
			StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT,
			StatTypes.CurrencyType.BLOODSTONE_OF_FORGE,
			StatTypes.CurrencyType.BLOODSTONE_OF_RUIN,
			StatTypes.CurrencyType.BLOODSTONE_OF_PURGE,
			StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH,
		]
		var rolled: int = currencies[randi() % currencies.size()]
		_player.add_currency(rolled, 1)

	if is_rare or randf() < 0.45:
		_loot_seed += 1
		var slots := ["WEAPON", "ARMOUR", "BOOTS", "RING", "AMULET"]
		var slot: String = slots[_loot_seed % slots.size()]
		var item := _item_gen.create_normal_item("base_wolf_" + slot.to_lower(), slot, _player.level + 2, _loot_seed)
		if is_rare:
			_item_gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
		elif randf() < 0.6:
			_item_gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT)

		var drop := LootDrop.new()
		drop.item_data = item
		drop.position = pos
		drop.picked_up.connect(_on_loot_picked_up)
		call_deferred("add_child", drop)


func _on_loot_picked_up(item: Dictionary) -> void:
	var added := _player.add_item_to_inventory(item)
	var mod_texts: Array[String] = []
	for p in item.get("prefixes", []):
		mod_texts.append("%s +%s" % [p["stat"], p["value"]])
	for s in item.get("suffixes", []):
		mod_texts.append("%s +%s" % [s["stat"], s["value"]])
	var prefix_note := "" if added else "[가방 가득참] "
	var summary := "%s%s (%s)" % [prefix_note, item.get("baseId", "item"), ", ".join(mod_texts) if not mod_texts.is_empty() else "일반"]
	_loot_lines.push_front(summary)
	if _loot_lines.size() > 4:
		_loot_lines.resize(4)
	loot_log_label.text = "최근 획득:\n" + "\n".join(_loot_lines)


func _on_player_stats_changed(hp: float, max_hp: float, mana: float, max_mana: float, flask: int, lv: int, cur_xp: int, next_xp: int) -> void:
	var pts_text := "  |  [패시브 포인트: %d]" % _player.passive_points if _player.passive_points > 0 else ""
	hud_label.text = "Lv.%d (XP %d/%d)%s  |  HP: %d/%d  |  Mana: %d/%d  |  물약(1): %d/5  |  처치: %d\n[WASD] 이동  [좌/우클릭] 스킬  [Space] 질주  [I] 인벤토리·크래프팅  [P] 패시브 트리" % [
		lv, cur_xp, next_xp, pts_text, int(hp), int(max_hp), int(mana), int(max_mana), flask, _kills
	]


func _build_ground_grid() -> void:
	for x in range(-12, 13):
		for y in range(-12, 13):
			var tile := ColorRect.new()
			tile.size = Vector2(62, 62)
			tile.position = Vector2(x * 64, y * 64)
			var shade := 0.11 if (x + y) % 2 == 0 else 0.09
			tile.color = Color(shade, shade * 0.95, shade * 1.05, 1.0)
			tile.z_index = -10
			add_child(tile)
