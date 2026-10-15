extends Node3D

const CarScene = preload("res://scenes/car.tscn")
const TrackScene = preload("res://scenes/race_track.tscn")
const EnvironmentBuilder = preload("res://scripts/environment_builder.gd")
const CameraController = preload("res://scripts/camera_controller.gd")
const RaceManager = preload("res://scripts/race_manager.gd")
const HudSceneScript = preload("res://scripts/ui/driving_hud.gd")
const ResultsScreenScript = preload("res://scripts/ui/results_screen.gd")
const GarageController = preload("res://scripts/garage_controller.gd")
const SettingsManager = preload("res://scripts/settings_manager.gd")

var ui_layer: CanvasLayer
var ui_root: Control
var world_root: Node3D
var menu_camera: Camera3D
var world_light: DirectionalLight3D
var menu_car: Node3D
var player_car: CharacterBody3D
var ai_opponents: Array[CharacterBody3D] = []
var camera_rig: Node3D
var race_manager: Node
var hud: Control
var selected_car: int = 0
var current_screen: String = "menu"
var _sound_button: Button
var _active_results: Dictionary = {}

func _ready() -> void:
    selected_car = int(SaveManager.setting("selected_car", 0))
    _setup_world()
    _setup_ui_layer()
    AudioManager.apply_settings()
    _show_main_menu()

func _setup_world() -> void:
    world_root = Node3D.new()
    world_root.name = "GeneratedWorld"
    add_child(world_root)
    var world_environment := WorldEnvironment.new()
    world_environment.name = "WorldLighting"
    var env := Environment.new()
    env.background_mode = Environment.BG_SKY
    var sky := Sky.new()
    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color(0.12, 0.42, 0.82)
    sky_material.sky_horizon_color = Color(0.68, 0.83, 0.96)
    sky_material.ground_bottom_color = Color(0.40, 0.48, 0.35)
    sky_material.ground_horizon_color = Color(0.72, 0.79, 0.69)
    sky_material.sun_angle_max = 18.0
    sky.sky_material = sky_material
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.70, 0.79, 0.90)
    env.ambient_light_energy = 1.15
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_environment.environment = env
    add_child(world_environment)
    world_light = DirectionalLight3D.new()
    world_light.name = "KeySunlight"
    world_light.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
    world_light.light_color = Color(1.0, 0.96, 0.87)
    world_light.light_energy = 1.55
    world_light.shadow_enabled = true
    world_light.directional_shadow_max_distance = 90.0
    add_child(world_light)
    menu_camera = Camera3D.new()
    menu_camera.name = "ShowcaseCamera"
    menu_camera.position = Vector3(6.5, 5.4, 18.0)
    menu_camera.fov = 48.0
    menu_camera.near = 0.08
    menu_camera.far = 650.0
    add_child(menu_camera)
    menu_camera.look_at(Vector3(0.0, 1.0, -14.0), Vector3.UP)
    menu_camera.make_current()
    _apply_graphics_setting()

func _setup_ui_layer() -> void:
    ui_layer = CanvasLayer.new()
    ui_layer.name = "GameUI"
    add_child(ui_layer)
    ui_root = Control.new()
    ui_root.name = "UIRoot"
    ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui_root.mouse_filter = Control.MOUSE_FILTER_PASS
    ui_root.layout_direction = Control.LAYOUT_DIRECTION_RTL
    var arabic_theme := Theme.new()
    arabic_theme.default_font = load("res://assets/fonts/NotoSansArabic-Regular.ttf")
    arabic_theme.default_font_size = 18
    ui_root.theme = arabic_theme
    ui_layer.add_child(ui_root)

func _process(delta: float) -> void:
    if current_screen in ["menu", "garage", "settings"] and is_instance_valid(menu_car):
        menu_car.rotate_y(delta * 0.13)
    if current_screen in ["race", "free_drive"] and is_instance_valid(race_manager):
        race_manager.call("tick", delta)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_GO_BACK_REQUEST:
        if current_screen in ["race", "free_drive"]:
            if get_tree().paused:
                get_tree().paused = false
                _show_main_menu()
            elif is_instance_valid(hud):
                hud.call("_toggle_pause")
        else:
            _show_main_menu()

