extends RefCounted
## The demo's particle effects, built in code. Every emitter is one-shot and uses a fixed
## seed, so the same hit sprays the same sparks on every run.


## Sparks off the bucket: hot streaks that fly along their velocity and fall, a star-shaped
## flash at the point of contact, and a little tin dust.
static func make_sparks() -> PackedScene:
	var sparks := _streaks(26, 0.55, Color(1.0, 0.66, 0.22), 7.0, Vector2(3.5, 8.5), Vector3(0.016, 0.22, 0.016))
	sparks.name = "Sparks"
	var flash := GPUParticles3D.new()
	flash.name = "Flash"
	flash.emitting = false
	flash.one_shot = true
	flash.amount = 1
	flash.lifetime = 0.09
	flash.explosiveness = 1.0
	var still := ParticleProcessMaterial.new()
	still.gravity = Vector3.ZERO
	still.scale_curve = _curve(1.0, 0.3)
	flash.process_material = still
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.7)
	var glow := ShaderMaterial.new()
	glow.shader = load("res://flash.gdshader")
	glow.set_shader_parameter(&"energy", 7.0)
	quad.material = glow
	flash.draw_pass_1 = quad
	sparks.add_child(flash)
	var dust := _puffs(5, 0.7, Color(0.9, 0.86, 0.8, 0.4), Vector2(0.4, 1.1), 0.2)
	dust.name = "Dust"
	sparks.add_child(dust)
	return _pack(sparks)


## A puff of yard dust, for the bucket landing and the dummy hitting the ground.
static func make_dust() -> PackedScene:
	var dust := _puffs(7, 0.9, Color(0.8, 0.66, 0.46, 0.5), Vector2(0.5, 1.4), 0.34)
	dust.name = "Dust"
	return _pack(dust)


static func _streaks(amount: int, lifetime: float, color: Color, glow: float, speed: Vector2,
		size: Vector3) -> GPUParticles3D:
	var particles := _emitter(amount, lifetime)
	var motion := particles.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 28.0
	motion.initial_velocity_min = speed.x
	motion.initial_velocity_max = speed.y
	motion.gravity = Vector3(0.0, -9.8, 0.0)
	motion.scale_min = 0.6
	motion.scale_max = 1.2
	motion.scale_curve = _curve(1.0, 0.2)
	# Point each streak's Y axis along its velocity.
	motion.particle_flag_align_y = true
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	if glow > 0.0:
		# Emissive particles reach the environment glow threshold.
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = color * glow
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles


static func _puffs(amount: int, lifetime: float, color: Color, speed: Vector2,
		size: float) -> GPUParticles3D:
	var particles := _emitter(amount, lifetime)
	particles.explosiveness = 0.85
	var motion := particles.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 40.0
	motion.initial_velocity_min = speed.x
	motion.initial_velocity_max = speed.y
	motion.gravity = Vector3.ZERO
	motion.damping_min = 2.0
	motion.damping_max = 3.0
	motion.angle_min = -180.0
	motion.angle_max = 180.0
	motion.scale_min = 0.7
	motion.scale_max = 1.3
	motion.scale_curve = _curve(0.6, 1.8)
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


static func _curve(from: float, to: float) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = maxf(from, to)
	curve.add_point(Vector2(0.0, from))
	curve.add_point(Vector2(1.0, to))
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
