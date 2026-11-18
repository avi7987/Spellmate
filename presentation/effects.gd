class_name Effects
extends RefCounted
## Small one-shot visual effects (particles, flashes, rings) on the board.


static func burst(parent: Node3D, pos: Vector3, color: Color, amount: int = 24, speed: float = 2.5, size: float = 0.08) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 0.7
	p.explosiveness = 0.95
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var mesh := SphereMesh.new()
	mesh.radius = size
	mesh.height = size * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	p.mesh = mesh
	p.material_override = Style.glow(color, 2.0)
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)


## Expanding ring on the ground (impact / magic circle).
static func ring(parent: Node3D, pos: Vector3, color: Color, max_scale: float = 1.2, duration: float = 0.45) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.32
	t.outer_radius = 0.42
	mi.mesh = t
	var mat := Style.overlay(color)
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.12, 0)
	mi.scale = Vector3.ONE * 0.2
	parent.add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * max_scale, duration).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.chain().tween_callback(mi.queue_free)


## Short flash of a coloured square overlay.
static func square_flash(parent: Node3D, pos: Vector3, color: Color, duration: float = 0.4) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	mi.mesh = plane
	var mat := Style.overlay(color)
	mi.material_override = mat
	mi.position = pos + Vector3(0, 0.11, 0)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, duration)
	tw.tween_callback(mi.queue_free)


## A tall column of light that shoots up and fades (power casts).
static func pillar(parent: Node3D, pos: Vector3, color: Color, height: float = 6.0, duration: float = 0.9) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.35
	c.bottom_radius = 0.45
	c.height = height
	mi.mesh = c
	var mat := Style.overlay(Color(color.r, color.g, color.b, 0.75))
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = mat
	mi.position = pos + Vector3(0, height * 0.5, 0)
	mi.scale = Vector3(0.1, 1, 0.1)
	parent.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.2, 1, 1.2), duration * 0.25).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, duration).set_delay(duration * 0.2)
	tw.tween_callback(mi.queue_free)


## A wide ring blasting outward along the ground.
static func shockwave(parent: Node3D, pos: Vector3, color: Color, radius: float = 3.0, duration: float = 0.6) -> void:
	ring(parent, pos, color, radius / 0.42, duration)
	burst(parent, pos + Vector3(0, 0.2, 0), color, 40, 4.0, 0.07)


## Lots of particles raining down over an area (frost storm, fire storm).
static func storm(parent: Node3D, pos: Vector3, color: Color, size: float = 1.6, amount: int = 60) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 1.0
	p.explosiveness = 0.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(size, 0.2, size)
	p.direction = Vector3.DOWN
	p.spread = 15.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -4, 0)
	var mesh := SphereMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.12
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	p.material_override = Style.glow(color, 2.5)
	p.position = pos + Vector3(0, 3.0, 0)
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
