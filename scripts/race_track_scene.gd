extends Node3D

const EnvironmentBuilder = preload("res://scripts/environment_builder.gd")

var track_config: Dictionary = {}

func _ready() -> void:
    var builder = EnvironmentBuilder.new()
    track_config = builder.build_track(self)
