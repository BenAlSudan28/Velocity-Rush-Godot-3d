extends Node3D

var target: Node3D
var camera: Camera3D
var cockpit_mode: bool = false
var shake_amount: float = 0.0
var _shake_time: float = 0.0

func _ready() -> void:
    camera = Camera3D.new()
    camera.name = "RaceCamera"
    camera.current = true
    camera.fov = 72.0
    camera.near = 0.08
    camera.far = 650.0
    add_child(camera)
    if target != null:
        camera.global_position = target.global_position + Vector3(0, 3.0, 8.0)

func set_target(vehicle: Node3D) -> void:
    target = vehicle

func toggle_camera() -> bool:
    cockpit_mode = not cockpit_mode
    return cockpit_mode

func set_cockpit(enabled: bool) -> void:
    cockpit_mode = enabled

func _process(delta: float) -> void:
    if not is_instance_valid(target) or not is_instance_valid(camera):
        return
    if cockpit_mode and target.has_method("get_cockpit_anchor"):
        var anchor: Node3D = target.call("get_cockpit_anchor")
        if is_instance_valid(anchor):
            camera.global_transform = anchor.global_transform
            camera.fov = 76.0
            return
    camera.fov = lerpf(camera.fov, 70.0 + minf(_vehicle_speed_ratio() * 8.0, 8.0), delta * 2.2)
    var backwards := target.global_transform.basis.z.normalized()
    var desired := target.global_position + backwards * 8.8 + Vector3(0, 3.0, 0)
    if _vehicle_speed_ratio() > 0.55:
        desired += backwards * 1.0 + Vector3(0, 0.45, 0)
    var smoothing := 1.0 - exp(-delta * 4.8)
    camera.global_position = camera.global_position.lerp(desired, smoothing)
    var look_point := target.global_position - backwards * 3.0 + Vector3(0, 0.95, 0)
    if shake_amount > 0.0:
        _shake_time += delta * 32.0
        camera.position.y += sin(_shake_time) * shake_amount
        shake_amount = move_toward(shake_amount, 0.0, delta * 0.05)
    camera.look_at(look_point, Vector3.UP)

func _vehicle_speed_ratio() -> float:
    if target != null and target.has_method("get_forward_speed_ratio"):
        return float(target.call("get_forward_speed_ratio"))
    return 0.0

func impact_shake(strength: float) -> void:
    shake_amount = clampf(strength, 0.0, 0.16)
