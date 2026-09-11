extends Node2D

var state: Node
var inventory_screen: Control
var mobile_controls: Control
var rng := RandomNumberGenerator.new()
var grid_size := 48.0
var world_origin := Vector2(48, 96)
var world_cols := 24
var world_rows := 10
var player_cell := Vector2i(12, 5)
var enemies := [Vector2i(17, 4), Vector2i(7, 8)]
var loot := [Vector2i(5, 3), Vector2i(20, 8)]
var hp := 100
var max_hp := 100
var ap := 6
var max_ap := 6
var ammo := 8
var level := 1
var xp := 0
var combat := false
var selected_enemy := -1
var enemy_hp := [55, 45]
var combat_player_cell := Vector2i(4, 5)
var combat_enemy_cell := Vector2i(18, 5)
var combat_covers := [Vector2i(9,3),Vector2i(10,3),Vector2i(13,7),Vector2i(14,7),Vector2i(16,3)]
var combat_selected_target := "torso"
var defensive_stance := false
var combat_path: Array[Vector2i] = []
var combat_path_cost := 0
var message := "Вы очнулись в разрушенном городе. Найдите припасы."
var wounds := {"head":0,"torso":0,"arm":0,"leg":0}
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

func _process(_delta):
    queue_redraw()

func _input(event):
    if inventory_screen.visible or game_over:
        return
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        handle_pointer(to_world_point(event.position))
    elif event is InputEventScreenTouch and event.pressed:
        handle_pointer(to_world_point(event.position))

func to_world_point(p: Vector2) -> Vector2:
    var s := get_viewport_rect().size
    return Vector2(p.x / max(0.01,s.x/1280.0), p.y / max(0.01,s.y/720.0))

func handle_pointer(p: Vector2):
    if Rect2(20,610,190,95).has_point(p):
        open_inventory(); return
    if combat:
        handle_combat_pointer(p); return
    if p.y >= world_origin.y and p.y < world_origin.y + world_rows*grid_size:
        move_world_to_cell(world_to_cell(p))

func on_mobile_move(direction: Vector2):
    if combat or game_over:
        return
    var d := Vector2i(round(direction.x),round(direction.y))
    if d == Vector2i.ZERO:
        return
    move_world_to_cell(player_cell + d)

func on_mobile_action(action: String):
    match action:
        "inventory": open_inventory()
        "shoot": quick_shot()
        "heal": heal()
        "end_turn": end_turn()

func world_to_cell(p: Vector2) -> Vector2i:
    return Vector2i(floor((p-world_origin)/grid_size))

func cell_to_world(c: Vector2i) -> Vector2:
    return world_origin + Vector2(c)*grid_size + Vector2(grid_size/2,grid_size/2)

func valid_world_cell(c: Vector2i) -> bool:
    return c.x >= 0 and c.x < world_cols and c.y >= 0 and c.y < world_rows

func move_world_to_cell(target: Vector2i):
    if not valid_world_cell(target): return
    var dx := target.x-player_cell.x
    var dy := target.y-player_cell.y
    if abs(dx)+abs(dy) != 1:
        message = "Двигайтесь по соседним клеткам."
        return
    player_cell = target
    check_interactions()

func check_interactions():
    for i in range(enemies.size()):
        if enemies[i] == player_cell:
            start_combat(i); return
    for p in loot.duplicate():
        if p == player_cell:
            loot.erase(p)
            state.add_item({"name":"Найденные патроны","type":"ammo","amount":4,"weight":0.15,"count":1})
            ammo += 4; xp += 15
            message = "Найдено: 4 патрона."; check_level(); return
    if player_cell == Vector2i(12,5):
        message = "Убежище. Здесь можно управлять запасами."

func start_combat(enemy_index:int):
    combat=true; selected_enemy=enemy_index; ap=max_ap; defensive_stance=false
    combat_player_cell=Vector2i(4,5); combat_enemy_cell=Vector2i(18,5)
    combat_selected_target="torso"; combat_path.clear(); combat_path_cost=0
    message="БОЙ! Тапните по клетке назначения — путь покажет расход AP."
    mobile_controls.set_mobile_mode(false)

func finish_combat(victory:bool):
    combat=false; selected_enemy=-1; ap=max_ap; defensive_stance=false
    combat_path.clear(); combat_path_cost=0
    mobile_controls.set_mobile_mode(true)
    if victory: message="ВРАГ УБИТ. +50 XP."
    check_level()

func combat_cell_valid(c:Vector2i)->bool:
    return c.x>=0 and c.x<24 and c.y>=0 and c.y<10

