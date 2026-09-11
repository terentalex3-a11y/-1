extends Node2D

const GRID_COLS: int = 22
const GRID_ROWS: int = 10

var rng := RandomNumberGenerator.new()
var player := Vector2i(10, 5)
var enemies: Array[Vector2i] = [Vector2i(17, 3), Vector2i(6, 7)]
var loot: Array[Vector2i] = [Vector2i(4, 2), Vector2i(19, 7)]
var obstacles: Array[Vector2i] = [Vector2i(8, 2), Vector2i(9, 2), Vector2i(8, 3), Vector2i(14, 6), Vector2i(15, 6), Vector2i(14, 7), Vector2i(3, 6), Vector2i(4, 6)]

var hp: int = 100
var max_hp: int = 100
var ammo: int = 8
var xp: int = 0
var level: int = 1
var medkits: int = 2
var message: String = "Вы очнулись в разрушенном городе. Найдите припасы."

var combat: bool = false
var combat_enemy_index: int = -1
var combat_player := Vector2i(4, 5)
var combat_enemy := Vector2i(17, 5)
var combat_ap: int = 6
var combat_max_ap: int = 6
var enemy_hp: Array[int] = [55, 45]
var target_part: String = "torso"

var inventory_open: bool = false
var inventory_from_combat: bool = false
var joystick_active: bool = false
var joystick_touch_id: int = -1
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_last_dir := Vector2i.ZERO

func _ready() -> void:
    rng.randomize()
    get_window().mode = Window.MODE_FULLSCREEN
    get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    get_tree().root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
    get_viewport().size_changed.connect(_on_viewport_changed)
    queue_redraw()

func _on_viewport_changed() -> void:
    queue_redraw()

func _process(_delta: float) -> void:
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _touch_down(event.position, event.index)
        else:
            _touch_up(event.position, event.index)
    elif event is InputEventScreenDrag:
        _touch_drag(event.position, event.index)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_pointer(event.position)

func _touch_down(pos: Vector2, touch_id: int) -> void:
    if inventory_open:
        _handle_inventory_tap(pos)
        get_viewport().set_input_as_handled()
        return
    if combat:
        _handle_combat_tap(pos)
        get_viewport().set_input_as_handled()
        return
    if _world_button_rect("inventory").has_point(pos):
        inventory_open = true
        inventory_from_combat = false
        _reset_joystick()
        get_viewport().set_input_as_handled()
        queue_redraw()
        return
    var s := get_viewport_rect().size
    var zone := Rect2(0.0, s.y * 0.68, s.x * 0.42, s.y * 0.32)
    if zone.has_point(pos):
        joystick_active = true
        joystick_touch_id = touch_id
        joystick_center = Vector2(s.x * 0.14, s.y * 0.83)
        joystick_knob = joystick_center
        joystick_last_dir = Vector2i.ZERO
        get_viewport().set_input_as_handled()
        queue_redraw()

func _touch_drag(pos: Vector2, touch_id: int) -> void:
    if not joystick_active or touch_id != joystick_touch_id:
        return
    var delta := pos - joystick_center
    var radius := joystick_radius()
    if delta.length() > radius:
        delta = delta.normalized() * radius
    joystick_knob = joystick_center + delta
    if delta.length() > radius * 0.28:
        var dir := Vector2i.ZERO
        if abs(delta.x) >= abs(delta.y):
            dir.x = 1 if delta.x > 0.0 else -1
        else:
            dir.y = 1 if delta.y > 0.0 else -1
        if dir != joystick_last_dir:
            joystick_last_dir = dir
            move_world(dir)
    else:
        joystick_last_dir = Vector2i.ZERO
    get_viewport().set_input_as_handled()
    queue_redraw()

func _touch_up(_pos: Vector2, touch_id: int) -> void:
    if joystick_active and touch_id == joystick_touch_id:
        _reset_joystick()
        get_viewport().set_input_as_handled()
        queue_redraw()

