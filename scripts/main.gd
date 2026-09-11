extends Node2D

var rng := RandomNumberGenerator.new()
var grid_size: float = 48.0
var origin := Vector2(48, 82)
var cols: int = 24
var rows: int = 9
var player := Vector2i(12, 4)
var enemies := [Vector2i(17, 3), Vector2i(7, 7)]
var loot := [Vector2i(5, 2), Vector2i(20, 7)]
var enemy_hp := [55, 45]
var hp: int = 100
var ammo: int = 8
var ap: int = 6
var max_ap: int = 6
var xp: int = 0
var level: int = 1
var combat: bool = false
var enemy_index: int = -1
var combat_player := Vector2i(4, 4)
var combat_enemy := Vector2i(18, 4)
var target := "torso"
var inventory_open: bool = false
var message := "Вы очнулись в разрушенном городе. Найдите припасы."
var medkits: int = 2

func _ready() -> void:
    rng.randomize()
    get_viewport().set_embedding_subwindows(false)
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        handle_tap(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        handle_tap(event.position)

func screen_point(p: Vector2) -> Vector2:
    var s: Vector2 = get_viewport_rect().size
    return Vector2(p.x * 1280.0 / max(1.0, s.x), p.y * 720.0 / max(1.0, s.y))

func handle_tap(raw: Vector2) -> void:
    var p := screen_point(raw)
    if inventory_open:
        if Rect2(1050, 35, 180, 60).has_point(p):
            inventory_open = false
        elif Rect2(820, 530, 180, 70).has_point(p) and medkits > 0:
            medkits -= 1
            hp = min(100, hp + 40)
            message = "Аптечка: +40 HP."
        queue_redraw()
        return
    if Rect2(20, 630, 180, 70).has_point(p):
        inventory_open = true
        queue_redraw()
        return
    if combat:
        handle_combat_tap(p)
    else:
        if Rect2(20, 540, 70, 70).has_point(p): move_world(Vector2i(-1, 0))
        elif Rect2(100, 540, 70, 70).has_point(p): move_world(Vector2i(1, 0))
        elif Rect2(60, 460, 70, 70).has_point(p): move_world(Vector2i(0, -1))
        elif Rect2(60, 620, 70, 70).has_point(p): move_world(Vector2i(0, 1))
        elif p.y >= origin.y and p.y < origin.y + rows * grid_size:
            var c := Vector2i(floor((p - origin) / grid_size))
            if abs(c.x - player.x) + abs(c.y - player.y) == 1:
                move_world(c - player)
    queue_redraw()

func move_world(d: Vector2i) -> void:
    var next := player + d
    if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows:
        return
    player = next
    for i in range(enemies.size()):
        if enemies[i] == player:
            start_combat(i)
            return
    for p in loot.duplicate():
        if p == player:
            loot.erase(p)
            ammo += 4
            xp += 15
            message = "Найдены патроны: +4."
            check_level()
            return
    message = "Перемещение."

func start_combat(i: int) -> void:
    combat = true
    enemy_index = i
    ap = max_ap
    combat_player = Vector2i(4, 4)
    combat_enemy = Vector2i(18, 4)
    target = "torso"
    message = "БОЙ. Выберите действие."

func handle_combat_tap(p: Vector2) -> void:
    if Rect2(20, 610, 170, 90).has_point(p):
        inventory_open = true
    elif Rect2(205, 610, 150, 90).has_point(p):
        shoot(2, 0.9, 82)
    elif Rect2(370, 610, 150, 90).has_point(p):
        shoot(3, 1.35, 68)
    elif Rect2(535, 610, 150, 90).has_point(p):
        melee()
    elif Rect2(700, 610, 130, 90).has_point(p):
        heal()
    elif Rect2(845, 610, 130, 90).has_point(p):
        end_turn()
    elif Rect2(990, 610, 130, 90).has_point(p):
        cycle_target()
    elif p.y >= 82 and p.y < 560:
        var c := Vector2i(floor((p - origin) / grid_size))
        move_combat(c)

func move_combat(c: Vector2i) -> void:
    if c == combat_enemy:
        message = "Клетка занята врагом."
        return
    var dist: int = abs(c.x - combat_player.x) + abs(c.y - combat_player.y)
    if dist == 0:
        return
    if dist > ap:
        message = "Нужно %d AP. Доступно %d." % [dist, ap]
        return
    combat_player = c
    ap -= dist
    message = "Перемещение: -%d AP." % dist

func chance(base: int) -> int:
    var d: int = abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    return clamp(base - d * 4, 10, 95)

func shoot(cost: int, mult: float, base: int) -> void:
    if ap < cost:
        message = "Недостаточно AP."
        return
    if ammo <= 0:
        message = "Нет патронов."
        return
    ammo -= 1
    ap -= cost
    var hit: int = chance(base)
    if rng.randi_range(1, 100) <= hit:
        var damage: int = int(20.0 * mult)
        if target == "head": damage = int(damage * 1.8)
        elif target == "arm" or target == "leg": damage = int(damage * 0.75)
        enemy_hp[enemy_index] -= damage
        message = "Попадание: %d урона. Шанс %d%%." % [damage, hit]
        if enemy_hp[enemy_index] <= 0:
            enemies[enemy_index] = Vector2i(-99, -99)
            xp += 50
            combat = false
            enemy_index = -1
            message = "ВРАГ УБИТ. +50 XP."
            check_level()
    else:
        message = "ПРОМАХ. Шанс %d%%." % hit

func melee() -> void:
    var d: int = abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    if d > 1:
        message = "Подойдите ближе."
        return
    if ap < 2:
        message = "Недостаточно AP."
        return
    ap -= 2
    if rng.randi_range(1, 100) <= 88:
        enemy_hp[enemy_index] -= 18
        message = "Удар: 18 урона."
        if enemy_hp[enemy_index] <= 0:
            enemies[enemy_index] = Vector2i(-99, -99)
            xp += 50
            combat = false
            enemy_index = -1
            message = "ВРАГ УБИТ. +50 XP."
            check_level()
    else:
        message = "Удар промахнулся."

func heal() -> void:
    if medkits <= 0:
        message = "Аптечек нет."
        return
    if combat and ap < 2:
        message = "Недостаточно AP."
        return
    medkits -= 1
    hp = min(100, hp + 40)
    if combat: ap -= 2
    message = "Лечение: +40 HP."

func end_turn() -> void:
    if not combat:
        return
    var d: int = abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    if d <= 1:
        hp -= 12
        message = "Враг атакует: -12 HP."
        if hp <= 0:
            hp = 0
            message = "ВЫ ПОГИБЛИ. Перезапустите игру."
    else:
        var dx: int = sign(combat_player.x - combat_enemy.x)
        var dy: int = sign(combat_player.y - combat_enemy.y)
        if abs(combat_player.x - combat_enemy.x) >= abs(combat_player.y - combat_enemy.y):
            combat_enemy.x += dx
        else:
            combat_enemy.y += dy
        message = "Враг переместился. Ваш ход."
    ap = max_ap

func cycle_target() -> void:
    if target == "torso": target = "head"
    elif target == "head": target = "arm"
    elif target == "arm": target = "leg"
    else: target = "torso"
    message = "Цель: %s." % target

func check_level() -> void:
    if xp >= level * 100:
        level += 1
        max_ap += 1
        ap = max_ap
        message = "УРОВЕНЬ %d! AP увеличены." % level

func _draw() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("111111"))
    if inventory_open:
        draw_inventory()
    elif combat:
        draw_combat()
    else:
        draw_world()

