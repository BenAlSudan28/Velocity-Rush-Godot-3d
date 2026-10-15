extends Node

signal countdown_changed(value: int)
signal race_finished(results: Dictionary)
signal race_started

var mode: String = "race"
var vehicle: Node
var target_distance: float = 850.0
var elapsed: float = 0.0
var countdown: float = 3.0
var counting_down: bool = true
var finished: bool = false
var peak_speed: float = 0.0
var distance_at_start: float = 0.0

func setup(car: Node, selected_mode: String, distance_target: float = 850.0) -> void:
    vehicle = car
    mode = selected_mode
    target_distance = maxf(50.0, distance_target)
    elapsed = 0.0
    countdown = 3.0 if mode == "race" else 0.0
    counting_down = mode == "race"
    finished = false
    peak_speed = 0.0
    distance_at_start = float(vehicle.get("distance_travelled")) if vehicle != null else 0.0
    if vehicle != null:
        vehicle.set("input_enabled", not counting_down)
    if counting_down:
        countdown_changed.emit(3)
    else:
        race_started.emit()

func tick(delta: float) -> void:
    if finished or not is_instance_valid(vehicle):
        return
    if counting_down:
        var old_count := int(ceil(countdown))
        countdown -= delta
        var new_count := int(ceil(maxf(0.0, countdown)))
        if new_count != old_count:
            countdown_changed.emit(new_count)
            AudioManager.play_ui()
        if countdown <= 0.0:
            counting_down = false
            vehicle.set("input_enabled", true)
            race_started.emit()
            AudioManager.play_start()
        return
    elapsed += delta
    var distance := float(vehicle.get("distance_travelled")) - distance_at_start
    peak_speed = maxf(peak_speed, float(vehicle.call("get_speed_kmh")))
    if mode == "race" and distance >= target_distance:
        finish_race()

func finish_race() -> void:
    if finished:
        return
    finished = true
    if vehicle != null:
        vehicle.set("input_enabled", false)
        vehicle.call("set_inputs", 0.0, 0.0, 0.0, false)
    var distance := maxf(0.0, float(vehicle.get("distance_travelled")) - distance_at_start) if vehicle != null else 0.0
    var actual_peak := float(vehicle.get("max_speed_seen")) * 3.6 if vehicle != null else peak_speed
    var collisions := int(vehicle.get("collision_count")) if vehicle != null else 0
    # A transparent single-player sprint score: distance + average pace bonus - impact penalty.
    var pace_bonus := int(maxf(0.0, 120.0 - elapsed) * 12.0)
    var score := int(distance * 8.0) + pace_bonus - collisions * 250
    var results := {
        "mode": mode,
        "duration": elapsed,
        "distance": distance,
        "max_speed": maxf(peak_speed, actual_peak),
        "collisions": collisions,
        "score": maxi(0, score)
    }
    SaveManager.record_race(results)
    race_finished.emit(results)

func snapshot() -> Dictionary:
    var distance := 0.0
    if is_instance_valid(vehicle):
        distance = maxf(0.0, float(vehicle.get("distance_travelled")) - distance_at_start)
    return {"elapsed": elapsed, "distance": distance, "target": target_distance, "countdown": countdown, "counting_down": counting_down, "finished": finished}
