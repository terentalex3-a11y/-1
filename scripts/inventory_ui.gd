class_name InventoryUI

static func build_text(inventory: Array[Dictionary], armor: Dictionary, max_weight: float = 18.0) -> String:
    var text := "ИНВЕНТАРЬ\n"
    text += "Вес: %.1f / %.1f кг\n" % [total_weight(inventory, armor), max_weight]
    text += "\nБРОНЯ: %s  защита %d\n" % [armor.get("name", "нет"), int(armor.get("protection", 0))]
    text += "\nПРЕДМЕТЫ:\n"
    if inventory.is_empty():
        text += "Пусто\n"
    else:
        for i in inventory.size():
            var item = inventory[i]
            var count := int(item.get("count", 1))
            text += "%d. %s x%d" % [i + 1, item.get("name", "Предмет"), count]
            text += "  %.1f кг\n" % (float(item.get("weight", 0.0)) * count)
    return text

static func total_weight(inventory: Array[Dictionary], armor: Dictionary) -> float:
    var total := float(armor.get("weight", 0.0))
    for item in inventory:
        total += float(item.get("weight", 0.0)) * float(item.get("count", 1))
    return total
