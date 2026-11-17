extends Node2D

@onready var hud_label: Label = $HUD/MarginContainer/VBoxContainer/StatsLabel
@onready var loot_log_label: Label = $HUD/MarginContainer/VBoxContainer/LootLogLabel

var _player: Player
var _item_gen := ItemGenerator.new()
var _kills: int = 0
var _spawn_timer: float = 1.0
var _loot_seed: int = 1000
var _loot_lines: Array[String] = []


func _ready() -> void:
	_item_gen.load_affixes_from_json_file("res://data/affixes.json")
	_build_ground_grid()

	_player = Player.new()
	_player.position = Vector2.ZERO
	_player.stats_changed.connect(_on_player_stats_changed)
	add_child(_player)

	# Run Phase 0 unit tests in console on startup
	var test_results := Phase0Tests.run_all()
	for line in test_results:
		print(line)

	_spawn_pack(false)


func _process(delta: float) -> void:
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

	if is_rare or randf() < 0.45:
		_loot_seed += 1
		var slots := ["WEAPON", "ARMOUR", "BOOTS", "RING", "AMULET"]
		var slot: String = slots[_loot_seed % slots.size()]
		var item := _item_gen.create_normal_item("base_wolf_" + slot.to_lower(), slot, 12, _loot_seed)
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
	var mod_texts: Array[String] = []
	for p in item.get("prefixes", []):
		mod_texts.append("%s +%s" % [p["stat"], p["value"]])
	for s in item.get("suffixes", []):
		mod_texts.append("%s +%s" % [s["stat"], s["value"]])
	var summary := "%s (%s)" % [item.get("baseId", "item"), ", ".join(mod_texts) if not mod_texts.is_empty() else "일반"]
	_loot_lines.push_front(summary)
	if _loot_lines.size() > 4:
		_loot_lines.resize(4)
	loot_log_label.text = "최근 획득:\n" + "\n".join(_loot_lines)


func _on_player_stats_changed(hp: float, max_hp: float, mana: float, max_mana: float, flask: int) -> void:
	hud_label.text = "HP: %d/%d  |  Mana: %d/%d  |  물약(1키): %d/5  |  처치: %d\n[WASD] 이동  [좌클릭] 핏빛 난무(출혈)  [우클릭] 관통 송곳니(투사체)  [Space] 그림자 질주" % [
		int(hp), int(max_hp), int(mana), int(max_mana), flask, _kills
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
