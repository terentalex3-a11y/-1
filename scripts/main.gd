extends Node2D

var state: Node
var inventory_screen: Control
var mobile_controls: Control
var ap := 6
var max_ap := 6
var hp := 100
var max_hp := 100
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
var enemy_attack_flash := 0.0
var game_over := false

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
    mobile_controls.move_requested.connect(on_mobile_move)
    mobile_controls.action_requested.connect(on_mobile_action)
    queue_redraw()

func _process(delta):
    if enemy_attack_flash > 0.0:
        enemy_attack_flash -= delta
    queue_redraw()

func _input(event):
    if inventory_screen.visible:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        handle_pointer(event.position)
    elif event is InputEventScreenTouch and event.pressed:
        handle_pointer(event.position)

func to_world_point(p: Vector2) -> Vector2:
    var s := get_viewport_rect().size
    var sx := max(0.01, s.x / 1280.0)
    var sy := max(0.01, s.y / 720.0)
    return Vector2(p.x / sx, p.y / sy)

func handle_pointer(p: Vector2):
    if game_over:
        return
    var point := to_world_point(p)

    if Rect2(20, 610, 210, 95).has_point(point) or Rect2(1030, 10, 230, 50).has_point(point):
        open_inventory()
        return
    if Rect2(245, 610, 210, 95).has_point(point):
        end_turn()
        return
    if Rect2(470, 610, 250, 95).has_point(point):
        heal()
        return
    if Rect2(735, 610, 250, 95).has_point(point):
        shoot()
        return

    if combat:
        message = "Сейчас бой. Стреляйте, лечитесь или завершайте ход."
        return

    move_to(point)

func move_to(point: Vector2):
    if ap <= 0:
        message = "Очки действий закончились. Нажмите ЗАВЕРШИТЬ ХОД."
        return
    if point.y < 75 or point.y > 565:
        return
    var distance := player_pos.distance_to(point)
    if distance < 8:
        return
    var step := min(95.0, distance)
    player_pos += (point - player_pos).normalized() * step
    player_pos.x = clamp(player_pos.x, 30.0, 1250.0)
    player_pos.y = clamp(player_pos.y, 90.0, 550.0)
    ap -= 1
    check_interactions()

func on_mobile_move(direction: Vector2):
    if game_over or combat:
        return
    if ap <= 0:
        message = "Очки действий закончились. Нажмите ЗАВЕРШИТЬ ХОД."
        return
    var movement_speed := 90.0 if wounds.leg < 20 else 55.0
    player_pos += direction * movement_speed
    player_pos.x = clamp(player_pos.x, 30.0, 1250.0)
    player_pos.y = clamp(player_pos.y, 90.0, 550.0)
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
    if index < 0 or index >= state.inventory.size():
        return
    var item = state.inventory[index]
    if item.get("type", "") != "medical":
        message = "Этот предмет нельзя использовать сейчас."
        return
    var heal_amount := int(item.get("heal", 25))
    var old_hp := hp
    hp = min(max_hp, hp + heal_amount)
    var count: int = int(item.get("count", 1))
    if count > 1:
        item["count"] = count - 1
    else:
        state.inventory.remove_at(index)
    message = "%s: +%d HP." % [item.get("name", "Медикамент"), hp - old_hp]
    inventory_screen.setup(state.inventory, state.body_armor)

func equip_item(index: int):
    if index < 0 or index >= state.inventory.size():
        return
    var item = state.inventory[index]
    if item.get("type", "") == "weapon":
        state.equipped_weapon = index
        if item.has("ammo"):
            ammo = int(item.ammo)
        message = "Оружие экипировано: %s." % item.name
    elif item.get("type", "") == "armor":
        state.body_armor = item.duplicate(true)
        state.inventory.remove_at(index)
        message = "Экипировано: %s." % item.name
        inventory_screen.setup(state.inventory, state.body_armor)
    else:
        message = "Этот предмет нельзя экипировать."

