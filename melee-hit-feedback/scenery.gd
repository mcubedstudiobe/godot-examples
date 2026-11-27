extends Node3D
## The castle training yard, built from primitives, a few shaders and two noise textures.
## Camera side is +Z and the castle wall stands at the back, along -Z.

const Props := preload("res://props.gd")
const STONE := preload("res://stone.gdshader")
const GROUND := preload("res://ground.gdshader")
const HAY := preload("res://hay.gdshader")
const BANNER := preload("res://banner.gdshader")

var wood_dark: StandardMaterial3D
var wood_light: StandardMaterial3D
var stone: ShaderMaterial
var hay: ShaderMaterial
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 20261127
	wood_dark = _wood(Color(0.33, 0.2, 0.12), Color(0.5, 0.32, 0.19))
	wood_light = _wood(Color(0.55, 0.38, 0.22), Color(0.74, 0.54, 0.33))
	stone = ShaderMaterial.new()
	stone.shader = STONE
	hay = ShaderMaterial.new()
	hay.shader = HAY
	_ground()
	_dais()
	_wall()
	_towers()
	_banners()
	_bunting()
	_fence()
	_hay()
	_props()
	_trees()
	_grass()
	_motes()
	_torches()


func _wood(dark: Color, light: Color) -> StandardMaterial3D:
	var grain := FastNoiseLite.new()
	grain.frequency = 0.02
	grain.fractal_octaves = 3
	grain.seed = 11
	var ramp := Gradient.new()
	ramp.set_color(0, dark)
	ramp.set_color(1, light)
	var texture := NoiseTexture2D.new()
	texture.noise = grain
	texture.color_ramp = ramp
	texture.width = 32
	texture.height = 256
	texture.seamless = true
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.85
	return material


func _add(mesh: Mesh, material: Material, at: Vector3, turn := Vector3.ZERO,
		parent: Node3D = self) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	mesh.material = material
	part.mesh = mesh
	part.position = at
	part.rotation_degrees = turn
	parent.add_child(part)
	return part