func _handle_pointer(pos: Vector2) -> void:
    if inventory_open:
        _handle_inventory_tap(pos)
    elif combat:
        _handle_combat_tap(pos)
    else:
        if _world_button_rect("inventory").has_point(pos):
            inventory_open = true
            inventory_from_combat = false
            return
        var center := Vector2(get_viewport_rect().size.x * 0.14, get_viewport_rect().size.y * 0.83)
        var delta := pos - center
        if delta.length() > joystick_radius() * 0.25 and delta.length() < joystick_radius() * 1.8:
            if abs(delta.x) >= abs(delta.y):
                move_world(Vector2i(1 if delta.x > 0.0 else -1, 0))
            else:
                move_world(Vector2i(0, 1 if delta.y > 0.0 else -1))

func joystick_radius() -> float:
    var s := get_viewport_rect().size
    return clamp(min(s.x, s.y) * 0.11, 72.0, 118.0)

func move_world(direction: Vector2i) -> void:
    var next := player + direction
    if next.x < 0 or next.x >= GRID_COLS or next.y < 0 or next.y >= GRID_ROWS:
        message = "Дальше пройти нельзя."
        return
    if next in obstacles:
        message = "Путь перекрыт."
        return
    player = next
    for i in range(enemies.size()):
        if enemies[i] == player:
            start_combat(i)
            return
    for item_pos in loot.duplicate():
        if item_pos == player:
            loot.erase(item_pos)
            ammo += 4
            xp += 15
            message = "Найдены патроны 9 мм: +4."
            check_level()
            return
    message = "Перемещение."

func start_combat(index: int) -> void:
    combat = true
    combat_enemy_index = index
    combat_player = Vector2i(4, 5)
    combat_enemy = Vector2i(17, 5)
    combat_ap = combat_max_ap
    target_part = "torso"
    message = "КОНТАКТ — тактический бой"
    _reset_joystick()

func combat_grid_rect() -> Rect2:
    var s := get_viewport_rect().size
    return Rect2(26.0, 112.0, s.x - 52.0, max(300.0, s.y - 250.0))

func _handle_combat_tap(pos: Vector2) -> void:
    if _combat_button_rect("inventory").has_point(pos):
        inventory_open = true
        inventory_from_combat = true
        return
    if _combat_button_rect("quick").has_point(pos):
        shoot(2, 1.0, 82)
        return
    if _combat_button_rect("aim").has_point(pos):
        shoot(3, 1.35, 68)
        return
    if _combat_button_rect("melee").has_point(pos):
        melee()
        return
    if _combat_button_rect("heal").has_point(pos):
        heal()
        return
    if _combat_button_rect("end").has_point(pos):
        end_turn()
        return
    if _combat_button_rect("target").has_point(pos):
        cycle_target()
        return
    var r := combat_grid_rect()
    if not r.has_point(pos):
        return
    var cell_size := min(r.size.x / float(GRID_COLS), r.size.y / float(GRID_ROWS))
    var used := Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
    var origin := r.position + (r.size - used) * 0.5
    var cell := Vector2i(floor((pos - origin) / cell_size))
    if cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS:
        select_combat_destination(cell)

func select_combat_destination(cell: Vector2i) -> void:
    if cell == combat_enemy:
        message = "Клетка занята врагом."
        return
    if cell in obstacles:
        message = "Клетка занята укрытием."
        return
    if cell == combat_player:
        message = "Вы уже здесь."
        return
    var path := build_combat_path(combat_player, cell)
    if path.is_empty():
        message = "Маршрут недоступен."
        return
    var cost := max(0, path.size() - 1)
    if cost > combat_ap:
        message = "Нужно %d AP. Доступно: %d." % [cost, combat_ap]
        return
    combat_player = cell
    combat_ap -= cost
    message = "Перемещение: -%d AP" % cost

