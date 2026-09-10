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
var wounds := {"head":0,"torso":0,"arm":0,"leg":0}
var rng := RandomNumberGenerator.new()
var enemy_attack_flash := 0.0
var game_over := false
var combat_player_pos := Vector2(300, 360)
var combat_enemy_pos := Vector2(930, 360)
var combat_cover := false
var combat_selected_target := "torso"
var combat_covers := [Rect2(430, 180, 110, 70), Rect2(600, 410, 120, 70), Rect2(760, 180, 100, 65)]

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

func _process(delta: float):
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
    return Vector2(p.x / max(0.01, s.x / 1280.0), p.y / max(0.01, s.y / 720.0))

func handle_pointer(p: Vector2):
    if game_over:
        return
    var point := to_world_point(p)
    if Rect2(20, 610, 210, 95).has_point(point):
        open_inventory()
        return
    if combat:
        handle_combat_pointer(point)
        return
    move_to(point)

func handle_combat_pointer(point: Vector2):
    if Rect2(20, 610, 210, 95).has_point(point):
        open_inventory()
    elif Rect2(220, 610, 175, 95).has_point(point):
        quick_shot()
    elif Rect2(400, 610, 175, 95).has_point(point):
        aimed_shot()
    elif Rect2(580, 610, 175, 95).has_point(point):
        melee_attack()
    elif Rect2(760, 610, 150, 95).has_point(point):
        heal()
    elif Rect2(915, 610, 170, 95).has_point(point):
        end_turn()
    elif Rect2(1090, 610, 170, 95).has_point(point):
        cycle_target()
    elif point.y > 85 and point.y < 585:
        move_in_combat(point)

func move_to(point: Vector2):
    if point.y < 75 or point.y > 565:
        return
    var distance := player_pos.distance_to(point)
    if distance < 8.0:
        return
    var step := min(38.0, distance)
    player_pos += (point - player_pos).normalized() * step
    player_pos.x = clamp(player_pos.x, 30.0, 1250.0)
    player_pos.y = clamp(player_pos.y, 90.0, 550.0)
    check_interactions()

func on_mobile_move(direction: Vector2):
    if game_over or combat:
        return
    var movement_speed := 2.5 if wounds.leg < 20 else 1.6
    player_pos += direction * movement_speed
    player_pos.x = clamp(player_pos.x, 30.0, 1250.0)
    player_pos.y = clamp(player_pos.y, 90.0, 550.0)
    check_interactions()

func on_mobile_action(action: String):
    match action:
        "inventory": open_inventory()
        "shoot": quick_shot()
        "heal": heal()
        "end_turn": end_turn()

func open_inventory():
    inventory_screen.setup(state.inventory, state.body_armor)
    inventory_screen.visible = true
    mobile_controls.set_mobile_mode(false)
    message = "Инвентарь открыт."

func close_inventory():
    inventory_screen.visible = false
    mobile_controls.set_mobile_mode(not combat)
    message = "Инвентарь закрыт."

func use_item(index: int):
    if index < 0 or index >= state.inventory.size():
        return
    var item: Dictionary = state.inventory[index]
    if item.get("type", "") != "medical":
        message = "Этот предмет нельзя использовать сейчас."
        return
    var item_name := str(item.get("name", "Медикамент"))
    var heal_amount := int(item.get("heal", 25))
    var old_hp := hp
    hp = min(max_hp, hp + heal_amount)
    var count := int(item.get("count", 1))
    if count > 1:
        item["count"] = count - 1
    else:
        state.inventory.remove_at(index)
    message = "%s: +%d HP." % [item_name, hp - old_hp]
    inventory_screen.setup(state.inventory, state.body_armor)

func equip_item(index: int):
    if index < 0 or index >= state.inventory.size():
        return
    var item: Dictionary = state.inventory[index]
    if item.get("type", "") == "weapon":
        state.equipped_weapon = index
        if item.has("ammo"):
            ammo = int(item.get("ammo", ammo))
        message = "Оружие экипировано: %s." % str(item.get("name", "оружие"))
    elif item.get("type", "") == "armor":
        state.body_armor = item.duplicate(true)
        state.inventory.remove_at(index)
        message = "Экипировано: %s." % str(item.get("name", "броня"))
        inventory_screen.setup(state.inventory, state.body_armor)

func check_interactions():
    if combat:
        return
    for i in range(enemies.size()):
        if enemies[i].x > 0.0 and player_pos.distance_to(enemies[i]) < 70.0:
            start_combat(i)
            return
    for p in loot.duplicate():
        if player_pos.distance_to(p) < 55.0:
            loot.erase(p)
            state.add_item({"name":"Найденные патроны", "type":"ammo", "amount":4, "weight":0.15, "count":1})
            ammo += 4
            xp += 15
            message = "Найдено: 4 патрона."
            check_level()
            return
    if player_pos.distance_to(Vector2(640, 360)) < 80.0:
        message = "Убежище. Здесь можно восстановиться и управлять запасами."

