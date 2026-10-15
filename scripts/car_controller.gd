extends CharacterBody3D

const CAR_SPECS: Array[Dictionary] = [
    {"name": "AERION GT-R", "class": "رياضية فائقة", "max_speed": 318.0, "acceleration": 20.5, "braking": 38.0, "steering": 1.62, "width": 1.92, "length": 4.42, "color": "#e52d47", "roof": 1.17, "spoiler": true},
    {"name": "VORTEX SV-X", "class": "هايبر رياضية", "max_speed": 352.0, "acceleration": 24.0, "braking": 41.0, "steering": 1.48, "width": 2.02, "length": 4.58, "color": "#f1b92e", "roof": 1.13, "spoiler": true},
    {"name": "TERRA RALLY S", "class": "رياضية سياحية", "max_speed": 286.0, "acceleration": 18.0, "braking": 36.0, "steering": 1.78, "width": 1.96, "length": 4.65, "color": "#23b9c6", "roof": 1.31, "spoiler": false},
    {"name": "SCARLET V12", "class": "جراند تورر", "max_speed": 329.0, "acceleration": 21.8, "braking": 39.0, "steering": 1.56, "width": 1.98, "length": 4.55, "color": "#c51f35", "roof": 1.10, "spoiler": false},
    {"name": "NIGHTFALL X", "class": "كوبيه هايبر", "max_speed": 361.0, "acceleration": 25.2, "braking": 42.0, "steering": 1.44, "width": 2.04, "length": 4.62, "color": "#7b4dff", "roof": 1.08, "spoiler": true},
    {"name": "APEX R SPORT", "class": "مخصصة للحلبة", "max_speed": 304.0, "acceleration": 19.7, "braking": 43.0, "steering": 1.86, "width": 1.90, "length": 4.38, "color": "#d9e3ea", "roof": 1.14, "spoiler": true}
]

@export var preview_mode: bool = false
var car_index: int = 0
var stats: Dictionary = {}
var input_steer: float = 0.0
var input_throttle: float = 0.0
var input_brake: float = 0.0
var input_nitro: bool = false
var input_enabled: bool = true
var ai_controlled: bool = false
var ai_active: bool = false
var ai_path: Array[Vector3] = []
var ai_target_speed_kmh: float = 132.0
var _ai_repath_timer: float = 0.0
var _ai_target_index: int = 0
var nitro_charge: float = 100.0
var fuel_level: float = 100.0
var speed_mps: float = 0.0
var rpm: float = 900.0
var distance_travelled: float = 0.0
var max_speed_seen: float = 0.0
var collision_count: int = 0
var _collision_cooldown: float = 0.0
var _wheel_pivots: Array[Node3D] = []
var _cockpit_anchor: Node3D
var _visual_root: Node3D

func _ready() -> void:
    configure(car_index)

func configure(index: int) -> void:
    car_index = clampi(index, 0, CAR_SPECS.size() - 1)
    stats = CAR_SPECS[car_index].duplicate(true)
    if is_inside_tree():
        _rebuild_car()

func _rebuild_car() -> void:
    for child in get_children():
        if child == $CollisionShape3D:
            continue
        child.queue_free()
    _wheel_pivots.clear()
    _visual_root = Node3D.new()
    _visual_root.name = "CarVisuals"
    add_child(_visual_root)
    _make_model()
    if not has_node("CollisionShape3D"):
        var collision := CollisionShape3D.new()
        collision.name = "CollisionShape3D"
        var box_shape := BoxShape3D.new()
        box_shape.size = Vector3(float(stats["width"]) * 0.9, 0.78, float(stats["length"]) * 0.88)
        collision.shape = box_shape
        collision.position.y = 0.53
        add_child(collision)
    else:
        var collision_shape := get_node("CollisionShape3D") as CollisionShape3D
        var box_shape := BoxShape3D.new()
        box_shape.size = Vector3(float(stats["width"]) * 0.9, 0.78, float(stats["length"]) * 0.88)
        collision_shape.shape = box_shape
        collision_shape.position.y = 0.53
    collision_layer = 1 if not preview_mode else 0
    collision_mask = 1 if not preview_mode else 0