func draw_world() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(25, 35), "ПОСЛЕ КАТАСТРОФЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("eeeeee"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 62), message, HORIZONTAL_ALIGNMENT_LEFT, 1200, 18, Color("cccccc"))
    for y in range(rows):
        for x in range(cols):
            var r := Rect2(origin + Vector2(x, y) * grid_size, Vector2(grid_size - 2, grid_size - 2))
            draw_rect(r, Color("222222"))
            draw_rect(r, Color("383838"), false, 1)
    for p in loot:
        draw_circle(origin + Vector2(p.x + 0.5, p.y + 0.5) * grid_size, 11, Color("d3a52b"))
    for e in enemies:
        if e.x >= 0:
            draw_circle(origin + Vector2(e.x + 0.5, e.y + 0.5) * grid_size, 14, Color("a63c3c"))
    draw_circle(origin + Vector2(player.x + 0.5, player.y + 0.5) * grid_size, 14, Color("5b8fc7"))
    draw_button(Rect2(20, 460, 70, 70), "▲")
    draw_button(Rect2(20, 540, 70, 70), "◀")
    draw_button(Rect2(100, 540, 70, 70), "▶")
    draw_button(Rect2(60, 620, 70, 70), "▼")
    draw_button(Rect2(20, 630, 180, 70), "ИНВЕНТАРЬ")
    draw_string(ThemeDB.fallback_font, Vector2(225, 665), "HP %d/100   Патроны %d   Уровень %d   XP %d" % [hp, ammo, level, xp], HORIZONTAL_ALIGNMENT_LEFT, 900, 20, Color("dddddd"))

