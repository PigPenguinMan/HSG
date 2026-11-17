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