func combat_cover_at(c:Vector2i)->bool:
    return combat_covers.has(c)

func combat_cell_blocked(c:Vector2i)->bool:
    return c==combat_enemy_cell or combat_cover_at(c)

func build_combat_path(target:Vector2i) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    if not combat_cell_valid(target) or target==combat_player_cell or target==combat_enemy_cell:
        return result
    var current:=combat_player_cell
    var guard:=0
    while current!=target and guard<240:
        guard+=1
        var candidates: Array[Vector2i] = []
        var dx:=target.x-current.x
        var dy:=target.y-current.y
        if abs(dx)>=abs(dy) and dx!=0:
            candidates.append(current+Vector2i(sign(dx),0))
        if dy!=0:
            candidates.append(current+Vector2i(0,sign(dy)))
        if dx!=0 and abs(dx)<abs(dy):
            candidates.append(current+Vector2i(sign(dx),0))
        var moved:=false
        for c in candidates:
            if combat_cell_valid(c) and not combat_cell_blocked(c):
                current=c; result.append(c); moved=true; break
        if not moved: return []
    if current!=target: return []
    return result

func select_combat_destination(target:Vector2i):
    combat_path=build_combat_path(target)
    combat_path_cost=combat_path.size()
    if combat_path.is_empty():
        if target==combat_enemy_cell:
            message="Клетка занята врагом."
        elif target==combat_player_cell:
            message="Вы уже на этой клетке."
        else:
            message="Путь сюда заблокирован."
        return
    if combat_path_cost>ap:
        message="Путь: %d AP. Доступно: %d AP."%[combat_path_cost,ap]
        return
    for c in combat_path:
        combat_player_cell=c
        ap-=1
    defensive_stance=false
    message="Перемещение: -%d AP. Осталось %d AP. %s"%[combat_path_cost,ap,"УКРЫТИЕ." if combat_cover_at(combat_player_cell) else "Открытая позиция."]
    combat_path.clear(); combat_path_cost=0

func move_in_combat(target:Vector2i):
    select_combat_destination(target)

func handle_combat_pointer(p:Vector2):
    if Rect2(20,610,190,95).has_point(p): open_inventory(); return
    if Rect2(205,610,145,95).has_point(p): quick_shot(); return
    if Rect2(355,610,145,95).has_point(p): aimed_shot(); return
    if Rect2(505,610,145,95).has_point(p): melee_attack(); return
    if Rect2(655,610,125,95).has_point(p): heal(); return
    if Rect2(785,610,125,95).has_point(p): defend(); return
    if Rect2(915,610,165,95).has_point(p): end_turn(); return
    if Rect2(1085,610,175,95).has_point(p): cycle_target(); return
    if p.y>=90 and p.y<585:
        move_in_combat(world_to_cell(p))

func cycle_target():
    var targets=["torso","head","arm","leg"]
    combat_selected_target=targets[(targets.find(combat_selected_target)+1)%targets.size()]
    message="Цель: %s" % target_name(combat_selected_target)

func target_name(part:String)->String:
    match part:
        "head": return "ГОЛОВА"
        "arm": return "РУКА"
        "leg": return "НОГА"
    return "КОРПУС"

func attack_chance(base:int)->int:
    var d:=abs(combat_player_cell.x-combat_enemy_cell.x)+abs(combat_player_cell.y-combat_enemy_cell.y)
    var chance:=base-d*4
    if combat_cover_at(combat_player_cell): chance+=10
    if combat_cover_at(combat_enemy_cell): chance-=25
    if wounds.arm>=20: chance-=15
    return clamp(chance,10,95)

func do_shot(cost:int,mult:float,base:int,label:String):
    if not combat or selected_enemy<0:return
    if ap<cost: message="Недостаточно AP."; return
    if ammo<=0: message="Нет патронов."; return
    ammo-=1; ap-=cost; defensive_stance=false
    var chance:=attack_chance(base)
    if rng.randi_range(1,100)<=chance:
        var weapon_damage:=20
        if state.equipped_weapon>=0 and state.equipped_weapon<state.inventory.size():
            weapon_damage=int(state.inventory[state.equipped_weapon].get("damage",20))
        var result:Dictionary=preload("res://scripts/combat_system.gd").body_damage(combat_selected_target,int(weapon_damage*mult))
        var dealt:=int(result.get("damage",weapon_damage)); enemy_hp[selected_enemy]-=dealt
        message="%s: %s — %d урона. Шанс %d%%. AP %d."%[label,target_name(combat_selected_target),dealt,chance,ap]
        if enemy_hp[selected_enemy]<=0:
            xp+=50; enemies[selected_enemy]=Vector2i(-99,-99); finish_combat(true)
    else: message="%s: ПРОМАХ. Шанс %d%%. AP %d."%[label,chance,ap]