func _box(size: Vector3, material: Material, at: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(mesh, material, at, turn)


func _cylinder(top: float, bottom: float, height: float, material: Material, at: Vector3,
		turn := Vector3.ZERO, segments := 24, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add(mesh, material, at, turn, parent)


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _ground() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(160.0, 160.0)
	var material := ShaderMaterial.new()
	material.shader = GROUND
	_add(plane, material, Vector3.ZERO)


## The dummy's wooden dais, matching the Stand body's collision shape.
func _dais() -> void:
	var stand := get_node("../Stand") as Node3D
	var top := stand.position + Vector3(0.0, 0.09, 0.0)
	_cylinder(0.5, 0.54, 0.18, wood_light, top)
	_cylinder(0.43, 0.43, 0.02, wood_dark, top + Vector3(0.0, 0.095, 0.0))


func _wall() -> void:
	_box(Vector3(60.0, 5.2, 1.8), stone, Vector3(0.0, 2.6, -9.0))
	_box(Vector3(60.0, 0.35, 2.1), stone, Vector3(0.0, 5.3, -9.0))
	var merlon := BoxMesh.new()
	merlon.size = Vector3(1.0, 0.95, 1.4)
	merlon.material = stone
	var merlons := MultiMesh.new()
	merlons.transform_format = MultiMesh.TRANSFORM_3D
	merlons.mesh = merlon
	var count := 31
	merlons.instance_count = count
	for i in count:
		merlons.set_instance_transform(i, Transform3D(Basis.IDENTITY,
				Vector3(-28.5 + i * 1.9, 5.95, -9.0)))
	var row := MultiMeshInstance3D.new()
	row.multimesh = merlons
	add_child(row)
	# The gate: a dark arch with warm light behind it and heavy timber frames.
	var glow := _glow(Color(1.0, 0.62, 0.3), 1.6)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.1, 0.07, 0.07)
	_box(Vector3(3.0, 3.0, 0.3), dark, Vector3(-2.8, 1.5, -8.05))
	_cylinder(1.5, 1.5, 0.3, dark, Vector3(-2.8, 3.0, -8.05), Vector3(90.0, 0.0, 0.0), 32)
	_box(Vector3(2.4, 2.8, 0.05), glow, Vector3(-2.8, 1.4, -8.2))
	_box(Vector3(0.28, 3.3, 0.45), wood_dark, Vector3(-4.4, 1.65, -7.95))
	_box(Vector3(0.28, 3.3, 0.45), wood_dark, Vector3(-1.2, 1.65, -7.95))
	_box(Vector3(3.4, 0.28, 0.45), wood_dark, Vector3(-2.8, 3.5, -7.95), Vector3.ZERO)


func _towers() -> void:
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Props.TEAL.darkened(0.1)
	roof.roughness = 0.55
	var window := _glow(Color(1.0, 0.7, 0.35), 2.2)
	# Near towers on the wall and far keeps in the haze, so the backdrop has depth.
	for spec: Array in [[-13.0, -10.2, 2.7, 10.5], [15.0, -10.6, 2.4, 12.0],
			[-30.0, -26.0, 3.5, 20.0], [22.0, -34.0, 4.2, 26.0], [-6.0, -44.0, 5.0, 30.0]]:
		var at := Vector3(spec[0], 0.0, spec[1])
		var radius: float = spec[2]
		var height: float = spec[3]
		_cylinder(radius, radius * 1.08, height, stone, at + Vector3(0.0, height * 0.5, 0.0), Vector3.ZERO, 28)
		_cylinder(radius * 1.2, radius * 1.2, 0.5, stone, at + Vector3(0.0, height + 0.1, 0.0), Vector3.ZERO, 28)
		_cylinder(0.0, radius * 1.3, radius * 1.4, roof, at + Vector3(0.0, height + 0.35 + radius * 0.7, 0.0), Vector3.ZERO, 28)
		_cylinder(0.04, 0.04, 1.6, wood_dark, at + Vector3(0.0, height + 0.35 + radius * 1.4 + 0.7, 0.0), Vector3.ZERO, 6)
		var pennant := PrismMesh.new()
		pennant.size = Vector3(0.9, 0.55, 0.02)
		var flag := StandardMaterial3D.new()
		flag.albedo_color = Props.SAFFRON
		_add(pennant, flag, at + Vector3(0.45, height + 0.35 + radius * 1.4 + 1.2, 0.0), Vector3(0.0, 0.0, -90.0))
		# Lit windows, facing the camera.
		for level in int(height / 4.0):
			var w := _box(Vector3(0.45, 0.8, 0.2), window, at + Vector3(0.0, 2.6 + level * 3.6, radius * 0.99))
			w.rotation_degrees.y = 0.0


func _banner(at: Vector3, size: Vector2, phase: float) -> void:
	var cloth := QuadMesh.new()
	cloth.size = size
	cloth.subdivide_depth = 8
	cloth.subdivide_width = 4
	var material := ShaderMaterial.new()
	material.shader = BANNER
	material.set_shader_parameter(&"phase", phase)
	_add(cloth, material, at)
	# The pole and the rod it hangs from.
	_cylinder(0.04, 0.04, size.x + 0.5, wood_dark, at + Vector3(0.0, size.y * 0.5 + 0.03, 0.02), Vector3(0.0, 0.0, 90.0), 8)


func _banners() -> void:
	_banner(Vector3(1.5, 2.8, -8.02), Vector2(1.9, 4.2), 0.0)
	_banner(Vector3(-7.4, 2.8, -8.02), Vector2(1.7, 3.8), 1.7)
	_banner(Vector3(5.8, 2.8, -8.02), Vector2(1.7, 3.8), 3.1)
	_banner(Vector3(-11.0, 2.8, -8.02), Vector2(1.5, 3.4), 4.4)


## Bunting on a drooping rope between two poles, three colours in turn.
func _bunting() -> void:
	var left := Vector3(-5.6, 3.1, -3.4)
	var right := Vector3(6.0, 3.1, -4.2)
	for pole in [left, right]:
		_cylinder(0.05, 0.07, pole.y, wood_dark, Vector3(pole.x, pole.y * 0.5, pole.z), Vector3.ZERO, 8)
	var colors := [Props.TEAL, Props.SAFFRON, Props.CREAM]
	var flags := 16
	for i in flags:
		var t := (i + 0.5) / flags
		var droop := sin(t * PI) * 0.75
		var at := left.lerp(right, t) + Vector3(0.0, -droop, 0.0)
		var pennant := PrismMesh.new()
		pennant.size = Vector3(0.42, 0.55, 0.02)
		var cloth := StandardMaterial3D.new()
		cloth.albedo_color = colors[i % 3]
		cloth.roughness = 0.8
		cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
		var flag := _add(pennant, cloth, at + Vector3(0.0, -0.3, 0.0), Vector3(0.0, 0.0, 180.0))
		flag.name = "Pennant"
		# Rope segment between this flag and the next.
		var next_t := (i + 1.5) / flags
		var next := left.lerp(right, next_t) + Vector3(0.0, -sin(next_t * PI) * 0.75, 0.0)
		var rope := _box(Vector3(0.025, 0.025, at.distance_to(next)), wood_dark, (at + next) * 0.5 + Vector3(0.0, 0.02, 0.0))
		rope.look_at_from_position(rope.position, next + Vector3(0.0, 0.02, 0.0), Vector3.UP)


func _fence() -> void:
	var shield_colors := [Props.TEAL, Props.SAFFRON, Props.CREAM, Props.TEAL, Props.SAFFRON]
	var z := -4.6
	var from := -8.0
	var to := 9.0
	var posts := 14
	for i in posts:
		var x := lerpf(from, to, float(i) / (posts - 1))
		var lean := rng.randf_range(-3.0, 3.0)
		_box(Vector3(0.16, 1.3, 0.16), wood_light, Vector3(x, 0.62, z), Vector3(0.0, 0.0, lean))
	for height in [0.5, 0.98]:
		_box(Vector3(to - from + 0.4, 0.11, 0.07), wood_light, Vector3((from + to) * 0.5, height, z + 0.1))
	# Heraldic shields hung on the rail.
	var xs := [-6.2, -3.2, -0.4, 2.4, 5.3, 7.4]
	for i in xs.size():
		_cylinder(0.33, 0.33, 0.06, _shield_paint(shield_colors[i % 5]), Vector3(xs[i], 0.8, z + 0.2),
				Vector3(90.0, 0.0, 0.0), 32)
		var boss := SphereMesh.new()
		boss.radius = 0.1
		boss.height = 0.1
		_add(boss, Props.steel(Color(0.85, 0.85, 0.9), 0.25), Vector3(xs[i], 0.8, z + 0.26), Vector3(0.0, 0.0, 0.0))


func _shield_paint(color: Color) -> StandardMaterial3D:
	var paint := StandardMaterial3D.new()
	paint.albedo_color = color
	paint.roughness = 0.5
	paint.metallic = 0.15
	return paint


func _hay() -> void:
	# A stack of three bales on the left, a round bale on the right, and a target board
	# leaning on the stack.
	for spec: Array in [[Vector3(-2.3, 0.23, -3.0), 4.0], [Vector3(-3.3, 0.23, -2.7), -6.0],
			[Vector3(-2.8, 0.69, -2.9), 12.0]]:
		_bale(spec[0], spec[1])
	var roll := _cylinder(0.55, 0.55, 1.1, hay, Vector3(4.6, 0.55, -2.6), Vector3(0.0, 0.0, 90.0), 28)
	roll.rotation_degrees.y = 24.0
	_cylinder(0.56, 0.56, 0.04, hay, roll.position)
	var board := Node3D.new()
	board.position = Vector3(-4.35, 0.0, -1.55)
	board.rotation_degrees = Vector3(-14.0, 18.0, 0.0)
	add_child(board)
	var rings := [[0.5, Props.CREAM], [0.4, Props.TEAL], [0.28, Props.CREAM], [0.16, Props.SAFFRON]]
	for i in rings.size():
		_cylinder(rings[i][0], rings[i][0], 0.05 + i * 0.006, _shield_paint(rings[i][1]),
				Vector3(0.0, 0.95, 0.0), Vector3(90.0, 0.0, 0.0), 40, board)
	for side in [-0.25, 0.25]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.07, 1.0, 0.07)
		_add(leg, wood_dark, Vector3(side, 0.45, -0.1), Vector3.ZERO, board)


