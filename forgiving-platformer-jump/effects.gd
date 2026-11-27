class_name Effects
extends RefCounted
## Small effects: the ripple and droplets when something drops into the cocoa, and the stars that
## circle a dazed head.

const RING := preload("res://ring.gdshader")
const COCOA_DROP := Color(0.22, 0.1, 0.05)


## An expanding ripple on the lake surface at a point.
static func ripple(parent: Node3D, at: Vector3, size := 5.0, seconds := 1.8) -> void:
	var instance := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.orientation = PlaneMesh.FACE_Y
	instance.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = RING
	instance.material_override = material
	parent.add_child(instance)
	instance.global_position = at + Vector3(0.0, 0.02, 0.0)
	var tween := instance.create_tween()
	material.set_shader_parameter(&"progress", 0.0)
	tween.tween_property(material, "shader_parameter/progress", 1.0, seconds)
	tween.tween_callback(instance.queue_free)


## Droplets of cocoa thrown up from a splash. One shot, with a fixed seed, so every splash looks
## the same.
static func droplets(parent: Node3D, at: Vector3, power := 1.0) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.amount = 36
	particles.lifetime = 1.4
	particles.one_shot = true
	particles.explosiveness = 0.95
	particles.use_fixed_seed = true
	particles.seed = 4
	particles.fixed_fps = 60
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 32.0
	process.initial_velocity_min = 2.6 * power
	process.initial_velocity_max = 5.4 * power
	process.gravity = Vector3(0.0, -11.0, 0.0)
	process.scale_min = 0.5
	process.scale_max = 1.3
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.25
	particles.process_material = process
	var drop := SphereMesh.new()
	drop.radius = 0.06
	drop.height = 0.12
	drop.radial_segments = 12
	drop.rings = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = COCOA_DROP
	material.roughness = 0.08
	material.emission_enabled = true
	material.emission = Color(0.3, 0.14, 0.07)
	drop.material = material
	particles.draw_pass_1 = drop
	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


## A five-pointed star, flat, facing the camera along +z.
static func star_mesh(outer := 0.09, inner := 0.04) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.BACK)
	for i in 10:
		var a := float(i) / 10.0 * TAU + PI * 0.5
		var r := outer if i % 2 == 0 else inner
		vertices.append(Vector3(cos(a) * r, sin(a) * r, 0.0))
		normals.append(Vector3.BACK)
	for i in 10:
		indices.append_array([0, 1 + i, 1 + (i + 1) % 10])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
