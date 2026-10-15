extends Control

signal menu_requested
signal camera_requested

const WheelScript = preload("res://scripts/ui/steering_wheel.gd")
const PedalScript = preload("res://scripts/ui/pedal_control.gd")

var vehicle: Node
var race_manager: Node
var mode: String = "race"
var speed_label: Label
var rpm_label: Label
var time_label: Label
var distance_label: Label
var score_label: Label
var progress_bar: ProgressBar
var countdown_label: Label
var hint_label: Label
var wheel: Control
var brake_pedal: Button
var throttle_pedal: Button
var nitro_button: Button
var nitro_bar: ProgressBar
var fuel_bar: ProgressBar
var fuel_label: Label
var fuel_fill_style: StyleBoxFlat
var refuel_button: Button
var left_button: Button
var right_button: Button
var pause_layer: Control
var wheel_steer: float = 0.0
var button_steer: float = 0.0
var throttle_value: float = 0.0
var brake_value: float = 0.0
var nitro_active: bool = false
var _pause_open := false
var _last_speed := 0.0
var _elapsed_local := 0.0
var _control_mode := "HYDRAULIC STEERING"

func setup(car: Node, race: Node, selected_mode: String) -> void:
    vehicle = car
    race_manager = race
    mode = selected_mode
    _control_mode = str(SaveManager.setting("control_mode", "HYDRAULIC STEERING"))
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_hud()

