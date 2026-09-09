class_name CombatSystem

static func hit_chance(attacker: Dictionary, target: Dictionary, distance: float, has_cover: bool) -> int:
    var accuracy := int(attacker.get("accuracy", 55))
    var defense := int(target.get("defense", 10))
    var chance := accuracy - defense - int(distance * 3.0)
    if has_cover:
        chance -= 20
    return clamp(chance, 5, 95)

static func roll_hit(chance: int, rng: RandomNumberGenerator) -> bool:
    return rng.randi_range(1, 100) <= chance

static func body_damage(body_part: String, base_damage: int) -> Dictionary:
    match body_part:
        "head": return {"damage": int(base_damage * 1.8), "effect":"критическое ранение"}
        "arm": return {"damage": int(base_damage * 0.75), "effect":"рука повреждена"}
        "leg": return {"damage": int(base_damage * 0.8), "effect":"движение снижено"}
        "torso": return {"damage": base_damage, "effect":"ранение корпуса"}
    return {"damage":base_damage,"effect":"ранение"}

static func choose_body_part(rng: RandomNumberGenerator) -> String:
    var roll := rng.randi_range(1, 100)
    if roll <= 8: return "head"
    if roll <= 25: return "arm"
    if roll <= 42: return "leg"
    return "torso"
