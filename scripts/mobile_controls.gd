extends Control

signal move_requested(direction: Vector2)
signal action_requested(action: String)

var joystick_center := Vector2.ZERO
var joystick_knob := Vector2.ZERO
var joystick_radius := 78.0
var active_touch := -1

func _ready():
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    queue_redraw()

func _gui_input(event):
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < size.x * 0.45 and event.position.y > size.y * 0.45:
            active_touch = event.index
            joystick_center = event.position
            joystick_knob = event.position
            queue_redraw()
        elif not event.pressed and event.index == active_touch:
            active_touch = -1
            joystick_knob = joystick_center
            queue_redraw()
    elif event is InputEventScreenDrag and event.index == active_touch:
        var delta: Vector2 = event.position - joystick_center
        if delta.length() > joystick_radius:
            delta = delta.normalized() * joystick_radius
        joystick_knob = joystick_center + delta
        if delta.length() > 18.0:
            move_requested.emit(delta.normalized())
        queue_redraw()

func _draw():
    if joystick_center != Vector2.ZERO:
        draw_circle(joystick_center, joystick_radius, Color(0.15,0.15,0.15,0.65))
        draw_circle(joystick_center, joystick_radius, Color(0.65,0.65,0.65,0.7), false, 3)
        draw_circle(joystick_knob, 34, Color(0.35,0.45,0.55,0.9))

func _unhandled_input(event):
    if event is InputEventMouseButton and event.pressed:
        _handle_action(event.position)
    elif event is InputEventScreenTouch and event.pressed and active_touch == -1:
        _handle_action(event.position)

func _handle_action(p: Vector2):
    if p.y < size.y * 0.18 and p.x > size.x * 0.78:
        action_requested.emit("inventory")
    elif p.y > size.y * 0.76:
        if p.x > size.x * 0.78:
            action_requested.emit("shoot")
        elif p.x > size.x * 0.59:
            action_requested.emit("heal")
        elif p.x > size.x * 0.40:
            action_requested.emit("end_turn")

func set_mobile_mode(enabled: bool):
    visible = enabled