func build_combat_path(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
    var frontier: Array[Vector2i] = [start]
    var came_from: Dictionary = {start: start}
    var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
    while not frontier.is_empty():
        var current: Vector2i = frontier.pop_front()
        if current == goal:
            break
        for d in dirs:
            var next: Vector2i = current + d
            if next.x < 0 or next.x >= GRID_COLS or next.y < 0 or next.y >= GRID_ROWS:
                continue
            if next in obstacles or next == combat_enemy or came_from.has(next):
                continue
            came_from[next] = current
            frontier.append(next)
    if not came_from.has(goal):
        return []
    var path: Array[Vector2i] = []
    var cur := goal
    while cur != start:
        path.push_front(cur)
        cur = came_from[cur]
    path.push_front(start)
    return path

func chance(base: int) -> int:
    var distance := abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    var bonus := 0
    if target_part == "head":
        bonus = -18
    elif target_part == "arm" or target_part == "leg":
        bonus = -8
    return clamp(base - distance * 4 + bonus, 10, 95)

func shoot(cost: int, multiplier: float, base_chance: int) -> void:
    if combat_ap < cost:
        message = "Недостаточно AP."
        return
    if ammo <= 0:
        message = "Нет патронов."
        return
    ammo -= 1
    combat_ap -= cost
    var hit_chance := chance(base_chance)
    if rng.randi_range(1, 100) <= hit_chance:
        var damage := int(20.0 * multiplier)
        if target_part == "head":
            damage = int(damage * 1.8)
        elif target_part == "arm" or target_part == "leg":
            damage = int(damage * 0.75)
        enemy_hp[combat_enemy_index] -= damage
        message = "Попадание: %d урона. Шанс %d%%." % [damage, hit_chance]
        if enemy_hp[combat_enemy_index] <= 0:
            win_combat()
    else:
        message = "ПРОМАХ. Шанс %d%%." % hit_chance

func melee() -> void:
    var distance := abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    if distance > 1:
        message = "Подойдите к врагу на соседнюю клетку."
        return
    if combat_ap < 2:
        message = "Недостаточно AP."
        return
    combat_ap -= 2
    if rng.randi_range(1, 100) <= 88:
        enemy_hp[combat_enemy_index] -= 18
        message = "Удар: 18 урона."
        if enemy_hp[combat_enemy_index] <= 0:
            win_combat()
    else:
        message = "Удар промахнулся."

func heal() -> void:
    if medkits <= 0:
        message = "Аптечек нет."
        return
    if combat_ap < 2:
        message = "Недостаточно AP."
        return
    medkits -= 1
    hp = min(max_hp, hp + 40)
    combat_ap -= 2
    message = "Лечение: +40 HP."

func end_turn() -> void:
    var distance := abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    if distance <= 1:
        hp -= 12
        message = "Враг атакует: -12 HP."
    else:
        var dx := sign(combat_player.x - combat_enemy.x)
        var dy := sign(combat_player.y - combat_enemy.y)
        if abs(combat_player.x - combat_enemy.x) >= abs(combat_player.y - combat_enemy.y):
            combat_enemy.x += dx
        else:
            combat_enemy.y += dy
        message = "Враг переместился. Ваш ход."
    if hp <= 0:
        hp = 0
        message = "ВЫ ПОГИБЛИ."
    combat_ap = combat_max_ap

func cycle_target() -> void:
    if target_part == "torso":
        target_part = "head"
    elif target_part == "head":
        target_part = "arm"
    elif target_part == "arm":
        target_part = "leg"
    else:
        target_part = "torso"
    message = "Цель: %s" % target_part

func win_combat() -> void:
    xp += 50
    enemies[combat_enemy_index] = Vector2i(-99, -99)
    combat = false
    combat_enemy_index = -1
    message = "ВРАГ УБИТ. +50 XP. Осмотрите место."
    check_level()

func check_level() -> void:
    if xp >= level * 100:
        level += 1
        combat_max_ap += 1
        combat_ap = combat_max_ap
        message = "УРОВЕНЬ %d. Максимум AP увеличен." % level

func _handle_inventory_tap(pos: Vector2) -> void:
    var s := get_viewport_rect().size
    var back := Rect2(s.x - 190.0, 30.0, 160.0, 58.0)
    if back.has_point(pos):
        inventory_open = false
        message = "Возвращаемся."
        return
    var heal_rect := Rect2(s.x - 250.0, s.y - 112.0, 190.0, 64.0)
    if heal_rect.has_point(pos) and medkits > 0:
        medkits -= 1
        hp = min(max_hp, hp + 40)
        message = "Аптечка: +40 HP."

func _reset_joystick() -> void:
    joystick_active = false
    joystick_touch_id = -1
    joystick_last_dir = Vector2i.ZERO
    joystick_center = Vector2.ZERO
    joystick_knob = Vector2.ZERO

func _world_button_rect(_name: String) -> Rect2:
    var s := get_viewport_rect().size
    return Rect2(s.x - 238.0, s.y - 112.0, 210.0, 70.0)

func _combat_button_rect(name: String) -> Rect2:
    var s := get_viewport_rect().size
    var gap := 10.0
    var left := 24.0
    var widths := {"inventory": 160.0, "quick": 128.0, "aim": 128.0, "melee": 112.0, "heal": 112.0, "end": 112.0, "target": 112.0}
    var order := ["inventory", "quick", "aim", "melee", "heal", "end", "target"]
    var total := 864.0
    var available := max(520.0, s.x - 48.0 - gap * 6.0)
    var scale := min(1.0, available / total)
    var x := left
    for item in order:
        var w: float = widths[item] * scale
        if item == name:
            return Rect2(x, s.y - 86.0, w, 58.0)
        x += w + gap
    return Rect2()

func _draw() -> void:
    if inventory_open:
        draw_inventory()
    elif combat:
        draw_combat()
    else:
        draw_world()

func _font() -> Font:
    return ThemeDB.fallback_font

func label(text: String, pos: Vector2, size: int, alpha := 1.0) -> void:
    draw_string(_font(), pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.93, 0.93, 0.91, alpha))