func quick_shot(): do_shot(2,0.9,82,"БЫСТРЫЙ ВЫСТРЕЛ")
func aimed_shot(): do_shot(3,1.35,68,"ПРИЦЕЛЬНЫЙ ВЫСТРЕЛ")

func melee_attack():
    if not combat:return
    var d:=abs(combat_player_cell.x-combat_enemy_cell.x)+abs(combat_player_cell.y-combat_enemy_cell.y)
    if d>1: message="Для удара подойдите на соседнюю клетку."; return
    if ap<2: message="Недостаточно AP."; return
    ap-=2; defensive_stance=false
    if rng.randi_range(1,100)<=88:
        var result:Dictionary=preload("res://scripts/combat_system.gd").body_damage(combat_selected_target,18)
        var dealt:=int(result.get("damage",18)); enemy_hp[selected_enemy]-=dealt
        message="УДАР: %s — %d урона. AP %d."%[target_name(combat_selected_target),dealt,ap]
        if enemy_hp[selected_enemy]<=0:
            xp+=50; enemies[selected_enemy]=Vector2i(-99,-99); finish_combat(true)
    else: message="УДАР ПРОМАХНУЛСЯ. AP %d."%ap

func defend():
    if not combat:return
    if ap<1: message="Недостаточно AP."; return
    ap-=1; defensive_stance=true
    message="ОБОРОНА: урон следующей атаки врага снижен на 50%. AP %d."%ap

func end_turn():
    if not combat: message="В мире ход не нужен."; return
    message="Ход завершён. Враг действует..."; enemy_turn()

func enemy_turn():
    if not combat:return
    var d:=abs(combat_player_cell.x-combat_enemy_cell.x)+abs(combat_player_cell.y-combat_enemy_cell.y)
    if d>1:
        var candidates=[combat_enemy_cell+Vector2i(sign(combat_player_cell.x-combat_enemy_cell.x),0),combat_enemy_cell+Vector2i(0,sign(combat_player_cell.y-combat_enemy_cell.y))]
        for c in candidates:
            if combat_cell_valid(c) and c!=combat_player_cell and not combat_cover_at(c):
                combat_enemy_cell=c; break
        d=abs(combat_player_cell.x-combat_enemy_cell.x)+abs(combat_player_cell.y-combat_enemy_cell.y)
    if d<=1:
        var dmg=12
        if defensive_stance:dmg=6
        hp-=dmg; message="Враг атакует: -%d HP. Ваш ход."%dmg
        if hp<=0: hp=0; game_over=true; message="ВЫ ПОГИБЛИ. Перезапустите игру."
    ap=max_ap; defensive_stance=false

func heal():
    if combat and ap<2: message="Недостаточно AP для лечения."; return
    var i=find_medical()
    if i<0:return
    use_item(i)
    if combat: ap-=2; message="Лечение: -2 AP. Осталось %d AP."%ap

func find_medical()->int:
    for i in range(state.inventory.size()):
        if state.inventory[i].get("type","")=="medical":return i
    message="Медицинских предметов нет."; return -1

func use_item(index:int):
    if index<0 or index>=state.inventory.size():return
    var item:Dictionary=state.inventory[index]
    if item.get("type","")!="medical": message="Этот предмет нельзя использовать сейчас."; return
    var old:=hp; hp=min(max_hp,hp+int(item.get("heal",25)))
    var count:=int(item.get("count",1))
    if count>1:item["count"]=count-1
    else:state.inventory.remove_at(index)
    message="%s: +%d HP."%[str(item.get("name","Медикамент")),hp-old]
    inventory_screen.setup(state.inventory,state.body_armor)

func equip_item(index:int):
    if index<0 or index>=state.inventory.size():return
    var item:Dictionary=state.inventory[index]
    if item.get("type","")=="weapon":
        state.equipped_weapon=index; ammo=int(item.get("ammo",ammo)); message="Оружие экипировано: %s."%item.get("name","оружие")

func open_inventory():
    inventory_screen.setup(state.inventory,state.body_armor); inventory_screen.visible=true; mobile_controls.set_mobile_mode(false); message="Инвентарь открыт."
func close_inventory():
    inventory_screen.visible=false; mobile_controls.set_mobile_mode(not combat); message="Инвентарь закрыт."

