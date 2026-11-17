class_name StatTypes
extends RefCounted

enum ModType {
	FLAT,
	INCREASED,
	MORE,
	FLAG,
}

enum DamageSource {
	ATTACK_HIT,
	SPELL_HIT,
	AILMENT_DOT,
}

enum Rarity {
	NORMAL,
	MAGIC,
	RARE,
}

enum CurrencyType {
	BLOODSTONE_OF_SHIFT,   # Normal -> Magic (1-2 mods)
	BLOODSTONE_OF_FORGE,   # Normal -> Rare (4-6 mods)
	BLOODSTONE_OF_RUIN,    # Rare -> Reroll all mods (4-6 mods)
	BLOODSTONE_OF_PURGE,   # Magic/Rare -> Normal (0 mods)
	BLOODSTONE_OF_ZENITH,  # Rare (<6 mods) -> Add 1 mod
}


static func make_mod(
	stat: String,
	mod_type: ModType,
	value: float,
	source_id: String = "",
	tags: Array = []
) -> Dictionary:
	return {
		"stat": stat,
		"mod_type": mod_type,
		"value": value,
		"source_id": source_id,
		"tags": tags,
	}


const STAT_LABELS: Dictionary = {
	"STR": "힘",
	"DEX": "민첩",
	"INT": "지능",
	"MAX_LIFE": "최대 생명력",
	"MAX_MANA": "최대 마나",
	"ARMOUR": "방어도",
	"EVASION": "회피",
	"ACCURACY": "명중률",
	"PHYSICAL_DAMAGE": "물리 피해",
	"ATTACK_DAMAGE": "공격 피해",
	"SPELL_DAMAGE": "주문 피해",
	"FIRE_DAMAGE": "화염 피해",
	"ADDED_PHYSICAL_DAMAGE": "추가 물리 피해",
	"ADDED_FIRE_DAMAGE": "추가 화염 피해",
	"ATTACK_SPEED": "공격 속도",
	"MOVEMENT_SPEED": "이동 속도",
	"CRIT_CHANCE": "치명타 확률",
	"CRIT_MULTIPLIER": "치명타 피해 배율",
	"BLEED_CHANCE": "출혈 확률",
	"AILMENT_DAMAGE": "상태이상 피해",
	"FIRE_RES": "화염 저항",
	"COLD_RES": "냉기 저항",
	"DAMAGE_TAKEN": "받는 피해",
	"ALWAYS_HITS": "공격이 항상 명중",
	"CANNOT_CRIT": "치명타 불가",
	"DISABLE_MINIONS": "소환수 소환 불가",
	"BLOODTHIRST": "마나 대신 생명력 소모 (피의 갈증)",
}


static func format_stat(stat: String, mod_type: String, value: float) -> String:
	var label: String = STAT_LABELS.get(stat, stat)
	if mod_type == "FLAG":
		return label
	var iv := int(roundf(value))
	var sign_str := "+" if iv >= 0 else ""
	match mod_type:
		"INCREASED":
			return "%s %s%d%% 증가" % [label, sign_str, iv]
		"MORE":
			if iv < 0:
				return "%s %d%% 감폭" % [label, abs(iv)]
			return "%s +%d%% 증폭" % [label, iv]
		_:
			if stat in ["BLEED_CHANCE", "CRIT_MULTIPLIER", "FIRE_RES", "COLD_RES"]:
				return "%s %s%d%%" % [label, sign_str, iv]
			return "%s %s%d" % [label, sign_str, iv]

