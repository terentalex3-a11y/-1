extends Node2D

const GRID_COLS: int = 22
const GRID_ROWS: int = 10

var rng := RandomNumberGenerator.new()

# World state
var player := Vector2i(10, 5)
var enemies: Array[Vector2i] = [Vector2i(17, 3), Vector2i(6, 7)]
var loot: Array[Vector2i] = [Vector2i(4, 2), Vector2i(19, 7)]
var hp: int = 100
var max_hp: int = 100
var ammo: int = 8
var xp: int = 0
var level: int = 1
var message: String = "Исследуйте район. Найдите припасы и избегайте лишнего шума."
var medkits: int = 2

# Combat state
var combat: bool = false
var combat_enemy_index: int = -1
var combat_player := Vector2i(4, 4)
var combat_enemy := Vector2i(17, 4)
var combat_ap: int = 6
var combat_max_ap: int = 6
var enemy_hp: Array[int] = [55, 45]
var target_part: String = "torso"
var combat_path: Array[Vector2i] = []
var combat_path_cost: int = 0

# UI state
var inventory_open: bool = false
var inventory_from_combat: bool = false
var joystick_active: bool = false
var joystick_touch_id: int = -1
var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_last_dir := Vector2i.ZERO

func _ready() -> void:
    rng.randomize()
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

    var s: Vector2 = get_viewport_rect().size
    var bottom_y: float = s.y * 0.76
    var joystick_area := Rect2(0.0, bottom_y, s.x * 0.42, s.y - bottom_y)
    if joystick_area.has_point(pos):
        joystick_active = true
        joystick_touch_id = touch_id
        joystick_center = Vector2(s.x * 0.17, s.y * 0.86)
        joystick_knob = joystick_center
        joystick_last_dir = Vector2i.ZERO
        get_viewport().set_input_as_handled()
        queue_redraw()
        return

    if _world_button_rect("inventory").has_point(pos):
        inventory_open = true
        inventory_from_combat = false
        get_viewport().set_input_as_handled()
        queue_redraw()

func _touch_drag(pos: Vector2, touch_id: int) -> void:
    if not joystick_active or touch_id != joystick_touch_id:
        return
    var delta: Vector2 = pos - joystick_center
    var radius: float = joystick_radius()
    if delta.length() > radius:
        delta = delta.normalized() * radius
    joystick_knob = joystick_center + delta

    if delta.length() > radius * 0.25:
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

func _touch_up(pos: Vector2, touch_id: int) -> void:
    if joystick_active and touch_id == joystick_touch_id:
        joystick_active = false
        joystick_touch_id = -1
        joystick_knob = joystick_center
        joystick_last_dir = Vector2i.ZERO
        get_viewport().set_input_as_handled()
        queue_redraw()

func _handle_pointer(pos: Vector2) -> void:
    if inventory_open:
        _handle_inventory_tap(pos)
    elif combat:
        _handle_combat_tap(pos)
    else:
        var center := Vector2(get_viewport_rect().size.x * 0.17, get_viewport_rect().size.y * 0.86)
        var delta := pos - center
        if delta.length() < joystick_radius() * 1.8 and delta.length() > joystick_radius() * 0.25:
            if abs(delta.x) >= abs(delta.y):
                move_world(Vector2i(1 if delta.x > 0.0 else -1, 0))
            else:
                move_world(Vector2i(0, 1 if delta.y > 0.0 else -1))
        elif _world_button_rect("inventory").has_point(pos):
            inventory_open = true
            inventory_from_combat = false

func joystick_radius() -> float:
    var s: Vector2 = get_viewport_rect().size
    return clamp(min(s.x, s.y) * 0.095, 64.0, 108.0)

