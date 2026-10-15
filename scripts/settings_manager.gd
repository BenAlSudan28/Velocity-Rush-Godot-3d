extends RefCounted

static func apply_graphics(viewport: Viewport, quality: String, light: DirectionalLight3D = null) -> void:
    if quality == "low":
        viewport.msaa_3d = Viewport.MSAA_DISABLED
        if is_instance_valid(light):
            light.shadow_enabled = false
    else:
        viewport.msaa_3d = Viewport.MSAA_2X
        if is_instance_valid(light):
            light.shadow_enabled = true

static func apply_default_audio() -> void:
    if is_instance_valid(AudioManager):
        AudioManager.apply_settings()