func start_combat(enemy_index: int):
    combat = true
    selected_enemy = enemy_index
    ap = max_ap
    combat_player_pos = Vector2(300, 360)
    combat_enemy_pos = Vector2(930, 360)
    combat_cover = false
    combat_selected_target = "torso"
    message = "ВРАГ ОБНАРУЖЕН! Ходите по полю, ищите укрытие и выбирайте атаку."
    mobile_controls.set_mobile_mode(false)

func finish_combat(victory: bool):
    combat = false
    selected_enemy = -1
    ap = max_ap
    mobile_controls.set_mobile_mode(true)
    if victory:
        message = "ВРАГ УБИТ. +50 XP. Возвращаемся в мир."
    check_level()

func combat_move_cost(distance: float) -> int:
    return max(1, int(ceil(distance / 75.0)))

func is_in_cover(pos: Vector2) -> bool:
    for cover in combat_covers:
        if cover.grow(18).has_point(pos):
            return true
    return false

func move_in_combat(point: Vector2):
    var distance := combat_player_pos.distance_to(point)
    if distance < 15.0:
        return
    var cost := combat_move_cost(distance)
    if cost > ap:
        message = "Недостаточно AP для перемещения. Нужно %d AP." % cost
        return
    combat_player_pos += (point - combat_player_pos).normalized() * min(distance, float(cost * 75))
    combat_player_pos.x = clamp(combat_player_pos.x, 55.0, 1220.0)
    combat_player_pos.y = clamp(combat_player_pos.y, 105.0, 560.0)
    ap -= cost
    combat_cover = is_in_cover(combat_player_pos)
    message = "Перемещение: -%d AP. %s" % [cost, "Вы в укрытии." if combat_cover else "Открытая позиция."]

func cycle_target():
    var targets := ["torso", "head", "arm", "leg"]
    var index := targets.find(combat_selected_target)
    combat_selected_target = targets[(index + 1) % targets.size()]
    message = "Выбрана зона: %s." % combat_selected_target

func attack_chance(base: int) -> int:
    var distance := combat_player_pos.distance_to(combat_enemy_pos)
    var chance := base - int(distance / 22.0)
    if combat_cover:
        chance += 5
    if wounds.arm >= 20:
        chance -= 15
    return clamp(chance, 10, 95)

func do_shot(ap_cost: int, damage_mult: float, chance_base: int, label: String):
    if not combat or selected_enemy < 0:
        message = "Сейчас вы не в бою."
        return
    if ap < ap_cost:
        message = "Недостаточно AP."
        return
    if ammo <= 0:
        message = "Нет патронов."
        return
    ammo -= 1
    ap -= ap_cost
    var chance := attack_chance(chance_base)
    if rng.randi_range(1, 100) <= chance:
        var weapon_damage := 20
        if state.equipped_weapon >= 0 and state.equipped_weapon < state.inventory.size():
            weapon_damage = int(state.inventory[state.equipped_weapon].get("damage", 20))
        var result: Dictionary = preload("res://scripts/combat_system.gd").body_damage(combat_selected_target, int(weapon_damage * damage_mult))
        var dealt := int(result.get("damage", weapon_damage))
        enemy_hp[selected_enemy] -= dealt
        message = "%s: %s — %d урона. Шанс %d%%. AP: %d." % [label, combat_selected_target, dealt, chance, ap]
        if enemy_hp[selected_enemy] <= 0:
            xp += 50
            enemies[selected_enemy] = Vector2(-100, -100)
            finish_combat(true)
            return
    else:
        message = "%s: ПРОМАХ. Шанс %d%%. AP: %d." % [label, chance, ap]

func quick_shot():
    do_shot(2, 0.9, 82, "БЫСТРЫЙ ВЫСТРЕЛ")

func aimed_shot():
    do_shot(3, 1.35, 68, "ПРИЦЕЛЬНЫЙ ВЫСТРЕЛ")

func melee_attack():
    if not combat or selected_enemy < 0:
        return
    var distance := combat_player_pos.distance_to(combat_enemy_pos)
    if distance > 120.0:
        message = "Слишком далеко для удара. Подойдите ближе."
        return
    if ap < 2:
        message = "Недостаточно AP для удара."
        return
    ap -= 2
    if rng.randi_range(1, 100) <= 88:
        var result: Dictionary = preload("res://scripts/combat_system.gd").body_damage(combat_selected_target, 18)
        var dealt := int(result.get("damage", 18))
        enemy_hp[selected_enemy] -= dealt
        message = "УДАР: %s — %d урона. AP: %d." % [combat_selected_target, dealt, ap]
        if enemy_hp[selected_enemy] <= 0:
            xp += 50
            enemies[selected_enemy] = Vector2(-100, -100)
            finish_combat(true)
    else:
        message = "УДАР ПРОМАХНУЛСЯ. AP: %d." % ap

