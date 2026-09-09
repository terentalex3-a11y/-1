extends Node2D

var state: Node
var inventory_screen: Control
var mobile_controls: Control
var ap := 6
var hp := 100
var ammo := 8
var level := 1
var xp := 0
var player_pos := Vector2(640, 360)
var enemies := [Vector2(900, 280), Vector2(400, 520)]
var loot := [Vector2(300, 260), Vector2(1030, 500)]
var message := "Вы очнулись в разрушенном городе. Найдите припасы."
var combat := false
var selected_enemy := -1
var enemy_hp := [55, 45]
var wounds := {"head":0, "torso":0, "arm":0, "leg":0}
var rng := RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    state = preload("res://scripts/game_state.gd").new()
    add_child(state)
    inventory_screen = preload("res://scripts/inventory_screen.gd").new()
    inventory_screen.visible = false
    add_child(inventory_screen)
    inventory_screen.closed.connect(close_inventory)
    inventory_screen.item_used.connect(use_item)
    inventory_screen.item_equipped.connect(equip_item)
    mobile_controls = preload("res://scripts/mobile_controls.gd").new()
    add_child(mobile_controls)
    mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mobile_controls.move_requested.connect(on_mobile_move)
    mobile_controls.action_requested.connect(on_mobile_action)
    queue_redraw()

func _process(_delta):
    queue_redraw()

func _input(event):
    if inventory_screen.visible:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        handle_pointer(event.position)

func handle_pointer(p: Vector2):
    var s := get_viewport_rect().size
    var sx := s.x / 1280.0
    var sy := s.y / 720.0
    var point := Vector2(p.x / sx, p.y / sy)
    if Rect2(1030, 10, 230, 60).has_point(point):
        open_inventory()
        return
    if combat:
        if Rect2(1010, 575, 250, 125).has_point(point): shoot()
        elif Rect2(755, 575, 240, 125).has_point(point): heal()
        elif Rect2(500, 575, 240, 125).has_point(point): end_turn()
    elif ap > 0 and point.y > 70 and point.y < 570:
        player_pos = player_pos.move_toward(point, 90)
        ap -= 1
        check_interactions()

func on_mobile_move(direction: Vector2):
    if combat or ap <= 0:
        return
    var movement := direction * (90.0 if wounds.leg < 20 else 55.0)
    player_pos += movement
    player_pos.x = clamp(player_pos.x, 30.0, 1250.0)
    player_pos.y = clamp(player_pos.y, 80.0, 550.0)
    ap -= 1
    check_interactions()

func on_mobile_action(action: String):
    match action:
        "inventory": open_inventory()
        "shoot": shoot()
        "heal": heal()
        "end_turn": end_turn()

func open_inventory():
    inventory_screen.setup(state.inventory, state.body_armor)
    inventory_screen.visible = true
    message = "Инвентарь открыт."

func close_inventory():
    inventory_screen.visible = false
    message = "Инвентарь закрыт."

func use_item(index: int):
    if index < 0 or index >= state.inventory.size(): return
    var item = state.inventory[index]
    if item.get("type", "") == "medical":
        hp = min(100, hp + int(item.get("heal", 25)))
        var count := int(item.get("count", 1))
        if count > 1: item["count"] = count - 1
        else: state.inventory.remove_at(index)
        message = "%s использован." % item.get("name", "Предмет")
        inventory_screen.setup(state.inventory, state.body_armor)
    else:
        message = "Этот предмет нельзя использовать сейчас."

func equip_item(index: int):
    if index < 0 or index >= state.inventory.size(): return
    var item = state.inventory[index]
    if item.get("type", "") == "weapon":
        state.equipped_weapon = index
        if item.has("ammo"): ammo = int(item.ammo)
        message = "Экипировано: %s" % item.name
    elif item.get("type", "") == "armor":
        state.body_armor = item.duplicate(true)
        state.inventory.remove_at(index)
        message = "Экипировано: %s" % item.name
        inventory_screen.setup(state.inventory, state.body_armor)
    else:
        message = "Этот предмет нельзя экипировать."

func check_interactions():
    for i in range(enemies.size()):
        if enemies[i].x > 0 and player_pos.distance_to(enemies[i]) < 85:
            combat = true
            selected_enemy = i
            message = "Противник замечен! Ваш ход."
            return
    for p in loot.duplicate():
        if player_pos.distance_to(p) < 70:
            loot.erase(p)
            state.add_item({"name":"Найденные патроны", "type":"ammo", "amount":4, "weight":0.15, "count":1})
            ammo += 4
            xp += 15
            message = "Найдено: 4 патрона."
            return
    if player_pos.distance_to(Vector2(640, 360)) < 80:
        ap = 6
        message = "Убежище: восстановлены очки действий."

