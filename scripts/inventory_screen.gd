extends Control

signal closed
signal item_used(index)
signal item_equipped(index)

var inventory: Array[Dictionary] = []
var armor: Dictionary = {}
var selected := -1
var max_weight := 18.0

func setup(items: Array[Dictionary], equipped_armor: Dictionary) -> void:
    inventory = items
    armor = equipped_armor
    queue_redraw()

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var p: Vector2 = event.position
        if Rect2(1030, 35, 210, 55).has_point(p):
            closed.emit()
            return
        for i in inventory.size():
            var row := Rect2(55, 145 + i * 48, 730, 42)
            if row.has_point(p):
                selected = i
                queue_redraw()
                return
        if selected >= 0 and Rect2(805, 540, 190, 60).has_point(p):
            item_used.emit(selected)
        elif selected >= 0 and Rect2(1010, 540, 190, 60).has_point(p):
            item_equipped.emit(selected)

func _draw():
    draw_rect(Rect2(0, 0, 1280, 720), Color("111111"))
    draw_rect(Rect2(35, 25, 1210, 660), Color("1e1e1e"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 75), "ИНВЕНТАРЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(55, 110), "Вес %.1f / %.1f кг" % [weight(), max_weight], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("cccccc"))
    draw_string(ThemeDB.fallback_font, Vector2(805, 110), "БРОНЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("d9c39a"))
    draw_string(ThemeDB.fallback_font, Vector2(805, 140), "%s  | защита %d" % [armor.get("name", "Нет"), int(armor.get("protection", 0))], HORIZONTAL_ALIGNMENT_LEFT, 380, 16, Color.WHITE)
    for i in inventory.size():
        var y: float = 145 + i * 48
        var active := i == selected
        draw_rect(Rect2(55, y, 730, 42), Color("3a3a3a") if active else Color("292929"))
        var item: Dictionary = inventory[i]
        var count: int = int(item.get("count", 1))
        draw_string(ThemeDB.fallback_font, Vector2(70, y + 27), "%d. %s x%d" % [i + 1, item.get("name", "Предмет"), count], HORIZONTAL_ALIGNMENT_LEFT, 500, 17, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(600, y + 27), "%.1f кг" % (float(item.get("weight", 0.0)) * count), HORIZONTAL_ALIGNMENT_LEFT, 130, 15, Color("bbbbbb"))
    if selected >= 0 and selected < inventory.size():
        var item: Dictionary = inventory[selected]
        draw_string(ThemeDB.fallback_font, Vector2(805, 230), "ВЫБРАНО", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d9c39a"))
        draw_string(ThemeDB.fallback_font, Vector2(805, 265), str(item.get("name", "Предмет")), HORIZONTAL_ALIGNMENT_LEFT, 380, 24, Color.WHITE)
        draw_string(ThemeDB.fallback_font, Vector2(805, 305), details(item), HORIZONTAL_ALIGNMENT_LEFT, 380, 16, Color("cccccc"))
        button(Rect2(805, 540, 190, 60), "Использовать")
        button(Rect2(1010, 540, 190, 60), "Экипировать")
    button(Rect2(1030, 35, 210, 55), "Назад")

func weight() -> float:
    var total: float = float(armor.get("weight", 0.0))
    for item in inventory:
        total += float(item.get("weight", 0.0)) * float(item.get("count", 1))
    return total

func details(item: Dictionary) -> String:
    var t := "Тип: %s\n" % item.get("type", "прочее")
    if item.has("damage"): t += "Урон: %d\n" % int(item.damage)
    if item.has("heal"): t += "Лечение: +%d HP\n" % int(item.heal)
    if item.has("durability"): t += "Прочность: %d\n" % int(item.durability)
    return t

func button(rect: Rect2, text: String):
    draw_rect(rect, Color("353535"))
    draw_rect(rect, Color("777777"), false, 2)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(18, 37), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