func _show_main_menu() -> void:
    get_tree().paused = false
    current_screen = "menu"
    player_car = null
    if is_instance_valid(camera_rig):
        camera_rig.queue_free()
    camera_rig = null
    hud = null
    _free_race_manager()
    AudioManager.set_menu_audio()
    _rebuild_menu_stage()
    _clear_ui()
    _add_dark_overlay(0.37)
    var panel := _panel("MainMenuPanel", Vector2(28, 28), Vector2(425, 662), Color(0.018, 0.034, 0.052, 0.93), 18)
    ui_root.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 9)
    panel.add_child(content)
    content.add_child(_label("VELOCITY RUSH 3D", 38, Color(0.96, 0.98, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label("سباق حضري • قيادة بلا إنترنت", 13, Color(0.12, 0.82, 0.90), HORIZONTAL_ALIGNMENT_RIGHT))
    var line := ColorRect.new()
    line.custom_minimum_size = Vector2(0, 3)
    line.color = Color(0.06, 0.75, 0.84)
    content.add_child(line)
    content.add_child(_label("طارد الأفق.\nامتلك الطريق.", 22, Color(0.88, 0.92, 0.96), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label("اختر نمط القيادة", 13, Color(0.48, 0.61, 0.70), HORIZONTAL_ALIGNMENT_RIGHT))
    var race_button := _menu_button("01   سباق السرعة", true)
    race_button.pressed.connect(func(): _start_game("race"))
    content.add_child(race_button)
    var free_button := _menu_button("02   قيادة حرة", false)
    free_button.pressed.connect(func(): _start_game("free_drive"))
    content.add_child(free_button)
    var garage_button := _menu_button("03   مرآب السيارات", false)
    # Defer scene/UI teardown until Godot has finished dispatching the button event.
    garage_button.pressed.connect(func(): call_deferred("_show_garage"))
    content.add_child(garage_button)
    var settings_button := _menu_button("04   الإعدادات", false)
    settings_button.pressed.connect(_show_settings)
    content.add_child(settings_button)
    _sound_button = _menu_button(_sound_button_text(), false)
    _sound_button.pressed.connect(_toggle_sound)
    content.add_child(_sound_button)
    var exit_button := _menu_button("خروج", false)
    exit_button.custom_minimum_size.y = 43
    exit_button.pressed.connect(func(): get_tree().quit())
    content.add_child(exit_button)
    content.add_child(_label("لعب بلا إنترنت • سباق فردي • الإصدار 01", 10, Color(0.39, 0.50, 0.59), HORIZONTAL_ALIGNMENT_RIGHT))
    _add_showcase_card()

func _show_garage() -> void:
    get_tree().paused = false
    current_screen = "garage"
    AudioManager.set_menu_audio()
    _rebuild_menu_stage()
    _clear_ui()
    _add_dark_overlay(0.34)
    var panel := _panel("GaragePanel", Vector2(35, 42), Vector2(440, 636), Color(0.015, 0.030, 0.048, 0.94), 20)
    ui_root.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 12)
    panel.add_child(content)
    content.add_child(_label("اختيار السيارة", 30, Color(0.95, 0.98, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label("سيارتك. أسلوبك.", 12, Color(0.12, 0.82, 0.90), HORIZONTAL_ALIGNMENT_RIGHT))
    var spec: Dictionary = GarageController.car_spec(selected_car)
    content.add_child(_label("السيارة %02d / %02d" % [selected_car + 1, GarageController.car_count()], 13, Color(0.55, 0.68, 0.77), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label(str(spec["name"]), 28, Color.from_string(str(spec["color"]), Color.WHITE), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label(str(spec["class"]), 13, Color(0.71, 0.79, 0.84), HORIZONTAL_ALIGNMENT_RIGHT))
    var chooser := HBoxContainer.new()
    chooser.add_theme_constant_override("separation", 12)
    var previous := _menu_button("◀ السابقة", false)
    previous.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    previous.pressed.connect(func():
        selected_car = GarageController.next_index(selected_car, -1)
        SaveManager.set_setting("selected_car", selected_car)
        _show_garage()
    )
    chooser.add_child(previous)
    var next := _menu_button("التالية ▶", false)
    next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next.pressed.connect(func():
        selected_car = GarageController.next_index(selected_car, 1)
        SaveManager.set_setting("selected_car", selected_car)
        _show_garage()
    )
    chooser.add_child(next)
    content.add_child(chooser)
    var performance := _panel("PerformancePanel", Vector2.ZERO, Vector2(0, 170), Color(0.035, 0.065, 0.085, 0.87), 12)
    content.add_child(performance)
    var perf_label := _label(GarageController.performance_summary(spec), 17, Color(0.83, 0.90, 0.94), HORIZONTAL_ALIGNMENT_RIGHT)
    performance.add_child(perf_label)
    content.add_child(_label("تصاميم خيالية إجرائية بلا شعارات تجارية.", 11, Color(0.46, 0.58, 0.66), HORIZONTAL_ALIGNMENT_RIGHT))
    var drive := _menu_button("قد هذه السيارة", true)
    drive.pressed.connect(func(): _start_game("free_drive"))
    content.add_child(drive)
    var back := _menu_button("العودة إلى القائمة الرئيسية", false)
    back.pressed.connect(_show_main_menu)
    content.add_child(back)
    _add_showcase_card()

func _show_settings() -> void:
    get_tree().paused = false
    current_screen = "settings"
    AudioManager.set_menu_audio()
    _rebuild_menu_stage()
    _clear_ui()
    _add_dark_overlay(0.48)
    var panel := _panel("SettingsPanel", Vector2(170, 34), Vector2(935, 650), Color(0.015, 0.031, 0.049, 0.97), 20)
    ui_root.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 8)
    panel.add_child(content)
    content.add_child(_label("إعدادات القيادة", 31, Color(0.95, 0.98, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label("اضبط الصوت والرسومات وطريقة القيادة.", 13, Color(0.45, 0.61, 0.70), HORIZONTAL_ALIGNMENT_RIGHT))
    _add_slider_row(content, "صوت المحرك", "engine_volume", 0.0, 1.0)
    _add_slider_row(content, "صوت المؤثرات", "sfx_volume", 0.0, 1.0)
    _add_slider_row(content, "صوت الموسيقى", "music_volume", 0.0, 1.0)
    _add_slider_row(content, "حساسية التوجيه", "steering_sensitivity", 0.45, 1.65)
    _add_slider_row(content, "حساسية الإمالة", "tilt_sensitivity", 0.45, 2.0)
    var choice_row := HBoxContainer.new()
    choice_row.add_theme_constant_override("separation", 22)
    var mode_box := VBoxContainer.new()
    mode_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    mode_box.add_child(_label("نمط التحكم", 13, Color(0.73, 0.82, 0.88), HORIZONTAL_ALIGNMENT_RIGHT))
    var mode_option := OptionButton.new()
    var mode_keys: Array[String] = ["HYDRAULIC STEERING", "BUTTON STEERING", "TILT STEERING"]
    var mode_labels: Array[String] = ["مقود لمس", "أزرار يمين/يسار", "إمالة الهاتف"]
    for mode_label in mode_labels:
        mode_option.add_item(mode_label)
    mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var current_mode := str(SaveManager.setting("control_mode", "HYDRAULIC STEERING"))
    for i in range(mode_option.item_count):
        if mode_keys[i] == current_mode:
            mode_option.select(i)
    mode_option.item_selected.connect(func(index: int):
        SaveManager.set_setting("control_mode", mode_keys[index])
    )
    mode_box.add_child(mode_option)
    choice_row.add_child(mode_box)
    var quality_box := VBoxContainer.new()
    quality_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quality_box.add_child(_label("جودة الرسومات", 13, Color(0.73, 0.82, 0.88), HORIZONTAL_ALIGNMENT_RIGHT))
    var quality_option := OptionButton.new()
    quality_option.add_item("عالية • ظلال وتنعيم", 0)
    quality_option.add_item("منخفضة • أداء أسرع", 1)
    quality_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    quality_option.select(1 if str(SaveManager.setting("graphics_quality", "high")) == "low" else 0)
    quality_option.item_selected.connect(func(index: int):
        SaveManager.set_setting("graphics_quality", "low" if index == 1 else "high")
        _apply_graphics_setting()
    )
    quality_box.add_child(quality_option)
    choice_row.add_child(quality_box)
    content.add_child(choice_row)
    var music_toggle := CheckButton.new()
    music_toggle.text = "موسيقى القائمة الرئيسية"
    music_toggle.button_pressed = bool(SaveManager.setting("music_enabled", true))
    music_toggle.toggled.connect(func(value: bool):
        SaveManager.set_setting("music_enabled", value)
        AudioManager.apply_settings()
    )
    content.add_child(music_toggle)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 14)
    var reset := _menu_button("استعادة الافتراضي", false)
    reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    reset.pressed.connect(func():
        SaveManager.reset_settings()
        selected_car = int(SaveManager.setting("selected_car", 0))
        AudioManager.apply_settings()
        _apply_graphics_setting()
        _show_settings()
    )
    buttons.add_child(reset)
    var back := _menu_button("حفظ والعودة", true)
    back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    back.pressed.connect(_show_main_menu)
    buttons.add_child(back)
    content.add_child(buttons)
    content.add_child(_label("تُحفظ الإعدادات محليًا على هذا الجهاز.", 11, Color(0.43, 0.55, 0.64), HORIZONTAL_ALIGNMENT_RIGHT))

func _start_game(mode: String) -> void:
    get_tree().paused = false
    _free_race_manager()
    current_screen = mode
    AudioManager.set_tire_skid(false)
    _clear_ui()
    _clear_world()
    player_car = null
    menu_car = null
    if is_instance_valid(camera_rig):
        camera_rig.queue_free()
        camera_rig = null
    menu_camera.make_current()
    var track: Node3D = TrackScene.instantiate()
    track.name = "RaceTrack"
    world_root.add_child(track)
    var track_config: Dictionary = track.get("track_config")
    var centreline: Array = track_config.get("centreline", [])
    var start_position: Vector3 = track_config.get("start_position", Vector3(0.0, 0.02, 7.5))
    var start_forward := Vector3(0.0, 0.0, -1.0)
    if centreline.size() >= 2 and centreline[0] is Vector3 and centreline[1] is Vector3:
        var first_point: Vector3 = centreline[0]
        var second_point: Vector3 = centreline[1]
        start_forward = (second_point - first_point).normalized()
        start_forward.y = 0.0
        if start_forward.length_squared() > 0.001:
            start_forward = start_forward.normalized()
        else:
            start_forward = Vector3(0.0, 0.0, -1.0)
    var start_right := Vector3(-start_forward.z, 0.0, start_forward.x).normalized()
    var start_yaw := atan2(-start_forward.x, -start_forward.z)

    ai_opponents.clear()
    player_car = CarScene.instantiate() as CharacterBody3D
    player_car.set("preview_mode", false)
    player_car.call("configure", selected_car)
    player_car.position = start_position
    player_car.rotation.y = start_yaw
    world_root.add_child(player_car)

    # Rivals are aligned to the actual first road tangent instead of hard-coded
    # world X/Z offsets. Put two cars in each of two rows ahead of the player so
    # they are visible from the chase camera during the countdown, without spawn overlap.
    if mode == "race" and centreline.size() >= 4:
        var grid_lanes: Array[float] = [-2.55, 2.55, -2.55, 2.55]
        var grid_rows: Array[float] = [1.0, 1.0, 2.0, 2.0]
        var car_choices: Array[int] = [1, 2, 3, 4]
        var speeds: Array[float] = [138.0, 126.0, 145.0, 132.0]
        for index in range(grid_lanes.size()):
            var opponent := CarScene.instantiate() as CharacterBody3D
            opponent.name = "Rival_%02d" % (index + 1)
            opponent.set("preview_mode", false)
            opponent.call("configure", car_choices[index] % 6)
            opponent.position = start_position + start_right * grid_lanes[index] + start_forward * (4.8 * grid_rows[index])
            opponent.rotation.y = start_yaw
            world_root.add_child(opponent)
            opponent.call("setup_ai", centreline, speeds[index])
            opponent.call("set_ai_active", false)
            ai_opponents.append(opponent)
    camera_rig = CameraController.new()
    camera_rig.call("set_target", player_car)
    world_root.add_child(camera_rig)
    menu_camera.current = false
    race_manager = RaceManager.new()
    race_manager.name = "RaceSession"
    add_child(race_manager)
    var target_distance := float(track_config.get("target_distance", 850.0))
    race_manager.connect("race_finished", _on_race_finished)
    race_manager.connect("race_started", _start_ai_opponents)
    race_manager.call("setup", player_car, mode, target_distance)
    hud = HudSceneScript.new()
    hud.name = "DrivingHUD"
    hud.call("setup", player_car, race_manager, mode)
    hud.connect("menu_requested", _show_main_menu)
    hud.connect("camera_requested", _toggle_camera)
    ui_root.add_child(hud)
    AudioManager.engine_active(true)
    if mode == "free_drive":
        player_car.set("input_enabled", true)

func _start_ai_opponents() -> void:
    if current_screen != "race":
        return
    for opponent in ai_opponents:
        if is_instance_valid(opponent):
            opponent.call("set_ai_active", true)

func _on_race_finished(results: Dictionary) -> void:
    if current_screen != "race":
        return
    for opponent in ai_opponents:
        if is_instance_valid(opponent):
            opponent.call("set_ai_active", false)
    _active_results = results.duplicate(true)
    current_screen = "results"
    AudioManager.engine_active(false)
    AudioManager.set_tire_skid(false)
    get_tree().paused = false
    _clear_ui()
    var results_ui = ResultsScreenScript.new()
    results_ui.name = "RaceResults"
    results_ui.call("setup", results)
    results_ui.connect("retry_requested", func(): _start_game("race"))
    results_ui.connect("menu_requested", _show_main_menu)
    ui_root.add_child(results_ui)

func _toggle_camera() -> void:
    if is_instance_valid(camera_rig):
        var cockpit := bool(camera_rig.call("toggle_camera"))
        if is_instance_valid(hud):
            var camera_node: Camera3D = camera_rig.get_node_or_null("RaceCamera") as Camera3D
            if is_instance_valid(camera_node) and cockpit:
                camera_node.fov = 76.0

func _free_race_manager() -> void:
    if is_instance_valid(race_manager):
        race_manager.queue_free()
    race_manager = null

func _rebuild_menu_stage() -> void:
    _clear_world()
    menu_camera.make_current()
    var builder = EnvironmentBuilder.new()
    builder.build_menu(world_root)
    menu_car = CarScene.instantiate() as Node3D
    menu_car.name = "GarageShowcaseVehicle"
    menu_car.set("preview_mode", true)
    menu_car.call("configure", selected_car)
    menu_car.position = Vector3(3.2, 0.0, -8.5)
    menu_car.rotation.y = PI
    world_root.add_child(menu_car)
    menu_camera.position = Vector3(7.2, 5.4, 18.0)
    menu_camera.look_at(Vector3(0.0, 1.0, -16.0), Vector3.UP)
    menu_camera.fov = 48.0
    menu_camera.make_current()

func _add_showcase_card() -> void:
    var spec: Dictionary = GarageController.car_spec(selected_car)
    var panel := _panel("ShowcaseInfo", Vector2(824, 478), Vector2(420, 190), Color(0.012, 0.027, 0.043, 0.82), 17)
    ui_root.add_child(panel)
    var content := VBoxContainer.new()
    content.add_theme_constant_override("separation", 5)
    panel.add_child(content)
    content.add_child(_label("سيارتك الحالية  /  %02d" % (selected_car + 1), 11, Color(0.13, 0.82, 0.90), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label(str(spec["name"]), 24, Color.from_string(str(spec["color"]), Color.WHITE), HORIZONTAL_ALIGNMENT_RIGHT))
    content.add_child(_label(str(spec["class"]), 11, Color(0.72, 0.80, 0.85), HORIZONTAL_ALIGNMENT_RIGHT))
    var stats := HBoxContainer.new()
    stats.add_theme_constant_override("separation", 20)
    stats.add_child(_stat_block("السرعة القصوى", "%d" % int(spec["max_speed"]), "كم/س"))
    stats.add_child(_stat_block("التسارع", "%d" % int(float(spec["acceleration"])), "قوة"))
    stats.add_child(_stat_block("التماسك", "%d" % int(float(spec["steering"]) * 50.0), "تماسك"))
    content.add_child(stats)

func _stat_block(caption: String, value: String, suffix: String) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_child(_label(caption, 9, Color(0.45, 0.60, 0.69), HORIZONTAL_ALIGNMENT_RIGHT))
    box.add_child(_label(value, 20, Color(0.94, 0.98, 1.0), HORIZONTAL_ALIGNMENT_RIGHT))
    box.add_child(_label(suffix, 9, Color(0.13, 0.82, 0.90), HORIZONTAL_ALIGNMENT_RIGHT))
    return box

func _add_slider_row(parent: VBoxContainer, caption: String, key: String, min_value: float, max_value: float) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 16)
    var title := _label(caption, 12, Color(0.73, 0.82, 0.88), HORIZONTAL_ALIGNMENT_RIGHT)
    title.custom_minimum_size = Vector2(205, 28)
    row.add_child(title)
    var slider := HSlider.new()
    slider.min_value = min_value
    slider.max_value = max_value
    slider.step = 0.01
    slider.value = clampf(float(SaveManager.setting(key, 0.8)), min_value, max_value)
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.custom_minimum_size = Vector2(300, 30)
    slider.value_changed.connect(func(value: float):
        SaveManager.set_setting(key, value)
        AudioManager.apply_settings()
    )
    row.add_child(slider)
    var value_label := _label("%d%%" % int(round((slider.value - min_value) / maxf(0.001, max_value - min_value) * 100.0)), 12, Color(0.12, 0.82, 0.90), HORIZONTAL_ALIGNMENT_RIGHT)
    value_label.custom_minimum_size = Vector2(44, 28)
    slider.value_changed.connect(func(value: float):
        value_label.text = "%d%%" % int(round((value - min_value) / maxf(0.001, max_value - min_value) * 100.0))
    )
    row.add_child(value_label)
    parent.add_child(row)

func _toggle_sound() -> void:
    var next_value := not bool(SaveManager.setting("sound_enabled", true))
    SaveManager.set_setting("sound_enabled", next_value)
    AudioManager.apply_settings()
    if is_instance_valid(_sound_button):
        _sound_button.text = _sound_button_text()

func _sound_button_text() -> String:
    return "الصوت / يعمل" if bool(SaveManager.setting("sound_enabled", true)) else "الصوت / مغلق"

func _apply_graphics_setting() -> void:
    SettingsManager.apply_graphics(get_viewport(), str(SaveManager.setting("graphics_quality", "high")), world_light)

func _clear_ui() -> void:
    # Never free a Control immediately while its pressed/input signal is executing.
    for child in ui_root.get_children():
        # Queue while it is still in the SceneTree, then detach it immediately.
        child.queue_free()
        ui_root.remove_child(child)
    _sound_button = null

func _clear_world() -> void:
    menu_car = null
    for child in world_root.get_children():
        child.queue_free()
        world_root.remove_child(child)

func _add_dark_overlay(alpha: float) -> void:
    var overlay := ColorRect.new()
    overlay.name = "InterfaceDarken"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.color = Color(0.004, 0.010, 0.018, alpha)
    ui_root.add_child(overlay)

func _panel(panel_name: String, at: Vector2, dimensions: Vector2, color: Color, radius: int) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = panel_name
    panel.position = at
    panel.size = dimensions
    panel.add_theme_stylebox_override("panel", _stylebox(color, Color(0.07, 0.68, 0.78, 0.55), radius))
    return panel

func _label(text_value: String, font_size: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
    var label := Label.new()
    label.text = text_value
    if font_size >= 22:
        label.add_theme_font_override("font", load("res://assets/fonts/NotoSansArabic-Bold.ttf"))
    label.horizontal_alignment = alignment
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.45))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 1)
    label.clip_text = true
    return label

func _menu_button(text_value: String, accent: bool) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 48)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 16)
    button.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
    button.add_theme_color_override("font_hover_color", Color(0.03, 0.07, 0.10))
    var normal := _stylebox(Color(0.035, 0.58, 0.66, 0.94) if accent else Color(0.027, 0.053, 0.074, 0.96), Color(0.07, 0.70, 0.80, 0.55), 10)
    var hover := _stylebox(Color(0.26, 0.86, 0.89) if accent else Color(0.08, 0.17, 0.21, 0.98), Color(0.44, 0.91, 0.95), 10)
    var pressed := _stylebox(Color(0.02, 0.39, 0.46), Color(0.44, 0.91, 0.95), 10)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", pressed)
    return button

func _stylebox(color: Color, border: Color, radius: int) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(radius)
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 10.0
    style.content_margin_bottom = 10.0
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
    style.shadow_size = 6
    return style