func move_world(direction: Vector2i) -> void:
    var next := player + direction
    if next.x < 0 or next.x >= GRID_COLS or next.y < 0 or next.y >= GRID_ROWS:
        message = "Дальше пройти нельзя."
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
    combat_path.clear()
    combat_path_cost = 0
    message = "КОНТАКТ. Тактический бой."
    _reset_joystick()

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

    var grid_rect := combat_grid_rect()
    if grid_rect.has_point(pos):
        var cell_size: float = min(grid_rect.size.x / float(GRID_COLS), grid_rect.size.y / float(GRID_ROWS))
        var used_size := Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
        var grid_origin := grid_rect.position + (grid_rect.size - used_size) * 0.5
        var cell := Vector2i(floor((pos - grid_origin) / cell_size))
        if cell.x >= 0 and cell.x < GRID_COLS and cell.y >= 0 and cell.y < GRID_ROWS:
            select_combat_destination(cell)

func select_combat_destination(cell: Vector2i) -> void:
    if cell == combat_enemy:
        message = "Клетка занята врагом."
        return
    if cell == combat_player:
        combat_path.clear()
        combat_path_cost = 0
        return

    var path := build_combat_path(combat_player, cell)
    if path.is_empty():
        message = "Маршрут недоступен."
        return

    combat_path = path
    combat_path_cost = max(0, path.size() - 1)
    if combat_path_cost > combat_ap:
        message = "Маршрут: %d AP. Доступно: %d." % [combat_path_cost, combat_ap]
        return

    combat_player = cell
    combat_ap -= combat_path_cost
    message = "Перемещение: -%d AP." % combat_path_cost
    combat_path.clear()
    combat_path_cost = 0

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
            if next == combat_enemy:
                continue
            if came_from.has(next):
                continue
            came_from[next] = current
            frontier.append(next)

    if not came_from.has(goal):
        return []

    var path: Array[Vector2i] = []
    var cur: Vector2i = goal
    while cur != start:
        path.push_front(cur)
        cur = came_from[cur]
    path.push_front(start)
    return path

func chance(base: int) -> int:
    var distance: int = abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    var target_bonus: int = 0
    if target_part == "head":
        target_bonus = -18
    elif target_part == "arm" or target_part == "leg":
        target_bonus = -8
    return clamp(base - distance * 4 + target_bonus, 10, 95)

func shoot(cost: int, multiplier: float, base_chance: int) -> void:
    if combat_ap < cost:
        message = "Недостаточно AP."
        return
    if ammo <= 0:
        message = "Нет патронов."
        return

    ammo -= 1
    combat_ap -= cost
    var hit_chance: int = chance(base_chance)
    if rng.randi_range(1, 100) <= hit_chance:
        var damage: int = int(20.0 * multiplier)
        if target_part == "head":
            damage = int(damage * 1.8)
        elif target_part == "arm" or target_part == "leg":
            damage = int(damage * 0.75)
        enemy_hp[combat_enemy_index] -= damage
        message = "Попадание в %s: %d урона. Шанс %d%%." % [target_part, damage, hit_chance]
        if enemy_hp[combat_enemy_index] <= 0:
            win_combat()
    else:
        message = "ПРОМАХ. Шанс %d%%." % hit_chance

func melee() -> void:
    var distance: int = abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
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
    var distance: int = abs(combat_player.x - combat_enemy.x) + abs(combat_player.y - combat_enemy.y)
    if distance <= 1:
        hp -= 12
        message = "Враг атакует: -12 HP."
    else:
        var dx: int = sign(combat_player.x - combat_enemy.x)
        var dy: int = sign(combat_player.y - combat_enemy.y)
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
    message = "Цель: %s." % target_part

func win_combat() -> void:
    xp += 50
    combat = false
    enemies[combat_enemy_index] = Vector2i(-99, -99)
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
    var s: Vector2 = get_viewport_rect().size
    if Rect2(s.x - 190.0, 28.0, 160.0, 58.0).has_point(pos):
        inventory_open = false
        message = "Возвращаемся."
        return

    var heal_rect := Rect2(s.x * 0.68, s.y - 150.0, 190.0, 70.0)
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

func _world_button_rect(name: String) -> Rect2:
    var s: Vector2 = get_viewport_rect().size
    if name == "inventory":
        return Rect2(s.x - 210.0, s.y - 112.0, 180.0, 72.0)
    return Rect2()

