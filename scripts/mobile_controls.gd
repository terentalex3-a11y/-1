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

func _input(event):
    if event is InputEventScreenTouch:
        if event.pressed and event.position.x < get_viewport_rect().size.x * 0.38 and event.position.y > get_viewport_rect().size.y * 0.45:
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
        draw_circle(joystick_center, joystick_radius, Color(0.08,0.09,0.09,0.82))
        draw_circle(joystick_center, joystick_radius, Color(0.72,0.72,0.68,0.85), false, 3)
        draw_circle(joystick_knob, 34, Color(0.32,0.42,0.50,0.95))
        draw_string(ThemeDB.fallback_font, joystick_center + Vector2(-42,115), "ДВИЖЕНИЕ", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("d8d8d2"))

func set_mobile_mode(enabled: bool):
    visible = enabled
