extends RefCounted
## What the fighter wears: a headband with a knot and two tails at the back.

const BAND := Color("#d11f27")
const STRIPE := Color("#fff4dc")
## Where the band sits on the head bone, in metres of the bone's own frame, and how it tilts.
const BAND_PLACE := Vector3(0.0, 0.5, -0.015)
const BAND_TILT := -7.0


static func cloth(color: Color, roughness := 0.7) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.rim_enabled = true
	material.rim = 0.2
	material.rim_tint = 0.5
	return material


static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3,
		turn := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	mesh.material = material
	part.mesh = mesh
	part.position = at
	part.rotation_degrees = turn
	parent.add_child(part)
	return part


## The headband: a wide cloth ring, a thin stripe along its lower edge, and a knot at the back with
## two tails that hang down and trail.
static func make_headband() -> Node3D:
	var band := Node3D.new()
	band.name = "Headband"
	band.position = BAND_PLACE
	band.rotation_degrees.x = BAND_TILT
	var ring := CylinderMesh.new()
	ring.top_radius = 0.445
	ring.bottom_radius = 0.455
	ring.height = 0.12
	ring.radial_segments = 64
	ring.rings = 1
	ring.cap_top = false
	ring.cap_bottom = false
	_part(band, ring, cloth(BAND), Vector3.ZERO)
	var stripe := CylinderMesh.new()
	stripe.top_radius = 0.4475
	stripe.bottom_radius = 0.4475
	stripe.height = 0.025
	stripe.radial_segments = 64
	stripe.rings = 1
	stripe.cap_top = false
	stripe.cap_bottom = false
	_part(band, stripe, cloth(STRIPE), Vector3(0.0, 0.0, 0.0)).scale = Vector3(1.012, 1.0, 1.012)
	var knot := SphereMesh.new()
	knot.radius = 0.06
	knot.height = 0.12
	_part(band, knot, cloth(BAND.darkened(0.12)), Vector3(0.0, 0.0, -0.46))
	for side in [-1.0, 1.0]:
		var tail := CapsuleMesh.new()
		tail.radius = 0.035
		tail.height = 0.34
		var piece := _part(band, tail, cloth(BAND), Vector3(0.07 * side, -0.14, -0.5),
				Vector3(14.0, 0.0, 12.0 * side))
		piece.scale = Vector3(1.0, 1.0, 0.35)
	return band