func _make_model() -> void:
    var body_color := Color.from_string(str(stats["color"]), Color.RED)
    var width: float = float(stats["width"])
    var length: float = float(stats["length"])
    var roof: float = float(stats["roof"])
    var body_mat := _material(body_color, 0.62, 0.23)
    var trim_mat := _material(Color(0.035, 0.045, 0.06), 0.18, 0.30)
    var glass_mat := _material(Color(0.055, 0.16, 0.22), 0.42, 0.16)
    var tire_mat := _material(Color(0.018, 0.021, 0.025), 0.02, 0.85)
    var rim_mat := _material(Color(0.70, 0.76, 0.82), 0.82, 0.22)
    var head_mat := _material(Color(0.75, 0.94, 1.0), 0.15, 0.2, true)
    var tail_mat := _material(Color(1.0, 0.035, 0.025), 0.1, 0.25, true)
    _add_box("LowerBody", Vector3(width, 0.40, length), Vector3(0, 0.48, 0), body_mat)
    _add_box("SculptedHood", Vector3(width * 0.93, 0.18, length * 0.34), Vector3(0, 0.70, -length * 0.285), body_mat)
    _add_box("RearDeck", Vector3(width * 0.88, 0.20, length * 0.23), Vector3(0, 0.68, length * 0.34), body_mat)
    _add_box("CabinFrame", Vector3(width * 0.70, maxf(0.30, roof - 0.83), length * 0.36), Vector3(0, 0.83 + (roof - 0.83) * 0.5, 0.03), trim_mat)
    _add_box("PanoramicGlass", Vector3(width * 0.65, maxf(0.23, roof - 0.88), length * 0.32), Vector3(0, 0.86 + (roof - 0.88) * 0.5, 0.01), glass_mat)
    _add_box("FrontBumper", Vector3(width * 0.98, 0.15, 0.24), Vector3(0, 0.35, -length * 0.50), trim_mat)
    _add_box("RearDiffuser", Vector3(width * 0.82, 0.14, 0.22), Vector3(0, 0.32, length * 0.50), trim_mat)
    _add_box("FrontLightL", Vector3(0.34, 0.07, 0.12), Vector3(-width * 0.30, 0.64, -length * 0.48), head_mat)
    _add_box("FrontLightR", Vector3(0.34, 0.07, 0.12), Vector3(width * 0.30, 0.64, -length * 0.48), head_mat)
    _add_box("RearLightL", Vector3(0.42, 0.07, 0.10), Vector3(-width * 0.28, 0.61, length * 0.49), tail_mat)
    _add_box("RearLightR", Vector3(0.42, 0.07, 0.10), Vector3(width * 0.28, 0.61, length * 0.49), tail_mat)
    _add_box("SideSkirtL", Vector3(0.10, 0.12, length * 0.62), Vector3(-width * 0.50, 0.30, 0), trim_mat)
    _add_box("SideSkirtR", Vector3(0.10, 0.12, length * 0.62), Vector3(width * 0.50, 0.30, 0), trim_mat)
    if bool(stats["spoiler"]):
        _add_box("RearWing", Vector3(width * 0.72, 0.075, 0.25), Vector3(0, 0.92, length * 0.46), trim_mat)
        _add_box("RearWingStandL", Vector3(0.07, 0.20, 0.08), Vector3(-width * 0.22, 0.82, length * 0.44), trim_mat)
        _add_box("RearWingStandR", Vector3(0.07, 0.20, 0.08), Vector3(width * 0.22, 0.82, length * 0.44), trim_mat)
    for side in [-1.0, 1.0]:
        for longitudinal in [-1.0, 1.0]:
            var wheel_pivot := Node3D.new()
            wheel_pivot.name = "Wheel_%s_%s" % [str(side), str(longitudinal)]
            wheel_pivot.position = Vector3(side * width * 0.49, 0.34, longitudinal * length * 0.31)
            _visual_root.add_child(wheel_pivot)
            _wheel_pivots.append(wheel_pivot)
            var tire := CylinderMesh.new()
            tire.top_radius = 0.33
            tire.bottom_radius = 0.33
            tire.height = 0.23
            tire.radial_segments = 18
            var tire_mesh := MeshInstance3D.new()
            tire_mesh.name = "RubberTire"
            tire_mesh.mesh = tire
            tire_mesh.material_override = tire_mat
            tire_mesh.rotation.z = PI * 0.5
            wheel_pivot.add_child(tire_mesh)
            var rim := CylinderMesh.new()
            rim.top_radius = 0.19
            rim.bottom_radius = 0.19
            rim.height = 0.245
            rim.radial_segments = 16
            var rim_mesh := MeshInstance3D.new()
            rim_mesh.name = "AlloyRim"
            rim_mesh.mesh = rim
            rim_mesh.material_override = rim_mat
            rim_mesh.rotation.z = PI * 0.5
            wheel_pivot.add_child(rim_mesh)
            var hub := SphereMesh.new()
            hub.radius = 0.075
            hub.height = 0.15
            var hub_mesh := MeshInstance3D.new()
            hub_mesh.mesh = hub
            hub_mesh.material_override = trim_mat
            hub_mesh.scale = Vector3(0.65, 0.65, 0.65)
            wheel_pivot.add_child(hub_mesh)
    # A basic 3D cockpit is built into every vehicle; this is not a flat HUD overlay.
    _add_box("Dashboard", Vector3(width * 0.92, 0.17, 0.66), Vector3(0, 0.84, -0.31), trim_mat)
    _add_box("InstrumentCluster", Vector3(0.58, 0.08, 0.12), Vector3(0, 0.94, -0.34), _material(Color(0.02, 0.42, 0.50), 0.25, 0.25, true))
    var cockpit_wheel := MeshInstance3D.new()
    cockpit_wheel.name = "CockpitSteeringWheel"
    var torus := TorusMesh.new()
    torus.inner_radius = 0.16
    torus.outer_radius = 0.22
    cockpit_wheel.mesh = torus
    cockpit_wheel.material_override = trim_mat
    cockpit_wheel.position = Vector3(0, 0.99, -0.08)
    cockpit_wheel.rotation.x = deg_to_rad(68.0)
    cockpit_wheel.scale = Vector3(0.9, 0.9, 0.7)
    _visual_root.add_child(cockpit_wheel)
    _cockpit_anchor = Node3D.new()
    _cockpit_anchor.name = "CockpitAnchor"
    _cockpit_anchor.position = Vector3(0, 1.10, 0.35)
    _visual_root.add_child(_cockpit_anchor)