func heal():
    if game_over:
        return
    if combat and ap < 2:
        message = "Недостаточно AP для лечения."
        return
    var index := find_medical()
    if index < 0:
        return
    use_item(index)
    if combat:
        ap -= 2
        message = "Лечение: -2 AP. Осталось %d AP." % ap

func find_medical() -> int:
    for i in range(state.inventory.size()):
        if state.inventory[i].get("type", "") == "medical":
            return i
    message = "Медицинских предметов нет."
    return -1

func end_turn():
    if game_over:
        return
    if not combat:
        message = "В мире движение свободное. Ход нужен только во время боя."
        return
    message = "Ваш ход завершён. Враг действует..."
    enemy_turn()

func enemy_turn():
    if not combat or selected_enemy < 0 or game_over:
        return
    var distance := combat_enemy_pos.distance_to(combat_player_pos)
    if distance > 260.0:
        var step := min(120.0, distance - 150.0)
        combat_enemy_pos += (combat_player_pos - combat_enemy_pos).normalized() * step
        message = "Враг перемещается и ищет позицию. Ваш ход."
    else:
        var attack_chance := 72
        if combat_cover:
            attack_chance -= 25
        if rng.randi_range(1, 100) <= attack_chance:
            var raw_damage := rng.randi_range(7, 15)
            var part: String = preload("res://scripts/combat_system.gd").choose_body_part(rng)
            wounds[part] = int(wounds.get(part, 0)) + raw_damage
            var protection := int(state.body_armor.get("protection", 0))
            var dmg := max(1, raw_damage - int(protection / 2))
            hp = max(0, hp - dmg)
            enemy_attack_flash = 0.25
            message = "ВРАГ АТАКУЕТ! %s, -%d HP. Осталось %d/%d." % [part, dmg, hp, max_hp]
            if hp <= 0:
                game_over = true
                combat = false
                selected_enemy = -1
                mobile_controls.set_mobile_mode(false)
                message = "ВЫ ПОГИБЛИ. Перезапустите игру."
                return
        else:
            message = "Враг стреляет, но промахивается. Ваш ход."
    ap = max_ap
    combat_cover = is_in_cover(combat_player_pos)

func check_level():
    while xp >= level * 100:
        level += 1
        message += " Уровень повышен: %d." % level

func _draw():
    var s := get_viewport_rect().size
    var scale_x := s.x / 1280.0
    var scale_y := s.y / 720.0
    draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_x, scale_y))
    draw_rect(Rect2(0, 0, 1280, 720), Color("121417"))
    if combat:
        draw_combat_screen()
    else:
        draw_world()
    draw_hud()