func _build_hud() -> void:
    mouse_filter = Control.MOUSE_FILTER_PASS
    var tint := ColorRect.new()
    tint.name = "HudVignette"
    tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    tint.color = Color(0.005, 0.012, 0.020, 0.025)
    add_child(tint)
    var stats_panel := _panel("TelemetryPanel", Vector2(24, 20), Vector2(490, 98), Color(0.012, 0.025, 0.040, 0.82))
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    row.offset_left = 18
    row.offset_top = 8
    row.offset_right = -16
    row.offset_bottom = -8
    stats_panel.add_child(row)
    var speed_box := VBoxContainer.new()
    speed_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(speed_box)
    speed_label = _label("000", 38, Color(0.94, 0.98, 1.0))
    speed_box.add_child(speed_label)
    speed_box.add_child(_label("كم/س • السرعة الحالية", 11, Color(0.35, 0.80, 0.88)))
    var separator := VSeparator.new()
    row.add_child(separator)
    var telemetry_box := VBoxContainer.new()
    telemetry_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(telemetry_box)
    rpm_label = _label("د/د  0850", 17, Color(0.85, 0.91, 0.94))
    telemetry_box.add_child(rpm_label)
    time_label = _label("الزمن  00:00.0", 15, Color(0.96, 0.74, 0.32))
    telemetry_box.add_child(time_label)
    distance_label = _label("المسافة  000 م", 13, Color(0.67, 0.75, 0.82))
    telemetry_box.add_child(distance_label)
    score_label = _label("سباق  /  850 م", 11, Color(0.35, 0.80, 0.88))
    telemetry_box.add_child(score_label)

    var pause_button := _button("Ⅱ", Vector2.ZERO, Vector2(58, 56), true)
    pause_button.anchor_left = 1.0
    pause_button.anchor_right = 1.0
    pause_button.anchor_top = 0.0
    pause_button.anchor_bottom = 0.0
    pause_button.offset_left = -84
    pause_button.offset_right = -22
    pause_button.offset_top = 20
    pause_button.offset_bottom = 76
    pause_button.add_theme_font_size_override("font_size", 26)
    pause_button.pressed.connect(_toggle_pause)
    add_child(pause_button)
    var camera_button := _button("كاميرا", Vector2.ZERO, Vector2(82, 45), false)
    camera_button.anchor_left = 1.0
    camera_button.anchor_right = 1.0
    camera_button.anchor_top = 0.0
    camera_button.anchor_bottom = 0.0
    camera_button.offset_left = -106
    camera_button.offset_right = -20
    camera_button.offset_top = 88
    camera_button.offset_bottom = 133
    camera_button.add_theme_font_size_override("font_size", 14)
    camera_button.pressed.connect(func(): camera_requested.emit())
    add_child(camera_button)

    if _control_mode == "HYDRAULIC STEERING":
        wheel = WheelScript.new()
        wheel.name = "HydraulicSteeringWheel"
        wheel.anchor_left = 0.0
        wheel.anchor_right = 0.0
        wheel.anchor_top = 1.0
        wheel.anchor_bottom = 1.0
        wheel.offset_left = 22
        wheel.offset_right = 222
        wheel.offset_top = -220
        wheel.offset_bottom = -20
        wheel.set("sensitivity", float(SaveManager.setting("steering_sensitivity", 1.0)))
        wheel.connect("steering_changed", Callable(self, "_on_wheel_steering"))
        add_child(wheel)
    elif _control_mode == "BUTTON STEERING":
        left_button = _button("◀", Vector2.ZERO, Vector2(94, 100), true)
        right_button = _button("▶", Vector2.ZERO, Vector2(94, 100), true)
        _place_bottom_left(left_button, 22, 120)
        _place_bottom_left(right_button, 125, 120)
        left_button.button_down.connect(func(): button_steer = -1.0)
        left_button.button_up.connect(func(): button_steer = 0.0)
        right_button.button_down.connect(func(): button_steer = 1.0)
        right_button.button_up.connect(func(): button_steer = 0.0)
        add_child(left_button)
        add_child(right_button)
    else:
        hint_label = _label("تحكم بالإمالة • أمسك الهاتف باستواء", 12, Color(0.65, 0.88, 0.94))
        hint_label.anchor_left = 0.0
        hint_label.anchor_right = 0.0
        hint_label.anchor_top = 1.0
        hint_label.anchor_bottom = 1.0
        hint_label.offset_left = 26
        hint_label.offset_right = 285
        hint_label.offset_top = -55
        hint_label.offset_bottom = -22
        add_child(hint_label)

    brake_pedal = PedalScript.new()
    brake_pedal.name = "BrakePedal"
    brake_pedal.text = "فرامل"
    brake_pedal.strength = 1.0
    _style_pedal(brake_pedal, Color(0.72, 0.13, 0.18))
    brake_pedal.anchor_left = 1.0
    brake_pedal.anchor_right = 1.0
    brake_pedal.anchor_top = 1.0
    brake_pedal.anchor_bottom = 1.0
    brake_pedal.offset_left = -218
    brake_pedal.offset_right = -116
    brake_pedal.offset_top = -139
    brake_pedal.offset_bottom = -24
    brake_pedal.pressure_changed.connect(_on_brake_pressure)
    add_child(brake_pedal)

    throttle_pedal = PedalScript.new()
    throttle_pedal.name = "AcceleratorPedal"
    throttle_pedal.text = "تسارع"
    throttle_pedal.strength = 1.0
    _style_pedal(throttle_pedal, Color(0.05, 0.55, 0.58))
    throttle_pedal.anchor_left = 1.0
    throttle_pedal.anchor_right = 1.0
    throttle_pedal.anchor_top = 1.0
    throttle_pedal.anchor_bottom = 1.0
    throttle_pedal.offset_left = -108
    throttle_pedal.offset_right = -8
    throttle_pedal.offset_top = -159
    throttle_pedal.offset_bottom = -24
    throttle_pedal.pressure_changed.connect(_on_throttle_pressure)
    add_child(throttle_pedal)

    nitro_button = PedalScript.new() as Button
    nitro_button.name = "NitroButton"
    nitro_button.text = "نيترو 100%"
    nitro_button.set("strength", 1.0)
    nitro_button.anchor_left = 1.0
    nitro_button.anchor_right = 1.0
    nitro_button.anchor_top = 1.0
    nitro_button.anchor_bottom = 1.0
    nitro_button.offset_left = -164
    nitro_button.offset_right = -58
    nitro_button.offset_top = -210
    nitro_button.offset_bottom = -165
    nitro_button.add_theme_font_size_override("font_size", 12)
    nitro_button.connect("pressure_changed", Callable(self, "_on_nitro_pressure"))
    _style_pedal(nitro_button, Color(0.04, 0.48, 0.62))
    nitro_button.custom_minimum_size = Vector2(106, 45)
    nitro_button.add_theme_font_size_override("font_size", 12)
    add_child(nitro_button)

    # The previous HUD read nitro_bar.value every frame but never created the
    # ProgressBar. That nil access aborted _process() before set_inputs() ran,
    # so throttle, braking, steering, and nitro never reached the car.
    nitro_bar = ProgressBar.new()
    nitro_bar.name = "NitroChargeBar"
    nitro_bar.anchor_left = 1.0
    nitro_bar.anchor_right = 1.0
    nitro_bar.anchor_top = 1.0
    nitro_bar.anchor_bottom = 1.0
    nitro_bar.offset_left = -164
    nitro_bar.offset_right = -58
    nitro_bar.offset_top = -231
    nitro_bar.offset_bottom = -220
    nitro_bar.min_value = 0.0
    nitro_bar.max_value = 100.0
    nitro_bar.value = 100.0
    nitro_bar.show_percentage = false
    nitro_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    nitro_bar.focus_mode = Control.FOCUS_NONE
    var nitro_bg := StyleBoxFlat.new()
    nitro_bg.bg_color = Color(0.025, 0.045, 0.060, 0.96)
    nitro_bg.set_corner_radius_all(4)
    nitro_bar.add_theme_stylebox_override("background", nitro_bg)
    var nitro_fill := StyleBoxFlat.new()
    nitro_fill.bg_color = Color(0.05, 0.88, 0.96, 1.0)
    nitro_fill.set_corner_radius_all(4)
    nitro_bar.add_theme_stylebox_override("fill", nitro_fill)
    add_child(nitro_bar)

    # Fuel is a real gameplay resource. In Free Drive the player can refill
    # only after stopping; the button is disabled during a race or while moving.
    fuel_label = _label("الوقود  100%", 13, Color(0.55, 0.94, 0.63))
    fuel_label.anchor_left = 1.0
    fuel_label.anchor_right = 1.0
    fuel_label.anchor_top = 0.0
    fuel_label.anchor_bottom = 0.0
    fuel_label.offset_left = -154
    fuel_label.offset_right = -20
    fuel_label.offset_top = 137
    fuel_label.offset_bottom = 162
    fuel_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    add_child(fuel_label)

    fuel_bar = ProgressBar.new()
    fuel_bar.name = "FuelLevelBar"
    fuel_bar.anchor_left = 1.0
    fuel_bar.anchor_right = 1.0
    fuel_bar.anchor_top = 0.0
    fuel_bar.anchor_bottom = 0.0
    fuel_bar.offset_left = -150
    fuel_bar.offset_right = -20
    fuel_bar.offset_top = 222
    fuel_bar.offset_bottom = 234
    fuel_bar.min_value = 0.0
    fuel_bar.max_value = 100.0
    fuel_bar.value = 100.0
    fuel_bar.show_percentage = false
    fuel_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var fuel_bg := StyleBoxFlat.new()
    fuel_bg.bg_color = Color(0.025, 0.045, 0.060, 0.96)
    fuel_bg.set_corner_radius_all(4)
    fuel_bar.add_theme_stylebox_override("background", fuel_bg)
    fuel_fill_style = StyleBoxFlat.new()
    fuel_fill_style.bg_color = Color(0.30, 0.88, 0.43, 1.0)
    fuel_fill_style.set_corner_radius_all(4)
    fuel_bar.add_theme_stylebox_override("fill", fuel_fill_style)
    add_child(fuel_bar)

    refuel_button = _button("تعبئة الوقود", Vector2.ZERO, Vector2(130, 42), false)
    refuel_button.anchor_left = 1.0
    refuel_button.anchor_right = 1.0
    refuel_button.anchor_top = 0.0
    refuel_button.anchor_bottom = 0.0
    refuel_button.offset_left = -150
    refuel_button.offset_right = -20
    refuel_button.offset_top = 170
    refuel_button.offset_bottom = 213
    refuel_button.add_theme_font_size_override("font_size", 12)
    refuel_button.pressed.connect(_try_refuel)
    add_child(refuel_button)

    countdown_label = _label("", 66, Color(0.97, 0.80, 0.35))
    countdown_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    countdown_label.offset_left = -145
    countdown_label.offset_right = 145
    countdown_label.offset_top = -72
    countdown_label.offset_bottom = 20
    countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    add_child(countdown_label)

    progress_bar = ProgressBar.new()
    progress_bar.anchor_left = 0.5
    progress_bar.anchor_right = 0.5
    progress_bar.anchor_top = 0.0
    progress_bar.anchor_bottom = 0.0
    progress_bar.offset_left = -120
    progress_bar.offset_right = 120
    progress_bar.offset_top = 30
    progress_bar.offset_bottom = 37
    progress_bar.min_value = 0.0
    progress_bar.max_value = 850.0
    progress_bar.show_percentage = false
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.10, 0.16, 0.20, 0.9)
    bg.set_corner_radius_all(4)
    progress_bar.add_theme_stylebox_override("background", bg)
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color(0.08, 0.78, 0.86)
    fill.set_corner_radius_all(4)
    progress_bar.add_theme_stylebox_override("fill", fill)
    add_child(progress_bar)
    _build_pause_layer()

