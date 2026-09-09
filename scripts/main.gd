extends Node2D

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
var rng := RandomNumberGenerator.new()

func _ready():
    rng.randomize()
    queue_redraw()

func _process(_delta):
    queue_redraw()

func _input(event):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        var p = event.position
        if combat:
            if Rect2(1030, 610, 210, 70).has_point(p): shoot()
            elif Rect2(800, 610, 210, 70).has_point(p): heal()
            elif Rect2(570, 610, 210, 70).has_point(p): end_turn()
        else:
            player_pos = player_pos.move_toward(p, 90)
            ap = max(0, ap - 1)
            check_interactions()

func check_interactions():
    for i in range(enemies.size()):
        if player_pos.distance_to(enemies[i]) < 85:
            combat = true
            selected_enemy = i
            message = "Противник замечен! Ваш ход."
            return
    for p in loot:
        if player_pos.distance_to(p) < 70:
            loot.erase(p)
            ammo += 4
            xp += 15
            message = "Найдено: 4 патрона."
            return
    if player_pos.distance_to(Vector2(640, 360)) < 80:
        ap = 6
        message = "Убежище: восстановлены очки действий."

func shoot():
    if ammo <= 0:
        message = "Нет патронов."
        return
    ammo -= 1
    ap = max(0, ap - 2)
    var chance = 65
    if rng.randi_range(1, 100) <= chance:
        var dmg = rng.randi_range(18, 32)
        enemy_hp[selected_enemy] -= dmg
        message = "Попадание! Урон: %d" % dmg
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
    hp = min(100, hp + 25)
    message = "Перевязка: +25 HP."
    enemy_turn()

func end_turn():
    enemy_turn()

func enemy_turn():
    if not combat:
        return
    var hit = rng.randi_range(1, 100) <= 55
    if hit:
        var dmg = rng.randi_range(8, 18)
        hp -= dmg
        message += " Враг наносит %d урона." % dmg
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
    draw_rect(Rect2(0, 0, 1280, 720), Color("171717"))
    # city blocks
    for x in range(0, 1280, 160):
        for y in range(70, 600, 130):
            draw_rect(Rect2(x + 8, y + 8, 135, 105), Color("303030"))
            draw_line(Vector2(x + 8, y + 8), Vector2(x + 143, y + 113), Color("454545"), 2)
    # roads
    draw_rect(Rect2(0, 320, 1280, 70), Color("222222"))
    draw_rect(Rect2(590, 70, 100, 530), Color("222222"))
    # shelter
    draw_circle(Vector2(640, 360), 42, Color("58705a"))
    draw_string(ThemeDB.fallback_font, Vector2(605, 355), "УБЕЖИЩЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
    # loot
    for p in loot:
        draw_circle(p, 15, Color("c2a44d"))
        draw_string(ThemeDB.fallback_font, p + Vector2(-18, 32), "ЛУТ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e6d58a"))
    # enemies
    for i in range(enemies.size()):
        if enemies[i].x > 0:
            draw_circle(enemies[i], 22, Color("8a3d3d"))
            draw_string(ThemeDB.fallback_font, enemies[i] + Vector2(-22, 38), "ВРАГ", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("d98b8b"))
    # player
    draw_circle(player_pos, 20, Color("6b8fb3"))
    # UI
    draw_rect(Rect2(0, 0, 1280, 70), Color("101010"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 30), "POST APOCALYPSE RPG", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
    draw_string(ThemeDB.fallback_font, Vector2(380, 29), "HP %d/100   AP %d   Патроны %d   LVL %d   XP %d" % [hp, ap, ammo, level, xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("d5d5d5"))
    draw_string(ThemeDB.fallback_font, Vector2(25, 650), message, HORIZONTAL_ALIGNMENT_LEFT, 900, 18, Color("eeeeee"))
    if combat:
        draw_rect(Rect2(0, 585, 1280, 135), Color("111111"))
        draw_string(ThemeDB.fallback_font, Vector2(25, 615), "ПОШАГОВЫЙ БОЙ", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("e8c9a0"))
        draw_button(Rect2(570, 610, 210, 70), "Завершить ход")
        draw_button(Rect2(800, 610, 210, 70), "Лечиться")
        draw_button(Rect2(1030, 610, 210, 70), "Стрелять")

func draw_button(rect: Rect2, text: String):
    draw_rect(rect, Color("353535"))
    draw_rect(rect, Color("777777"), false, 2)
    draw_string(ThemeDB.fallback_font, rect.position + Vector2(20, 42), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