func shoot():
    if not combat or selected_enemy < 0: return
    if ammo <= 0:
        message = "Нет патронов."
        return
    if ap < 2:
        message = "Недостаточно очков действий."
        return
    ammo -= 1
    ap -= 2
    var weapon = state.inventory[state.equipped_weapon] if state.equipped_weapon < state.inventory.size() else {"damage":20}
    var chance = clamp(65 - int(player_pos.distance_to(enemies[selected_enemy]) / 20), 15, 90)
    if wounds.arm >= 20:
        chance -= 15
    if rng.randi_range(1, 100) <= chance:
        var part = ["head", "torso", "arm", "leg"][rng.randi_range(0, 3)]
        var result = preload("res://scripts/combat_system.gd").body_damage(part, int(weapon.get("damage", 20)))
        enemy_hp[selected_enemy] -= int(result.damage)
        message = "Попадание: %s. Урон %d." % [part, int(result.damage)]
        if enemy_hp[selected_enemy] <= 0:
            xp += 50
            enemies[selected_enemy] = Vector2(-100, -100)
            combat = false
            message = "Враг убит. Получено 50 XP."
            check_level()
            return
    else:
        message = "Промах."
    enemy_turn()

func heal():
    var index := find_medical()
    if index < 0: return
    use_item(index)
    if combat: enemy_turn()

func find_medical() -> int:
    for i in state.inventory.size():
        if state.inventory[i].get("type", "") == "medical": return i
    message = "Медицинских предметов нет."
    return -1

func end_turn():
    enemy_turn()

func enemy_turn():
    if not combat: return
    if rng.randi_range(1, 100) <= 55:
        var raw_damage := rng.randi_range(8, 18)
        var part = preload("res://scripts/combat_system.gd").choose_body_part(rng)
        wounds[part] = int(wounds.get(part, 0)) + raw_damage
        var protection := int(state.body_armor.get("protection", 0))
        var dmg := max(1, raw_damage - protection / 2)
        hp -= dmg
        message += " Враг ранит %s: %d урона." % [part, dmg]
        if part == "leg": message += " Движение снижено."
        if part == "arm": message += " Точность снижена."
        if hp <= 0:
            hp = 0
            message = "Вы погибли. Перезапустите игру."
            combat = false
    ap = 6

func check_level():
    if xp >= level * 100:
        level += 1
        hp = 100
        message += " Уровень повышен: %d." % level

func _draw():
    var s := get_viewport_rect().size
    var scale_x := s.x / 1280.0
    var scale_y := s.y / 720.0
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_x, scale_y))
    draw_rect(Rect2(0, 0, 1280, 720), Color("171717"))
    for x in range(0, 1280, 160):
        for y in range(70, 570, 130):
            draw_rect(Rect2(x + 8, y + 8, 135, 105), Color("303030"))
            draw_line(Vector2(x + 8, y + 8), Vector2(x + 143, y + 113), Color("454545"), 2)
    draw_rect(Rect2(0, 320, 1280, 70), Color("222222"))
    draw_rect(Rect2(590, 70, 100, 500), Color("222222"))
    draw_circle(Vector2(640, 360), 42, Color("58705a"))
    draw_string(ThemeDB.fallback_font, Vector2(605, 355), "УБЕЖИЩЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
    for p in loot:
        draw_circle(p, 15, Color("c2a44d"))
        draw_string(ThemeDB.fallback_font, p + Vector2(-18, 32), "ЛУТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6d58a"))
    for i in range(enemies.size()):
        if enemies[i].x > 0:
            draw_circle(enemies[i], 22, Color("8a3d3d"))
            draw_string(ThemeDB.fallback_font, enemies[i] + Vector2(-22, 38), "ВРАГ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d98b8b"))
    draw_circle(player_pos, 20, Color("6b8fb3"))
    draw_rect(Rect2(0, 0, 1280, 70), Color("101010"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 30), "POST APOCALYPSE RPG", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(380, 29), "HP %d/100   AP %d   Патроны %d   LVL %d   XP %d" % [hp, ap, ammo, level, xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d5d5d5"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 600), "Ранения: голова %d | корпус %d | рука %d | нога %d" % [wounds.head, wounds.torso, wounds.arm, wounds.leg], HORIZONTAL_ALIGNMENT_LEFT, 800, 15, Color("c99b9b"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 635), message, HORIZONTAL_ALIGNMENT_LEFT, 1000, 17, Color("eeeeee"))
    if combat:
        draw_rect(Rect2(0, 555, 1280, 165), Color("111111"))
        draw_string(ThemeDB.fallback_font, Vector2(25, 585), "ПОШАГОВЫЙ БОЙ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8c9a0"))
        draw_button(Rect2(500, 590, 240, 115), "Завершить ход")
        draw_button(Rect2(755, 590, 240, 115), "Лечиться")
        draw_button(Rect2(1010, 590, 250, 115), "СТРЕЛЯТЬ")

func draw_button(rect: Rect2, text: String):
    draw_rect(rect, Color("353535"))
    draw_rect(rect, Color("777777"), false, 3)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 67), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
