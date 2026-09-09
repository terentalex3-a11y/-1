extends Node

var inventory: Array[Dictionary] = [
    {"name":"Старый пистолет", "type":"weapon", "damage":18, "ammo":6, "weight":1.2, "durability":72},
    {"name":"Бинт", "type":"medical", "heal":25, "weight":0.2, "count":2},
    {"name":"Патроны 9мм", "type":"ammo", "amount":8, "weight":0.3}
]
var equipped_weapon := 0
var body_armor := {"name":"Потрёпанная куртка", "protection":4, "weight":1.5, "durability":60}
var skills := {"Стрельба":1, "Медицина":1, "Скрытность":1, "Ремонт":1, "Сила":1, "Точность":1}
var reputation := {"Поселенцы":0, "Сборщики":0, "Каратели":0}
var shelter_level := 1
var saved := false

func inventory_weight() -> float:
    var total := body_armor.weight
    for item in inventory:
        total += float(item.get("weight", 0.0)) * float(item.get("count", 1))
    return total

func add_item(item: Dictionary) -> void:
    inventory.append(item)

func remove_item(index: int) -> void:
    if index >= 0 and index < inventory.size():
        inventory.remove_at(index)

func save_game() -> void:
    var data = {"inventory":inventory,"armor":body_armor,"skills":skills,"reputation":reputation,"shelter_level":shelter_level}
    var file = FileAccess.open("user://savegame.json", FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    saved = true

func load_game() -> bool:
    if not FileAccess.file_exists("user://savegame.json"):
        return false
    var file = FileAccess.open("user://savegame.json", FileAccess.READ)
    var data = JSON.parse_string(file.get_as_text())
    if typeof(data) != TYPE_DICTIONARY:
        return false
    inventory = data.get("inventory", inventory)
    body_armor = data.get("armor", body_armor)
    skills = data.get("skills", skills)
    reputation = data.get("reputation", reputation)
    shelter_level = data.get("shelter_level", shelter_level)
    saved = true
    return true
