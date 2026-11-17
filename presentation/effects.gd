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
