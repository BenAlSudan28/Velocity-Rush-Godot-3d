extends RefCounted

const CarController = preload("res://scripts/car_controller.gd")

static func car_count() -> int:
    return CarController.CAR_SPECS.size()

static func car_spec(index: int) -> Dictionary:
    var bounded := clampi(index, 0, CarController.CAR_SPECS.size() - 1)
    return CarController.CAR_SPECS[bounded].duplicate(true)

static func next_index(index: int, direction: int) -> int:
    var count := CarController.CAR_SPECS.size()
    return posmod(index + direction, count)

static func performance_summary(spec: Dictionary) -> String:
    return "السرعة القصوى  %d كم/س\nالتسارع 0–100  %0.1f ث\nالفرملة  %d\nالتماسك  %d" % [int(spec.get("max_speed", 0)), 100.0 / maxf(1.0, float(spec.get("acceleration", 1.0)) * 2.1), int(float(spec.get("braking", 0.0)) * 2.1), int(float(spec.get("steering", 0.0)) * 52.0)]
