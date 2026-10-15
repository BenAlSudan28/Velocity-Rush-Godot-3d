extends Control

signal steering_changed(value: float)

var steering_value: float = 0.0
var sensitivity: float = 1.0
var _dragging: bool = false
var _last_x: float = 0.0
var _visual_angle: float = 0.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    custom_minimum_size = Vector2(180, 180)
    queue_redraw()

func _gui_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            _dragging = true
            _last_x = event.position.x
            accept_event()
        else:
            _dragging = false
            accept_event()
    elif event is InputEventScreenDrag and _dragging:
        var delta_x: float = event.position.x - _last_x
        _last_x = event.position.x
        steering_value = clampf(steering_value + delta_x / 88.0 * sensitivity, -1.0, 1.0)
        _visual_angle = steering_value * 2.25
        steering_changed.emit(steering_value)
        queue_redraw()
        accept_event()
    elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
        _dragging = event.pressed
        if event.pressed:
            _last_x = event.position.x
        accept_event()
    elif event is InputEventMouseMotion and _dragging:
        var movement: float = event.position.x - _last_x
        _last_x = event.position.x
        steering_value = clampf(steering_value + movement / 88.0 * sensitivity, -1.0, 1.0)
        _visual_angle = steering_value * 2.25
        steering_changed.emit(steering_value)
        queue_redraw()
        accept_event()

func release_steering() -> void:
    _dragging = false

func reset_center() -> void:
    steering_value = 0.0
    _visual_angle = 0.0
    steering_changed.emit(0.0)
    queue_redraw()

func _process(delta: float) -> void:
    if not _dragging:
        steering_value = move_toward(steering_value, 0.0, delta * 0.72)
        _visual_angle = lerpf(_visual_angle, steering_value * 2.25, delta * 6.0)
        steering_changed.emit(steering_value)
        queue_redraw()

func _draw() -> void:
    var center := size * 0.5
    var radius := minf(size.x, size.y) * 0.40
    draw_circle(center, radius + 8.0, Color(0.015, 0.025, 0.035, 0.78))
    draw_arc(center, radius + 4.0, 0.0, TAU, 64, Color(0.15, 0.79, 0.88, 0.75), 4.0, true)
    draw_arc(center, radius - 3.0, 0.0, TAU, 64, Color(0.40, 0.48, 0.54, 0.98), 8.0, true)
    draw_arc(center, radius - 10.0, 0.0, TAU, 64, Color(0.06, 0.09, 0.12, 1.0), 5.0, true)
    var transform := Transform2D(_visual_angle, center)
    var points := [Vector2(0, -radius + 7), Vector2(-radius * 0.71, radius * 0.45), Vector2(radius * 0.71, radius * 0.45)]
    var transformed: Array[Vector2] = []
    for point in points:
        transformed.append(transform * point)
    draw_line(transformed[0], transformed[1], Color(0.72, 0.79, 0.83), 8.0, true)
    draw_line(transformed[0], transformed[2], Color(0.72, 0.79, 0.83), 8.0, true)
    draw_line(transformed[1], transformed[2], Color(0.72, 0.79, 0.83), 8.0, true)
    draw_circle(transform * Vector2.ZERO, 14.0, Color(0.04, 0.72, 0.82))
    draw_circle(center, 5.0, Color(0.88, 0.95, 0.97))
