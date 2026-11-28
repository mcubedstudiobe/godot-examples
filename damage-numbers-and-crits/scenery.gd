extends Node3D
## The dojo at evening, built from primitives, a few shaders and a lot of light: tatami floor,
## a back wall of shoji screens glowing with dusk, a plaster alcove with a hanging scroll, dark
## timber posts and beams, paper lanterns, two floor lamps, a weapon rack and floor cushions.
## The camera looks along -Z; the plushes stand on the middle of the mats at the origin, and the
## back wall is at -Z.

const TATAMI := preload("res://tatami.gdshader")
const SHOJI := preload("res://shoji.gdshader")
const WOOD := preload("res://wood.gdshader")
const LANTERN := preload("res://lantern.gdshader")
const SCROLL := preload("res://scroll.gdshader")
const Effects := preload("res://effects.gd")

## The warm colour of every lantern's light.
const LAMP := Color(1.0, 0.76, 0.5)
const WALL_Z := -3.4
const WALL_WIDTH := 16.8
const WALL_HEIGHT := 2.6
const CEILING := 3.5

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 20261128
	_environment()
	_floor()
	_wall()
	_alcove()
	_ceiling()
	_lanterns()
	_floor_lamps()
	_rack()
	_cushions()
	var motes: GPUParticles3D = Effects.make_motes(Vector3(4.0, 1.6, 2.6), 90)
	motes.position = Vector3(0.0, 1.6, -0.4)
	add_child(motes)


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


func _timber(axis := 1, scale := 34.0, tint := Color(0.26, 0.15, 0.08), roughness := 0.5) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = WOOD
	material.set_shader_parameter(&"grain_axis", axis)
	material.set_shader_parameter(&"grain_scale", scale)
	material.set_shader_parameter(&"wood_colour", tint)
	material.set_shader_parameter(&"grain_colour", tint.darkened(0.5))
	material.set_shader_parameter(&"roughness", roughness)
	return material


func _box(size: Vector3, material: Material, at: Vector3, turn := Vector3.ZERO, parent: Node3D = self) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _add(box, material, at, turn, parent)


# ---------- the air and the light ----------

func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.03, 0.02, 0.025)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.5, 0.42, 0.62)
	environment.ambient_light_energy = 0.3
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 5.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 1.6
	environment.glow_enabled = true
	environment.glow_intensity = 0.75
	environment.glow_bloom = 0.04
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.006
	environment.volumetric_fog_albedo = Color(1.0, 0.82, 0.62)
	environment.volumetric_fog_emission = Color(0.05, 0.03, 0.02)
	environment.volumetric_fog_anisotropy = 0.55
	environment.volumetric_fog_length = 18.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = 1.12
	var world := WorldEnvironment.new()
	world.environment = environment
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 6.5
	attributes.dof_blur_far_transition = 4.0
	attributes.dof_blur_amount = 0.06
	world.camera_attributes = attributes
	add_child(world)
	# The key: warm low light from the front left, so the plushes cast soft shadows on the mats.
	var key := DirectionalLight3D.new()
	key.light_color = Color(1.0, 0.86, 0.7)
	key.light_energy = 0.7
	key.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.directional_shadow_max_distance = 14.0
	key.light_volumetric_fog_energy = 0.0
	add_child(key)
	# A cool bounce from the dusk behind the shoji, so edges keep a blue-violet outline.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.5, 0.58, 1.0)
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-18.0, 172.0, 0.0)
	rim.light_volumetric_fog_energy = 0.0
	add_child(rim)


# ---------- the room ----------

func _floor() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	var material := ShaderMaterial.new()
	material.shader = TATAMI
	_add(plane, material, Vector3(0.0, 0.0, 3.0))


func _wall() -> void:
	# The shoji: a quad in a lattice of dark wood, with the dusk behind the paper.
	var quad := QuadMesh.new()
	quad.size = Vector2(WALL_WIDTH, WALL_HEIGHT)
	var material := ShaderMaterial.new()
	material.shader = SHOJI
	material.set_shader_parameter(&"size", quad.size)
	var wall := _add(quad, material, Vector3(0.0, WALL_HEIGHT * 0.5, WALL_Z))
	wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A plaster band above the screens, a lintel beam across the top and a sill below.
	var plaster := _plain(Color(0.6, 0.45, 0.33), 0.95)
	var band := _box(Vector3(WALL_WIDTH, CEILING - WALL_HEIGHT, 0.1), plaster, Vector3(0.0, (CEILING + WALL_HEIGHT) * 0.5, WALL_Z - 0.04))
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(WALL_WIDTH, 0.2, 0.26), _timber(0, 30.0), Vector3(0.0, WALL_HEIGHT + 0.1, WALL_Z + 0.1)) \
			.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box(Vector3(WALL_WIDTH, 0.14, 0.34), _timber(0, 30.0, Color(0.2, 0.11, 0.06)), Vector3(0.0, 0.07, WALL_Z + 0.12)) \
			.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Square posts either side of the alcove and at the far edges.
	for x in [-2.6, 2.6, -6.0, 6.0]:
		_box(Vector3(0.22, CEILING, 0.22), _timber(1, 38.0), Vector3(x, CEILING * 0.5, WALL_Z + 0.16)) \
				.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## The alcove between the posts: a plaster wall, a raised dais, a hanging scroll and a vase.
