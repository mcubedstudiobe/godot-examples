extends RefCounted
## The demo's particle effects, built in code. Every emitter is one-shot and uses a fixed seed,
## so the same hit puffs the same way on every run.

const IMPACT := preload("res://impact.gdshader")


## A comic impact star and a puff of felt fuzz, where a ball bonks the plush.
static func make_bonk() -> PackedScene:
	var root := _puffs(12, 0.7, Color(1.0, 0.97, 0.8, 0.8), Vector2(0.8, 2.4), 0.26)
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
	quad.size = Vector2(1.0, 1.0)
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


## Nervous sweat: a few big cartoon drops flung up and out of the head, then falling.
static func make_sweat() -> GPUParticles3D:
	var drops := _emitter(5, 0.9)
	drops.explosiveness = 0.95
	var motion := drops.process_material as ParticleProcessMaterial
	motion.direction = Vector3.UP
	motion.spread = 80.0
	motion.initial_velocity_min = 1.3
	motion.initial_velocity_max = 2.3
	motion.gravity = Vector3(0.0, -5.5, 0.0)
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motion.emission_sphere_radius = 0.42
	motion.scale_min = 0.85
	motion.scale_max = 1.25
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = _drop_picture()
	material.no_depth_test = true
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	quad.material = material
	drops.draw_pass_1 = quad
	drops.name = "Sweat"
	return drops


## A soft trail behind a flying ball: pale green-yellow puffs left hanging in the air.
static func make_trail() -> GPUParticles3D:
	var puffs := _emitter(12, 0.2)
	puffs.one_shot = false
	puffs.explosiveness = 0.0
	puffs.local_coords = false
	var motion := puffs.process_material as ParticleProcessMaterial
	motion.gravity = Vector3.ZERO
	motion.initial_velocity_max = 0.1
	motion.scale_curve = _curve([Vector2(0.0, 1.0), Vector2(1.0, 0.1)])
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.7))
	fade.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	motion.color_ramp = ramp
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.9, 1.0, 0.45, 1.0)
	material.albedo_texture = _soft_dot()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.24)
	quad.material = material
	puffs.draw_pass_1 = quad
	return puffs


## A cartoon teardrop, drawn once into a texture: sky blue with a darker rim and a white glint.
static func _drop_picture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for py in size:
		for px in size:
			var x := (px + 0.5) / size * 2.0 - 1.0
			var y := 1.0 - (py + 0.5) / size * 2.0
			# A circle low down and a point above it, blended into one outline.
			var round_part := Vector2(x, y + 0.28).length() / 0.62
			var width := clampf((0.9 - y) / 1.1, 0.0, 1.0) * 0.62
			var point_part := absf(x) / maxf(width, 0.001) if y > -0.28 and y < 0.9 else 9.0
			var inside := minf(round_part, point_part)
			if inside > 1.0:
				image.set_pixel(px, py, Color(0, 0, 0, 0))
				continue
			var rim := smoothstep(0.82, 1.0, inside)
			var body := Color(0.45, 0.76, 1.0).lerp(Color(0.13, 0.42, 0.9), rim)
			var glint := Vector2(x + 0.2, y + 0.38).length()
			body = body.lerp(Color(1, 1, 1), smoothstep(0.2, 0.1, glint))
			image.set_pixel(px, py, Color(body.r, body.g, body.b, 1.0 - smoothstep(0.96, 1.0, inside)))
	return ImageTexture.create_from_image(image)


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
