#!/usr/bin/env python3
"""Lightweight static preflight for the Godot project; Godot itself parses scripts in CI."""
from pathlib import Path
import re
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []

required = [
    "project.godot",
    "export_presets.cfg",
    "icon.png",
    "icon.svg",
    "assets/fonts/NotoSansArabic-Regular.ttf",
    "assets/fonts/NotoSansArabic-Bold.ttf",
    "assets/fonts/OFL.txt",
    "scenes/main.tscn",
    "scenes/car.tscn",
    "scenes/race_track.tscn",
    "scenes/free_drive.tscn",
    ".github/workflows/build.yml",
    "scripts/game_manager.gd",
    "scripts/car_controller.gd",
    "scripts/environment_builder.gd",
    "scripts/camera_controller.gd",
    "scripts/race_manager.gd",
    "scripts/audio_manager.gd",
    "scripts/save_manager.gd",
    "scripts/ui/driving_hud.gd",
    "scripts/ui/steering_wheel.gd",
    "scripts/ui/pedal_control.gd",
    "scripts/ui/results_screen.gd",
    "tools/verify_game.gd",
]
for rel in required:
    path = ROOT / rel
    if not path.is_file():
        errors.append(f"Missing required file: {rel}")
    elif path.stat().st_size == 0:
        errors.append(f"Empty required file: {rel}")

# Verify literal res:// references from project/resource/source files.
scan_suffixes = {".gd", ".tscn", ".tres", ".godot", ".cfg"}
ref_pattern = re.compile(r"res://([^\"'\s,)]+)")
for path in ROOT.rglob("*"):
    if not path.is_file() or path.suffix not in scan_suffixes:
        continue
    try:
        source = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for ref in ref_pattern.findall(source):
        ref = ref.rstrip(".;]")
        target = ROOT / ref
        if not target.exists():
            errors.append(f"Broken res:// reference in {path.relative_to(ROOT)}: {ref}")

# Every locally used sound should be an actual, non-trivial WAV file.
for wav_path in sorted((ROOT / "assets" / "sounds").rglob("*.wav")):
    try:
        with wave.open(str(wav_path), "rb") as stream:
            frames = stream.getnframes()
            rate = stream.getframerate()
            if frames < int(rate * 0.05):
                errors.append(f"Audio file is too short: {wav_path.relative_to(ROOT)}")
            if stream.getnchannels() != 1 or stream.getsampwidth() != 2:
                errors.append(f"Expected mono 16-bit PCM audio: {wav_path.relative_to(ROOT)}")
    except (wave.Error, OSError) as exc:
        errors.append(f"Invalid WAV {wav_path.relative_to(ROOT)}: {exc}")

project = (ROOT / "project.godot").read_text(encoding="utf-8")
if 'run/main_scene="res://scenes/main.tscn"' not in project:
    errors.append("Main scene is not configured in project.godot")
if 'buses/default_bus_layout="res://assets/sounds/default_bus_layout.tres"' not in project:
    errors.append("Godot audio bus setting must use audio/buses/default_bus_layout")
if '\ndefault_bus_layout=' in project:
    errors.append("Legacy/incorrect default_bus_layout key found in project.godot")
if 'name="Android"' not in (ROOT / "export_presets.cfg").read_text(encoding="utf-8"):
    errors.append("Android export preset name must be exactly Android")
export_preset = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
if "version/min_sdk=28" not in export_preset or "version/target_sdk=35" not in export_preset:
    errors.append("Android export preset must target min SDK 28 and target SDK 35")
workflow = (ROOT / ".github/workflows/build.yml").read_text(encoding="utf-8")
if '"ndk;23.2.8568313"' not in workflow:
    errors.append("Godot 4.4.1 Android workflow should use the compatible NDK r23c package")
if 'textures/vram_compression/import_etc2_astc=true' not in project:
    errors.append("Android ETC2/ASTC texture compression must be declared in project.godot")
if "Run gameplay sanity checks" not in workflow:
    errors.append("GitHub Actions must run the deterministic gameplay smoke checks")