func _build_pause_layer() -> void:
    pause_layer = Control.new()
    pause_layer.name = "PauseOverlay"
    pause_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    pause_layer.visible = false
    pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
    var shade := ColorRect.new()
    shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    shade.color = Color(0.005, 0.012, 0.021, 0.78)
    pause_layer.add_child(shade)
    var card := PanelContainer.new()
    card.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
    card.offset_left = -205
    card.offset_right = 205
    card.offset_top = -190
    card.offset_bottom = 190
    card.add_theme_stylebox_override("panel", _stylebox(Color(0.025, 0.045, 0.067, 0.98), Color(0.07, 0.77, 0.86), 20))
    pause_layer.add_child(card)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 16)
    content.alignment = BoxContainer.ALIGNMENT_CENTER
    card.add_child(content)
    content.add_child(_label("توقف مؤقت", 30, Color(0.95, 0.97, 1.0)))
    content.add_child(_label("تم إيقاف القيادة مؤقتًا.", 14, Color(0.62, 0.72, 0.79)))
    var resume := _button("استئناف القيادة", Vector2.ZERO, Vector2(270, 52), true)
    resume.pressed.connect(_resume)
    content.add_child(resume)
    var menu := _button("العودة إلى القائمة", Vector2.ZERO, Vector2(270, 48), false)
    menu.pressed.connect(func():
        _pause_open = false
        menu_requested.emit()
    )
    content.add_child(menu)
    add_child(pause_layer)

