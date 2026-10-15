extends RefCounted

const ROAD_WIDTH := 12.0

var _rng := RandomNumberGenerator.new()

func build_menu(world: Node3D) -> void:
    _rng.seed = 84127
    _add_ground(world, 260.0, Color(0.025, 0.055, 0.064))
    var asphalt := _mat(Color(0.045, 0.055, 0.067), 0.08, 0.82)
    _add_box(world, "ShowroomLane", Vector3(28.0, 0.12, 75.0), Vector3(0.0, 0.0, -30.0), asphalt, false)
    var stripe := _mat(Color(0.03, 0.82, 0.89), 0.28, 0.26, true)
    for z in range(-65, 9, 9):
        _add_box(world, "LaneDash", Vector3(0.18, 0.025, 4.2), Vector3(0.0, 0.075, float(z)), stripe, false)
    var gold := _mat(Color(1.0, 0.54, 0.12), 0.45, 0.26, true)
    _add_box(world, "ShowroomAccent", Vector3(0.18, 0.04, 58.0), Vector3(-14.3, 0.08, -30.0), gold, false)
    _add_box(world, "ShowroomAccent2", Vector3(0.18, 0.04, 58.0), Vector3(14.3, 0.08, -30.0), stripe, false)
    _build_skyline(world, true)

func build_track(world: Node3D) -> Dictionary:
    _rng.seed = 671923
    _add_ground(world, 430.0, Color(0.34, 0.49, 0.30))
    # A closed, smooth circuit. The start point is on the eastern straight,
    # with the first segment heading toward -Z to match the car's forward axis.
    var controls: Array[Vector2] = [
        Vector2(50, -20), Vector2(50, -45), Vector2(28, -65),
        Vector2(0, -70), Vector2(-30, -60), Vector2(-50, -35),
        Vector2(-55, -5), Vector2(-45, 25), Vector2(-20, 40),
        Vector2(10, 40), Vector2(35, 25), Vector2(50, 0)
    ]
    var centreline := _smooth_loop(controls, 9)
    _create_ground_collision(world)
    _create_road(world, centreline, ROAD_WIDTH)
    _add_track_markings(world, centreline)
    _add_barriers(world, centreline, ROAD_WIDTH)
    _add_city_along_track(world, centreline)
    _build_skyline(world, false)
    _add_start_gate(world, centreline[0])
    return {
        "start_position": Vector3(centreline[0].x, 0.02, centreline[0].z),
        "track_length": _measure_path(centreline),
        "target_distance": 850.0,
        "centreline": centreline
    }

func _smooth_loop(points: Array[Vector2], steps: int) -> Array[Vector3]:
    var output: Array[Vector3] = []
    var count := points.size()
    for i in range(count):
        var p0: Vector2 = points[(i - 1 + count) % count]
        var p1: Vector2 = points[i]
        var p2: Vector2 = points[(i + 1) % count]
        var p3: Vector2 = points[(i + 2) % count]
        for j in range(steps):
            var t := float(j) / float(steps)
            var t2 := t * t
            var t3 := t2 * t
            var point := 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
            output.append(Vector3(point.x, 0.055, point.y))
    return output