func draw_world():
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
        draw_line(b.position + Vector2(12, b.size.y - 18), b.end - Vector2(12,18), Color("1b1d1c"), 5)
    for r in [Vector2(280,285),Vector2(735,275),Vector2(540,475),Vector2(1005,380),Vector2(75,350)]:
        draw_circle(r, 24, Color("1d201f"))
        draw_circle(r + Vector2(-9,-5), 9, Color("55524b"))
        draw_circle(r + Vector2(11,7), 7, Color("67635a"))
    draw_rect(Rect2(575,315,130,90), Color("4b5d4d"))
    draw_rect(Rect2(585,325,110,70), Color("354436"))
    draw_rect(Rect2(610,345,60,50), Color("1a201b"))
    draw_string(ThemeDB.fallback_font, Vector2(592,312), "УБЕЖИЩЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d9e0d6"))
    for p in loot:
        draw_rect(Rect2(p - Vector2(16,13), Vector2(32,26)), Color("80663a"))
        draw_rect(Rect2(p - Vector2(13,10), Vector2(26,20)), Color("a4874e"), false, 3)
        draw_string(ThemeDB.fallback_font, p + Vector2(-20,30), "ЛУТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e0c987"))
    for e in enemies:
        if e.x > 0:
            draw_circle(e, 19, Color("7a2f2f"))
            draw_circle(e + Vector2(0,-18), 10, Color("b64b45"))
            draw_string(ThemeDB.fallback_font, e + Vector2(-26,32), "ВРАГ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e09b96"))
    draw_circle(player_pos, 22, Color("6d8794"))
    draw_circle(player_pos + Vector2(0,-20), 11, Color("b5c3c7"))
    draw_string(ThemeDB.fallback_font, player_pos + Vector2(-30,38), "ВЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("dce8eb"))

func draw_combat_screen():
    draw_rect(Rect2(0, 70, 1280, 495), Color("242824"))
    draw_rect(Rect2(0, 300, 1280, 90), Color("2e332f"))
    for x in range(40, 1260, 80):
        draw_line(Vector2(x, 90), Vector2(x, 565), Color("343a35"), 1)
    for y in range(100, 570, 70):
        draw_line(Vector2(20, y), Vector2(1260, y), Color("343a35"), 1)
    for cover in combat_covers:
        draw_rect(cover, Color("4c514a"))
        draw_rect(cover.grow(-7), Color("343934"))
        draw_string(ThemeDB.fallback_font, cover.position + Vector2(8, 20), "УКРЫТИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("aeb5aa"))
    if combat_cover:
        draw_circle(combat_player_pos, 32, Color(0.3,0.7,0.4,0.18))
        draw_string(ThemeDB.fallback_font, combat_player_pos + Vector2(-35,-35), "УКРЫТИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("8dd39a"))
    draw_circle(combat_player_pos, 23, Color("6d8794"))
    draw_circle(combat_player_pos + Vector2(0,-20), 11, Color("b5c3c7"))
    draw_circle(combat_enemy_pos, 23, Color("8b3535"))
    draw_circle(combat_enemy_pos + Vector2(0,-20), 11, Color("c65a52"))
    draw_string(ThemeDB.fallback_font, Vector2(255,105), "ВАША ПОЗИЦИЯ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d8e1e3"))
    draw_string(ThemeDB.fallback_font, Vector2(875,105), "ВРАГ: %d HP" % enemy_hp[selected_enemy], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("f0b0a8"))
    draw_string(ThemeDB.fallback_font, Vector2(30,595), "Нажмите на поле — перемещение. Серые объекты дают укрытие.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("c6c8c0"))

func draw_hud():
    draw_rect(Rect2(0, 0, 1280, 70), Color("181b1c"))
    draw_string(ThemeDB.fallback_font, Vector2(20, 28), "HP %d/%d" % [hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("e5d7d0"))
    draw_string(ThemeDB.fallback_font, Vector2(160, 28), "Патроны %d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d9d0ad"))
    draw_string(ThemeDB.fallback_font, Vector2(310, 28), "LVL %d  XP %d" % [level, xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("b9c9bd"))
    if combat:
        draw_string(ThemeDB.fallback_font, Vector2(500, 28), "AP %d/%d" % [ap, max_ap], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("e7c879"))
        draw_string(ThemeDB.fallback_font, Vector2(700, 28), "Цель: %s" % combat_selected_target, HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("d6d9d1"))
        draw_string(ThemeDB.fallback_font, Vector2(850, 28), "Укрытие" if combat_cover else "Открыто", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("9bd09f") if combat_cover else Color("d19b8d"))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(500, 28), "Мир: медленное перемещение", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("bfc5bb"))
    draw_rect(Rect2(20, 610, 210, 95), Color("303538"))
    draw_string(ThemeDB.fallback_font, Vector2(45, 652), "ИНВЕНТАРЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("d9ddda"))
    if combat:
        draw_button(Rect2(220,610,175,95), "БЫСТРЫЙ\nВЫСТРЕЛ", Color("5a4740"))
        draw_button(Rect2(400,610,175,95), "ПРИЦЕЛЬНЫЙ\nВЫСТРЕЛ", Color("5b5540"))
        draw_button(Rect2(580,610,175,95), "УДАР\nБЛИЖНИЙ", Color("514246"))
        draw_button(Rect2(760,610,150,95), "ЛЕЧЕНИЕ\n2 AP", Color("3f5144"))
        draw_button(Rect2(915,610,170,95), "ЗАВЕРШИТЬ\nХОД", Color("4a4c42"))
        draw_button(Rect2(1090,610,170,95), "ЦЕЛЬ: %s" % combat_selected_target.to_upper(), Color("41464a"))
    else:
        draw_string(ThemeDB.fallback_font, Vector2(260,650), message, HORIZONTAL_ALIGNMENT_LEFT, 990, 17, Color("d4d3c8"))
        draw_string(ThemeDB.fallback_font, Vector2(260,680), "Джойстик замедлен. В бою поле будет пошаговым.", HORIZONTAL_ALIGNMENT_LEFT, 900, 14, Color("8f9890"))

func draw_button(rect: Rect2, text: String, fill: Color):
    draw_rect(rect, fill)
    draw_rect(rect, Color("858980"), false, 2)
    var lines := text.split("\n")
    var y := rect.position.y + 38
    for line in lines:
        draw_string(ThemeDB.fallback_font, Vector2(rect.position.x + 10, y), line, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 20, 15, Color("e3e1d8"))
        y += 24
