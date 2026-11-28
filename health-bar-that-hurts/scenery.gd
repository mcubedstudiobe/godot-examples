extends Node3D
## The sunny backyard, built from primitives, a few shaders and a lot of grass blades: a mown
## lawn, a picket fence with a hedge and a tree behind it, sunflowers and pots, a gnome who
## watches the action, and the pillow fort the plush hides in. The camera looks along -Z; the
## plush stands at the origin behind the fort's front wall, which runs along +Z.

const FABRIC := preload("res://fabric.gdshader")
const PAINT := preload("res://paint.gdshader")
const LAWN := preload("res://lawn.gdshader")
const GRASS := preload("res://grass.gdshader")
const FOLIAGE := preload("res://foliage.gdshader")

## How tall the front wall of cushions is: the plush hides below this and peeks over it.
const WALL_TOP := 0.6
## Where the blanket roof sits and how far its front edge reaches.
const ROOF_HEIGHT := 1.6
const ROOF_FRONT := -0.05

## One StaticBody3D per cushion, so a ball can bounce off it and the cushion can squash.
var cushions: Array[StaticBody3D] = []
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 20261128
	_lawn()
	_grass()
	_fort()
	_fence()
	_trees()
	_garden()
	_gnome()


# ---------- small builders ----------

func _add(mesh: Mesh, material: Material, at: Vector3, turn := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation_degrees = turn
	parent.add_child(part)
	return part


func _plain(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _fabric(base: Color, accent: Color, pattern: int, scale := 4.0, piping := 0.0) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FABRIC
	material.set_shader_parameter(&"base_colour", base)
	material.set_shader_parameter(&"accent_colour", accent)
	material.set_shader_parameter(&"pattern", pattern)
	material.set_shader_parameter(&"scale", scale)
	material.set_shader_parameter(&"piping", piping)
	return material


func _sphere(radius: float, squash := 1.0) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * squash
	mesh.radial_segments = 40
	mesh.rings = 20
	return mesh


func _cylinder(top: float, bottom: float, height: float, segments := 40) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _noise(frequency: float, seed_value: int) -> Image:
	var simplex := FastNoiseLite.new()
	simplex.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	simplex.frequency = frequency
	simplex.seed = seed_value
	return simplex.get_seamless_image(256, 256)


# ---------- the lawn ----------

func _lawn() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(90.0, 90.0)
	plane.subdivide_width = 1
	plane.subdivide_depth = 1
	var material := ShaderMaterial.new()
	material.shader = LAWN
	_add(plane, material, Vector3.ZERO)
	var ground := StaticBody3D.new()
	ground.name = "Ground"
	ground.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90.0, 0.4, 90.0)
	shape.shape = box
	shape.position = Vector3(0.0, -0.2, 0.0)
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.62
	physics.friction = 0.9
	ground.physics_material_override = physics
	ground.add_child(shape)
	add_child(ground)


## Thousands of blades in two layers: a dense stand close to the action, a thinner and taller
## one round it. Each blade is a tapered ribbon, drawn with one MultiMesh and swayed by the wind.
func _grass() -> void:
	var blade := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var segments := 4
	for i in segments + 1:
		var t := float(i) / segments
		var half := 0.011 * (1.0 - pow(t, 1.4)) + 0.0006
		var bend := t * t * 0.35
		vertices.append(Vector3(-half, t, bend * 0.4))
		vertices.append(Vector3(half, t, bend * 0.4))
		uvs.append(Vector2(0.0, t))
		uvs.append(Vector2(1.0, t))
	for i in segments:
		var a := i * 2
		indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := ShaderMaterial.new()
	material.shader = GRASS
	blade.surface_set_material(0, material)
	_blades(blade, 26000, Rect2(-4.6, -2.6, 8.4, 7.6), Vector2(0.075, 0.13))
	_blades(blade, 9000, Rect2(-9.0, -5.0, 18.0, 11.0), Vector2(0.14, 0.24))


func _blades(blade: Mesh, count: int, area: Rect2, height: Vector2) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = blade
	multi.instance_count = count
	for i in count:
		var at := Vector3(area.position.x + rng.randf() * area.size.x, 0.0, area.position.y + rng.randf() * area.size.y)
		# No grass pokes up through the cushions.
		if absf(at.x) < 1.7 and at.z > -1.2 and at.z < 1.0:
			at.y = -0.2
		var h := rng.randf_range(height.x, height.y)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.0, h, 1.0))
		multi.set_instance_transform(i, Transform3D(basis, at))
		multi.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.4, 1.0), 0.0, 0.0))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)


# ---------- the pillow fort ----------

