class_name Scenery
extends RefCounted
## The breakfast table: toast, waffle, pancake and marshmallow platforms, a lake of hot cocoa in a
## giant bowl, and the table beyond with its jars and boxes. All of it is built from meshes,
## shaders and a little maths, with no textures.

const BREAD := preload("res://bread.gdshader")
const WAFFLE := preload("res://waffle.gdshader")
const MARSHMALLOW := preload("res://marshmallow.gdshader")
const COCOA := preload("res://cocoa.gdshader")
const CLOTH := preload("res://cloth.gdshader")
const CERAMIC := preload("res://ceramic.gdshader")
const BACKDROP := preload("res://backdrop.gdshader")
const CONTACT := preload("res://contact.gdshader")

const BOWL_RADIUS := 10.5
const RIM_Y := -0.95
const BACKDROP_SCALE := 0.5


## One platform: a slab with the surface of its kind, centred where the collision box is.
static func make_platform(kind: String, x0: float, x1: float, top: float, z: float, seed_value: float) -> Node3D:
	var root := Node3D.new()
	var width := x1 - x0
	var depth := Course.PLATFORM_DEPTH
	var radius := 0.34
	var bevel := 0.13
	if kind == "pancake":
		depth = width
		radius = width * 0.5
		bevel = 0.17
	elif kind == "marshmallow":
		depth = minf(width * 1.1, 1.3)
		radius = 0.5
		bevel = 0.2
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = Slab.make(width, depth, Course.PLATFORM_THICKNESS, radius, bevel)
	# A soft round patch under each platform (below) stands in for its shadow on the cocoa.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	match kind:
		"waffle":
			material.shader = WAFFLE
			material.set_shader_parameter(&"cell", 0.3)
		"marshmallow":
			material.shader = MARSHMALLOW
			material.set_shader_parameter(&"toast", 0.25)
		_:
			material.shader = BREAD
			material.set_shader_parameter(&"kind", 1.0 if kind == "pancake" else 0.0)
	if kind != "marshmallow":
		material.set_shader_parameter(&"half_size", Vector2(width, depth) * 0.5)
		material.set_shader_parameter(&"corner", minf(radius, minf(width, depth) * 0.5))
	material.set_shader_parameter(&"seed", seed_value)
	mesh_instance.material_override = material
	root.add_child(mesh_instance)
	root.position = Vector3((x0 + x1) * 0.5, top - Course.PLATFORM_THICKNESS * 0.5, z)
	root.add_child(_contact(width, depth, top - Course.PLATFORM_THICKNESS * 0.5))
	# Toppings sit on the top face.
	var y_top := Course.PLATFORM_THICKNESS * 0.5
	if kind == "toast" and width > 1.5:
		root.add_child(_butter(Vector3(width * 0.18, y_top, -0.35), 0.42))
	elif kind == "waffle" and width > 1.5:
		root.add_child(_butter(Vector3(-width * 0.22, y_top, 0.1), 0.38))
	elif kind == "pancake":
		root.add_child(_butter(Vector3(0.0, y_top, 0.0), 0.3))
	return root


## A soft dark patch on the cocoa straight under a platform, the way it shades the surface.
static func _contact(width: float, depth: float, platform_y: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width * 1.25, depth * 1.25)
	quad.orientation = PlaneMesh.FACE_Y
	var material := ShaderMaterial.new()
	material.shader = CONTACT
	quad.material = material
	var patch := MeshInstance3D.new()
	patch.mesh = quad
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	patch.position = Vector3(0.0, Course.LAKE_Y + 0.03 - platform_y, 0.0)
	return patch


## A pat of butter: a small glossy soft-cornered block.
static func _butter(at: Vector3, size: float) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = Slab.make(size, size * 0.8, 0.11, 0.06, 0.04)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.86, 0.38)
	material.roughness = 0.22
	material.rim_enabled = true
	material.rim = 0.3
	material.rim_tint = 0.5
	material.emission_enabled = true
	material.emission = Color(0.5, 0.35, 0.05)
	material.emission_energy_multiplier = 0.15
	instance.material_override = material
	instance.position = at + Vector3(0.0, 0.05, 0.0)
	instance.rotation.y = 0.35
	return instance