func _create_road(world: Node3D, points: Array[Vector3], width: float) -> void:
    var road_mat := _mat(Color(0.24, 0.26, 0.30), 0.02, 0.84)
    # Procedural road winding can vary around tight curves; disable back-face culling
    # so the asphalt remains visible even if a triangle winding is reversed.
    road_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    var road_st := SurfaceTool.new()
    road_st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var half := width * 0.5
    for i in range(points.size()):
        var prev: Vector3 = points[(i - 1 + points.size()) % points.size()]
        var next: Vector3 = points[(i + 1) % points.size()]
        var tangent := (next - prev).normalized()
        var normal := Vector3(-tangent.z, 0.0, tangent.x).normalized()
        var next_index: int = (i + 1) % points.size()
        var prev_normal := normal
        var tangent_next := (points[(next_index + 1) % points.size()] - points[i]).normalized()
        var next_normal := Vector3(-tangent_next.z, 0.0, tangent_next.x).normalized()
        var left0 := points[i] + prev_normal * half
        var right0 := points[i] - prev_normal * half
        var left1 := points[next_index] + next_normal * half
        var right1 := points[next_index] - next_normal * half
        road_st.set_normal(Vector3.UP)
        road_st.set_uv(Vector2(0, float(i) * 0.5))
        road_st.add_vertex(left0)
        road_st.set_normal(Vector3.UP)
        road_st.set_uv(Vector2(0, float(i + 1) * 0.5))
        road_st.add_vertex(left1)
        road_st.set_normal(Vector3.UP)
        road_st.set_uv(Vector2(1, float(i) * 0.5))
        road_st.add_vertex(right0)
        road_st.set_normal(Vector3.UP)
        road_st.set_uv(Vector2(1, float(i) * 0.5))
        road_st.add_vertex(right0)
        road_st.set_normal(Vector3.UP)
        road_st.set_uv(Vector2(0, float(i + 1) * 0.5))
        road_st.add_vertex(left1)
        road_st.set_normal(Vector3.UP)
        road_st.set_uv(Vector2(1, float(i + 1) * 0.5))
        road_st.add_vertex(right1)
    var road_mesh := road_st.commit()
    var road_body := StaticBody3D.new()
    road_body.name = "CurvedRoadCollision"
    world.add_child(road_body)
    var road_instance := MeshInstance3D.new()
    road_instance.name = "CurvedAsphalt"
    road_instance.mesh = road_mesh
    road_instance.material_override = road_mat
    road_body.add_child(road_instance)
    var shape := CollisionShape3D.new()
    shape.shape = road_mesh.create_trimesh_shape()
    road_body.add_child(shape)

func _add_track_markings(world: Node3D, points: Array[Vector3]) -> void:
    var dash_mat := _mat(Color(1.0, 0.91, 0.55), 0.05, 0.48, true)
    var edge_mat := _mat(Color(0.97, 0.98, 1.0), 0.03, 0.48)
    for i in range(0, points.size(), 5):
        var a: Vector3 = points[i]
        var b: Vector3 = points[(i + 1) % points.size()]
        var dir := (b - a).normalized()
        var yaw := atan2(-dir.x, -dir.z)
        var mid := (a + b) * 0.5
        mid.y = 0.082
        var dash_length := minf(1.35, a.distance_to(b) * 0.90)
        var dash := BoxMesh.new()
        dash.size = Vector3(0.13, 0.025, dash_length)
        var dash_node := MeshInstance3D.new()
        dash_node.name = "LaneDash"
        dash_node.mesh = dash
        dash_node.material_override = dash_mat
        dash_node.position = mid
        dash_node.rotation.y = yaw
        world.add_child(dash_node)
        if i % 10 == 0:
            var tangent := (b - a).normalized()
            var normal := Vector3(-tangent.z, 0.0, tangent.x).normalized()
            for side in [-1.0, 1.0]:
                var edge := BoxMesh.new()
                edge.size = Vector3(0.11, 0.025, 3.0)
                var edge_node := MeshInstance3D.new()
                edge_node.name = "RoadEdgeMark"
                edge_node.mesh = edge
                edge_node.material_override = edge_mat
                edge_node.position = mid + normal * (ROAD_WIDTH * 0.5 - 0.16) * side
                edge_node.position.y = 0.085
                edge_node.rotation.y = yaw
                world.add_child(edge_node)

func _add_barriers(world: Node3D, points: Array[Vector3], width: float) -> void:
    var metal := _mat(Color(0.36, 0.43, 0.48), 0.7, 0.32)
    var red := _mat(Color(0.78, 0.09, 0.11), 0.18, 0.38)
    var white := _mat(Color(0.88, 0.91, 0.90), 0.18, 0.35)
    for i in range(0, points.size(), 2):
        var a: Vector3 = points[i]
        var b: Vector3 = points[(i + 2) % points.size()]
        var direction := (b - a).normalized()
        var side_normal := Vector3(-direction.z, 0.0, direction.x).normalized()
        var yaw := atan2(-direction.x, -direction.z)
        var length := maxf(1.0, a.distance_to(b) + 0.15)
        var middle := (a + b) * 0.5
        for side in [-1.0, 1.0]:
            var barrier := StaticBody3D.new()
            barrier.name = "SafetyBarrier"
            barrier.position = middle + side_normal * (width * 0.5 + 0.43) * side
            barrier.position.y = 0.40
            barrier.rotation.y = yaw
            world.add_child(barrier)
            var box := BoxMesh.new()
            box.size = Vector3(0.34, 0.72, length)
            var mesh := MeshInstance3D.new()
            mesh.mesh = box
            mesh.material_override = red if (i / 2) % 2 == 0 else white
            barrier.add_child(mesh)
            var collision := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = box.size
            collision.shape = shape
            barrier.add_child(collision)
            if i % 14 == 0:
                var post := _mat_mesh_box("BarrierPost", Vector3(0.18, 0.85, 0.20), Vector3(0, 0.18, -length * 0.36), metal)
                barrier.add_child(post)