func _bale(at: Vector3, yaw: float) -> void:
	var bale := _box(Vector3(0.95, 0.46, 0.5), hay, at, Vector3(0.0, yaw, 0.0))
	for offset in [-0.25, 0.25]:
		var twine := BoxMesh.new()
		twine.size = Vector3(0.025, 0.475, 0.52)
		var string := StandardMaterial3D.new()
		string.albedo_color = Color(0.4, 0.28, 0.16)
		var tie := _add(twine, string, Vector3(offset, 0.0, 0.0), Vector3.ZERO, bale)
		tie.name = "Twine"


func _props() -> void:
	# A barrel of wooden practice swords.
	var barrel_at := Vector3(4.6, 0.0, -1.2)
	_cylinder(0.36, 0.3, 0.8, wood_light, barrel_at + Vector3(0.0, 0.4, 0.0), Vector3.ZERO, 20)
	for h in [0.14, 0.66]:
		_cylinder(0.36, 0.36, 0.05, Props.steel(Color(0.28, 0.28, 0.3), 0.5), barrel_at + Vector3(0.0, h, 0.0), Vector3.ZERO, 20)
	for spec: Array in [[0.05, -10.0, 14.0], [-0.12, 8.0, -10.0], [0.15, 4.0, 22.0]]:
		_box(Vector3(0.07, 0.9, 0.025), wood_light, barrel_at + Vector3(spec[0], 1.0, 0.0), Vector3(spec[1], 0.0, spec[2]))
	# Spare tin buckets in a stack: the dummy's whole wardrobe.
	var buckets := Vector3(3.2, 0.0, -1.5)
	var tin := Props.steel(Color(0.78, 0.82, 0.86), 0.3)
	_cylinder(0.31, 0.22, 0.4, tin, buckets + Vector3(0.0, 0.2, 0.0), Vector3.ZERO, 28)
	_cylinder(0.31, 0.22, 0.4, tin, buckets + Vector3(0.02, 0.5, 0.0), Vector3(0.0, 20.0, 0.0), 28)
	_cylinder(0.31, 0.22, 0.4, tin, buckets + Vector3(0.7, 0.2, 0.25), Vector3(0.0, 0.0, 78.0), 28)
	# A weapon rack on the left with spears.
	var rack := Vector3(-5.8, 0.0, -0.4)
	for x in [-0.6, 0.6]:
		_box(Vector3(0.12, 1.4, 0.12), wood_dark, rack + Vector3(x, 0.7, 0.0))
	_box(Vector3(1.4, 0.1, 0.14), wood_dark, rack + Vector3(0.0, 0.5, 0.0))
	for x in [-0.4, -0.15, 0.1, 0.35]:
		_cylinder(0.02, 0.02, 1.9, wood_light, rack + Vector3(x, 1.0, 0.0), Vector3(0.0, 0.0, 6.0 - x * 8.0), 6)
		_box(Vector3(0.05, 0.14, 0.02), Props.steel(), rack + Vector3(x + 0.1, 1.95, 0.0), Vector3(0.0, 0.0, 6.0 - x * 8.0))


