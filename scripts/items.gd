class_name ItemDatabase

static func starter_items() -> Array[Dictionary]:
    return [
        {"name":"Бинт", "type":"medical", "heal":25, "weight":0.2, "count":2},
        {"name":"Аптечка", "type":"medical", "heal":55, "weight":0.7, "count":1},
        {"name":"Патроны 9мм", "type":"ammo", "amount":8, "weight":0.3, "count":1},
        {"name":"Патроны 5.45", "type":"ammo", "amount":5, "weight":0.25, "count":1},
        {"name":"Самодельный нож", "type":"weapon", "damage":12, "weight":0.8, "durability":90},
        {"name":"Охотничья винтовка", "type":"weapon", "damage":34, "ammo":5, "weight":3.2, "durability":80}
    ]

static func random_loot(rng: RandomNumberGenerator) -> Dictionary:
    var items = starter_items()
    return items[rng.randi_range(0, items.size() - 1)].duplicate(true)