func _add_city_along_track(world: Node3D, points: Array[Vector3]) -> void:
    var building_colors: Array[Color] = [Color("#d9e3ea"), Color("#b8ccd9"), Color("#e8d3bd"), Color("#b8d2c8"), Color("#d8c5d4"), Color("#c5d0e3")]
    var window_mat := _mat(Color(0.08, 0.63, 0.88), 0.18, 0.25, true)
    var shop_sign := _mat(Color(1.0, 0.48, 0.12), 0.08, 0.35, true)
    var tree_trunk := _mat(Color(0.19, 0.105, 0.065), 0.0, 0.9)
    var tree_leaf := _mat(Color(0.13, 0.43, 0.19), 0.02, 0.78)
    var lamp_mat := _mat(Color(0.33, 0.40, 0.46), 0.67, 0.3)
    var lamp_light := _mat(Color(0.84, 0.94, 1.0), 0.1, 0.3, true)
    # Sample more frequently and base decoration spacing on the sample index,
    # not the raw point index. The old step of 6 made the lamp/tree modulo
    # branches unreachable except where a building branch took priority.
    var sample_index := 0
    for i in range(0, points.size(), 3):
        var p: Vector3 = points[i]
        var next: Vector3 = points[(i + 1) % points.size()]
        var direction := (next - p).normalized()
        var normal := Vector3(-direction.z, 0.0, direction.x).normalized()
        for side in [-1.0, 1.0]:
            var base: Vector3 = p + normal * (ROAD_WIDTH * 0.5 + _rng.randf_range(9.0, 19.0)) * side
            base.y = 0.0
            if sample_index % 5 == 0:
                var bw := _rng.randf_range(5.5, 10.0)
                var bh := _rng.randf_range(7.0, 21.0)
                var bd := _rng.randf_range(5.0, 9.0)
                var building_mat := _mat(building_colors[_rng.randi_range(0, building_colors.size() - 1)], 0.16, 0.72)
                _add_box(world, "CityBuilding", Vector3(bw, bh, bd), base + Vector3(0, bh * 0.5, 0), building_mat, true)
                # Windows on all four facades keep the city readable from bends.
                var window_y_start := 1.0
                for floor_index in range(1, int(bh / 2.8)):
                    for column in range(2):
                        var wx := base.x + (float(column) - 0.5) * bw * 0.52
                        var wz_front := base.z + bd * 0.5 + 0.025
                        var wz_back := base.z - bd * 0.5 - 0.025
                        var wy := float(floor_index) * 2.45 + window_y_start
                        _add_box(world, "LitWindow", Vector3(0.75, 0.85, 0.06), Vector3(wx, wy, wz_front), window_mat, false)
                        _add_box(world, "LitWindow", Vector3(0.75, 0.85, 0.06), Vector3(wx, wy, wz_back), window_mat, false)
                        var wx_left := base.x - bw * 0.5 - 0.025
                        var wx_right := base.x + bw * 0.5 + 0.025
                        var side_z := base.z + (float(column) - 0.5) * bd * 0.52
                        var left_window := _add_box(world, "LitWindow", Vector3(0.06, 0.85, 0.75), Vector3(wx_left, wy, side_z), window_mat, false)
                        var right_window := _add_box(world, "LitWindow", Vector3(0.06, 0.85, 0.75), Vector3(wx_right, wy, side_z), window_mat, false)
                        left_window.rotation.y = 0.0
                        right_window.rotation.y = 0.0
                if sample_index % 10 == 0:
                    _add_box(world, "StorefrontCanopy", Vector3(bw * 0.82, 0.34, 0.65), base + Vector3(0, 2.0, bd * 0.5 + 0.30), shop_sign, false)
            elif sample_index % 3 == 0:
                _add_lamp(world, base, lamp_mat, lamp_light)
            elif sample_index % 2 == 0:
                _add_tree(world, base, tree_trunk, tree_leaf)
            elif sample_index % 7 == 0:
                _add_pedestrian(world, base, Color(0.20 + _rng.randf() * 0.7, 0.18 + _rng.randf() * 0.6, 0.16 + _rng.randf() * 0.75))
        sample_index += 1
    # A handful of parked traffic vehicles give the roadside depth without adding AI claims.
    for i in range(10):
        var p: Vector3 = points[(i * 9 + 7) % points.size()]
        var next: Vector3 = points[(i * 9 + 8) % points.size()]
        var direction := (next - p).normalized()
        var normal := Vector3(-direction.z, 0.0, direction.x).normalized()
        var parked := p + normal * (ROAD_WIDTH * 0.5 + 4.3) * (1.0 if i % 2 == 0 else -1.0)
        parked.y = 0.0
        _add_parked_car(world, parked, atan2(-direction.x, -direction.z), Color.from_string(["#dce4eb", "#1ca6a9", "#9d263d", "#d3a63b"][i % 4], Color.WHITE))

