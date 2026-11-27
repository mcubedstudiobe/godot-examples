extends RefCounted
## The things the plushes carry and wear, built from primitives with a few good materials:
## the knight's oversized sword and the dummy's tin bucket helmet.

const TEAL := Color("#127a7d")
const SAFFRON := Color("#f2a51a")
const CREAM := Color("#f6ecd3")
## The bucket is tipped back on the dummy's head by this many degrees about X.
const BUCKET_TIP := -34.0
const BUCKET_PLACE := Vector3(0.0, 0.64, -0.04)


static func steel(tint := Color(0.8, 0.86, 0.95), roughness := 0.16) -> StandardMaterial3D:
	var steel := StandardMaterial3D.new()
	steel.albedo_color = tint
	steel.metallic = 1.0
	steel.metallic_specular = 0.9
	steel.roughness = roughness
	return steel


static func cloth(color: Color, roughness := 0.8) -> StandardMaterial3D:
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = color
	cloth.roughness = roughness
	return cloth


static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3,
		turn := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	mesh.material = material
	part.mesh = mesh
	part.position = at
	part.rotation_degrees = turn
	parent.add_child(part)
	return part


## The knight's sword. It is built in the hand bone's own frame: the blade runs along the
## bone's +X, its edge faces +Y (the way the forearm swings) and the flat faces +Z. The hand
## bone is the end of the arm, so the grip sits a paw's length along Y.
static func make_sword() -> Node3D:
	var sword := Node3D.new()
	sword.name = "Sword"
	sword.position = Vector3(0.0, 0.1, 0.0)
	var blade_steel := steel()
	var edge := BoxMesh.new()
	edge.size = Vector3(1.55, 0.2, 0.045)
	_part(sword, edge, blade_steel, Vector3(0.9, 0.0, 0.0))
	var tip := PrismMesh.new()
	tip.size = Vector3(0.2, 0.3, 0.045)
	_part(sword, tip, blade_steel, Vector3(1.8, 0.0, 0.0), Vector3(0.0, 0.0, -90.0))
	var fuller := BoxMesh.new()
	fuller.size = Vector3(1.4, 0.06, 0.06)
	_part(sword, fuller, steel(Color(0.62, 0.68, 0.75), 0.35), Vector3(0.82, 0.0, 0.0))
	var guard := BoxMesh.new()
	guard.size = Vector3(0.09, 0.6, 0.12)
	_part(sword, guard, steel(SAFFRON, 0.3), Vector3(0.14, 0.0, 0.0))
	for side in [-1.0, 1.0]:
		var knob := SphereMesh.new()
		knob.radius = 0.07
		knob.height = 0.14
		_part(sword, knob, steel(SAFFRON, 0.3), Vector3(0.14, 0.3 * side, 0.0))
	var grip := CylinderMesh.new()
	grip.top_radius = 0.045
	grip.bottom_radius = 0.045
	grip.height = 0.34
	_part(sword, grip, cloth(TEAL, 0.6), Vector3(-0.04, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	var pommel := SphereMesh.new()
	pommel.radius = 0.085
	pommel.height = 0.17
	_part(sword, pommel, steel(SAFFRON, 0.3), Vector3(-0.24, 0.0, 0.0))
	return sword


## A tin bucket, open end down. The worn one sits tipped back on the dummy's head bone; the
## thrown one is the same build with no tilt, parented to the RigidBody3D.
static func make_bucket(thrown: bool) -> Node3D:
	var bucket := Node3D.new()
	bucket.name = "Bucket"
	if not thrown:
		bucket.position = BUCKET_PLACE
		bucket.rotation_degrees.x = BUCKET_TIP
	var tin := steel(Color(0.78, 0.82, 0.86), 0.3)
	var dents := FastNoiseLite.new()
	dents.noise_type = FastNoiseLite.TYPE_CELLULAR
	dents.frequency = 0.03
	dents.seed = 7
	var bumps := NoiseTexture2D.new()
	bumps.noise = dents
	bumps.width = 256
	bumps.height = 256
	bumps.seamless = true
	bumps.as_normal_map = true
	bumps.bump_strength = 4.0
	tin.normal_enabled = true
	tin.normal_texture = bumps
	tin.normal_scale = 0.6
	tin.uv1_scale = Vector3(3.0, 1.5, 1.0)
	var body := CylinderMesh.new()
	body.top_radius = 0.3
	body.bottom_radius = 0.42
	body.height = 0.42
	body.radial_segments = 40
	body.rings = 2
	_part(bucket, body, tin, Vector3.ZERO)
	var rim := TorusMesh.new()
	rim.inner_radius = 0.4
	rim.outer_radius = 0.44
	rim.rings = 40
	_part(bucket, rim, steel(Color(0.66, 0.7, 0.75), 0.4), Vector3(0.0, -0.21, 0.0))
	var rib := TorusMesh.new()
	rib.inner_radius = 0.345
	rib.outer_radius = 0.375
	rib.rings = 40
	_part(bucket, rib, steel(Color(0.66, 0.7, 0.75), 0.4), Vector3(0.0, -0.02, 0.0))
	# A painted band, so it reads as a bucket someone has had for years.
	var band := CylinderMesh.new()
	band.top_radius = 0.337
	band.bottom_radius = 0.356
	band.height = 0.09
	band.radial_segments = 40
	band.rings = 1
	_part(bucket, band, cloth(SAFFRON, 0.55), Vector3(0.0, 0.09, 0.0))
	for side in [-1.0, 1.0]:
		var lug := TorusMesh.new()
		lug.inner_radius = 0.035
		lug.outer_radius = 0.06
		_part(bucket, lug, steel(Color(0.5, 0.54, 0.58), 0.4), Vector3(0.355 * side, 0.1, 0.0),
				Vector3(0.0, 0.0, 90.0 + 18.0 * side))
	return bucket


## The knight's helmet: a steel cap tipped back a little, a saffron brim and a teal crest
## that sweeps back. It sits on the head bone, so it nods with the knight's breath.
static func make_helm() -> Node3D:
	var helm := Node3D.new()
	helm.name = "Helm"
	helm.position = Vector3(0.0, 0.4, -0.03)
	helm.rotation_degrees.x = -14.0
	var cap := SphereMesh.new()
	cap.radius = 0.45
	cap.height = 0.45
	cap.is_hemisphere = true
	cap.radial_segments = 40
	cap.rings = 14
	var cap_part := _part(helm, cap, steel(Color(0.84, 0.87, 0.92), 0.3), Vector3.ZERO)
	cap_part.scale = Vector3(1.0, 0.85, 1.0)
	var brim := TorusMesh.new()
	brim.inner_radius = 0.43
	brim.outer_radius = 0.475
	brim.rings = 40
	_part(helm, brim, steel(SAFFRON, 0.3), Vector3.ZERO)
	var crest := SphereMesh.new()
	crest.radius = 1.0
	crest.height = 2.0
	var arch := _part(helm, crest, cloth(TEAL, 0.55), Vector3(0.0, 0.33, -0.04))
	arch.scale = Vector3(0.05, 0.14, 0.4)
	var tail := _part(helm, crest, cloth(TEAL, 0.55), Vector3(0.0, 0.25, -0.42))
	tail.scale = Vector3(0.05, 0.1, 0.2)
	tail.rotation_degrees.x = -25.0
	return helm
