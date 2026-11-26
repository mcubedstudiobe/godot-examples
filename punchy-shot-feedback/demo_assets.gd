extends RefCounted
## Original placeholder assets generated from text source for the tutorial demo.

const SAMPLE_RATE := 22050


## Sparks for a wall hit: hot streaks that fly along their velocity and drop, a flash at
## the impact point, and a little dust. Every emitter is one-shot; restart them together.
static func make_sparks() -> PackedScene:
	var sparks := _streaks(16, 0.3, Color(1.0, 0.62, 0.2), 6.0, Vector2(3.0, 7.5), Vector3(0.018, 0.2, 0.018))
	sparks.name = "Sparks"
	var flash := GPUParticles3D.new()
	flash.name = "Flash"
	flash.emitting = false
	flash.one_shot = true
	flash.amount = 1
	flash.lifetime = 0.07
	flash.explosiveness = 1.0
	var still := ParticleProcessMaterial.new()
	still.gravity = Vector3.ZERO
	still.scale_curve = _curve(1.0, 0.3)
	flash.process_material = still
	var quad := QuadMesh.new()
	quad.size = Vector2(0.55, 0.55)
	var glow := ShaderMaterial.new()
	glow.shader = load("res://flash.gdshader")
	glow.set_shader_parameter(&"energy", 6.0)
	quad.material = glow
	flash.draw_pass_1 = quad
	sparks.add_child(flash)
	var dust := _puffs(5, 0.7, Color(0.86, 0.72, 0.55, 0.5), Vector2(0.4, 1.2), 0.22)
	dust.name = "Dust"
	sparks.add_child(dust)
	return _pack(sparks)


## Paint droplets for a body hit: they streak out of the hit, then fall.
static func make_paint() -> PackedScene:
	var paint := _streaks(18, 0.45, Color("#e34883"), 0.0, Vector2(1.5, 4.0), Vector3(0.05, 0.1, 0.05))
	paint.name = "Paint"
	return _pack(paint)


## Muzzle smoke: a few soft puffs that drift forward and up, grow, and fade.
static func make_smoke() -> PackedScene:
	var smoke := _puffs(6, 0.9, Color(0.93, 0.9, 0.86, 0.38), Vector2(0.4, 1.1), 0.18)
	smoke.name = "Smoke"
	(smoke.process_material as ParticleProcessMaterial).gravity = Vector3(0.0, 0.5, 0.0)
	return _pack(smoke)


static func _streaks(amount: int, lifetime: float, color: Color, glow: float, speed: Vector2,
		size: Vector3) -> GPUParticles3D:
	var particles := _emitter(amount, lifetime)
	var motion := particles.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 55.0
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
	motion.spread = 35.0
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


static func make_splatter() -> Texture2D:
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	var ink := Color("#e34883")
	for spot: Vector3i in [
		Vector3i(26, 35, 14), Vector3i(44, 24, 8), Vector3i(45, 46, 5),
		Vector3i(15, 19, 3), Vector3i(29, 50, 4), Vector3i(53, 31, 3),
	]:
		var center := Vector2i(spot.x, spot.y)
		for y in range(center.y - spot.z, center.y + spot.z + 1):
			for x in range(center.x - spot.z, center.x + spot.z + 1):
				if center.distance_squared_to(Vector2i(x, y)) <= spot.z * spot.z:
					image.set_pixel(x, y, ink)
	return ImageTexture.create_from_image(image)


static func make_sound(duration: float, start_hz: float, end_hz: float, noise_mix: float,
		level: float, seed_value: int) -> AudioStreamRandomizer:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var sample_count := roundi(duration * SAMPLE_RATE)
	var samples := PackedByteArray()
	samples.resize(sample_count * 2)
	var phase := 0.0
	for i in range(sample_count):
		var progress := float(i) / sample_count
		phase += TAU * lerpf(start_hz, end_hz, progress) / SAMPLE_RATE
		var tone := sin(phase)
		var wave := lerpf(tone, rng.randf_range(-1.0, 1.0), noise_mix)
		var envelope := minf(float(i) / 12.0, 1.0) * pow(1.0 - progress, 3.0)
		samples.encode_s16(i * 2, roundi(wave * envelope * level * 32767.0))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = SAMPLE_RATE
	clip.data = samples
	var cue := AudioStreamRandomizer.new()
	cue.random_pitch_semitones = 0.4
	cue.add_stream(0, clip)
	return cue