func _build_skyline(world: Node3D, menu: bool) -> void:
    var palette: Array[Color] = [Color("#9fb9cf"), Color("#b8cad8"), Color("#8fa9bd"), Color("#c2cfda"), Color("#9bb6c0")]
    var start_z := -68.0 if menu else -125.0
    var count := 30 if menu else 42
    for i in range(count):
        var x := _rng.randf_range(-145.0, 145.0)
        var z := start_z - _rng.randf_range(0.0, 115.0)
        var h := _rng.randf_range(13.0, 45.0)
        var w := _rng.randf_range(7.0, 16.0)
        var d := _rng.randf_range(8.0, 19.0)
        var mat := _mat(palette[_rng.randi_range(0, palette.size() - 1)], 0.08, 0.8)
        _add_box(world, "DistantSkyline", Vector3(w, h, d), Vector3(x, h * 0.5 - 0.04, z), mat, false)

func _add_start_gate(world: Node3D, at: Vector3) -> void:
    var frame_mat := _mat(Color(0.14, 0.18, 0.23), 0.64, 0.3)
    var neon := _mat(Color(0.07, 0.85, 0.96), 0.15, 0.25, true)
    _add_box(world, "StartGateTop", Vector3(ROAD_WIDTH + 1.2, 0.22, 0.34), at + Vector3(0, 5.0, -7.0), frame_mat, false)
    _add_box(world, "StartGateLeft", Vector3(0.24, 5.0, 0.34), at + Vector3(-ROAD_WIDTH * 0.5, 2.5, -7.0), frame_mat, false)
    _add_box(world, "StartGateRight", Vector3(0.24, 5.0, 0.34), at + Vector3(ROAD_WIDTH * 0.5, 2.5, -7.0), frame_mat, false)
    _add_box(world, "StartGateNeon", Vector3(ROAD_WIDTH - 1.0, 0.12, 0.40), at + Vector3(0, 4.82, -7.0), neon, false)

func _add_ground(world: Node3D, size: float, color: Color) -> void:
    var plane := PlaneMesh.new()
    plane.size = Vector2(size, size)
    var ground := MeshInstance3D.new()
    ground.name = "LandscapeGround"
    ground.mesh = plane
    ground.material_override = _mat(color, 0.0, 1.0)
    ground.position.y = -0.20
    world.add_child(ground)

func _create_ground_collision(world: Node3D) -> void:
    var ground_body := StaticBody3D.new()
    ground_body.name = "GroundCollision"
    ground_body.position.y = -0.20
    world.add_child(ground_body)
    var collision := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(440.0, 0.30, 440.0)
    collision.shape = shape
    ground_body.add_child(collision)