func _process(delta: float) -> void:
    if not is_instance_valid(vehicle) or not is_instance_valid(race_manager):
        return

    if not _pause_open:
        _elapsed_local += delta

    # Resolve and forward controls before updating optional HUD widgets. A HUD
    # display issue must never prevent input from reaching the vehicle physics.
    if _control_mode == "TILT STEERING":
        var tilt := Input.get_accelerometer()
        var gravity := Input.get_gravity()
        if OS.has_feature("android") and (tilt != Vector3.ZERO or gravity != Vector3.ZERO):
            wheel_steer = clampf(-tilt.x * 2.6 * float(SaveManager.setting("tilt_sensitivity", 1.0)), -1.0, 1.0)
        else:
            wheel_steer = 0.0
            if is_instance_valid(hint_label):
                hint_label.text = "مستشعر الإمالة غير متاح • غيّر التحكم من الإعدادات"

    var steer := wheel_steer if _control_mode != "BUTTON STEERING" else button_steer
    var final_throttle := throttle_value
    var final_brake := brake_value
    var final_nitro := nitro_active
    if not OS.has_feature("mobile"):
        var key_steer := (1.0 if Input.is_key_pressed(KEY_D) else 0.0) - (1.0 if Input.is_key_pressed(KEY_A) else 0.0)
        if key_steer != 0.0:
            steer = key_steer
        final_throttle = maxf(final_throttle, 1.0 if Input.is_key_pressed(KEY_W) else 0.0)
        final_brake = maxf(final_brake, 1.0 if Input.is_key_pressed(KEY_S) else 0.0)
        final_nitro = final_nitro or Input.is_key_pressed(KEY_SHIFT)

    vehicle.call("set_inputs", steer, final_throttle, final_brake, final_nitro)

    var speed := float(vehicle.call("get_speed_kmh"))
    var rpm := float(vehicle.get("rpm"))
    var forward_speed_ratio := float(vehicle.call("get_forward_speed_ratio"))

    if vehicle.has_method("get_nitro_percentage"):
        var nitro_level := float(vehicle.call("get_nitro_percentage"))
        if is_instance_valid(nitro_bar):
            nitro_bar.value = nitro_level
        if is_instance_valid(nitro_button):
            nitro_button.text = "نيترو %d%%" % int(round(nitro_level))
            nitro_button.disabled = nitro_level <= 0.5

    var fuel_level := float(vehicle.call("get_fuel_percentage")) if vehicle.has_method("get_fuel_percentage") else 100.0
    if is_instance_valid(fuel_bar):
        fuel_bar.value = fuel_level
    if is_instance_valid(refuel_button):
        refuel_button.text = "تعبئة %d%%" % int(round(fuel_level))
        refuel_button.visible = mode == "free_drive"
        refuel_button.disabled = mode != "free_drive" or speed > 7.2 or fuel_level >= 99.9
    if is_instance_valid(fuel_label):
        fuel_label.text = "الوقود  %d%%" % int(round(fuel_level)) if fuel_level > 0.1 else "نفد الوقود"
        fuel_label.add_theme_color_override("font_color", Color(1.0, 0.33, 0.30) if fuel_level <= 20.0 else Color(0.55, 0.94, 0.63))
    if fuel_fill_style != null:
        fuel_fill_style.bg_color = Color(1.0, 0.27, 0.24) if fuel_level <= 15.0 else (Color(1.0, 0.68, 0.20) if fuel_level <= 35.0 else Color(0.30, 0.88, 0.43))

    if is_instance_valid(speed_label):
        speed_label.text = "%03d" % int(round(speed))
    if is_instance_valid(rpm_label):
        rpm_label.text = "د/د  %04d" % int(round(rpm))

    var snapshot: Dictionary = race_manager.call("snapshot")
    var elapsed := float(snapshot.get("elapsed", _elapsed_local))
    var minutes := int(elapsed / 60.0)
    var seconds := fmod(elapsed, 60.0)
    if is_instance_valid(time_label):
        time_label.text = "الزمن  %02d:%04.1f" % [minutes, seconds]
    var distance := float(snapshot.get("distance", 0.0))
    if is_instance_valid(distance_label):
        distance_label.text = "المسافة  %04d م" % int(distance)
    if mode == "race":
        if is_instance_valid(score_label):
            score_label.text = "السباق  /  %03d م" % int(snapshot.get("target", 850.0))
        if is_instance_valid(progress_bar):
            progress_bar.visible = true
            progress_bar.value = distance
    else:
        if is_instance_valid(score_label):
            score_label.text = "قيادة حرة • بلا حد زمني"
        if is_instance_valid(progress_bar):
            progress_bar.visible = false

    if is_instance_valid(countdown_label):
        if bool(snapshot.get("counting_down", false)):
            countdown_label.visible = true
            countdown_label.text = str(maxi(1, int(ceil(float(snapshot.get("countdown", 0.0))))))
        elif not bool(snapshot.get("finished", false)):
            countdown_label.visible = false

    AudioManager.update_engine(rpm, forward_speed_ratio, final_throttle)
    AudioManager.set_brake(final_brake > 0.01, forward_speed_ratio)
    AudioManager.set_tire_skid(absf(steer) > 0.72 and speed > 58.0)

