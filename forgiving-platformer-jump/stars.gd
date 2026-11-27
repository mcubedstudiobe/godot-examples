class_name Stars
extends Node3D
## Three little stars that circle a dazed head.

const RADIUS := 0.38

var time := 0.0
var stars: Array[MeshInstance3D] = []


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.88, 0.25)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission = Color(1.0, 0.8, 0.2)
	material.emission_energy_multiplier = 1.6
	for i in 3:
		var star := MeshInstance3D.new()
		star.mesh = Effects.star_mesh()
		star.material_override = material
		add_child(star)
		stars.append(star)


func _process(delta: float) -> void:
	time += delta
	for i in stars.size():
		var a := time * 3.4 + float(i) / stars.size() * TAU
		stars[i].position = Vector3(cos(a) * RADIUS, sin(a * 2.0) * 0.03, sin(a) * RADIUS * 0.6)
		stars[i].rotation.z = time * 4.0 + i