## A marshmallow, used for the bobbing ones in the cocoa and the one that lands on a head.
static func make_marshmallow(size: float, seed_value: float, toast := 0.0) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var pill := CapsuleMesh.new()
	pill.radius = size * 0.42
	pill.height = size * 1.0
	pill.radial_segments = 48
	pill.rings = 16
	instance.mesh = pill
	var material := ShaderMaterial.new()
	material.shader = MARSHMALLOW
	material.set_shader_parameter(&"top_y", size * 0.5)
	material.set_shader_parameter(&"seed", seed_value)
	material.set_shader_parameter(&"toast", toast)
	instance.material_override = material
	return instance


## The lake of cocoa, the ceramic bowl round it, the table beyond and the things standing on it.
static func build_set(parent: Node3D, lake_y: float) -> Node3D:
	var root := Node3D.new()
	root.name = "Set"
	parent.add_child(root)
	# The cocoa.
	var lake := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = BOWL_RADIUS
	disc.bottom_radius = BOWL_RADIUS
	disc.height = 0.02
	disc.radial_segments = 160
	disc.rings = 1
	lake.mesh = disc
	var cocoa := ShaderMaterial.new()
	cocoa.shader = COCOA
	lake.material_override = cocoa
	lake.position = Vector3(0.0, lake_y, -2.0)
	lake.name = "Cocoa"
	root.add_child(lake)
	# The bowl: a lip of ceramic that rises out of the cocoa and curls over, with the table below.
	var bowl := MeshInstance3D.new()
	bowl.mesh = _bowl_mesh(lake_y)
	var ceramic := ShaderMaterial.new()
	ceramic.shader = CERAMIC
	bowl.material_override = ceramic
	bowl.position = Vector3(0.0, 0.0, -2.0)
	root.add_child(bowl)
	var table := MeshInstance3D.new()
	var table_plane := PlaneMesh.new()
	table_plane.size = Vector2(160.0, 160.0)
	table.mesh = table_plane
	var cloth := ShaderMaterial.new()
	cloth.shader = CLOTH
	table.material_override = cloth
	table.position = Vector3(0.0, lake_y - 1.9, -40.0)
	root.add_child(table)
	# The things on the table are drawn half size: with the camera side-on and flat, distance gives
	# no shrinking, and full-size jars would crowd the course.
	var props := Node3D.new()
	props.scale = Vector3.ONE * BACKDROP_SCALE
	props.position = Vector3(0.0, lake_y - 1.9, -31.5) * (1.0 - BACKDROP_SCALE)
	root.add_child(props)
	build_props(props, lake_y - 1.9)
	_wall(root, lake_y - 1.9)
	return root