func _cushion(at: Vector3, size: Vector3, yaw: float, pattern: int, base: Color, accent: Color,
		tilt := Vector3.ZERO, scale := 4.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = at
	body.rotation_degrees = Vector3(tilt.x, yaw, tilt.z)
	body.collision_layer = 1
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.18
	physics.friction = 1.0
	body.physics_material_override = physics
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size * Vector3(0.9, 0.82, 0.9)
	shape.shape = box
	body.add_child(shape)
	var visual := Node3D.new()
	visual.name = "Visual"
	body.add_child(visual)
	var mesh := Soft.pillow(size, 0.45, 0.62)
	var material := _fabric(base, accent, pattern, scale, 1.0)
	_add(mesh, material, Vector3.ZERO, Vector3.ZERO, visual)
	add_child(body)
	cushions.append(body)
	return body


func _fort() -> void:
	var coral := Color(0.93, 0.36, 0.30)
	var teal := Color(0.15, 0.58, 0.60)
	var mustard := Color(0.96, 0.72, 0.18)
	var lilac := Color(0.62, 0.50, 0.80)
	var pink := Color(0.97, 0.62, 0.68)
	var cream := Color(1.0, 0.96, 0.88)
	var sage := Color(0.52, 0.70, 0.45)
	# The floor of the fort: a fat pad the plush stands on.
	_cushion(Vector3(0.0, 0.07, 0.0), Vector3(2.1, 0.22, 1.4), 0.0, 0, cream, cream)
	# The front wall: a row of big cushions with two more laid on top of them.
	_cushion(Vector3(-0.9, 0.17, 0.72), Vector3(0.98, 0.34, 0.68), 4.0, 2, coral, cream, Vector3(0, 0, 2), 7.0)
	_cushion(Vector3(0.02, 0.18, 0.76), Vector3(1.0, 0.36, 0.7), -3.0, 3, teal, cream, Vector3(0, 0, -1), 7.0)
	_cushion(Vector3(0.94, 0.17, 0.72), Vector3(0.96, 0.34, 0.68), -6.0, 1, mustard, cream, Vector3(0, 0, 2), 6.0)
	_cushion(Vector3(-0.44, 0.43, 0.72), Vector3(0.92, 0.3, 0.64), 5.0, 3, pink, cream, Vector3(-4, 0, 3), 8.0)
	_cushion(Vector3(0.5, 0.45, 0.74), Vector3(0.88, 0.3, 0.62), -4.0, 2, lilac, cream, Vector3(-3, 0, -3), 6.0)
	# The two towers that hold the roof up.
	var stacks := [[-1.4, [coral, teal, mustard, lilac]], [1.4, [sage, coral, pink, teal]]]
	for tower in stacks:
		var x: float = tower[0]
		var colours: Array = tower[1]
		for i in colours.size():
			var jitter := Vector3(rng.randf_range(-0.05, 0.05), 0.0, rng.randf_range(-0.05, 0.05))
			var pattern := (i + int(x * 3.0)) % 4
			_cushion(Vector3(x, 0.2 + i * 0.38, -0.05) + jitter, Vector3(0.9, 0.42, 0.85), rng.randf_range(-14.0, 14.0),
					pattern, colours[i], cream, Vector3.ZERO, 6.0)
	# The blanket roof, and the back of the blanket that closes the fort in.
	_blanket()


## A yellow gingham blanket thrown over the towers, sagging between them, with a scalloped
## hem along the front and sides, and the same blanket hanging down the back.
func _blanket() -> void:
	var material := _fabric(Color(0.98, 0.78, 0.2), Color(1.0, 0.97, 0.9), 1, 5.5, 0.0)
	var width := 3.9
	var back := -1.0
	var front := ROOF_FRONT
	var roof := func(u: float, v: float) -> Vector3:
		var x := (u - 0.5) * width
		var z := lerpf(back, front, v)
		var edge := absf(u - 0.5) * 2.0
		var sag := -0.16 * (1.0 - pow(edge, 2.0)) * sin(PI * v)
		var drape := -0.55 * pow(smoothstep(0.78, 1.0, edge), 1.4)
		var hem := -0.12 * pow(smoothstep(0.82, 1.0, v), 2.0) * (0.55 + 0.45 * sin(x * 7.0))
		var folds := 0.022 * sin(x * 8.5 + z * 3.0) + 0.012 * sin(x * 19.0 - z * 5.0)
		return Vector3(x, ROOF_HEIGHT + 0.12 + sag + drape + hem + folds, z)
	_add(Soft.sheet(roof, 120, 50), material, Vector3.ZERO)
	var curtain := func(u: float, v: float) -> Vector3:
		var x := (u - 0.5) * width * 0.97
		var drop := v
		var folds := 0.05 * sin(x * 6.0 + v * 2.0) * (0.3 + v) + 0.02 * sin(x * 15.0)
		return Vector3(x, ROOF_HEIGHT + 0.1 - drop * (ROOF_HEIGHT + 0.1), back - 0.02 + folds)
	_add(Soft.sheet(curtain, 120, 40), material, Vector3.ZERO)
	# Fill light inside the fort, so the plush's face is never lost under the roof.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0.0, 1.3, 0.9)
	fill.light_color = Color(1.0, 0.92, 0.78)
	fill.light_energy = 0.45
	fill.omni_range = 4.0
	fill.shadow_enabled = false
	fill.light_specular = 0.0
	add_child(fill)
	var roof_body := StaticBody3D.new()
	roof_body.collision_layer = 1
	var roof_shape := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(3.6, 0.1, 1.0)
	roof_shape.shape = slab
	roof_body.position = Vector3(0.0, ROOF_HEIGHT + 0.02, -0.55)
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.2
	physics.friction = 1.0
	roof_body.physics_material_override = physics
	roof_body.add_child(roof_shape)
	add_child(roof_body)


# ---------- fence, hedge, trees ----------

func _fence() -> void:
	var paint := ShaderMaterial.new()
	paint.shader = PAINT
	var picket := BoxMesh.new()
	picket.size = Vector3(0.16, 1.25, 0.04)
	var tip := PrismMesh.new()
	tip.size = Vector3(0.16, 0.14, 0.04)
	var count := 62
	var pickets := MultiMesh.new()
	pickets.transform_format = MultiMesh.TRANSFORM_3D
	pickets.mesh = picket
	pickets.instance_count = count
	var tips := MultiMesh.new()
	tips.transform_format = MultiMesh.TRANSFORM_3D
	tips.mesh = tip
	tips.instance_count = count
	for i in count:
		var x := -9.4 + i * 0.3
		var lean := rng.randf_range(-0.01, 0.01)
		var drop := rng.randf_range(-0.04, 0.04)
		pickets.set_instance_transform(i, Transform3D(Basis(Vector3(0, 0, 1), lean), Vector3(x, 0.62 + drop, -4.3)))
		tips.set_instance_transform(i, Transform3D(Basis(Vector3(0, 0, 1), lean), Vector3(x, 1.32 + drop, -4.3)))
	for multi in [pickets, tips]:
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = paint
		add_child(instance)
	for y in [0.35, 0.95]:
		var rail := BoxMesh.new()
		rail.size = Vector3(19.0, 0.1, 0.05)
		_add(rail, paint, Vector3(0.0, y, -4.35))
	# The hedge, a row of leafy blobs behind the fence.
	var leaf := ShaderMaterial.new()
	leaf.shader = FOLIAGE
	for i in 26:
		var blob := _sphere(rng.randf_range(0.7, 1.1), 0.9)
		_add(blob, leaf, Vector3(-9.5 + i * 0.78 + rng.randf_range(-0.2, 0.2), rng.randf_range(0.85, 1.25), -5.4 + rng.randf_range(-0.2, 0.2)))


func _trees() -> void:
	var leaf := ShaderMaterial.new()
	leaf.shader = FOLIAGE
	var bark := _plain(Color(0.36, 0.25, 0.17), 0.9)
	for tree in [[Vector3(4.4, 0.0, -3.6), 1.0], [Vector3(-6.2, 0.0, -3.4), 0.85]]:
		var at: Vector3 = tree[0]
		var scale: float = tree[1]
		var trunk := _add(_cylinder(0.2 * scale, 0.32 * scale, 3.4 * scale), bark, at + Vector3(0.0, 1.7 * scale, 0.0))
		trunk.rotation_degrees.z = 2.0
		for blob in [[0.0, 3.6, 0.0, 1.7], [-1.1, 3.1, 0.3, 1.2], [1.1, 3.2, -0.2, 1.3], [0.2, 4.4, 0.2, 1.1], [-0.4, 3.0, 0.9, 1.0]]:
			_add(_sphere(blob[3] * scale), leaf, at + Vector3(blob[0], blob[1], blob[2]) * scale)


# ---------- garden dressing ----------

func _garden() -> void:
	var stem := _plain(Color(0.22, 0.45, 0.14))
	var petal := _plain(Color(1.0, 0.8, 0.1), 0.6)
	var seed := _plain(Color(0.28, 0.17, 0.08), 0.9)
	for x in [-6.2, -3.9, -2.4, 1.9, 3.2, 5.6]:
		var height := rng.randf_range(1.5, 2.1)
		_add(_cylinder(0.025, 0.035, height, 12), stem, Vector3(x, height * 0.5, -3.9))
		var head := Node3D.new()
		head.position = Vector3(x, height, -3.82)
		head.rotation_degrees = Vector3(-8.0, rng.randf_range(-15.0, 15.0), 0.0)
		add_child(head)
		for ring in 2:
			for k in 15:
				var a := TAU * (k + 0.5 * ring) / 15.0
				var leaf := _add(_sphere(0.1), petal, Vector3(cos(a), sin(a), 0.0) * (0.22 - ring * 0.02) + Vector3(0, 0, ring * 0.012), Vector3(0, 0, rad_to_deg(a) - 90.0), head)
				leaf.scale = Vector3(0.42, 1.0, 0.16)
		var core := _add(_cylinder(0.2, 0.2, 0.05, 32), seed, Vector3(0.0, 0.0, 0.03), Vector3(90.0, 0.0, 0.0), head)
		core.scale = Vector3(1, 1, 1)
	# Terracotta pots with daisies, and a watering can by the machine.
	var clay := _plain(Color(0.78, 0.38, 0.22), 0.8)
	var daisy := _plain(Color(1, 1, 0.96), 0.6)
	for pot in [[Vector3(2.7, 0, -0.9), 0.3], [Vector3(3.15, 0, -0.55), 0.22], [Vector3(-3.0, 0, -1.2), 0.27]]:
		var at: Vector3 = pot[0]
		var r: float = pot[1]
		_add(_cylinder(r, r * 0.72, r * 1.7), clay, at + Vector3(0, r * 0.85, 0))
		_add(_cylinder(r * 1.12, r * 1.12, r * 0.3), clay, at + Vector3(0, r * 1.75, 0))
		_add(_cylinder(r * 0.95, r * 0.95, 0.03), _plain(Color(0.2, 0.13, 0.08), 1.0), at + Vector3(0, r * 1.88, 0))
		for k in 5:
			var a := TAU * k / 5.0
			var flower := at + Vector3(cos(a) * r * 0.5, r * 1.9 + 0.14 + 0.08 * (k % 3), sin(a) * r * 0.5)
			_add(_cylinder(0.01, 0.012, 0.28, 8), stem, flower - Vector3(0, 0.14, 0))
			_add(_sphere(0.05, 0.4), daisy, flower)
			_add(_sphere(0.02), petal, flower + Vector3(0, 0.012, 0))
	var can_colour := _plain(Color(0.2, 0.62, 0.55), 0.35)
	var can := Node3D.new()
	can.position = Vector3(-3.35, 0.0, 0.9)
	can.rotation_degrees.y = 25.0
	add_child(can)
	_add(_cylinder(0.2, 0.2, 0.34), can_colour, Vector3(0, 0.17, 0), Vector3.ZERO, can)
	_add(_cylinder(0.03, 0.05, 0.5, 16), can_colour, Vector3(0.28, 0.36, 0), Vector3(0, 0, -50), can)
	var rose := _add(_cylinder(0.07, 0.04, 0.05, 20), can_colour, Vector3(0.48, 0.55, 0), Vector3(0, 0, -50), can)
	rose.name = "Rose"
	var grip := TorusMesh.new()
	grip.inner_radius = 0.1
	grip.outer_radius = 0.14
	_add(grip, can_colour, Vector3(-0.2, 0.3, 0), Vector3(90, 0, 0), can)


## A garden gnome who has seen it all, off to the right.
func _gnome() -> void:
	var gnome := Node3D.new()
	gnome.position = Vector3(2.6, 0.0, 0.9)
	gnome.rotation_degrees.y = -25.0
	add_child(gnome)
	_add(_cylinder(0.17, 0.2, 0.34), _plain(Color(0.2, 0.35, 0.75), 0.5), Vector3(0, 0.17, 0), Vector3.ZERO, gnome)
	_add(_sphere(0.1), _plain(Color(0.2, 0.2, 0.25), 0.4), Vector3(-0.1, 0.05, 0.12), Vector3.ZERO, gnome)
	_add(_sphere(0.1), _plain(Color(0.2, 0.2, 0.25), 0.4), Vector3(0.1, 0.05, 0.12), Vector3.ZERO, gnome)
	_add(_sphere(0.14), _plain(Color(1.0, 0.86, 0.74), 0.55), Vector3(0, 0.45, 0.02), Vector3.ZERO, gnome)
	var beard := _add(_cylinder(0.01, 0.15, 0.32, 24), _plain(Color(0.97, 0.97, 0.95), 0.9), Vector3(0, 0.3, 0.1), Vector3(-12, 0, 0), gnome)
	beard.name = "Beard"
	_add(_sphere(0.035), _plain(Color(0.95, 0.55, 0.5), 0.5), Vector3(0, 0.46, 0.14), Vector3.ZERO, gnome)
	_add(_cylinder(0.005, 0.15, 0.34, 32), _plain(Color(0.88, 0.14, 0.12), 0.35), Vector3(0, 0.74, 0.0), Vector3(-6, 0, 4), gnome)
