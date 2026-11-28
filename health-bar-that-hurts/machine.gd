class_name Machine
extends Node3D
## The tennis-ball pitching machine, built from primitives: a chunky red toy on two fat wheels,
## a glass hopper full of balls, a yellow barrel and a bulb that blinks faster as it charges.
## It faces +X, so rotate the node to aim it. `wind_up()` and `fire()` only animate; yard.gd
## decides when a ball leaves and where it goes.

const RED := Color(0.9, 0.13, 0.11)
const YELLOW := Color(1.0, 0.78, 0.12)
const CREAM := Color(0.97, 0.94, 0.86)
const CHARCOAL := Color(0.13, 0.13, 0.16)
const BALL_SHADER := preload("res://ball.gdshader")

var turret: Node3D
var barrel: Node3D
var body: Node3D
var bulb: MeshInstance3D
var bulb_material: StandardMaterial3D
var hopper_balls: Node3D
var muzzle: Marker3D
var charge := 0.0
var clock := 0.0
var kick := 0.0
var tween: Tween


func _ready() -> void:
	body = Node3D.new()
	add_child(body)
	_chassis()
	_hopper()
	_turret()
	_details()


func _plastic(color: Color, roughness := 0.28) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.clearcoat_enabled = true
	material.clearcoat = 0.35
	material.clearcoat_roughness = 0.18
	return material


func _add(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, turn := Vector3.ZERO) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.rotation_degrees = turn
	parent.add_child(part)
	return part


func _cylinder(radius: float, height: float, segments := 56) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _torus(inner: float, outer: float) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 24
	return mesh


func _chassis() -> void:
	var red := _plastic(RED)
	var yellow := _plastic(YELLOW)
	var cream := _plastic(CREAM, 0.35)
	var rubber := StandardMaterial3D.new()
	rubber.albedo_color = CHARCOAL
	rubber.roughness = 0.75
	# The body: a fat rounded box with a cream stripe round its middle.
	_add(body, Soft.rounded_box(Vector3(1.0, 0.56, 0.74), 0.17), red, Vector3(0.0, 0.62, 0.0))
	_add(body, Soft.rounded_box(Vector3(1.02, 0.13, 0.76), 0.06), cream, Vector3(0.0, 0.58, 0.0))
	# Two big wheels on an axle: tyre, rim and a yellow hub.
	for side in [-1.0, 1.0]:
		var wheel := Node3D.new()
		wheel.position = Vector3(-0.12, 0.34, 0.47 * side)
		wheel.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		body.add_child(wheel)
		_add(wheel, _cylinder(0.34, 0.15), rubber, Vector3.ZERO)
		_add(wheel, _cylinder(0.22, 0.17), cream, Vector3.ZERO)
		_add(wheel, _cylinder(0.11, 0.2), yellow, Vector3.ZERO)
		for spoke in 6:
			var bolt := _add(wheel, _cylinder(0.022, 0.19, 16), red, Vector3(0.16 * cos(TAU * spoke / 6.0), 0.0, 0.16 * sin(TAU * spoke / 6.0)))
			bolt.name = "Bolt%d" % spoke
	# A stubby front leg and a rear tow handle.
	_add(body, Soft.rounded_box(Vector3(0.18, 0.34, 0.5), 0.06), yellow, Vector3(0.46, 0.2, 0.0))
	var handle := _add(body, _torus(0.028, 0.115), yellow, Vector3(-0.62, 0.78, 0.0), Vector3(0.0, 90.0, 0.0))
	handle.scale = Vector3(1.3, 1.0, 1.0)


func _hopper() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.9, 1.0, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic_specular = 0.9
	var funnel := CylinderMesh.new()
	funnel.top_radius = 0.34
	funnel.bottom_radius = 0.2
	funnel.height = 0.5
	funnel.radial_segments = 56
	funnel.rings = 1
	var hopper := Node3D.new()
	hopper.position = Vector3(-0.2, 1.17, 0.0)
	body.add_child(hopper)
	# A rim and a base ring in yellow, and the glass between them.
	_add(hopper, funnel, glass, Vector3.ZERO)
	_add(hopper, _torus(0.3, 0.37), _plastic(YELLOW), Vector3(0.0, 0.25, 0.0))
	_add(hopper, _torus(0.17, 0.23), _plastic(YELLOW), Vector3(0.0, -0.25, 0.0))
	hopper_balls = Node3D.new()
	hopper.add_child(hopper_balls)
	var spots := [Vector3(0.0, -0.1, 0.0), Vector3(0.17, -0.12, 0.05), Vector3(-0.15, -0.1, 0.1),
			Vector3(0.05, -0.12, -0.17), Vector3(-0.1, -0.1, -0.14), Vector3(0.12, 0.05, -0.1),
			Vector3(-0.12, 0.06, 0.0), Vector3(0.08, 0.08, 0.14), Vector3(0.0, 0.13, -0.02)]
	for i in spots.size():
		var ball := make_ball(0.1)
		ball.position = spots[i]
		ball.rotation = Vector3(i * 1.3, i * 2.1, i * 0.7)
		hopper_balls.add_child(ball)


