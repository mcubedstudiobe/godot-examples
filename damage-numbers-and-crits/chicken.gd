class_name RubberChicken
extends Node3D
## The weapon: a big rubber chicken, built from primitives. It is held by its legs, so everything
## that is not the legs hangs off the far end like a club. In the hand bone's own frame the chicken
## runs along +X from the paw, with its belly towards -Y.
##
## Its neck is floppy. The head is a point that a spring pulls towards a resting spot beyond the
## body, drooping under gravity, and the neck is a smooth curve from the body to that point, so a
## fast swing makes the head whip behind the body and flop forward again.

const YELLOW := Color("#ffe45c")
const ORANGE := Color("#f3a21c")
const RED := Color("#d92b2b")

## Where the neck leaves the body, and how long it is, in the hand bone's frame.
const NECK_BASE := Vector3(1.12, 0.02, 0.0)
const NECK_LENGTH := 0.62
const NECK_SEGMENTS := 7
## How hard the spring pulls the head to its resting place, how much it is damped, and how far
## the resting place droops.
const SPRING := 140.0
const DAMPING := 9.0
const DROOP := 0.45
const REACH := 0.4

var neck_parts: Array[MeshInstance3D] = []
var head: Node3D
var head_point := Vector3.ZERO ## in world space
var head_velocity := Vector3.ZERO
var started := false


func _ready() -> void:
	name = "RubberChicken"
	_build()


func _build() -> void:
	var rubber := _rubber(YELLOW)
	var beak_rubber := _rubber(ORANGE)
	var red_rubber := _rubber(RED)
	# The legs are the handle: two thin, slightly splayed shanks with a drumstick bulge each.
	for side in [-1.0, 1.0]:
		var shank := CapsuleMesh.new()
		shank.radius = 0.034
		shank.height = 0.5
		_part(self, shank, beak_rubber, Vector3(0.22, 0.0, 0.05 * side), Vector3(0.0, 0.0, 90.0))
		var drumstick := SphereMesh.new()
		drumstick.radius = 0.075
		drumstick.height = 0.15
		_part(self, drumstick, rubber, Vector3(0.52, 0.0, 0.1 * side)).scale = Vector3(1.55, 1.0, 1.0)
		for toe in [-1.0, 0.0, 1.0]:
			var claw := CapsuleMesh.new()
			claw.radius = 0.02
			claw.height = 0.1
			_part(self, claw, beak_rubber, Vector3(-0.07, 0.0, 0.05 * side + 0.035 * toe),
					Vector3(0.0, 25.0 * toe, 90.0))
	# The body: a plump ellipsoid, a lighter belly and a pair of stubby wings.
	var body := SphereMesh.new()
	body.radius = 0.3
	body.height = 0.6
	body.radial_segments = 64
	body.rings = 32
	_part(self, body, rubber, Vector3(0.86, 0.0, 0.0)).scale = Vector3(1.12, 0.88, 0.86)
	for side in [-1.0, 1.0]:
		var wing := SphereMesh.new()
		wing.radius = 0.2
		wing.height = 0.4
		wing.radial_segments = 40
		wing.rings = 20
		var w := _part(self, wing, _rubber(YELLOW.darkened(0.08)), Vector3(0.82, 0.03, 0.25 * side),
				Vector3(0.0, 0.0, -10.0))
		w.scale = Vector3(1.0, 0.7, 0.22)
	# The tail: three fat rubber plumes at the back, by the legs.
	for k in 3:
		var plume := CapsuleMesh.new()
		plume.radius = 0.045
		plume.height = 0.26
		_part(self, plume, _rubber(ORANGE.lerp(RED, 0.35)), Vector3(0.62, 0.0, 0.0),
				Vector3(0.0, 0.0, 90.0 + (k - 1) * 30.0)).position += Vector3(0.0, 0.0, 0.0)
	# The neck is a string of overlapping capsules, laid along a curve every frame.
	for i in NECK_SEGMENTS:
		var capsule := CapsuleMesh.new()
		capsule.radius = lerpf(0.082, 0.062, float(i) / NECK_SEGMENTS)
		capsule.height = NECK_LENGTH / NECK_SEGMENTS * 2.4
		capsule.radial_segments = 24
		capsule.rings = 8
		neck_parts.append(_part(self, capsule, rubber, NECK_BASE))
	# The head: round, with a two-part beak, a three-bump comb, a wattle and googly eyes.
	head = Node3D.new()
	head.name = "Head"
	add_child(head)
	var skull := SphereMesh.new()
	skull.radius = 0.15
	skull.height = 0.3
	skull.radial_segments = 40
	skull.rings = 20
	_part(head, skull, rubber, Vector3.ZERO)
	var upper := CylinderMesh.new()
	upper.top_radius = 0.0
	upper.bottom_radius = 0.1
	upper.height = 0.26
	upper.radial_segments = 24
	_part(head, upper, beak_rubber, Vector3(0.24, 0.02, 0.0), Vector3(0.0, 0.0, -90.0))
	var lower := CylinderMesh.new()
	lower.top_radius = 0.0
	lower.bottom_radius = 0.075
	lower.height = 0.2
	lower.radial_segments = 24
	_part(head, lower, beak_rubber.duplicate(), Vector3(0.2, -0.06, 0.0), Vector3(0.0, 0.0, -98.0))
	for k in 3:
		var comb := SphereMesh.new()
		comb.radius = 0.055 - 0.008 * abs(k - 1)
		comb.height = comb.radius * 2.0
		_part(head, comb, red_rubber, Vector3(-0.04 + 0.06 * k, 0.15 - 0.012 * abs(k - 1), 0.0))
	var wattle := SphereMesh.new()
	wattle.radius = 0.05
	wattle.height = 0.1
	_part(head, wattle, red_rubber, Vector3(0.15, -0.14, 0.0)).scale = Vector3(0.8, 1.5, 0.8)
	for side in [-1.0, 1.0]:
		var white := SphereMesh.new()
		white.radius = 0.062
		white.height = 0.124
		var eye := StandardMaterial3D.new()
		eye.albedo_color = Color.WHITE
		eye.roughness = 0.12
		_part(head, white, eye, Vector3(0.1, 0.07, 0.115 * side))
		var pupil := SphereMesh.new()
		pupil.radius = 0.03
		pupil.height = 0.06
		var ink := StandardMaterial3D.new()
		ink.albedo_color = Color.BLACK
		ink.roughness = 0.2
		# The pupils look a little off to each side: a chicken that cannot believe it either.
		_part(head, pupil, ink, Vector3(0.148, 0.062, 0.1 * side + 0.014 * side))


