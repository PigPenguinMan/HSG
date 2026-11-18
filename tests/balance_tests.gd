extends RefCounted
## BalanceDB loader tests + data/balance.json regression against the values that were
## hardcoded before the extraction (main @ 405038e). If a value here changes on purpose,
## update EXPECTED in the same commit as balance.json and say so in HANDOFF.md.

const T := preload("res://tests/test_check.gd")
const BalanceDBScript := preload("res://src/core/balance_db.gd")

## Every key the game code reads, with its pre-extraction hardcoded value.
const EXPECTED: Dictionary = {
	"player": {
		"base_hp": 100.0, "base_mana": 60.0, "base_armour": 50.0, "base_move_speed": 210.0,
		"life_per_level": 12.0,
		"base_attributes": {"str": 14.0, "dex": 24.0, "int": 10.0},
		"wolf_innate": {"physical_damage_increased": 25.0, "bleed_chance_flat": 40.0, "ailment_damage_increased": 20.0},
		"base_crit_chance": 0.15, "mana_regen_per_sec": 8.0,
		"dash_speed": 620.0, "dash_duration": 0.16, "dash_cooldown": 1.2,
		"flask_max_charges": 5, "flask_heal": 45.0,
		"xp_to_next_base": 100, "xp_level_multiplier": 1.45, "max_level": 20,
		"starting_passive_points": 2,
	},
	"enemies": {
		"aggro_radius": 360.0,
		"normal": {"max_hp": 60.0, "move_speed": 95.0, "attack_damage": 10.0, "armour": 20.0, "evasion": 10.0, "xp_reward": 25, "knockback_resist": 0.0, "attack_cooldown": 1.1},
		"rare": {"max_hp": 220.0, "move_speed": 115.0, "attack_damage": 18.0, "armour": 60.0, "evasion": 10.0, "xp_reward": 90, "knockback_resist": 0.5, "attack_cooldown": 1.1},
		"level_scaling": {"hp_per_level": 0.18, "damage_per_level": 0.12, "armour_per_level": 0.10, "xp_per_level": 0.15},
		"ailment_duration": {"bleed": 4.0, "ignite": 4.0},
	},
	"boss_brun": {
		"max_hp": 900.0, "move_speed": 92.0, "attack_damage": 24.0, "armour": 90.0,
		"xp_reward": 300, "knockback_resist": 0.85,
		"enrage_hp_ratio": 0.5, "enrage_cd_rate": 1.35, "enrage_speed_mult": 1.25,
		"slam_telegraph_time": 0.95, "slam_cooldown": 4.2, "slam_radius": 80.0, "slam_damage_mult": 1.8,
		"wave_cooldown": 3.6, "wave_damage_mult": 0.95,
		"charge_cooldown": 5.0, "charge_duration": 0.45, "charge_speed": 420.0, "charge_damage_mult": 1.35,
		"melee_cooldown": 1.15,
	},
	"drops": {
		"pack_size": 4, "currency_drop_chance": 0.25, "item_drop_chance": 0.45,
		"magic_upgrade_chance": 0.60, "boss_zenith_drop": 1, "boss_forge_drop": 2,
	},
}


static func test_names() -> Array[String]:
	return [
		"_test_balance_db_loader",
		"_test_balance_values_match_pre_extraction",
		"_test_boss_telegraph_contract",
	]


static func _test_balance_db_loader() -> String:
	T.ok(BalanceDBScript.load_from(), "load default balance.json")
	for section in EXPECTED.keys():
		T.ok(not BalanceDBScript.get_section(section).is_empty(), "section %s present" % section)
	T.ok(BalanceDBScript.get_section("no_such_section").is_empty(), "unknown section -> {}")

	# Missing file: loader reports failure and serves empty sections instead of crashing.
	T.ok(not BalanceDBScript.load_from("res://data/__missing_balance__.json"), "missing file -> false")
	T.ok(BalanceDBScript.get_section("player").is_empty(), "missing file -> empty sections")

	# Restore the real data for the following tests (BalanceDB caches statically).
	T.ok(BalanceDBScript.load_from(), "restore default balance.json")
	T.ok(not BalanceDBScript.get_section("player").is_empty(), "player section restored")
	return "BalanceDB: load, known/unknown sections, missing-file fallback, load_from"


static func _test_balance_values_match_pre_extraction() -> String:
	BalanceDBScript.load_from()
	for section in EXPECTED.keys():
		_compare(BalanceDBScript.get_section(section), EXPECTED[section], section)
	return "balance.json: every key the code reads exists and equals the pre-extraction value"


static func _compare(actual: Dictionary, expected: Dictionary, path: String) -> void:
	for key in expected.keys():
		var p: String = "%s.%s" % [path, key]
		if not T.ok(actual.has(key), "balance.json missing %s (code would silently use its fallback)" % p):
			continue
		var exp_v: Variant = expected[key]
		if exp_v is Dictionary:
			var act_v: Variant = actual[key]
			if T.ok(act_v is Dictionary, "%s should be an object" % p):
				_compare(act_v, exp_v, p)
		else:
			T.near(float(actual[key]), float(exp_v), p, 0.0001)


static func _test_boss_telegraph_contract() -> String:
	# docs/05: boss telegraphs must be 0.8-1.2 s so players can react.
	var boss: Dictionary = BalanceDBScript.get_section("boss_brun")
	var t: float = float(boss.get("slam_telegraph_time", 0.0))
	T.ok(t >= 0.8 and t <= 1.2, "slam_telegraph_time %s within 0.8-1.2 s (docs/05)" % t)
	return "Boss telegraph: slam_telegraph_time within docs/05 0.8-1.2 s window"
