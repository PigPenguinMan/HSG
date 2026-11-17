class_name DamagePipeline
extends RefCounted

const ARMOUR_FACTOR: float = 5.0


static func calculate_hit(
	attacker_stats: StatAggregator,
	defender: Dictionary,
	skill: Dictionary,
	is_crit: bool = false
) -> Dictionary:
	var source_type: int = int(skill.get("damage_source", StatTypes.DamageSource.ATTACK_HIT))
	var skill_tags: Array = skill.get("tags", []).duplicate()
	var effectiveness: float = float(skill.get("damage_effectiveness", 1.0))

	# 1. Base + Flat Added Damage
	var base_phys: float = float(skill.get("base_physical", 0.0)) + attacker_stats.get_stat("ADDED_PHYSICAL_DAMAGE", 0.0, skill_tags) * effectiveness
	var base_fire: float = float(skill.get("base_fire", 0.0)) + attacker_stats.get_stat("ADDED_FIRE_DAMAGE", 0.0, skill_tags) * effectiveness

	# 2. Savagery / Brutality style restriction (e.g. CANNOT_DEAL_NON_PHYSICAL)
	if attacker_stats.has_flag("CANNOT_DEAL_NON_PHYSICAL"):
		base_fire = 0.0

	# 3. Increased & More for Hit (strictly separated from Ailment DoT)
	var phys_after_inc: float = base_phys * _hit_multiplier(attacker_stats, "PHYSICAL_DAMAGE", skill_tags, source_type)
	var fire_after_inc: float = base_fire * _hit_multiplier(attacker_stats, "FIRE_DAMAGE", skill_tags, source_type)

	# 4. Critical Strike
	var crit_mult: float = 1.0
	var no_crit_flag: bool = attacker_stats.has_flag("CANNOT_CRIT")
	if is_crit and not no_crit_flag:
		var base_crit_mult: float = 150.0 + attacker_stats.get_stat("CRIT_MULTIPLIER", 0.0, skill_tags)
		crit_mult = maxf(1.0, base_crit_mult / 100.0)

	var raw_phys_hit: float = phys_after_inc * crit_mult
	var raw_fire_hit: float = fire_after_inc * crit_mult

	# 5. Defender Layer: Evasion -> Armour (Phys only) -> Resistances -> Life
	var hit_chance: float = 1.0
	if source_type == StatTypes.DamageSource.ATTACK_HIT and not attacker_stats.has_flag("ALWAYS_HITS"):
		var accuracy: float = attacker_stats.get_stat("ACCURACY", 100.0)
		var evasion: float = float(defender.get("evasion", 0.0))
		hit_chance = calculate_hit_chance(accuracy, evasion)

	var armour: float = float(defender.get("armour", 0.0))
	var phys_dr: float = calculate_armour_dr(armour, raw_phys_hit)
	var final_phys: float = raw_phys_hit * (1.0 - phys_dr)

	var fire_res: float = minf(0.90, float(defender.get("fire_res", 0.0)) / 100.0)
	var final_fire: float = raw_fire_hit * (1.0 - fire_res)

	# 6. Ailment Base Damage (calculated from base damage, NOT final hit damage -> no double dipping)
	var ailment_mult: float = _ailment_multiplier(attacker_stats, skill_tags)
	var bleed_dps: float = base_phys * 0.70 * ailment_mult
	var ignite_dps: float = base_fire * 0.50 * ailment_mult

	return {
		"hit_chance": hit_chance,
		"raw_physical": raw_phys_hit,
		"raw_fire": raw_fire_hit,
		"final_physical": final_phys,
		"final_fire": final_fire,
		"total_hit_damage": final_phys + final_fire,
		"bleed_dps": bleed_dps,
		"ignite_dps": ignite_dps,
		"is_crit": is_crit and not no_crit_flag,
	}


static func calculate_hit_chance(accuracy: float, evasion: float) -> float:
	if evasion <= 0.0:
		return 1.0
	var raw: float = (1.25 * accuracy) / (accuracy + pow(evasion / 4.0, 0.8))
	return clampf(raw, 0.05, 1.0)


static func calculate_armour_dr(armour: float, raw_physical_damage: float) -> float:
	if armour <= 0.0 or raw_physical_damage <= 0.0:
		return 0.0
	return minf(0.90, armour / (armour + ARMOUR_FACTOR * raw_physical_damage))


static func _hit_multiplier(stats: StatAggregator, dmg_stat: String, skill_tags: Array, source_type: int) -> float:
	var m: float = stats.get_stat(dmg_stat, 1.0, skill_tags)
	m *= stats.get_stat("GLOBAL_DAMAGE", 1.0, skill_tags)
	if source_type == StatTypes.DamageSource.ATTACK_HIT:
		m *= stats.get_stat("ATTACK_DAMAGE", 1.0, skill_tags)
	elif source_type == StatTypes.DamageSource.SPELL_HIT:
		m *= stats.get_stat("SPELL_DAMAGE", 1.0, skill_tags)
	return m


static func _ailment_multiplier(stats: StatAggregator, skill_tags: Array) -> float:
	var m: float = stats.get_stat("AILMENT_DAMAGE", 1.0, skill_tags)
	m *= stats.get_stat("DOT_DAMAGE", 1.0, skill_tags)
	return m