func check_interactions():
    if combat:
        return
    for i in range(enemies.size()):
        if enemies[i].x > 0 and player_pos.distance_to(enemies[i]) < 85:
            combat = true
            selected_enemy = i
            ap = max_ap
            message = "ВРАГ ОБНАРУЖЕН! Ваш ход. Выберите действие."
            return
    for p in loot.duplicate():
        if player_pos.distance_to(p) < 70:
            loot.erase(p)
            state.add_item({"name":"Найденные патроны", "type":"ammo", "amount":4, "weight":0.15, "count":1})
            ammo += 4
            xp += 15
            message = "Найдено: 4 патрона."
            check_level()
            return
    if player_pos.distance_to(Vector2(640, 360)) < 80:
        ap = max_ap
        message = "Убежище: очки действий восстановлены."

func shoot():
    if game_over:
        return
    if not combat or selected_enemy < 0:
        message = "Стрелять можно только в бою."
        return
    if ammo <= 0:
        message = "Нет патронов."
        enemy_turn()
        return
    if ap < 2:
        message = "Недостаточно AP. Завершите ход или двигайтесь после боя."
        return

    ammo -= 1
    ap -= 2
    var weapon: Dictionary = {"damage":20}
    if state.equipped_weapon >= 0 and state.equipped_weapon < state.inventory.size():
        weapon = state.inventory[state.equipped_weapon]
    var chance: int = clamp(75 - int(player_pos.distance_to(enemies[selected_enemy]) / 18.0), 20, 90)
    if wounds.arm >= 20:
        chance -= 15
    if rng.randi_range(1, 100) <= chance:
        var part: String = ["head", "torso", "arm", "leg"][rng.randi_range(0, 3)]
        var result: Dictionary = preload("res://scripts/combat_system.gd").body_damage(part, int(weapon.get("damage", 20)))
        enemy_hp[selected_enemy] -= int(result.damage)
        message = "ПОПАДАНИЕ: %s — %d урона. Враг: %d HP." % [part, int(result.damage), max(0, enemy_hp[selected_enemy])]
        if enemy_hp[selected_enemy] <= 0:
            xp += 50
            enemies[selected_enemy] = Vector2(-100, -100)
            combat = false
            selected_enemy = -1
            ap = max_ap
            message = "ВРАГ УБИТ. +50 XP. Можно снова свободно передвигаться."
            check_level()
            return
    else:
        message = "ПРОМАХ. Шанс попадания: %d%%." % chance
    enemy_turn()

func heal():
    if game_over:
        return
    var index: int = find_medical()
    if index < 0:
        return
    use_item(index)
    if combat:
        enemy_turn()

func find_medical() -> int:
    for i in range(state.inventory.size()):
        if state.inventory[i].get("type", "") == "medical":
            return i
    message = "Медицинских предметов нет."
    return -1

func end_turn():
    if game_over:
        return
    if combat:
        message = "Вы завершили ход. Враг атакует..."
        enemy_turn()
    else:
        ap = max_ap
        message = "Ход завершён. AP восстановлены: %d/6. Можно продолжать исследование." % ap

func enemy_turn():
    if not combat or selected_enemy < 0 or game_over:
        return
    var enemy_index := selected_enemy
    if enemy_index >= enemies.size() or enemies[enemy_index].x < 0:
        combat = false
        selected_enemy = -1
        ap = max_ap
        return

    var enemy_pos: Vector2 = enemies[enemy_index]
    var distance := enemy_pos.distance_to(player_pos)
    var attack_chance := 90 if distance <= 300 else 65
    if rng.randi_range(1, 100) <= attack_chance:
        var raw_damage: int = rng.randi_range(7, 15)
        var part: String = preload("res://scripts/combat_system.gd").choose_body_part(rng)
        wounds[part] = int(wounds.get(part, 0)) + raw_damage
        var protection: int = int(state.body_armor.get("protection", 0))
        var dmg: int = max(1, raw_damage - int(protection / 2))
        hp = max(0, hp - dmg)
        enemy_attack_flash = 0.25
        message = "ВРАГ СТРЕЛЯЕТ! Ранение: %s, -%d HP. Осталось %d/100." % [part, dmg, hp]
        if part == "leg":
            message += " Движение снижено."
        elif part == "arm":
            message += " Точность снижена."
        if hp <= 0:
            game_over = true
            combat = false
            message = "ВЫ ПОГИБЛИ. Перезапустите игру."
            return
    else:
        message = "Враг стреляет, но промахивается. Ваш ход."
    ap = max_ap

