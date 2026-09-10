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
var ui_hover := ""

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

func _process(_delta):
    queue_redraw()

func _input(event):
    if inventory_screen.visible:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        handle_pointer(event.position)
    elif event is InputEventScreenTouch and event.pressed:
        handle_pointer(event.position)

func handle_pointer(p: Vector2):
    var s := get_viewport_rect().size
    var sx := s.x / 1280.0
    var sy := s.y / 720.0
    var point := Vector2(p.x / sx, p.y / sy)
    # Persistent, clearly visible action bar.
    if Rect2(20, 580, 210, 120).has_point(point):
        open_inventory()
        return
    if Rect2(245, 580, 210, 120).has_point(point):
        if combat: end_turn()
        else: message = "Завершить ход можно во время боя."
        return
    if Rect2(470, 580, 250, 120).has_point(point):
        if combat: heal()
        else: message = "Лечение доступно в бою."
        return
    if Rect2(735, 580, 250, 120).has_point(point):
        if combat: shoot()
        else: message = "Стрельба доступна после встречи с врагом."
        return
    if Rect2(1030, 10, 230, 60).has_point(point):
        open_inventory()
        return
    if combat:
        return
    if ap > 0 and point.y > 70 and point.y < 565:
        player_pos = player_pos.move_toward(point, 90)
        ap -= 1
        check_interactions()

func on_mobile_move(direction: Vector2):
    if combat or ap <= 0:
        return
    var movement := direction * (90.0 if wounds.leg < 20 else 55.0)
    player_pos += movement
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
    if index < 0 or index >= state.inventory.size(): return
    var item = state.inventory[index]
    if item.get("type", "") == "medical":
        hp = min(100, hp + int(item.get("heal", 25)))
        var count: int = int(item.get("count", 1))
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
    var weapon: Dictionary = state.inventory[state.equipped_weapon] if state.equipped_weapon < state.inventory.size() else {"damage":20}
    var chance: int = clamp(65 - int(player_pos.distance_to(enemies[selected_enemy]) / 20), 15, 90)
    if wounds.arm >= 20: chance -= 15
    if rng.randi_range(1, 100) <= chance:
        var part: String = ["head", "torso", "arm", "leg"][rng.randi_range(0, 3)]
        var result: Dictionary = preload("res://scripts/combat_system.gd").body_damage(part, int(weapon.get("damage", 20)))
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
    var index: int = find_medical()
    if index < 0: return
    use_item(index)
    if combat: enemy_turn()

func find_medical() -> int:
    for i in state.inventory.size():
        if state.inventory[i].get("type", "") == "medical": return i
    message = "Медицинских предметов нет."
    return -1

func end_turn():
    if combat: enemy_turn()
    else: message = "Сейчас нет противника: исследуйте район."