func _alcove() -> void:
	var clay := _plain(Color(0.66, 0.5, 0.36), 0.97)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	noise.seed = 3
	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 4.0
	clay.normal_enabled = true
	clay.normal_texture = texture
	clay.normal_scale = 0.35
	var back := _box(Vector3(5.1, 2.55, 0.08), clay, Vector3(0.0, 1.275, WALL_Z + 0.06))
	back.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The scroll hangs between the plushes, a little above their heads.
	var quad := QuadMesh.new()
	quad.size = Vector2(0.78, 1.8)
	var material := ShaderMaterial.new()
	material.shader = SCROLL
	material.set_shader_parameter(&"size", quad.size)
	var scroll := _add(quad, material, Vector3(0.0, 1.62, WALL_Z + 0.12))
	scroll.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for y in [0.72, 2.52]:
		var rod := CylinderMesh.new()
		rod.top_radius = 0.025
		rod.bottom_radius = 0.025
		rod.height = 0.86
		_add(rod, _timber(0, 30.0, Color(0.2, 0.11, 0.06)), Vector3(0.0, y, WALL_Z + 0.125), Vector3(0.0, 0.0, 90.0))
	# The dais, in dark timber, with a vase and a few stalks on it.
	_box(Vector3(5.0, 0.16, 0.9), _timber(0, 30.0, Color(0.22, 0.12, 0.06), 0.4), Vector3(0.0, 0.08, WALL_Z + 0.5))
	_box(Vector3(5.0, 0.02, 0.9), _plain(Color(0.12, 0.08, 0.05), 0.5), Vector3(0.0, 0.17, WALL_Z + 0.5))
	var vase := SphereMesh.new()
	vase.radius = 0.16
	vase.height = 0.4
	var glaze := _plain(Color(0.15, 0.3, 0.38), 0.18)
	glaze.metallic_specular = 0.8
	glaze.clearcoat_enabled = true
	_add(vase, glaze, Vector3(-1.7, 0.4, WALL_Z + 0.5))
	var neck := CylinderMesh.new()
	neck.top_radius = 0.07
	neck.bottom_radius = 0.1
	neck.height = 0.18
	_add(neck, glaze, Vector3(-1.7, 0.66, WALL_Z + 0.5))
	for k in 3:
		var stalk := CylinderMesh.new()
		stalk.top_radius = 0.008
		stalk.bottom_radius = 0.012
		stalk.height = 1.0 + 0.2 * k
		var lean := Vector3(0.0, 0.0, -10.0 + 10.0 * k)
		var piece := _add(stalk, _plain(Color(0.35, 0.28, 0.14), 0.6), Vector3(-1.7 + 0.05 * (k - 1), 1.2 + 0.1 * k, WALL_Z + 0.5), lean)
		for leaf in 3:
			var shape := SphereMesh.new()
			shape.radius = 0.05
			shape.height = 0.1
			var blade := _add(shape, _plain(Color(0.78, 0.3, 0.1).lerp(Color(0.85, 0.55, 0.1), leaf * 0.4), 0.7),
					Vector3(0.03 * (leaf - 1), 0.28 + 0.12 * leaf, 0.0), Vector3.ZERO, piece)
			blade.scale = Vector3(1.6, 0.6, 0.4)


func _ceiling() -> void:
	var deck := _box(Vector3(WALL_WIDTH, 0.1, 12.0), _plain(Color(0.14, 0.09, 0.06), 0.8), Vector3(0.0, CEILING + 0.05, 2.0))
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for x in range(-8, 9, 2):
		_box(Vector3(0.2, 0.26, 12.0), _timber(2, 30.0), Vector3(x, CEILING - 0.13, 2.0)) \
				.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [-2.6, 0.2, 3.0]:
		_box(Vector3(WALL_WIDTH, 0.22, 0.2), _timber(0, 30.0), Vector3(0.0, CEILING - 0.11, z)) \
				.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# ---------- the lights ----------

## Hanging paper lanterns: a glowing shell on bamboo ribs, black lacquer caps, a cord to the beam
## and a warm omni light that spills on the mats and the walls.
func _lanterns() -> void:
	var spots := [
		[Vector3(-2.35, 2.35, -0.9), 1.0, true],
		[Vector3(2.4, 2.4, -1.5), 0.92, false],
		[Vector3(-4.1, 2.45, -2.2), 0.85, false],
		[Vector3(4.2, 2.3, -0.6), 0.9, false],
		[Vector3(0.1, 2.6, -2.7), 0.8, false],
	]
	for spot in spots:
		_lantern(spot[0], spot[1], spot[2])