func _add_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = at
    _visual_root.add_child(instance)
    return instance

func _material(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.4
    return mat

func set_inputs(steer: float, throttle: float, brake: float, nitro: bool = false) -> void:
    input_steer = clampf(steer, -1.0, 1.0) if input_enabled else 0.0
    input_throttle = clampf(throttle, 0.0, 1.0) if input_enabled else 0.0
    input_brake = clampf(brake, 0.0, 1.0) if input_enabled else 0.0
    input_nitro = nitro and input_enabled and input_throttle > 0.01 and nitro_charge > 0.5

func setup_ai(path_points: Array, target_speed_kmh: float = 132.0) -> void:
    ai_controlled = true
    ai_active = false
    ai_path.clear()
    for point in path_points:
        if point is Vector3:
            ai_path.append(point)
    ai_target_speed_kmh = clampf(target_speed_kmh, 85.0, 175.0)
    _ai_repath_timer = 0.0
    if not ai_path.is_empty():
        _ai_target_index = _find_nearest_path_index()

func set_ai_active(active: bool) -> void:
    ai_active = active
    input_enabled = active
    if not active:
        input_steer = 0.0
        input_throttle = 0.0
        input_brake = 0.0
        input_nitro = false

func _find_nearest_path_index() -> int:
    if ai_path.is_empty():
        return 0
    var nearest_index: int = 0
    var nearest_distance: float = INF
    for index in range(ai_path.size()):
        var distance := global_position.distance_squared_to(ai_path[index])
        if distance < nearest_distance:
            nearest_distance = distance
            nearest_index = index
    return nearest_index

func _update_ai_inputs(delta: float) -> void:
    if ai_path.size() < 4:
        input_steer = 0.0
        input_throttle = 1.0
        input_brake = 0.0
        return
    _ai_repath_timer -= delta
    if _ai_repath_timer <= 0.0:
        var nearest := _find_nearest_path_index()
        _ai_target_index = (nearest + 5) % ai_path.size()
        _ai_repath_timer = 0.18
    var target_point: Vector3 = ai_path[_ai_target_index]
    var desired := target_point - global_position
    desired.y = 0.0
    if desired.length_squared() > 0.01:
        desired = desired.normalized()
        var right_component := global_transform.basis.x.dot(desired)
        input_steer = clampf(right_component * 2.4, -1.0, 1.0)
    else:
        input_steer = 0.0
    input_throttle = 1.0
    input_brake = 0.0
    input_nitro = false

func get_nitro_percentage() -> float:
    return clampf(nitro_charge, 0.0, 100.0)

func get_fuel_percentage() -> float:
    return clampf(fuel_level, 0.0, 100.0)

func refuel() -> bool:
    # Refuelling is allowed only while stopped; the HUD exposes it in Free Drive.
    if absf(speed_mps) > 2.0:
        return false
    fuel_level = 100.0
    return true

func get_speed_kmh() -> float:
    return absf(speed_mps) * 3.6

func get_forward_speed_ratio() -> float:
    return clampf(absf(speed_mps) / maxf(float(stats.get("max_speed", 300.0)) / 3.6, 1.0), 0.0, 1.0)

func get_cockpit_anchor() -> Node3D:
    return _cockpit_anchor

func _physics_process(delta: float) -> void:
    if preview_mode:
        return
    if ai_controlled:
        if ai_active and input_enabled:
            _update_ai_inputs(delta)
        else:
            input_steer = 0.0
            input_throttle = 0.0
            input_brake = 0.0
            input_nitro = false
    _collision_cooldown = maxf(0.0, _collision_cooldown - delta)
    if not ai_controlled and input_throttle > 0.01:
        var fuel_burn_per_second := 0.18 + absf(speed_mps) * 0.008 + (0.10 if input_nitro else 0.0)
        fuel_level = maxf(0.0, fuel_level - fuel_burn_per_second * input_throttle * delta)
    if not ai_controlled and fuel_level <= 0.0:
        input_throttle = 0.0
        input_nitro = false
    var max_speed := float(stats["max_speed"]) / 3.6
    var acceleration := float(stats["acceleration"])
    if ai_controlled:
        max_speed = minf(max_speed, ai_target_speed_kmh / 3.6)
        if absf(input_steer) > 0.78:
            max_speed *= 0.78
    if input_nitro and nitro_charge > 0.0:
        max_speed *= 1.20
        acceleration *= 1.9
        nitro_charge = maxf(0.0, nitro_charge - 32.0 * delta)
        if nitro_charge <= 0.0:
            input_nitro = false
    else:
        nitro_charge = minf(100.0, nitro_charge + 8.5 * delta)
    if input_brake > 0.01:
        speed_mps = move_toward(speed_mps, 0.0, float(stats["braking"]) * input_brake * delta)
    elif input_throttle > 0.01:
        speed_mps = move_toward(speed_mps, max_speed, acceleration * input_throttle * delta)
    else:
        speed_mps = move_toward(speed_mps, 0.0, (1.1 + absf(speed_mps) * 0.045) * delta)
    var speed_factor := clampf(absf(speed_mps) / 8.0, 0.12, 1.0)
    var sensitivity := float(SaveManager.setting("steering_sensitivity", 1.0))
    var turn_rate := float(stats["steering"]) * sensitivity * speed_factor
    if absf(speed_mps) > 0.08:
        rotation.y -= input_steer * turn_rate * delta * signf(speed_mps)
    var forward := -global_transform.basis.z
    velocity.x = forward.x * speed_mps
    velocity.z = forward.z * speed_mps
    velocity.y -= 19.6 * delta
    move_and_slide()
    if get_slide_collision_count() > 0 and _collision_cooldown <= 0.0 and absf(speed_mps) > 2.0:
        collision_count += 1
        speed_mps *= 0.62
        _collision_cooldown = 0.8
        AudioManager.play_collision(clampf(absf(speed_mps) / max_speed, 0.2, 1.0))
    rpm = clampf(850.0 + get_forward_speed_ratio() * 5900.0 + input_throttle * 950.0, 850.0, 7800.0)
    distance_travelled += absf(speed_mps) * delta
    max_speed_seen = maxf(max_speed_seen, absf(speed_mps))
    for wheel in _wheel_pivots:
        wheel.rotate_x(speed_mps * delta / 0.33)

func reset_stats() -> void:
    speed_mps = 0.0
    nitro_charge = 100.0
    rpm = 850.0
    distance_travelled = 0.0
    max_speed_seen = 0.0
    collision_count = 0
    velocity = Vector3.ZERO
    set_inputs(0.0, 0.0, 0.0, false)