func panel(rect: Rect2, fill: Color, border: Color, width := 2.0) -> void:
    draw_rect(rect, fill, true)
    draw_rect(rect, border, false, width)

func draw_world() -> void:
    var s := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, s), Color("101214"))
    draw_rect(Rect2(0, 0, s.x, 86), Color("171a1d"))
    label("ПОСЛЕ КАТАСТРОФЫ", Vector2(30, 38), 30)
    label("20 лет спустя • район 01", Vector2(31, 67), 16, 0.65)

    var grid := Rect2(28, 98, s.x - 56, max(310.0, s.y - 244))
    var cell := min(grid.size.x / float(GRID_COLS), grid.size.y / float(GRID_ROWS))
    var used := Vector2(cell * GRID_COLS, cell * GRID_ROWS)
    var origin := grid.position + (grid.size - used) * 0.5
    for y in range(GRID_ROWS):
        for x in range(GRID_COLS):
            var r := Rect2(origin + Vector2(x, y) * cell, Vector2(cell - 2, cell - 2))
            var shade := 0.12 + float((x * 7 + y * 3) % 4) * 0.012
            draw_rect(r, Color(0.10 + shade, 0.11 + shade, 0.11 + shade), true)
            draw_rect(r, Color(0.25, 0.26, 0.25, 0.45), false, 1.0)

    for o in obstacles:
        var rr := Rect2(origin + Vector2(o) * cell + Vector2(4, 4), Vector2(cell - 10, cell - 10))
        draw_rect(rr, Color("303638"), true)
        draw_rect(rr, Color("6a6e6a"), false, 2.0)
        draw_line(rr.position + Vector2(5, 5), rr.end - Vector2(5, 5), Color("555a56"), 2)
        draw_line(Vector2(rr.end.x - 5, rr.position.y + 5), Vector2(rr.position.x + 5, rr.end.y - 5), Color("555a56"), 2)

    for l in loot:
        var c := origin + (Vector2(l) + Vector2(0.5, 0.5)) * cell
        draw_rect(Rect2(c - Vector2(cell * 0.20, cell * 0.20), Vector2(cell * 0.40, cell * 0.40)), Color("c99a35"), true)
        label("+", c + Vector2(-7, 8), int(clamp(cell * 0.32, 14, 26)))

    for e in enemies:
        if e.x < 0:
            continue
        var c := origin + (Vector2(e) + Vector2(0.5, 0.5)) * cell
        draw_circle(c, cell * 0.30, Color("a8443f"))
        draw_circle(c, cell * 0.30, Color("e26b61"), false, 2.0)

    var pc := origin + (Vector2(player) + Vector2(0.5, 0.5)) * cell
    draw_circle(pc, cell * 0.31, Color("4f8fcf"))
    draw_circle(pc, cell * 0.31, Color("b9ddff"), false, 2.0)

    var hud_y := s.y - 126.0
    panel(Rect2(26, hud_y, s.x - 52, 92), Color(0.08, 0.09, 0.09, 0.96), Color(0.30, 0.32, 0.31), 2)
    label("HP", Vector2(48, hud_y + 32), 15, 0.65)
    draw_rect(Rect2(84, hud_y + 19, 190, 14), Color("252a2a"), true)
    draw_rect(Rect2(84, hud_y + 19, 190.0 * float(hp) / float(max_hp), 14), Color("78a65a"), true)
    label("%d / %d" % [hp, max_hp], Vector2(284, hud_y + 32), 15)
    label("9 ММ  %d" % ammo, Vector2(380, hud_y + 32), 18)
    label("УР. %d" % level, Vector2(505, hud_y + 32), 18)
    label("XP %d / %d" % [xp, level * 100], Vector2(605, hud_y + 32), 17, 0.75)
    label(message, Vector2(48, hud_y + 67), 16, 0.70)

    draw_joystick()
    var inv := _world_button_rect("inventory")
    panel(inv, Color(0.16, 0.18, 0.18, 0.98), Color("8c928e"), 2)
    label("ИНВЕНТАРЬ", inv.position + Vector2(38, 44), 19)