func _lantern(at: Vector3, size: float, shadow: bool) -> void:
	var root := Node3D.new()
	root.position = at
	root.scale = Vector3.ONE * size
	add_child(root)
	var shell := SphereMesh.new()
	shell.radius = 0.3
	shell.height = 0.78
	shell.radial_segments = 48
	shell.rings = 24
	var paper := ShaderMaterial.new()
	paper.shader = LANTERN
	_add(shell, paper, Vector3.ZERO, Vector3.ZERO, root)
	var lacquer := _plain(Color(0.04, 0.03, 0.03), 0.3)
	lacquer.metallic_specular = 0.8
	for y in [0.37, -0.37]:
		var cap := CylinderMesh.new()
		cap.top_radius = 0.17
		cap.bottom_radius = 0.17
		cap.height = 0.07
		_add(cap, lacquer, Vector3(0.0, y, 0.0), Vector3.ZERO, root)
	var cord := CylinderMesh.new()
	cord.top_radius = 0.008
	cord.bottom_radius = 0.008
	cord.height = CEILING - at.y - 0.3
	cord.radial_segments = 6
	_add(cord, _plain(Color(0.08, 0.05, 0.04), 0.9), Vector3(0.0, 0.4 + cord.height * 0.5, 0.0), Vector3.ZERO, root).scale = Vector3.ONE / size
	var light := OmniLight3D.new()
	light.light_color = LAMP
	light.light_energy = 1.25
	light.omni_range = 7.5
	light.omni_attenuation = 1.3
	light.shadow_enabled = shadow
	light.light_volumetric_fog_energy = 1.2
	root.add_child(light)


## Two paper floor lamps in wooden frames at the back, glowing on the mats and the wall.
func _floor_lamps() -> void:
	for x in [-3.1, 3.4]:
		var root := Node3D.new()
		root.position = Vector3(x, 0.0, -2.75)
		add_child(root)
		var paper := ShaderMaterial.new()
		paper.shader = LANTERN
		paper.set_shader_parameter(&"paper_colour", Color(1.0, 0.62, 0.28))
		paper.set_shader_parameter(&"energy", 2.6)
		paper.set_shader_parameter(&"rib_spacing", 0.17)
		_box(Vector3(0.34, 0.58, 0.34), paper, Vector3(0.0, 0.5, 0.0), Vector3.ZERO, root)
		var frame := _timber(1, 40.0, Color(0.2, 0.11, 0.06))
		for cx in [-1.0, 1.0]:
			for cz in [-1.0, 1.0]:
				_box(Vector3(0.04, 0.66, 0.04), frame, Vector3(0.18 * cx, 0.5, 0.18 * cz), Vector3.ZERO, root)
		_box(Vector3(0.42, 0.045, 0.42), frame, Vector3(0.0, 0.84, 0.0), Vector3.ZERO, root)
		_box(Vector3(0.42, 0.05, 0.42), frame, Vector3(0.0, 0.15, 0.0), Vector3.ZERO, root)
		var light := OmniLight3D.new()
		light.light_color = LAMP
		light.light_energy = 1.5
		light.omni_range = 5.0
		light.omni_attenuation = 1.4
		light.position = Vector3(0.0, 0.5, 0.15)
		light.light_volumetric_fog_energy = 0.8
		root.add_child(light)


## A rack of wooden practice swords against the wall.
func _rack() -> void:
	var root := Node3D.new()
	root.position = Vector3(4.2, 0.0, -2.9)
	root.rotation_degrees.y = -12.0
	add_child(root)
	var dark := _timber(1, 38.0, Color(0.2, 0.11, 0.06))
	for x in [-0.55, 0.55]:
		_box(Vector3(0.07, 1.25, 0.1), dark, Vector3(x, 0.625, 0.0), Vector3.ZERO, root)
		_box(Vector3(0.16, 0.05, 0.5), dark, Vector3(x, 0.025, 0.0), Vector3.ZERO, root)
	for y in [0.55, 1.05]:
		_box(Vector3(1.2, 0.05, 0.07), dark, Vector3(0.0, y, 0.06), Vector3.ZERO, root)
	var oak := _timber(1, 60.0, Color(0.55, 0.38, 0.2), 0.45)
	for k in 3:
		var sword := CapsuleMesh.new()
		sword.radius = 0.03
		sword.height = 1.1
		_add(sword, oak, Vector3(-0.3 + 0.3 * k, 0.65, 0.14), Vector3(-6.0, 0.0, 3.0 * (k - 1)), root)


func _cushions() -> void:
	var spots := [[Vector3(-2.7, 0.06, 0.9), 20.0, Color(0.38, 0.14, 0.42)], [Vector3(2.8, 0.06, 1.3), -14.0, Color(0.55, 0.12, 0.14)]]
	for spot in spots:
		var cushion := _add(Soft.pillow(Vector3(0.78, 0.16, 0.78), 0.3, 0.45), _plain(spot[2], 0.95), spot[0], Vector3(0.0, spot[1], 0.0))
		cushion.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