func _combat_button_rect(name: String) -> Rect2:
    var s: Vector2 = get_viewport_rect().size
    var y: float = s.y - 92.0
    var gap: float = 10.0
    var left: float = 18.0
    var widths := {
        "inventory": 155.0,
        "quick": 128.0,
        "aim": 128.0,
        "melee": 112.0,
        "heal": 112.0,
        "end": 112.0,
        "target": 112.0
    }
    var order := ["inventory", "quick", "aim", "melee", "heal", "end", "target"]
    var total_width: float = 859.0
    var available: float = max(320.0, s.x - 36.0 - gap * 6.0)
    var scale: float = min(1.0, available / total_width)
    var x: float = left
    for key in order:
        var w: float = float(widths[key]) * scale
        if key == name:
            return Rect2(x, y, w, 68.0)
        x += w + gap
    return Rect2()

func world_grid_rect() -> Rect2:
    var s: Vector2 = get_viewport_rect().size
    return Rect2(26.0, 76.0, s.x - 52.0, s.y * 0.60)

func combat_grid_rect() -> Rect2:
    var s: Vector2 = get_viewport_rect().size
    return Rect2(26.0, 82.0, s.x - 52.0, s.y * 0.64)

func _draw() -> void:
    var s: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, s), Color("0b0d0e"))
    if inventory_open:
        draw_inventory()
    elif combat:
        draw_combat()
    else:
        draw_world()

func draw_header(title: String, subtitle: String) -> void:
    var s: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(0, 0, s.x, 68.0), Color("121618"))
    draw_line(Vector2(0, 67), Vector2(s.x, 67), Color("3b4548"), 1.0)
    draw_string(ThemeDB.fallback_font, Vector2(28, 34), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 27, Color("f1f1ec"))
    draw_string(ThemeDB.fallback_font, Vector2(28, 57), subtitle, HORIZONTAL_ALIGNMENT_LEFT, s.x - 56, 16, Color("aeb7b8"))

func draw_world() -> void:
    var s: Vector2 = get_viewport_rect().size
    draw_header("ПОСЛЕ КАТАСТРОФЫ", message)

    var grid := world_grid_rect()
    var cell_size: float = min(grid.size.x / float(GRID_COLS), grid.size.y / float(GRID_ROWS))
    var used := Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
    var start := grid.position + (grid.size - used) * 0.5

    draw_rect(Rect2(start - Vector2(8, 8), used + Vector2(16, 16)), Color("15191a"))
    for y in range(GRID_ROWS):
        for x in range(GRID_COLS):
            var cell_rect := Rect2(start + Vector2(x, y) * cell_size, Vector2(cell_size - 3, cell_size - 3))
            var shade := Color("1c2223") if (x + y) % 2 == 0 else Color("202627")
            draw_rect(cell_rect, shade)
            draw_rect(cell_rect, Color("343d3f"), false, 1.0)

    for p in [Vector2i(8, 3), Vector2i(9, 3), Vector2i(8, 4), Vector2i(15, 7), Vector2i(16, 7)]:
        var r := Rect2(start + Vector2(p) * cell_size + Vector2(8, 8), Vector2(cell_size - 19, cell_size - 19))
        draw_rect(r, Color("3b3530"))
        draw_line(r.position + Vector2(6, 6), r.end - Vector2(6, 6), Color("554b43"), 2.0)

    for p in loot:
        var center := start + (Vector2(p) + Vector2(0.5, 0.5)) * cell_size
        draw_circle(center, min(13.0, cell_size * 0.22), Color("d2a83d"))
        draw_circle(center, min(7.0, cell_size * 0.11), Color("f1d477"))

    for e in enemies:
        if e.x >= 0:
            var center := start + (Vector2(e) + Vector2(0.5, 0.5)) * cell_size
            draw_circle(center, min(16.0, cell_size * 0.26), Color("a94545"))
            draw_circle(center, min(9.0, cell_size * 0.15), Color("d66a5f"))

    var pc := start + (Vector2(player) + Vector2(0.5, 0.5)) * cell_size
    draw_circle(pc, min(17.0, cell_size * 0.27), Color("4e8ac5"))
    draw_circle(pc, min(9.0, cell_size * 0.15), Color("a8d0ef"))

    draw_world_hud()
    draw_joystick()

