class_name InjurySystem

static func apply_wound(wounds:Dictionary, body_part:String, damage:int) -> Dictionary:
    var result := wounds.duplicate(true)
    result[body_part] = int(result.get(body_part,0)) + damage
    return result

static func movement_penalty(wounds:Dictionary) -> int:
    return clamp(int(wounds.get("leg",0)) / 10, 0, 5)

static func accuracy_penalty(wounds:Dictionary) -> int:
    return clamp(int(wounds.get("arm",0)) / 10, 0, 5)

static func bleeding(wounds:Dictionary) -> bool:
    return int(wounds.get("torso",0)) >= 25 or int(wounds.get("leg",0)) >= 30 or int(wounds.get("arm",0)) >= 35

static func critical(wounds:Dictionary) -> bool:
    return int(wounds.get("head",0)) >= 30

static func status_text(wounds:Dictionary) -> String:
    var statuses:Array[String] = []
    if int(wounds.get("head",0)) >= 20:
        statuses.append("тяжёлая травма головы")
    if int(wounds.get("arm",0)) >= 20:
        statuses.append("повреждена рука")
    if int(wounds.get("leg",0)) >= 20:
        statuses.append("повреждена нога")
    if bleeding(wounds):
        statuses.append("кровотечение")
    if statuses.is_empty():
        return "Состояние стабильное"
    return ", ".join(statuses)
