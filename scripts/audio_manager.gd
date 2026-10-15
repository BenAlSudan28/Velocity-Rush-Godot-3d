extends Node

var _players: Dictionary = {}
var _brake_was_pressed: bool = false
var _last_turbo_time: float = -10.0
var _sound_enabled: bool = true
var _music_enabled: bool = true
var _engine_enabled: bool = false
var _headless_mode: bool = false

func _ready() -> void:
    _headless_mode = DisplayServer.get_name() == "headless"
    _add_player("engine", "Engine", "res://assets/sounds/engine/engine_loop.wav", true)
    _add_player("turbo", "SFX", "res://assets/sounds/turbo/turbo_burst.wav", false)
    _add_player("brake", "SFX", "res://assets/sounds/brakes/brake_pulse.wav", false)
    _add_player("tires", "SFX", "res://assets/sounds/tires/tire_skid.wav", true)
    _add_player("collision", "SFX", "res://assets/sounds/collisions/impact.wav", false)
    _add_player("ui", "SFX", "res://assets/sounds/ui/ui_tick.wav", false)
    _add_player("start", "SFX", "res://assets/sounds/ui/race_start.wav", false)
    _add_player("music", "Music", "res://assets/sounds/music/menu_drive.wav", true)
    apply_settings()

func _add_player(key: String, bus: String, path: String, looping: bool) -> void:
    var player := AudioStreamPlayer.new()
    player.name = "Audio_" + key
    player.bus = bus
    player.process_mode = Node.PROCESS_MODE_ALWAYS
    var stream := load(path)
    if stream == null:
        push_warning("Local audio asset could not be loaded: " + path)
    elif stream is AudioStreamWAV and looping:
        var wav := stream as AudioStreamWAV
        wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
        if wav.data.size() > 0:
            wav.loop_end = int(wav.data.size() / 2) if wav.format == AudioStreamWAV.FORMAT_16_BITS else int(wav.data.size())
    player.stream = stream
    add_child(player)
    _players[key] = player

func apply_settings() -> void:
    _sound_enabled = bool(SaveManager.setting("sound_enabled", true)) and not _headless_mode
    _music_enabled = bool(SaveManager.setting("music_enabled", true)) and not _headless_mode
    var master := AudioServer.get_bus_index("Master")
    if master >= 0:
        AudioServer.set_bus_mute(master, not _sound_enabled)
    _set_bus_volume("Engine", float(SaveManager.setting("engine_volume", 0.82)))
    _set_bus_volume("SFX", float(SaveManager.setting("sfx_volume", 0.90)))
    _set_bus_volume("Music", float(SaveManager.setting("music_volume", 0.35)))
    var music: AudioStreamPlayer = _players.get("music")
    if is_instance_valid(music):
        if _sound_enabled and _music_enabled and not music.playing:
            music.play()
        elif (not _sound_enabled or not _music_enabled) and music.playing:
            music.stop()

func _set_bus_volume(bus_name: String, linear: float) -> void:
    var idx := AudioServer.get_bus_index(bus_name)
    if idx >= 0:
        AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.001, 1.0)))

func engine_active(active: bool) -> void:
    _engine_enabled = active
    var player: AudioStreamPlayer = _players.get("engine")
    if not is_instance_valid(player):
        return
    if active and _sound_enabled and not player.playing:
        player.play()
    elif (not active or not _sound_enabled) and player.playing:
        player.stop()

func update_engine(rpm: float, speed_ratio: float, throttle: float) -> void:
    var player: AudioStreamPlayer = _players.get("engine")
    if not is_instance_valid(player):
        return
    if _engine_enabled and _sound_enabled and not player.playing:
        player.play()
    player.pitch_scale = clampf(0.65 + (rpm / 7800.0) * 1.20, 0.65, 1.95)
    player.volume_db = lerpf(-23.0, -8.5, clampf(0.23 + speed_ratio * 0.50 + throttle * 0.35, 0.0, 1.0))

func set_brake(active: bool, speed_ratio: float) -> void:
    if active and not _brake_was_pressed and speed_ratio > 0.12:
        _play_one_shot("brake", -4.0)
    _brake_was_pressed = active

func set_tire_skid(active: bool) -> void:
    var player: AudioStreamPlayer = _players.get("tires")
    if not is_instance_valid(player):
        return
    if active and _sound_enabled and not player.playing:
        player.play()
    elif (not active or not _sound_enabled) and player.playing:
        player.stop()

func trigger_turbo() -> void:
    if Time.get_ticks_msec() / 1000.0 - _last_turbo_time < 0.65:
        return
    _last_turbo_time = Time.get_ticks_msec() / 1000.0
    _play_one_shot("turbo", -1.0)

func play_collision(intensity: float = 0.5) -> void:
    _play_one_shot("collision", -4.0 + clampf(intensity, 0.0, 1.0) * 4.0)

func play_ui() -> void:
    _play_one_shot("ui", -11.0)

func play_start() -> void:
    _play_one_shot("start", -5.0)

func set_menu_audio() -> void:
    engine_active(false)
    set_tire_skid(false)
    apply_settings()

func _play_one_shot(key: String, volume: float) -> void:
    if not _sound_enabled:
        return
    var player: AudioStreamPlayer = _players.get(key)
    if not is_instance_valid(player) or player.stream == null:
        return
    player.volume_db = volume
    player.play()