func draw_world_hud() -> void:
    var s: Vector2 = get_viewport_rect().size
    var y: float = s.y - 98.0
    draw_rect(Rect2(0, y - 12.0, s.x, s.y - y + 12.0), Color("111516"))
    draw_string(ThemeDB.fallback_font, Vector2(28, y + 20), "HP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9fa8aa"))
    draw_string(ThemeDB.fallback_font, Vector2(28, y + 48), "%d / %d" % [hp, max_hp], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e4e6e2"))
    draw_string(ThemeDB.fallback_font, Vector2(145, y + 20), "ПАТРОНЫ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9fa8aa"))
    draw_string(ThemeDB.fallback_font, Vector2(145, y + 48), str(ammo), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e4e6e2"))
    draw_string(ThemeDB.fallback_font, Vector2(240, y + 20), "УРОВЕНЬ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9fa8aa"))
    draw_string(ThemeDB.fallback_font, Vector2(240, y + 48), str(level), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e4e6e2"))
    draw_string(ThemeDB.fallback_font, Vector2(320, y + 20), "XP", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("9fa8aa"))
    draw_string(ThemeDB.fallback_font, Vector2(320, y + 48), str(xp), HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e4e6e2"))
    draw_button(_world_button_rect("inventory"), "ИНВЕНТАРЬ", Color("2b3031"))

func draw_joystick() -> void:
    if joystick_center == Vector2.ZERO:
        var s: Vector2 = get_viewport_rect().size
        joystick_center = Vector2(s.x * 0.17, s.y * 0.86)
        joystick_knob = joystick_center
    var radius := joystick_radius()
    draw_circle(joystick_center, radius, Color(0.08, 0.10, 0.10, 0.92))
    draw_circle(joystick_center, radius, Color("667073"), false, 3.0)
    draw_circle(joystick_center, radius * 0.55, Color("252b2c"), false, 2.0)
    draw_circle(joystick_knob, radius * 0.38, Color("4e6874"))
    draw_circle(joystick_knob, radius * 0.38, Color("9caeb4"), false, 2.0)
    draw_string(ThemeDB.fallback_font, joystick_center + Vector2(-47, radius + 27), "ДВИЖЕНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("9fa8aa"))

func draw_combat() -> void:
    draw_header("ТАКТИЧЕСКИЙ БОЙ", "%s    HP %d/%d    AP %d/%d    Патроны %d    Цель: %s" % [message, hp, max_hp, combat_ap, combat_max_ap, ammo, target_part])

    var grid := combat_grid_rect()
    var cell_size: float = min(grid.size.x / float(GRID_COLS), grid.size.y / float(GRID_ROWS))
    var used := Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
    var start := grid.position + (grid.size - used) * 0.5

    draw_rect(Rect2(start - Vector2(8, 8), used + Vector2(16, 16)), Color("14191a"))
    for y in range(GRID_ROWS):
        for x in range(GRID_COLS):
            var cell_rect := Rect2(start + Vector2(x, y) * cell_size, Vector2(cell_size - 3, cell_size - 3))
            draw_rect(cell_rect, Color("222829"))
            draw_rect(cell_rect, Color("465052"), false, 1.0)

    for y in range(GRID_ROWS):
        for x in range(GRID_COLS):
            var d: int = abs(x - combat_player.x) + abs(y - combat_player.y)
            if d > 0 and d <= combat_ap:
                var rr := Rect2(start + Vector2(x, y) * cell_size + Vector2(3, 3), Vector2(cell_size - 9, cell_size - 9))
                draw_rect(rr, Color(0.25, 0.38, 0.45, 0.22))

    for p in combat_path:
        var pr := Rect2(start + Vector2(p) * cell_size + Vector2(7, 7), Vector2(cell_size - 17, cell_size - 17))
        draw_rect(pr, Color(0.78, 0.63, 0.25, 0.45))

    var pc := start + (Vector2(combat_player) + Vector2(0.5, 0.5)) * cell_size
    var ec := start + (Vector2(combat_enemy) + Vector2(0.5, 0.5)) * cell_size
    draw_circle(pc, min(18.0, cell_size * 0.28), Color("4e8ac5"))
    draw_circle(pc, min(10.0, cell_size * 0.16), Color("b5d6ed"))
    draw_circle(ec, min(18.0, cell_size * 0.28), Color("a94545"))
    draw_circle(ec, min(10.0, cell_size * 0.16), Color("e07868"))

    var enemy_bar := Rect2(ec.x - 28, ec.y - cell_size * 0.43, 56, 6)
    draw_rect(enemy_bar, Color("432b2b"))
    draw_rect(Rect2(enemy_bar.position, Vector2(56.0 * clamp(float(enemy_hp[combat_enemy_index]) / 55.0, 0.0, 1.0), 6)), Color("b74e4e"))

    var action_names := ["ИНВЕНТАРЬ", "БЫСТРЫЙ", "ПРИЦЕЛ", "УДАР", "ЛЕЧИТЬ", "ХОД", "ЦЕЛЬ"]
    var action_keys := ["inventory", "quick", "aim", "melee", "heal", "end", "target"]
    for i in range(action_names.size()):
        var rect := _combat_button_rect(action_keys[i])
        draw_button(rect, action_names[i], Color("2a3031"))
        if i == 1:
            draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 55), "2 AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8d999b"))
        elif i == 2:
            draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 55), "3 AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8d999b"))
        elif i == 3 or i == 4:
            draw_string(ThemeDB.fallback_font, rect.position + Vector2(10, 55), "2 AP", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("8d999b"))