func enemy_turn():
    if not combat: return
    if rng.randi_range(1, 100) <= 55:
        var raw_damage: int = rng.randi_range(8, 18)
        var part: String = preload("res://scripts/combat_system.gd").choose_body_part(rng)
        wounds[part] = int(wounds.get(part, 0)) + raw_damage
        var protection: int = int(state.body_armor.get("protection", 0))
        var dmg: int = max(1, raw_damage - protection / 2)
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
    draw_rect(Rect2(0, 0, 1280, 720), Color("121417"))

    # Ruined city ground and streets.
    draw_rect(Rect2(0, 70, 1280, 495), Color("252a29"))
    draw_rect(Rect2(0, 300, 1280, 100), Color("303333"))
    draw_rect(Rect2(560, 70, 150, 495), Color("303333"))
    for x in range(0, 1280, 160):
        draw_line(Vector2(x, 350), Vector2(x + 70, 350), Color("5b5d57"), 3)
    for y in range(100, 560, 150):
        draw_line(Vector2(635, y), Vector2(635, y + 55), Color("5b5d57"), 3)

    # Damaged buildings, rubble and windows.
    var buildings = [Rect2(20,90,250,180), Rect2(300,95,220,165), Rect2(760,90,230,175), Rect2(1030,100,220,170), Rect2(20,420,250,120), Rect2(290,420,230,125), Rect2(760,420,230,125), Rect2(1030,415,220,130)]
    for b in buildings:
        draw_rect(b, Color("3a3d3c"))
        draw_rect(Rect2(b.position + Vector2(8,8), b.size - Vector2(16,16)), Color("303332"), false, 3)
        for wx in range(int(b.position.x + 25), int(b.end.x - 20), 45):
            draw_rect(Rect2(wx, b.position.y + 28, 22, 16), Color("565951"))
            if int(wx / 45) % 3 == 0:
                draw_line(Vector2(wx, b.position.y + 28), Vector2(wx + 22, b.position.y + 44), Color("242725"), 2)
        draw_line(b.position + Vector2(12, b.size.y - 18), b.end - Vector2(12,18), Color("1b1d1c"), 5)

    # Rubble piles.
    for r in [Vector2(280,285),Vector2(735,275),Vector2(540,475),Vector2(1005,380),Vector2(75,350)]:
        draw_circle(r, 24, Color("1d201f"))
        draw_circle(r + Vector2(-9,-5), 9, Color("55524b"))
        draw_circle(r + Vector2(11,7), 7, Color("67635a"))

    # Shelter.
    draw_rect(Rect2(575,315,130,90), Color("4b5d4d"))
    draw_rect(Rect2(585,325,110,70), Color("354436"))
    draw_rect(Rect2(610,345,60,50), Color("1a201b"))
    draw_string(ThemeDB.fallback_font, Vector2(592,312), "УБЕЖИЩЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("d9e0d6"))
    draw_circle(Vector2(640,335), 7, Color("d5a84c"))

    # Loot crates.
    for p in loot:
        draw_rect(Rect2(p - Vector2(16,13), Vector2(32,26)), Color("80663a"))
        draw_rect(Rect2(p - Vector2(13,10), Vector2(26,20)), Color("a4874e"), false, 3)
        draw_line(p + Vector2(-13,0), p + Vector2(13,0), Color("5d4929"), 3)
        draw_string(ThemeDB.fallback_font, p + Vector2(-18,31), "ПРИПАСЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("e1c777"))

    # Enemies: human silhouettes instead of circles.
    for i in range(enemies.size()):
        if enemies[i].x > 0:
            var ep: Vector2 = enemies[i]
            draw_circle(ep + Vector2(0,-20), 10, Color("c0a18c"))
            draw_rect(Rect2(ep + Vector2(-12,-10), Vector2(24,34)), Color("7b3f3f"))
            draw_line(ep + Vector2(-5,23), ep + Vector2(-12,38), Color("242424"), 6)
            draw_line(ep + Vector2(5,23), ep + Vector2(12,38), Color("242424"), 6)
            draw_line(ep + Vector2(7,0), ep + Vector2(27,-9), Color("222222"), 5)
            draw_string(ThemeDB.fallback_font, ep + Vector2(-27,55), "ВРАГ  %d HP" % enemy_hp[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e3a0a0"))
            if combat and i == selected_enemy:
                draw_arc(ep, 34, 0, TAU, 32, Color("d8b05c"), 3)

    # Player: visible survivor silhouette.
    draw_circle(player_pos + Vector2(0,-18), 10, Color("c9ad98"))
    draw_rect(Rect2(player_pos + Vector2(-13,-8), Vector2(26,36)), Color("4d667b"))
    draw_line(player_pos + Vector2(-6,26), player_pos + Vector2(-13,42), Color("202326"), 7)
    draw_line(player_pos + Vector2(6,26), player_pos + Vector2(13,42), Color("202326"), 7)
    draw_line(player_pos + Vector2(9,0), player_pos + Vector2(27,-10), Color("17191b"), 5)
    draw_circle(player_pos + Vector2(0,-18), 13, Color("7e9ab0"), false, 2)

    # Top HUD.
    draw_rect(Rect2(0,0,1280,70), Color("0b0d0f"))
    draw_string(ThemeDB.fallback_font, Vector2(24,31), "ПЕПЕЛ И РУИНЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("e4e0d5"))
    draw_string(ThemeDB.fallback_font, Vector2(285,30), "HP %d/100" % hp, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d58e8e"))
    draw_string(ThemeDB.fallback_font, Vector2(410,30), "AP %d/6" % ap, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d9c27d"))
    draw_string(ThemeDB.fallback_font, Vector2(515,30), "ПАТРОНЫ %d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c7c7bd"))
    draw_string(ThemeDB.fallback_font, Vector2(690,30), "LVL %d   XP %d" % [level,xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("a9b8c4"))
    draw_button(Rect2(1030,10,230,50), "🎒  ИНВЕНТАРЬ", false)

    # Message and wounds.
    draw_rect(Rect2(0,545,1280,35), Color("101214"))
    draw_string(ThemeDB.fallback_font, Vector2(22,568), message, HORIZONTAL_ALIGNMENT_LEFT, 1235, 15, Color("e2e2de"))

    # Permanent mobile-friendly action bar.
    draw_rect(Rect2(0,575,1280,145), Color("0b0d0f"))
    draw_string(ThemeDB.fallback_font, Vector2(22,598), "РАНЕНИЯ  голова %d   корпус %d   рука %d   нога %d" % [wounds.head,wounds.torso,wounds.arm,wounds.leg], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("c68f8f"))
    draw_button(Rect2(20,610,210,95), "🎒  ИНВЕНТАРЬ", false)
    draw_button(Rect2(245,610,210,95), "⏳  ЗАВЕРШИТЬ\nХОД", combat)
    draw_button(Rect2(470,610,250,95), "✚  ЛЕЧИТЬСЯ", combat)
    draw_button(Rect2(735,610,250,95), "▰  СТРЕЛЯТЬ", combat)
    draw_button(Rect2(1000,610,260,95), "AP  %d/6" % ap, false)

func draw_button(rect: Rect2, text: String, active: bool):
    var fill := Color("4a3b29") if active else Color("292d2f")
    draw_rect(rect, fill)
    draw_rect(rect, Color("8b8e88"), false, 2)
    var lines := text.split("\n")
    for j in range(lines.size()):
        draw_string(ThemeDB.fallback_font, rect.position + Vector2(18,40 + j*25), lines[j], HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("f0eee6"))
