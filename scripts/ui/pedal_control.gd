extends Button

signal pressure_changed(value: float)

@export_range(0.0, 1.0, 0.05) var strength: float = 1.0
var _held := false
var _touch_index: int = -1

func _ready() -> void:
    focus_mode = Control.FOCUS_NONE
    mouse_filter = Control.MOUSE_FILTER_STOP
    action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    keep_pressed_outside = true
    button_down.connect(_press)
    button_up.connect(_release)
    # Keep the pedal active while a finger is held on it. Releasing outside the
    # button is handled by button_up; mouse_exited is unreliable on touchscreens.


func _input(event: InputEvent) -> void:
    # Standard Button mouse emulation handles only one touch at a time. Track
    # touchscreen indices directly as well, so throttle/brake/nitro can be held
    # while a second finger steers the wheel. The ordinary mouse signals remain
    # available for desktop testing and are safe because _press/_release are idempotent.
    if event is InputEventScreenTouch:
        if event.pressed:
            if _touch_index == -1 and _contains_viewport_point(event.position):
                _touch_index = event.index
                _press()
        elif event.index == _touch_index:
            _touch_index = -1
            _release()

func _contains_viewport_point(viewport_point: Vector2) -> bool:
    var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_point
    return Rect2(Vector2.ZERO, size).has_point(local_point)

func _press() -> void:
    _held = true
    pressure_changed.emit(strength)

func _release() -> void:
    if _held:
        _held = false
        pressure_changed.emit(0.0)

func cancel_pressure() -> void:
    _release()