# Guard against regressions in the mobile-driving path. A previous HUD version
# read nitro_bar.value without ever constructing nitro_bar; the runtime error
# aborted HUD _process() before set_inputs(), making all driving controls inert.
hud_path = ROOT / "scripts" / "ui" / "driving_hud.gd"
hud_source = hud_path.read_text(encoding="utf-8") if hud_path.is_file() else ""
if "nitro_bar = ProgressBar.new()" not in hud_source:
    errors.append("Driving HUD must instantiate its nitro charge ProgressBar")
else:
    process_start = hud_source.find("func _process(delta: float) -> void:")
    process_end = hud_source.find("\nfunc _toggle_pause()", process_start)
    process_body = hud_source[process_start:process_end] if process_start >= 0 and process_end > process_start else ""
    input_forward = process_body.find('vehicle.call("set_inputs"')
    nitro_update = process_body.find("nitro_bar.value = nitro_level")
    if input_forward < 0:
        errors.append("Driving HUD must forward input through vehicle.set_inputs()")
    elif nitro_update >= 0 and input_forward > nitro_update:
        errors.append("Driving HUD must forward controls before updating optional HUD widgets")

pedal_source = (ROOT / "scripts" / "ui" / "pedal_control.gd").read_text(encoding="utf-8")
if "InputEventScreenTouch" not in pedal_source or "_touch_index" not in pedal_source:
    errors.append("Mobile pedals must track touchscreen indices for simultaneous touch controls")
manager_source = (ROOT / "scripts" / "game_manager.gd").read_text(encoding="utf-8")
if 'race_manager.connect("race_started", _start_ai_opponents)' not in manager_source or 'opponent.call("setup_ai", centreline, speeds[index])' not in manager_source:
    errors.append("Race Mode must connect race start and initialize AI opponents")

car_source = (ROOT / "scripts" / "car_controller.gd").read_text(encoding="utf-8")
if "func get_fuel_percentage()" not in car_source or "func refuel()" not in car_source or "fuel_level = maxf(0.0" not in car_source:
    errors.append("Vehicle controller must implement fuel consumption, fuel telemetry, and refuelling")
if "FuelLevelBar" not in hud_source or "fuel_label" not in hud_source or "func _try_refuel()" not in hud_source:
    errors.append("Driving HUD must label the fuel gauge and provide a Free Drive refuelling action")
if "input_throttle > 0.01 and nitro_charge > 0.5" not in car_source:
    errors.append("Nitro must require throttle and available charge")
if 'res://assets/fonts/NotoSansArabic-Regular.ttf' not in manager_source:
    errors.append("Main UI must load the bundled Arabic font")
verify_source = (ROOT / "tools" / "verify_game.gd").read_text(encoding="utf-8")
for gameplay_check in ("four AI rivals", "Fuel did not decrease", "Nitro did not consume", "results screen", "Free Drive"):
    if gameplay_check not in verify_source:
        errors.append(f"Gameplay smoke test is missing a critical check: {gameplay_check}")

# The game uses three named audio buses. A blank/invalid layout silently
# routes them incorrectly and makes the individual volume settings ineffective.
bus_layout_path = ROOT / "assets" / "sounds" / "default_bus_layout.tres"
if not bus_layout_path.is_file() or bus_layout_path.stat().st_size < 100:
    errors.append("Audio bus layout is missing or empty: assets/sounds/default_bus_layout.tres")
else:
    bus_layout = bus_layout_path.read_text(encoding="utf-8")
    for bus_name in ("Master", "Engine", "SFX", "Music"):
        if f'&"{bus_name}"' not in bus_layout:
            errors.append(f"Audio bus layout is missing bus: {bus_name}")

# Avoid shipping empty scene/resource files, which can be overlooked by
# reference-only checks.
for path in ROOT.rglob("*"):
    if path.is_file() and path.suffix in {".gd", ".tscn", ".tres", ".wav"} and path.stat().st_size == 0:
        errors.append(f"Empty project asset: {path.relative_to(ROOT)}")

if errors:
    print("PROJECT PREFLIGHT FAILED:")
    for error in errors:
        print(" - " + error)
    sys.exit(1)

print("PROJECT PREFLIGHT PASSED")
print(f"Project: {ROOT.name}")
print(f"Local WAV assets: {len(list((ROOT / 'assets' / 'sounds').rglob('*.wav')))}")
print("Godot script parsing and APK export are verified separately by the GitHub Actions workflow.")