## A surface of revolution: the inside wall of the bowl from the cocoa up to a rounded lip, then
## down the outside to the table.
static func _bowl_mesh(lake_y: float) -> ArrayMesh:
	var profile: Array[Vector2] = [] # radius, y
	profile.append(Vector2(BOWL_RADIUS - 0.2, lake_y - 0.4))
	# A gentle curve up the inside.
	for i in 8:
		var t := float(i + 1) / 8.0
		profile.append(Vector2(BOWL_RADIUS - 0.2 + 0.2 * t, lake_y - 0.4 + (RIM_Y - 0.55 - lake_y + 0.4) * t * t))
	# The lip: a half circle over the top.
	var lip_centre := Vector2(BOWL_RADIUS + 0.55, RIM_Y - 0.55)
	for i in 13:
		var a := PI - float(i) / 12.0 * PI
		profile.append(lip_centre + Vector2(cos(a), sin(a)) * 0.55)
	var outer_foot := Vector2(BOWL_RADIUS + 1.9, lake_y - 1.9)
	for i in 8:
		var t := float(i + 1) / 8.0
		profile.append(Vector2(BOWL_RADIUS + 1.1 + (outer_foot.x - BOWL_RADIUS - 1.1) * t, RIM_Y - 0.55 + (outer_foot.y - RIM_Y + 0.55) * (1.0 - (1.0 - t) * (1.0 - t))))
	var segments := 128
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var n_profile := profile.size()
	for p in n_profile:
		var prev := profile[maxi(p - 1, 0)]
		var next := profile[mini(p + 1, n_profile - 1)]
		var tangent := (next - prev).normalized()
		var normal2d := Vector2(tangent.y, -tangent.x) # points away from the bowl's inside (to the right of travel)
		for s in segments + 1:
			var a := float(s) / segments * TAU
			var dir := Vector3(cos(a), 0.0, sin(a))
			vertices.append(dir * profile[p].x + Vector3(0.0, profile[p].y, 0.0))
			# The inside faces the camera: flip so the wall is lit from the cocoa side.
			var n3 := dir * -normal2d.x + Vector3(0.0, -normal2d.y, 0.0)
			normals.append(n3.normalized())
	for p in n_profile - 1:
		for s in segments:
			var a := p * (segments + 1) + s
			var b := a + 1
			var c := a + (segments + 1)
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Big breakfast things on the far side of the bowl: a mug, a glass of orange juice and a stack of
## pancakes. They are drawn out of focus, so they only have to read as a breakfast table.
static func build_props(parent: Node3D, table_y: float) -> void:
	var glossy := func(color: Color, rough := 0.2, metal := 0.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = rough
		m.metallic = metal
		m.rim_enabled = true
		m.rim = 0.25
		m.emission_enabled = true
		m.emission = color * 0.1
		return m
	var cylinder := func(radius_top: float, radius_bottom: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
		var instance := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius_top
		mesh.bottom_radius = radius_bottom
		mesh.height = height
		mesh.radial_segments = 64
		instance.mesh = mesh
		instance.material_override = material
		instance.position = at
		parent.add_child(instance)
		return instance
	# A big mug with a handle, full of cocoa.
	var mug_at := Vector3(-12.6, table_y, -26.0)
	cylinder.call(2.7, 2.5, 5.4, mug_at + Vector3(0.0, 2.7, 0.0), glossy.call(Color(0.42, 0.78, 0.7), 0.12))
	cylinder.call(2.35, 2.35, 0.1, mug_at + Vector3(0.0, 5.3, 0.0), glossy.call(Color(0.3, 0.15, 0.08), 0.1))
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.75
	ring.outer_radius = 1.45
	ring.rings = 48
	ring.ring_segments = 24
	handle.mesh = ring
	handle.material_override = glossy.call(Color(0.42, 0.78, 0.7), 0.12)
	handle.rotation.x = PI * 0.5
	handle.position = mug_at + Vector3(2.9, 2.9, 0.0)
	parent.add_child(handle)
	# A tall glass of orange juice.
	var glass_at := Vector3(10.8, table_y, -28.0)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.95, 0.98, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	cylinder.call(2.3, 1.9, 6.6, glass_at + Vector3(0.0, 3.3, 0.0), glass)
	var juice: StandardMaterial3D = glossy.call(Color(1.0, 0.62, 0.12), 0.1)
	juice.emission = Color(1.0, 0.5, 0.05)
	juice.emission_energy_multiplier = 0.35
	cylinder.call(2.1, 1.75, 5.2, glass_at + Vector3(0.0, 2.7, 0.0), juice)
	# A stack of pancakes with butter and syrup.
	var stack_at := Vector3(-6.8, table_y, -21.0)
	for layer in 4:
		var tone := Color(0.9, 0.64, 0.32).lerp(Color(0.8, 0.5, 0.22), float(layer % 2))
		cylinder.call(3.0, 3.1, 0.62, stack_at + Vector3(0.0, 0.31 + 0.64 * float(layer), 0.0), glossy.call(tone, 0.55))
	var syrup: StandardMaterial3D = glossy.call(Color(0.62, 0.28, 0.06), 0.05)
	cylinder.call(2.6, 2.9, 0.25, stack_at + Vector3(0.0, 2.65, 0.0), syrup)
	cylinder.call(0.9, 0.9, 0.35, stack_at + Vector3(0.0, 2.95, 0.0), glossy.call(Color(1.0, 0.9, 0.45), 0.25))


## The wall behind the table: a flat, softly lit backdrop with defocused lights in it.
static func _wall(parent: Node3D, table_y: float) -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(120.0, 60.0)
	var material := ShaderMaterial.new()
	material.shader = BACKDROP
	quad.material = material
	var wall := MeshInstance3D.new()
	wall.mesh = quad
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wall.position = Vector3(0.0, table_y + 29.5, -37.0)
	parent.add_child(wall)
