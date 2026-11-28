extends RefCounted
## The demo's particle effects, built in code. Every burst is one-shot and uses a fixed seed, so
## the same hit sprays the same way on every run. The dust motes are the only thing that drifts on
## its own, and they are seeded too.


## A soft cream puff where the chicken lands, so even a plain hit has a little weight.
static func make_puff() -> PackedScene:
	var puff := _puffs(6, 0.55, Color(1.0, 0.93, 0.8, 0.5), Vector2(0.5, 1.4), 0.34)
	puff.name = "Puff"
	return _pack(puff)


## The crit's burst: hot streaks thrown out in every direction, and a ring of round puffs.
static func make_crit_burst() -> PackedScene:
	var streaks := _streaks(36, 0.6, Color(1.0, 0.72, 0.16), 6.0, Vector2(2.5, 7.0), Vector3(0.02, 0.26, 0.02))
	streaks.name = "Streaks"
	var puffs := _puffs(8, 0.7, Color(1.0, 0.9, 0.55, 0.55), Vector2(1.2, 2.6), 0.5)
	puffs.name = "Puffs"
	streaks.add_child(puffs)
	return _pack(streaks)


## A drift of dust in the lantern light: tiny glowing specks that float slowly up.
static func make_motes(volume: Vector3, amount := 70) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Motes"
	particles.amount = amount
	particles.lifetime = 14.0
	particles.preprocess = 14.0
	particles.use_fixed_seed = true
	particles.seed = 20261128
	particles.visibility_aabb = AABB(-volume, volume * 2.0)
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = volume
	motion.direction = Vector3.UP
	motion.spread = 90.0
	motion.initial_velocity_min = 0.02
	motion.initial_velocity_max = 0.07
	motion.gravity = Vector3.ZERO
	motion.turbulence_enabled = true
	motion.turbulence_noise_strength = 0.2
	motion.turbulence_noise_scale = 1.5
	motion.scale_min = 0.5
	motion.scale_max = 1.3
	particles.process_material = motion
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = Color(1.0, 0.78, 0.45, 0.5)
	material.albedo_texture = _soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.03, 0.03)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


static func _streaks(amount: int, lifetime: float, color: Color, glow: float, speed: Vector2,
		size: Vector3) -> GPUParticles3D:
	var particles := _emitter(amount, lifetime)
	var motion := particles.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 180.0
	motion.initial_velocity_min = speed.x
	motion.initial_velocity_max = speed.y
	motion.gravity = Vector3(0.0, -6.0, 0.0)
	motion.scale_min = 0.6
	motion.scale_max = 1.3
	motion.scale_curve = _curve(1.0, 0.2)
	# Point each streak's Y axis along its velocity.
	motion.particle_flag_align_y = true
	var material := StandardMaterial3D.new()
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
	motion.spread = 70.0
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