func _trees() -> void:
	var trunk := wood_dark
	for spec: Array in [[-8.2, -6.4, 1.0], [-10.5, -4.5, 1.25], [10.2, -6.0, 1.15], [12.5, -4.0, 0.9]]:
		var at := Vector3(spec[0], 0.0, spec[1])
		var s: float = spec[2]
		_cylinder(0.18 * s, 0.28 * s, 2.6 * s, trunk, at + Vector3(0.0, 1.3 * s, 0.0), Vector3.ZERO, 10)
		for blob: Array in [[0.0, 3.4, 0.0, 1.5], [0.8, 3.0, 0.3, 1.1], [-0.8, 3.1, -0.2, 1.2], [0.1, 4.2, 0.1, 1.0]]:
			var crown := SphereMesh.new()
			crown.radius = blob[3] * s
			crown.height = blob[3] * s * 1.7
			crown.radial_segments = 16
			crown.rings = 8
			var leaf := StandardMaterial3D.new()
			leaf.albedo_color = Color(0.2, 0.36, 0.14).lerp(Color(0.5, 0.5, 0.16), rng.randf() * 0.5)
			leaf.roughness = 0.9
			_add(crown, leaf, at + Vector3(blob[0], blob[1], blob[2]) * s)


## Tufts of long grass around the edge of the yard, one multimesh.
func _grass() -> void:
	var tuft := ArrayMesh.new()
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var normals := PackedVector3Array()
	for blade in 7:
		var angle := blade * 0.9
		var lean := Vector3(cos(angle), 0.0, sin(angle))
		var side := Vector3(-lean.z, 0.0, lean.x) * 0.03
		var height := 0.32 + 0.12 * ((blade * 5) % 3)
		var base := lean * 0.04
		verts.append_array([base - side, base + side, base + lean * 0.12 + Vector3(0.0, height, 0.0)])
		colors.append_array([Color(0.3, 0.34, 0.1), Color(0.3, 0.34, 0.1), Color(0.78, 0.66, 0.3)])
		normals.append_array([Vector3.UP, Vector3.UP, Vector3.UP])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_NORMAL] = normals
	tuft.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	tuft.surface_set_material(0, material)
	var field := MultiMesh.new()
	field.transform_format = MultiMesh.TRANSFORM_3D
	field.mesh = tuft
	var spots: Array[Transform3D] = []
	for i in 1800:
		var p := Vector2(rng.randf_range(-14.0, 14.0), rng.randf_range(-8.0, 1.0))
		var q := (p - Vector2(0.0, -0.8)) / Vector2(5.8, 4.2)
		if q.length() < 0.82 + rng.randf() * 0.25:
			continue
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.45, 0.9))
		spots.append(Transform3D(basis, Vector3(p.x, 0.0, p.y)))
	field.instance_count = spots.size()
	for i in spots.size():
		field.set_instance_transform(i, spots[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = field
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


## A few dust motes floating in the light.
func _motes() -> void:
	var motes := GPUParticles3D.new()
	motes.amount = 90
	motes.lifetime = 9.0
	motes.preprocess = 9.0
	motes.use_fixed_seed = true
	motes.seed = 7
	motes.visibility_aabb = AABB(Vector3(-10, -1, -8), Vector3(20, 8, 16))
	var motion := ParticleProcessMaterial.new()
	motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents = Vector3(7.0, 1.6, 4.0)
	motion.direction = Vector3(0.3, 0.1, 0.0)
	motion.spread = 180.0
	motion.initial_velocity_min = 0.03
	motion.initial_velocity_max = 0.12
	motion.gravity = Vector3(0.02, 0.01, 0.0)
	motion.scale_min = 0.5
	motion.scale_max = 1.4
	motes.process_material = motion
	var quad := QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_color = Color(1.0, 0.85, 0.55) * 2.0
	quad.material = material
	motes.draw_pass_1 = quad
	motes.position = Vector3(0.0, 1.6, -1.5)
	add_child(motes)


func _torches() -> void:
	for x in [-4.9, -0.7]:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color(1.0, 0.6, 0.28)
		lamp.light_energy = 2.0
		lamp.omni_range = 5.0
		lamp.position = Vector3(x, 2.8, -7.4)
		add_child(lamp)
		var flame := SphereMesh.new()
		flame.radius = 0.1
		flame.height = 0.24
		_add(flame, _glow(Color(1.0, 0.7, 0.3), 4.0), lamp.position)
		_cylinder(0.05, 0.05, 0.5, wood_dark, lamp.position + Vector3(0.0, -0.35, 0.0), Vector3.ZERO, 6)