func draw_combat() -> void:
    draw_string(ThemeDB.fallback_font, Vector2(25, 35), "ТАКТИЧЕСКИЙ БОЙ", HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("eeeeee"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 62), "%s   HP %d/100   AP %d/%d   Патроны %d   Цель %s" % [message, hp, ap, max_ap, ammo, target], HORIZONTAL_ALIGNMENT_LEFT, 1200, 17, Color("cccccc"))
    for y in range(rows):
        for x in range(cols):
            var r := Rect2(origin + Vector2(x, y) * grid_size, Vector2(grid_size - 2, grid_size - 2))
            draw_rect(r, Color("252525"))
            draw_rect(r, Color("3b3b3b"), false, 1)
    draw_circle(origin + Vector2(combat_player.x + 0.5, combat_player.y + 0.5) * grid_size, 15, Color("5b8fc7"))
    draw_circle(origin + Vector2(combat_enemy.x + 0.5, combat_enemy.y + 0.5) * grid_size, 15, Color("a63c3c"))
    draw_button(Rect2(20, 610, 170, 90), "ИНВЕНТАРЬ")
    draw_button(Rect2(205, 610, 150, 90), "БЫСТРЫЙ")
    draw_button(Rect2(370, 610, 150, 90), "ПРИЦЕЛЬ")
    draw_button(Rect2(535, 610, 150, 90), "УДАР")
    draw_button(Rect2(700, 610, 130, 90), "ЛЕЧИТЬ")
    draw_button(Rect2(845, 610, 130, 90), "ХОД")
    draw_button(Rect2(990, 610, 130, 90), "ЦЕЛЬ")

func draw_inventory() -> void:
    draw_rect(Rect2(0, 0, 1280, 720), Color("151515"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 75), "ИНВЕНТАРЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("eeeeee"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 120), "Аптечки: %d    Патроны: %d    HP: %d/100" % [medkits, ammo, hp], HORIZONTAL_ALIGNMENT_LEFT, 700, 20, Color("cccccc"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 190), "Старый пистолет", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("eeeeee"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 235), "Урон 20   |   9 мм   |   обычное состояние", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bbbbbb"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 290), "Потрёпанная куртка", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("eeeeee"))
    draw_string(ThemeDB.fallback_font, Vector2(55, 335), "Защита 4   |   вес 1.5 кг", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("bbbbbb"))
    draw_button(Rect2(820, 530, 180, 70), "ЛЕЧИТЬ")
    draw_button(Rect2(1050, 35, 180, 60), "НАЗАД")

func draw_button(r: Rect2, text: String) -> void:
    draw_rect(r, Color("303030"))
    draw_rect(r, Color("777777"), false, 2)
    draw_string(ThemeDB.fallback_font, r.position + Vector2(12, r.size.y * 0.62), text, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24, 18, Color("eeeeee"))