func draw_inventory() -> void:
    var s: Vector2 = get_viewport_rect().size
    draw_rect(Rect2(Vector2.ZERO, s), Color("0d1011"))
    draw_header("ИНВЕНТАРЬ", "Снаряжение и лечение")
    draw_button(Rect2(s.x - 190.0, 28.0, 160.0, 58.0), "НАЗАД", Color("2a3031"))

    var panel := Rect2(34, 102, s.x - 68, s.y - 140)
    draw_rect(panel, Color("171d1e"))
    draw_rect(panel, Color("3c4648"), false, 1.5)

    draw_string(ThemeDB.fallback_font, Vector2(58, 145), "СНАРЯЖЕНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8e8e2"))
    draw_string(ThemeDB.fallback_font, Vector2(58, 177), "Вес    2.7 кг / 18 кг", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("9fa8aa"))
    draw_item_card(Rect2(58, 210, min(420.0, s.x * 0.38), 112), "СТАРЫЙ ПИСТОЛЕТ", "Урон 20   |   9 мм   |   состояние 72%", Color("c8a75a"))
    draw_item_card(Rect2(58, 340, min(420.0, s.x * 0.38), 112), "ПОТРЁПАННАЯ КУРТКА", "Защита 4   |   вес 1.5 кг", Color("8d9a9c"))

    draw_string(ThemeDB.fallback_font, Vector2(s.x * 0.52, 145), "РАСХОДНИКИ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8e8e2"))
    draw_string(ThemeDB.fallback_font, Vector2(s.x * 0.52, 180), "Аптечки: %d" % medkits, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d0d5d1"))
    draw_string(ThemeDB.fallback_font, Vector2(s.x * 0.52, 212), "Патроны 9 мм: %d" % ammo, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d0d5d1"))
    draw_button(Rect2(s.x * 0.68, s.y - 150.0, 190.0, 70.0), "ЛЕЧИТЬ", Color("303638"))

func draw_item_card(rect: Rect2, title: String, details: String, accent: Color) -> void:
    draw_rect(rect, Color("202627"))
    draw_rect(Rect2(rect.position, Vector2(5, rect.size.y)), accent)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 36), title, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 35, 19, Color("ecece6"))
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 70), details, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 35, 15, Color("aeb6b7"))

func draw_button(rect: Rect2, label: String, fill: Color = Color("292e2f")) -> void:
    draw_rect(rect, fill)
    draw_rect(rect, Color("667073"), false, 2.0)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(12, rect.size.y * 0.58), label, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 24, 16, Color("e7e8e4"))