func _add_tree(world: Node3D, at: Vector3, trunk_mat: Material, leaves_mat: Material) -> void:
    var trunk := CylinderMesh.new()
    trunk.top_radius = 0.15
    trunk.bottom_radius = 0.23
    trunk.height = 2.2
    trunk.radial_segments = 7
    var trunk_node := MeshInstance3D.new()
    trunk_node.mesh = trunk
    trunk_node.material_override = trunk_mat
    trunk_node.position = at + Vector3(0, 1.1, 0)
    world.add_child(trunk_node)
    var foliage := SphereMesh.new()
    foliage.radius = _rng.randf_range(1.0, 1.55)
    foliage.height = foliage.radius * 2.0
    foliage.radial_segments = 8
    foliage.rings = 5
    var leaf_node := MeshInstance3D.new()
    leaf_node.mesh = foliage
    leaf_node.material_override = leaves_mat
    leaf_node.position = at + Vector3(0, 2.7, 0)
    leaf_node.scale = Vector3(0.95, 1.2, 0.95)
    world.add_child(leaf_node)

func _add_lamp(world: Node3D, at: Vector3, metal_mat: Material, light_mat: Material) -> void:
    var pole := CylinderMesh.new()
    pole.top_radius = 0.055
    pole.bottom_radius = 0.085
    pole.height = 5.4
    pole.radial_segments = 8
    var pole_node := MeshInstance3D.new()
    pole_node.mesh = pole
    pole_node.material_override = metal_mat
    pole_node.position = at + Vector3(0, 2.7, 0)
    world.add_child(pole_node)
    _add_box(world, "LampArm", Vector3(1.15, 0.08, 0.10), at + Vector3(0.48, 5.25, 0), metal_mat, false)
    _add_box(world, "LampGlow", Vector3(0.40, 0.10, 0.25), at + Vector3(0.94, 5.18, 0), light_mat, false)

func _add_pedestrian(world: Node3D, at: Vector3, color: Color) -> void:
    var person_mat := _mat(color, 0.02, 0.8)
    var skin_mat := _mat(Color("#c78a61"), 0.0, 0.9)
    var body := CapsuleMesh.new()
    body.radius = 0.20
    body.height = 1.15
    body.radial_segments = 6
    var body_node := MeshInstance3D.new()
    body_node.mesh = body
    body_node.material_override = person_mat
    body_node.position = at + Vector3(0, 0.74, 0)
    world.add_child(body_node)
    var head := SphereMesh.new()
    head.radius = 0.15
    head.height = 0.30
    head.radial_segments = 8
    var head_node := MeshInstance3D.new()
    head_node.mesh = head
    head_node.material_override = skin_mat
    head_node.position = at + Vector3(0, 1.43, 0)
    world.add_child(head_node)

func _add_parked_car(world: Node3D, at: Vector3, yaw: float, color: Color) -> void:
    var material := _mat(color, 0.38, 0.32)
    var dark := _mat(Color(0.025, 0.035, 0.05), 0.12, 0.2)
    var mesh_body := BoxMesh.new()
    mesh_body.size = Vector3(1.65, 0.48, 3.4)
    var body := MeshInstance3D.new()
    body.mesh = mesh_body
    body.material_override = material
    body.position = at + Vector3(0, 0.52, 0)
    body.rotation.y = yaw
    world.add_child(body)
    var cabin := BoxMesh.new()
    cabin.size = Vector3(1.20, 0.42, 1.55)
    var top := MeshInstance3D.new()
    top.mesh = cabin
    top.material_override = dark
    top.position = at + Vector3(0, 0.89, 0)
    top.rotation.y = yaw
    world.add_child(top)

func _add_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, material: Material, with_collision: bool) -> MeshInstance3D:
    var box := BoxMesh.new()
    box.size = size
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = box
    instance.material_override = material
    instance.position = at
    if with_collision:
        var body := StaticBody3D.new()
        body.name = node_name + "Body"
        body.position = at
        parent.add_child(body)
        instance.position = Vector3.ZERO
        body.add_child(instance)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = size
        collision.shape = shape
        body.add_child(collision)
    else:
        parent.add_child(instance)
    return instance

func _mat_mesh_box(node_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = at
    return instance

func _mat(color: Color, metallic: float, roughness: float, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = roughness
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.3
    return material

func _measure_path(points: Array[Vector3]) -> float:
    var total := 0.0
    for i in range(points.size()):
        total += points[i].distance_to(points[(i + 1) % points.size()])
    return total