func _process(delta: float) -> void:
	if neck_parts.is_empty() or delta <= 0.0:
		return
	var base := to_global(NECK_BASE)
	var rest := base + global_basis.x.normalized() * REACH + Vector3.DOWN * DROOP
	if not started:
		head_point = rest
		started = true
	# A few small steps keep the spring stable however long the frame was.
	var steps := ceili(delta / 0.008)
	var dt := delta / steps
	for i in steps:
		head_velocity += ((rest - head_point) * SPRING - head_velocity * DAMPING) * dt
		head_point += head_velocity * dt
		var along := head_point - base
		var scale_ := global_basis.x.length()
		if along.length() > NECK_LENGTH * scale_:
			head_point = base + along.normalized() * NECK_LENGTH * scale_
	_lay_out_neck(base)


## Lay the neck along a curve: it leaves the body along the chicken's own X, and ends on the head.
func _lay_out_neck(base: Vector3) -> void:
	var tip := head_point
	var out := global_basis.x.normalized()
	var length := (tip - base).length()
	var control := base + out * length * 0.55
	var previous := base
	for i in NECK_SEGMENTS:
		var t := float(i + 1) / NECK_SEGMENTS
		var point := base.lerp(control, t).lerp(control.lerp(tip, t), t)
		var middle := (previous + point) * 0.5
		var direction := (point - previous)
		if direction.length() < 0.0001:
			direction = out * 0.001
		var part := neck_parts[i]
		part.global_transform = Transform3D(_aligned(direction, global_basis), middle)
		previous = point
	# The head hangs on the end: its beak follows the last stretch of neck, drooping.
	var heading := (tip - previous)
	if heading.length() < 0.0001:
		heading = out
	var droop := (heading.normalized() + Vector3.DOWN * 0.55 + out * 0.1).normalized()
	head.global_transform = Transform3D(_aligned(droop, global_basis, true), tip)


## A basis whose X axis (or, for a capsule, Y) runs along a direction, keeping the chicken's up.
func _aligned(direction: Vector3, reference: Basis, along_x := false) -> Basis:
	var d := direction.normalized()
	var up := reference.y.normalized()
	if absf(d.dot(up)) > 0.98:
		up = reference.z.normalized()
	var side := d.cross(up).normalized()
	var fixed_up := side.cross(d).normalized()
	var scale_ := reference.x.length()
	if along_x:
		return Basis(d, fixed_up, side) * Basis.from_scale(Vector3.ONE * scale_)
	# A capsule stands along its own Y.
	return Basis(side, d, -fixed_up) * Basis.from_scale(Vector3.ONE * scale_)


func _rubber(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.28
	material.metallic_specular = 0.7
	material.clearcoat_enabled = true
	material.clearcoat = 0.55
	material.clearcoat_roughness = 0.2
	material.rim_enabled = true
	material.rim = 0.25
	material.rim_tint = 0.6
	return material


func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	mesh.material = material
	part.mesh = mesh
	part.position = at
	part.rotation_degrees = turn
	parent.add_child(part)
	return part