func check_level():
    while xp>=level*100:
        level+=1; max_ap+=1; ap=max_ap; message="УРОВЕНЬ %d! AP увеличены."%level

func _draw():
    if combat: draw_combat()
    else: draw_world()
    if not inventory_screen.visible: draw_hud()

func draw_world():
    draw_rect(Rect2(0,0,1280,720),Color("151515"))
    for y in range(world_rows):
        for x in range(world_cols):
            var r:=Rect2(world_origin+Vector2(x,y)*grid_size,Vector2(grid_size-2,grid_size-2))
            draw_rect(r,Color("222222")); draw_rect(r,Color("303030"),false,1)
    for c in loot: draw_circle(cell_to_world(c),12,Color("d4a62a"))
    for c in enemies:
        if c.x>=0: draw_circle(cell_to_world(c),15,Color("a53a3a"))
    draw_circle(cell_to_world(player_cell),15,Color("5c91c9"))
    draw_string(ThemeDB.fallback_font,Vector2(25,40),"МИР — клеточное перемещение | шаг = 1 клетка",HORIZONTAL_ALIGNMENT_LEFT,700,24,Color("dddddd"))
    draw_string(ThemeDB.fallback_font,Vector2(25,70),message,HORIZONTAL_ALIGNMENT_LEFT,1200,20,Color("c8c8c8"))

func draw_combat():
    draw_rect(Rect2(0,0,1280,720),Color("121212"))
    for y in range(10):
        for x in range(24):
            var r:=Rect2(48+x*grid_size,90+y*grid_size,grid_size-2,grid_size-2)
            draw_rect(r,Color("252525")); draw_rect(r,Color("3b3b3b"),false,1)
    for c in combat_covers:
        draw_rect(Rect2(48+c.x*grid_size,90+c.y*grid_size,grid_size-2,grid_size-2),Color("5b5140"))
    for i in range(combat_path.size()):
        var pc:=combat_path[i]
        var pr:=Rect2(48+pc.x*grid_size+5,90+pc.y*grid_size+5,grid_size-12,grid_size-12)
        draw_rect(pr,Color("365a42"))
        draw_string(ThemeDB.fallback_font,pr.position+Vector2(8,29),str(i+1),HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("eeeeee"))
    draw_circle(Vector2(48+(combat_player_cell.x+.5)*grid_size,90+(combat_player_cell.y+.5)*grid_size),15,Color("5c91c9"))
    draw_circle(Vector2(48+(combat_enemy_cell.x+.5)*grid_size,90+(combat_enemy_cell.y+.5)*grid_size),15,Color("a53a3a"))
    draw_string(ThemeDB.fallback_font,Vector2(25,35),"ТАКТИЧЕСКИЙ БОЙ — КЛЕТКИ",HORIZONTAL_ALIGNMENT_LEFT,500,24,Color("eeeeee"))
    draw_string(ThemeDB.fallback_font,Vector2(25,65),"HP %d/%d   AP %d/%d   Патроны %d   Цель: %s"%[hp,max_hp,ap,max_ap,ammo,target_name(combat_selected_target)],HORIZONTAL_ALIGNMENT_LEFT,1000,20,Color("dddddd"))
    if combat_path_cost>0:
        draw_string(ThemeDB.fallback_font,Vector2(930,65),"ПУТЬ: %d AP"%combat_path_cost,HORIZONTAL_ALIGNMENT_LEFT,300,20,Color("eeeeee"))
    draw_string(ThemeDB.fallback_font,Vector2(25,575),message,HORIZONTAL_ALIGNMENT_LEFT,1200,18,Color("c8c8c8"))

func draw_hud():
    var buttons=[Rect2(20,610,190,95),Rect2(205,610,145,95),Rect2(355,610,145,95),Rect2(505,610,145,95),Rect2(655,610,125,95),Rect2(785,610,125,95),Rect2(915,610,165,95),Rect2(1085,610,175,95)]
    var labels=["ИНВЕНТАРЬ","БЫСТРЫЙ","ПРИЦЕЛЬНЫЙ","УДАР","ЛЕЧИТЬ","ОБОРОНА","ЗАВЕРШИТЬ ХОД","ЦЕЛЬ"]
    var count:=8 if combat else 1
    for i in range(count):
        draw_rect(buttons[i],Color("303030")); draw_rect(buttons[i],Color("777777"),false,2)
        draw_string(ThemeDB.fallback_font,buttons[i].position+Vector2(10,52),labels[i],HORIZONTAL_ALIGNMENT_LEFT,buttons[i].size.x-15,18,Color("eeeeee"))