func _turret() -> void:
	turret = Node3D.new()
	turret.position = Vector3(0.3, 0.98, 0.0)
	body.add_child(turret)
	_add(turret, Soft.rounded_box(Vector3(0.36, 0.3, 0.48), 0.1), _plastic(YELLOW), Vector3(-0.06, -0.02, 0.0))
	barrel = Node3D.new()
	barrel.position = Vector3(0.1, 0.04, 0.0)
	turret.add_child(barrel)
	var tube := _plastic(CREAM, 0.3)
	_add(barrel, _cylinder(0.205, 0.78), tube, Vector3(0.28, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	# Red bands round the barrel and a fat red lip at the mouth.
	_add(barrel, _cylinder(0.215, 0.08), _plastic(RED), Vector3(0.04, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	_add(barrel, _cylinder(0.215, 0.08), _plastic(RED), Vector3(0.38, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	_add(barrel, _torus(0.14, 0.27), _plastic(RED), Vector3(0.68, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	var hole := _cylinder(0.15, 0.02)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.02, 0.02, 0.03)
	dark.roughness = 1.0
	_add(barrel, hole, dark, Vector3(0.66, 0.0, 0.0), Vector3(0.0, 0.0, 90.0))
	muzzle = Marker3D.new()
	muzzle.position = Vector3(0.74, 0.0, 0.0)
	barrel.add_child(muzzle)


func _details() -> void:
	# The bulb on a stalk, a panel with a dial and two buttons on the side that faces the camera.
	bulb_material = StandardMaterial3D.new()
	bulb_material.albedo_color = Color(1.0, 0.2, 0.15)
	bulb_material.emission_enabled = true
	bulb_material.emission = Color(1.0, 0.15, 0.1)
	bulb_material.emission_energy_multiplier = 0.3
	var stalk := _cylinder(0.025, 0.22, 16)
	_add(body, stalk, _plastic(CHARCOAL), Vector3(0.12, 1.25, 0.3))
	var sphere := SphereMesh.new()
	sphere.radius = 0.075
	sphere.height = 0.15
	sphere.radial_segments = 40
	sphere.rings = 20
	bulb = _add(body, sphere, bulb_material, Vector3(0.12, 1.4, 0.3))
	for side in [1.0]:
		var panel := Node3D.new()
		panel.position = Vector3(0.0, 0.66, 0.375 * side)
		body.add_child(panel)
		_add(panel, Soft.rounded_box(Vector3(0.5, 0.26, 0.04), 0.02), _plastic(CHARCOAL, 0.5), Vector3.ZERO)
		var dial := _add(panel, _cylinder(0.075, 0.05, 40), _plastic(CREAM), Vector3(-0.13, 0.0, 0.03), Vector3(90.0, 0.0, 0.0))
		dial.rotation_degrees.y = 35.0
		_add(panel, Soft.rounded_box(Vector3(0.02, 0.1, 0.03), 0.008), _plastic(RED), Vector3(-0.13, 0.04, 0.062))
		for i in 2:
			_add(panel, _cylinder(0.04, 0.05, 28), _plastic(RED if i == 0 else YELLOW), Vector3(0.05 + 0.12 * i, 0.0, 0.03), Vector3(90.0, 0.0, 0.0))


## A tennis ball as the machine and the lawn see it.
static func make_ball(radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 48
	mesh.rings = 24
	var material := ShaderMaterial.new()
	material.shader = BALL_SHADER
	mesh.material = material
	var ball := MeshInstance3D.new()
	ball.mesh = mesh
	return ball


## Aim the barrel along a direction in the world: turn the whole machine, tilt the turret.
func aim(direction: Vector3) -> void:
	rotation.y = atan2(-direction.z, direction.x)
	var flat := Vector2(direction.x, direction.z).length()
	turret.rotation.z = atan2(direction.y, flat)


## The machine winds up for this long: it crouches on its wheels, the barrel draws back, the
## bulb blinks faster and the balls rattle in the hopper.
func wind_up(seconds: float) -> void:
	if tween != null:
		tween.kill()
	tween = create_tween().set_parallel()
	tween.tween_property(self, "charge", 1.0, seconds)
	tween.tween_property(body, "scale", Vector3(1.05, 0.9, 1.0), seconds * 0.8) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(barrel, "position:x", -0.04, seconds * 0.9) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


## The ball has left: the barrel slams forward and rings, the body hops back.
func fire() -> void:
	if tween != null:
		tween.kill()
	charge = 0.0
	kick = 1.0
	body.scale = Vector3(0.95, 1.08, 1.0)
	barrel.position.x = 0.26
	tween = create_tween().set_parallel()
	tween.tween_property(body, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(barrel, "position:x", 0.1, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func idle() -> void:
	if tween != null:
		tween.kill()
	charge = 0.0
	body.scale = Vector3.ONE
	barrel.position.x = 0.1


func _process(delta: float) -> void:
	clock += delta
	kick = maxf(kick - delta * 6.0, 0.0)
	var blink_hz := 1.4 + 9.0 * charge
	var on := 1.0 if fmod(clock * blink_hz, 1.0) < 0.5 else 0.0
	bulb_material.emission_energy_multiplier = 0.25 + 2.2 * on * (0.3 + 0.7 * charge) + 3.0 * kick
	# The balls shiver in the hopper while it charges.
	hopper_balls.position = Vector3(sin(clock * 90.0), cos(clock * 77.0), sin(clock * 63.0)) * 0.006 * charge