func _try_refuel() -> void:
    if not is_instance_valid(vehicle) or mode != "free_drive":
        return
    if vehicle.has_method("refuel"):
        vehicle.call("refuel")


func _toggle_pause() -> void:
    if _pause_open:
        _resume()
    else:
        _pause_open = true
        pause_layer.visible = true
        get_tree().paused = true
        AudioManager.set_tire_skid(false)
        AudioManager.engine_active(false)
        if is_instance_valid(vehicle):
            vehicle.call("set_inputs", 0.0, 0.0, 0.0, false)

func _resume() -> void:
    _pause_open = false
    pause_layer.visible = false
    get_tree().paused = false
    AudioManager.engine_active(true)

func _on_wheel_steering(value: float) -> void:
    wheel_steer = value

func _on_throttle_pressure(value: float) -> void:
    throttle_value = value

func _on_brake_pressure(value: float) -> void:
    brake_value = value

func _on_nitro_pressure(value: float) -> void:
    var was_active := nitro_active
    nitro_active = value > 0.01
    if nitro_active and not was_active:
        AudioManager.trigger_turbo()

func _place_bottom_left(control: Control, left: float, width: float) -> void:
    control.anchor_left = 0.0
    control.anchor_right = 0.0
    control.anchor_top = 1.0
    control.anchor_bottom = 1.0
    control.offset_left = left
    control.offset_right = left + width
    control.offset_top = -124
    control.offset_bottom = -24

