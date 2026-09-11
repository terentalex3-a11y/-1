class_name TacticalPathfinding

static func find_path(start:Vector2i, goal:Vector2i, width:int, height:int, blocked:Array[Vector2i]) -> Array[Vector2i]:
    if start == goal:
        return []
    if goal.x < 0 or goal.x >= width or goal.y < 0 or goal.y >= height:
        return []
    if blocked.has(goal):
        return []

    var queue:Array[Vector2i] = [start]
    var came_from:Dictionary = {start:Vector2i(-999,-999)}
    var head := 0
    var dirs := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]

    while head < queue.size():
        var current:Vector2i = queue[head]
        head += 1
        if current == goal:
            break
        for d in dirs:
            var next:Vector2i = current + d
            if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
                continue
            if blocked.has(next) or came_from.has(next):
                continue
            came_from[next] = current
            queue.append(next)

    if not came_from.has(goal):
        return []

    var path:Array[Vector2i] = []
    var current := goal
    while current != start:
        path.push_front(current)
        current = came_from[current]
    return path
