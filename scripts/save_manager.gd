extends Node

const SAVE_PATH := "user://velocity_rush_3d.cfg"
const DEFAULTS := {
    "engine_volume": 0.82,
    "sfx_volume": 0.90,
    "music_volume": 0.35,
    "music_enabled": true,
    "sound_enabled": true,
    "graphics_quality": "high",
    "control_mode": "HYDRAULIC STEERING",
    "steering_sensitivity": 1.0,
    "tilt_sensitivity": 1.0,
    "selected_car": 0,
    "best_score": 0,
    "best_time": 0.0
}

var settings: Dictionary = DEFAULTS.duplicate(true)
var _config := ConfigFile.new()

func _ready() -> void:
    load_settings()

func load_settings() -> void:
    settings = DEFAULTS.duplicate(true)
    var err: Error = _config.load(SAVE_PATH)
    if err == OK:
        for key in DEFAULTS.keys():
            settings[key] = _config.get_value("settings", key, DEFAULTS[key])
    else:
        _config.clear()
    _save_config()

func setting(key: String, fallback: Variant = null) -> Variant:
    if settings.has(key):
        return settings[key]
    return fallback

func set_setting(key: String, value: Variant) -> void:
    if not DEFAULTS.has(key):
        push_warning("Ignored unknown save setting: %s" % key)
        return
    settings[key] = value
    _config.set_value("settings", key, value)
    _save_config()

func reset_settings() -> void:
    settings = DEFAULTS.duplicate(true)
    _config.clear()
    for key in settings.keys():
        _config.set_value("settings", key, settings[key])
    _save_config()

func record_race(results: Dictionary) -> void:
    var score := int(results.get("score", 0))
    var duration := float(results.get("duration", 0.0))
    if score > int(setting("best_score", 0)):
        set_setting("best_score", score)
    var best_time := float(setting("best_time", 0.0))
    if duration > 0.0 and (best_time <= 0.0 or duration < best_time):
        set_setting("best_time", duration)

func _save_config() -> void:
    for key in settings.keys():
        _config.set_value("settings", key, settings[key])
    var err: Error = _config.save(SAVE_PATH)
    if err != OK:
        push_warning("Could not save local settings (error %s). Defaults remain active." % err)
