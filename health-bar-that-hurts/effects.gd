extends RefCounted
## The demo's particle effects, built in code. Every emitter is one-shot and uses a fixed seed,
## so the same hit puffs the same way on every run.

const IMPACT := preload("res://impact.gdshader")


## A comic impact star and a puff of felt fuzz, where a ball bonks the plush.
static func make_bonk() -> PackedScene:
	var root := _puffs(9, 0.7, Color(0.86, 0.95, 0.3, 0.55), Vector2(0.6, 1.8), 0.16)
	root.name = "Fuzz"
	var star := GPUParticles3D.new()
	star.name = "Star"
	star.emitting = false
	star.one_shot = true
	star.amount = 1
	star.lifetime = 0.2
	star.explosiveness = 1.0
	star.use_fixed_seed = true
	var still := ParticleProcessMaterial.new()
	still.gravity = Vector3.ZERO
	still.scale_curve = _curve([Vector2(0.0, 0.3), Vector2(0.25, 1.15), Vector2(1.0, 0.7)])
	star.process_material = still
	var quad := QuadMesh.new()
	quad.size = Vector2(0.75, 0.75)
	var material := ShaderMaterial.new()
	material.shader = IMPACT
	quad.material = material
	star.draw_pass_1 = quad
	root.add_child(star)
	return _pack(root)


## A soft cream puff, where a ball lands in the cushions.
static func make_dust() -> PackedScene:
	return _pack(_puffs(7, 0.8, Color(1.0, 0.94, 0.82, 0.5), Vector2(0.5, 1.3), 0.22))


## A little white puff from the barrel when the ball leaves it.
static func make_muzzle() -> PackedScene:
	return _pack(_puffs(8, 0.55, Color(1.0, 1.0, 1.0, 0.6), Vector2(0.8, 2.0), 0.14))


## Nervous sweat: a few drops flung up and out of the head, then falling.
static func make_sweat() -> GPUParticles3D:
	var drops := _emitter(5, 0.95)
	drops.explosiveness = 0.9
	var motion := drops.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 75.0
	motion.initial_velocity_min = 0.7
	motion.initial_velocity_max = 1.5
	motion.gravity = Vector3(0.0, -7.5, 0.0)
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.34
	motion.scale_min = 0.8
	motion.scale_max = 1.3
	var drop := SphereMesh.new()
	drop.radius = 0.034
	drop.height = 0.1
	drop.radial_segments = 16
	drop.rings = 10
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.62, 0.86, 1.0, 0.9)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.05
	material.emission_enabled = true
	material.emission = Color(0.4, 0.7, 1.0)
	material.emission_energy_multiplier = 0.5
	drop.material = material
	drops.draw_pass_1 = drop
	drops.name = "Sweat"
	return drops


static func _puffs(amount: int, lifetime: float, color: Color, speed: Vector2, size: float) -> GPUParticles3D:
	var particles := _emitter(amount, lifetime)
	particles.explosiveness = 0.85
	var motion := particles.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 55.0
	motion.initial_velocity_min = speed.x
	motion.initial_velocity_max = speed.y
	motion.gravity = Vector3.ZERO
	motion.damping_min = 2.0
	motion.damping_max = 3.0
	motion.angle_min = -180.0
	motion.angle_max = 180.0
	motion.scale_min = 0.7
	motion.scale_max = 1.3
	motion.scale_curve = _curve([Vector2(0.0, 0.6), Vector2(1.0, 1.8)])
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	motion.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = color
	material.albedo_texture = _soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


static func _emitter(amount: int, lifetime: float) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0
	particles.use_fixed_seed = true
	particles.process_material = ParticleProcessMaterial.new()
	return particles


static func _curve(points: Array) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 2.0
	for point: Vector2 in points:
		curve.add_point(point)
	var texture := CurveTexture.new()
	texture.curve = curve
	return texture


static func _soft_dot() -> GradientTexture2D:
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1, 1, 1, 1))
	falloff.set_color(1, Color(1, 1, 1, 0))
	var dot := GradientTexture2D.new()
	dot.gradient = falloff
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	return dot


static func _pack(root: Node) -> PackedScene:
	for child in root.get_children():
		child.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	return scene