func draw_joystick() -> void:
    var s := get_viewport_rect().size
    if joystick_center == Vector2.ZERO:
        joystick_center = Vector2(s.x * 0.14, s.y * 0.83)
        joystick_knob = joystick_center
    var r := joystick_radius()
    draw_circle(joystick_center, r + 14, Color(0.04, 0.05, 0.05, 0.72))
    draw_circle(joystick_center, r, Color(0.20, 0.22, 0.22, 0.92))
    draw_circle(joystick_center, r, Color(0.60, 0.63, 0.61, 0.55), false, 3.0)
    draw_circle(joystick_knob, r * 0.43, Color(0.32, 0.55, 0.72, 0.98))
    draw_circle(joystick_knob, r * 0.43, Color(0.70, 0.84, 0.93), false, 2.0)
    label("ДВИЖЕНИЕ", joystick_center + Vector2(-48, r + 34), 13, 0.55)

func draw_combat() -> void:
    var s := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, s), Color("0e1011"))
    draw_rect(Rect2(0, 0, s.x, 92), Color("171a1d"))
    label("ТАКТИЧЕСКИЙ БОЙ", Vector2(30, 38), 29)
    label("AP %d / %d    Цель: %s" % [combat_ap, combat_max_ap, target_part], Vector2(32, 68), 17, 0.75)

    var r := combat_grid_rect()
    var cell := min(r.size.x / float(GRID_COLS), r.size.y / float(GRID_ROWS))
    var used := Vector2(cell * GRID_COLS, cell * GRID_ROWS)
    var origin := r.position + (r.size - used) * 0.5
    for y in range(GRID_ROWS):
        for x in range(GRID_COLS):
            var rr := Rect2(origin + Vector2(x, y) * cell, Vector2(cell - 2, cell - 2))
            draw_rect(rr, Color("202426"), true)
            draw_rect(rr, Color(0.30, 0.32, 0.31, 0.55), false, 1.0)
            if (x + y) % 5 == 0:
                draw_circle(rr.position + rr.size * 0.5, 2.0, Color(0.55, 0.57, 0.54, 0.18))
    for o in obstacles:
        var rr := Rect2(origin + Vector2(o) * cell + Vector2(3, 3), Vector2(cell - 8, cell - 8))
        draw_rect(rr, Color("3a403f"), true)
        draw_rect(rr, Color("7a807a"), false, 2)
    var pc := origin + (Vector2(combat_player) + Vector2(0.5, 0.5)) * cell
    var ec := origin + (Vector2(combat_enemy) + Vector2(0.5, 0.5)) * cell
    draw_circle(pc, cell * 0.30, Color("4f8fcf"))
    draw_circle(pc, cell * 0.30, Color("c4e0ff"), false, 2)
    draw_circle(ec, cell * 0.30, Color("a8443f"))
    draw_circle(ec, cell * 0.30, Color("ffaaa0"), false, 2)
    draw_rect(Rect2(ec + Vector2(-cell * 0.42, -cell * 0.58), Vector2(cell * 0.84, 7)), Color("242727"), true)
    draw_rect(Rect2(ec + Vector2(-cell * 0.42, -cell * 0.58), Vector2(cell * 0.84 * max(0.0, float(enemy_hp[combat_enemy_index]) / 55.0), 7)), Color("b44d45"), true)

    var bar := Rect2(24, s.y - 78, s.x - 48, 56)
    draw_rect(bar, Color(0.06, 0.07, 0.07, 0.98), true)
    var names := ["ИНВЕНТАРЬ", "ОГОНЬ", "ПРИЦЕЛ", "УДАР", "ЛЕЧИТЬ", "КОНЕЦ ХОДА", "ЦЕЛЬ"]
    var order := ["inventory", "quick", "aim", "melee", "heal", "end", "target"]
    for i in range(order.size()):
        var b := _combat_button_rect(order[i])
        panel(b, Color(0.15, 0.17, 0.17, 0.98), Color("737a76"), 2)
        var fs := 14 if b.size.x < 100 else 16
        label(names[i], b.position + Vector2(12, 37), fs)
    label(message, Vector2(30, 108), 14, 0.60)