func check_level():
    if xp >= level * 100:
        level += 1
        hp = max_hp
        message += " Уровень повышен: %d." % level

func _draw():
    var s := get_viewport_rect().size
    var scale_x := s.x / 1280.0
    var scale_y := s.y / 720.0
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_x, scale_y))
    draw_rect(Rect2(0, 0, 1280, 720), Color("121417"))

    draw_rect(Rect2(0, 70, 1280, 495), Color("252a29"))
    draw_rect(Rect2(0, 300, 1280, 100), Color("303333"))
    draw_rect(Rect2(560, 70, 150, 495), Color("303333"))
    for x in range(0, 1280, 160):
        draw_line(Vector2(x, 350), Vector2(x + 70, 350), Color("5b5d57"), 3)
    for y in range(100, 560, 150):
        draw_line(Vector2(635, y), Vector2(635, y + 55), Color("5b5d57"), 3)

    var buildings = [Rect2(20,90,250,180), Rect2(300,95,220,165), Rect2(760,90,230,175), Rect2(1030,100,220,170), Rect2(20,420,250,120), Rect2(290,420,230,125), Rect2(760,420,230,125), Rect2(1030,415,220,130)]
    for b in buildings:
        draw_rect(b, Color("3a3d3c"))
        draw_rect(Rect2(b.position + Vector2(8,8), b.size - Vector2(16,16)), Color("303332"), false, 3)
        for wx in range(int(b.position.x + 25), int(b.end.x - 20), 45):
            draw_rect(Rect2(wx, b.position.y + 28, 22, 16), Color("565951"))
            if int(wx / 45) % 3 == 0:
                draw_line(Vector2(wx, b.position.y + 28), Vector2(wx + 22, b.position.y + 44), Color("242725"), 2)
        draw_line(b.position + Vector2(12, b.size.y - 18), b.end - Vector2(12,18), Color("1b1d1c"), 5)

    for r in [Vector2(280,285),Vector2(735,275),Vector2(540,475),Vector2(1005,380),Vector2(75,350)]:
        draw_circle(r, 24, Color("1d201f"))
        draw_circle(r + Vector2(-9,-5), 9, Color("55524b"))
        draw_circle(r + Vector2(11,7), 7, Color("67635a"))

    draw_rect(Rect2(575,315,130,90), Color("4b5d4d"))
    draw_rect(Rect2(585,325,110,70), Color("354436"))
    draw_rect(Rect2(610,345,60,50), Color("1a201b"))
    draw_string(ThemeDB.fallback_font, Vector2(592,312), "УБЕЖИЩЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d9e0d6"))
    draw_circle(Vector2(640,335), 7, Color("d5a84c"))

    for p in loot:
        draw_rect(Rect2(p - Vector2(16,13), Vector2(32,26)), Color("80663a"))
        draw_rect(Rect2(p - Vector2(13,10), Vector2(26,20)), Color("a4874e"), false, 3)
        draw_line(p + Vector2(-13,0), p + Vector2(13,0), Color("5d4929"), 3)
        draw_string(ThemeDB.fallback_font, p + Vector2(-18,31), "ПРИПАСЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1c777"))

    for i in range(enemies.size()):
        if enemies[i].x > 0:
            var ep: Vector2 = enemies[i]
            draw_circle(ep + Vector2(0,-20), 10, Color("c0a18c"))
            draw_rect(Rect2(ep + Vector2(-12,-10), Vector2(24,34)), Color("7b3f3f"))
            draw_line(ep + Vector2(-5,23), ep + Vector2(-12,38), Color("242424"), 6)
            draw_line(ep + Vector2(5,23), ep + Vector2(12,38), Color("242424"), 6)
            draw_line(ep + Vector2(7,0), ep + Vector2(30,-12), Color("222222"), 5)
            draw_string(ThemeDB.fallback_font, ep + Vector2(-27,55), "ВРАГ  %d HP" % enemy_hp[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e3a0a0"))
            if combat and i == selected_enemy:
                draw_arc(ep, 34, 0, TAU, 32, Color("d8b05c"), 3)
            if enemy_attack_flash > 0.0 and combat and i == selected_enemy:
                draw_line(ep + Vector2(25,-10), player_pos + Vector2(0,-15), Color("e8d26b"), 4)

    draw_circle(player_pos + Vector2(0,-18), 10, Color("c9ad98"))
    draw_rect(Rect2(player_pos + Vector2(-13,-8), Vector2(26,36)), Color("4d667b"))
    draw_line(player_pos + Vector2(-6,26), player_pos + Vector2(-13,42), Color("202326"), 7)
    draw_line(player_pos + Vector2(6,26), player_pos + Vector2(13,42), Color("202326"), 7)
    draw_line(player_pos + Vector2(9,0), player_pos + Vector2(27,-10), Color("17191b"), 5)
    draw_circle(player_pos + Vector2(0,-18), 13, Color("7e9ab0"), false, 2)

    draw_rect(Rect2(0,0,1280,70), Color("0b0d0f"))
    draw_string(ThemeDB.fallback_font, Vector2(24,31), "ПЕПЕЛ И РУИНЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e4e0d5"))
    draw_string(ThemeDB.fallback_font, Vector2(285,27), "ЖИЗНЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e5d9d2"))
    draw_rect(Rect2(285,37,125,18), Color("25282a"))
    draw_rect(Rect2(287,39,121 * float(hp) / float(max_hp),14), Color("9e4b4b"))
    draw_string(ThemeDB.fallback_font, Vector2(292,52), "%d / %d HP" % [hp,max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffffff"))
    draw_string(ThemeDB.fallback_font, Vector2(430,30), "AP %d/%d" % [ap,max_ap], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d9c27d"))
    draw_string(ThemeDB.fallback_font, Vector2(540,30), "ПАТРОНЫ %d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c7c7bd"))
    draw_string(ThemeDB.fallback_font, Vector2(690,30), "LVL %d   XP %d" % [level,xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("a9b8c4"))
    draw_button(Rect2(1030,10,230,50), "ИНВЕНТАРЬ", false)

    draw_rect(Rect2(0,545,1280,35), Color("101214"))
    draw_string(ThemeDB.fallback_font, Vector2(22,568), message, HORIZONTAL_ALIGNMENT_LEFT, 1235, 15, Color("e2e2de"))

    draw_rect(Rect2(0,575,1280,145), Color("0b0d0f"))
    draw_string(ThemeDB.fallback_font, Vector2(22,598), "РАНЕНИЯ  голова %d   корпус %d   рука %d   нога %d" % [wounds.head,wounds.torso,wounds.arm,wounds.leg], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c68f8f"))
    draw_button(Rect2(20,610,210,95), "ИНВЕНТАРЬ", false)
    draw_button(Rect2(245,610,210,95), "ЗАВЕРШИТЬ\nХОД", true)
    draw_button(Rect2(470,610,250,95), "ЛЕЧИТЬСЯ", combat and not game_over)
    draw_button(Rect2(735,610,250,95), "СТРЕЛЯТЬ", combat and not game_over)
    draw_button(Rect2(1000,610,260,95), "AP  %d/%d" % [ap,max_ap], false)

func draw_button(rect: Rect2, text: String, active: bool):
    var fill := Color("4a3b29") if active else Color("292d2f")
    draw_rect(rect, fill)
    draw_rect(rect, Color("8b8e88"), false, 2)
    var lines := text.split("\n")
    for j in range(lines.size()):
        draw_string(ThemeDB.fallback_font, rect.position + Vector2(18,40 + j*25), lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f0eee6"))
