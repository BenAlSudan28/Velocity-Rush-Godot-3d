extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run_checks")

func _run_checks() -> void:
    var packed := load("res://scenes/main.tscn") as PackedScene
    if packed == null:
        _fail("Could not load scenes/main.tscn")
        quit(1)
        return

    var game := packed.instantiate()
    root.add_child(game)
    await process_frame

    if str(game.get("current_screen")) != "menu":
        _fail("The main scene did not open on the menu.")

    game.call("_start_game", "race")
    await process_frame
    var rivals: Array = game.get("ai_opponents")
    var player: Node = game.get("player_car")
    var race: Node = game.get("race_manager")
    var hud: Control = game.get("hud")
    if rivals.size() != 4:
        _fail("Race Mode should spawn four AI rivals; got %d." % rivals.size())
    if not is_instance_valid(player) or not is_instance_valid(race) or not is_instance_valid(hud):
        _fail("Race Mode did not create its player car or race manager.")
        quit(1)
        return

    race.set("countdown", 0.01)
    race.call("tick", 0.02)
    for rival in rivals:
        if is_instance_valid(rival) and not bool(rival.get("ai_active")):
            _fail("An AI rival did not activate after the race countdown.")
            break

    var distance_before := float(player.get("distance_travelled"))
    var fuel_before := float(player.get("fuel_level"))
    hud.set("throttle_value", 1.0)
    for _frame in range(120):
        await physics_frame
    var distance_after := float(player.get("distance_travelled"))
    var fuel_after := float(player.get("fuel_level"))
    if distance_after <= distance_before + 1.0:
        _fail("Throttle did not move the car along the track.")
    if fuel_after >= fuel_before:
        _fail("Fuel did not decrease while accelerating.")

    var nitro_before := float(player.get("nitro_charge"))
    hud.set("nitro_active", true)
    for _frame in range(30):
        await physics_frame
    var nitro_after := float(player.get("nitro_charge"))
    if nitro_after >= nitro_before:
        _fail("Nitro did not consume charge while accelerating.")
    hud.set("throttle_value", 0.0)
    hud.set("nitro_active", false)
    player.call("set_inputs", 0.0, 0.0, 0.0, true)
    if bool(player.get("input_nitro")):
        _fail("Nitro should not be consumed without throttle.")

    player.set("speed_mps", 0.0)
    player.set("fuel_level", 22.0)
    if not bool(player.call("refuel")) or float(player.get("fuel_level")) < 99.9:
        _fail("Stopped refuelling did not restore the fuel tank.")

    race.call("finish_race")
    await process_frame
    if str(game.get("current_screen")) != "results":
        _fail("Finishing a race did not show the results screen.")

    game.call("_show_main_menu")
    await process_frame
    game.call("_start_game", "free_drive")
    await process_frame
    var free_drive_rivals: Array = game.get("ai_opponents")
    if not free_drive_rivals.is_empty():
        _fail("Free Drive should not create race-grid rivals.")

    if failures.is_empty():
        print("GAMEPLAY CHECKS PASSED: menu, four rivals, AI start, car movement, fuel burn/refuel, nitro, results, free drive.")
        game.queue_free()
        await process_frame
        quit(0)
        return

    for failure in failures:
        push_error(failure)
    game.queue_free()
    await process_frame
    quit(1)

func _fail(message: String) -> void:
    failures.append(message)