func draw_inventory() -> void:
    var s := get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, s), Color("101214"))
    draw_rect(Rect2(0, 0, s.x, 100), Color("171a1d"))
    label("ИНВЕНТАРЬ", Vector2(34, 44), 32)
    label("Снаряжение • лечение • припасы", Vector2(36, 73), 15, 0.60)
    var back := Rect2(s.x - 190, 24, 160, 58)
    panel(back, Color(0.16, 0.18, 0.18, 1), Color("8c928e"), 2)
    label("НАЗАД", back.position + Vector2(40, 38), 17)

    var card1 := Rect2(34, 132, min(500.0, s.x * 0.43), 150)
    var card2 := Rect2(34, 300, min(500.0, s.x * 0.43), 150)
    panel(card1, Color("1a1e1f"), Color("4f5652"), 2)
    panel(card2, Color("1a1e1f"), Color("4f5652"), 2)
    label("СТАРЫЙ ПИСТОЛЕТ", card1.position + Vector2(22, 38), 21)
    label("9 ММ   •   УРОН 20", card1.position + Vector2(22, 72), 16, 0.70)
    label("Состояние: обычное", card1.position + Vector2(22, 105), 15, 0.55)
    label("ПОТРЁПАННАЯ КУРТКА", card2.position + Vector2(22, 38), 21)
    label("ЗАЩИТА 4   •   ВЕС 1.5 КГ", card2.position + Vector2(22, 72), 16, 0.70)
    label("Надета", card2.position + Vector2(22, 105), 15, 0.55)

    var stats := Rect2(s.x * 0.52, 132, s.x * 0.44, 190)
    panel(stats, Color("16191a"), Color("4f5652"), 2)
    label("СОСТОЯНИЕ", stats.position + Vector2(24, 38), 20)
    label("HP", stats.position + Vector2(24, 74), 15, 0.60)
    label("%d / %d" % [hp, max_hp], stats.position + Vector2(170, 74), 17)
    label("ПАТРОНЫ", stats.position + Vector2(24, 108), 15, 0.60)
    label("9 мм × %d" % ammo, stats.position + Vector2(170, 108), 17)
    label("АПТЕЧКИ", stats.position + Vector2(24, 142), 15, 0.60)
    label("× %d" % medkits, stats.position + Vector2(170, 142), 17)

    var heal_rect := Rect2(s.x - 250, s.y - 100, 190, 64)
    panel(heal_rect, Color("27342a"), Color("6e8e6e"), 2)
    label("ЛЕЧИТЬ +40", heal_rect.position + Vector2(34, 41), 17)
    label("Инвентарь не занимает управление движением", Vector2(34, s.y - 30), 14, 0.45)