func _panel(panel_name: String, at: Vector2, dimensions: Vector2, color: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = panel_name
    panel.position = at
    panel.size = dimensions
    panel.add_theme_stylebox_override("panel", _stylebox(color, Color(0.09, 0.74, 0.84, 0.55), 16))
    add_child(panel)
    return panel

func _label(text: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    if font_size >= 30:
        label.add_theme_font_override("font", load("res://assets/fonts/NotoSansArabic-Bold.ttf"))
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.clip_text = true
    return label

func _button(text: String, at: Vector2, dimensions: Vector2, accent: bool) -> Button:
    var button := Button.new()
    button.text = text
    button.position = at
    button.size = dimensions
    button.custom_minimum_size = dimensions
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
    button.add_theme_color_override("font_hover_color", Color(0.04, 0.08, 0.11))
    var normal_color := Color(0.03, 0.59, 0.66, 0.93) if accent else Color(0.035, 0.065, 0.09, 0.87)
    var hover_color := Color(0.25, 0.88, 0.91, 1.0) if accent else Color(0.08, 0.15, 0.19, 0.96)
    button.add_theme_stylebox_override("normal", _stylebox(normal_color, Color(0.10, 0.74, 0.84, 0.70), 12))
    button.add_theme_stylebox_override("hover", _stylebox(hover_color, Color(0.35, 0.88, 0.93), 12))
    button.add_theme_stylebox_override("pressed", _stylebox(Color(0.03, 0.40, 0.48), Color(0.45, 0.91, 0.96), 12))
    return button

func _style_pedal(button: Button, fill: Color) -> void:
    button.custom_minimum_size = Vector2(98, 108)
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color(0.98, 0.99, 1.0))
    button.add_theme_color_override("font_hover_color", Color.WHITE)
    button.add_theme_stylebox_override("normal", _stylebox(Color(fill.r, fill.g, fill.b, 0.88), Color(0.85, 0.92, 0.96, 0.45), 15))
    button.add_theme_stylebox_override("pressed", _stylebox(Color(fill.r * 0.72, fill.g * 0.72, fill.b * 0.72, 0.98), Color.WHITE, 15))
    button.add_theme_stylebox_override("hover", _stylebox(Color(fill.r, fill.g, fill.b, 0.98), Color.WHITE, 15))

func _stylebox(color: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    style.shadow_color = Color(0, 0, 0, 0.24)
    style.shadow_size = 5
    return style
