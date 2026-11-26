extends Node3D

enum Stage { BASELINE, MUZZLE, TRACER, HIT, RECOIL, DEBRIS, SOUND, FINISH }

const Assets := preload("res://demo_assets.gd")
const CASING := preload("res://casing.tscn")
const STAGE_LABELS := [
	"Damage only", "Muzzle flash and barrel kick", "Spread, tracer and sparks",
	"Target reaction", "Shooter and camera recoil", "Splatter and casings",
	"Positional sound", "Finishing hit",
]
const WORLD_LAYER := 1
const TARGET_LAYER := 2
const STARTING_HP := 3

@export var stage: Stage = Stage.FINISH
@export_range(0.0, 4.0, 0.1) var spread_degrees := 1.0

@onready var muzzle: Marker3D = $Muzzle
@onready var flash: Node3D = $Muzzle/Flash
@onready var eject: Marker3D = $Eject
@onready var kick: Node3D = $Kick
@onready var kick_rest: Vector3 = kick.position
@onready var barrel: MeshInstance3D = $Kick/Barrel
@onready var barrel_rest: Vector3 = barrel.position
@onready var camera: Camera3D = $Camera3D
@onready var tracer: MeshInstance3D = $Tracer
@onready var target: StaticBody3D = $Target
@onready var target_visual: Plush = $Target/Visual
@onready var target_rest: Vector3 = target_visual.position
@onready var health: Label3D = $Target/Health
@onready var effects: Node3D = $Effects
@onready var guide: CanvasLayer = $Guide
@onready var stage_label: Label = $Guide/Stage

var hp := STARTING_HP
var shot_tween: Tween
var hit_tween: Tween
var white_flash := StandardMaterial3D.new()
var sparks: PackedScene
var paint_burst: PackedScene
var smoke: PackedScene
var splatter: Texture2D
var crack: AudioStream
var whiz: AudioStream
var thud: AudioStream
var ping: AudioStream


func _ready() -> void:
	white_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sparks = Assets.make_sparks()
	paint_burst = Assets.make_paint()
	smoke = Assets.make_smoke()
	splatter = Assets.make_splatter()
	crack = Assets.make_sound(0.14, 210.0, 62.0, 0.68, 0.65, 31)
	whiz = Assets.make_sound(0.12, 1320.0, 390.0, 0.12, 0.07, 71)
	thud = Assets.make_sound(0.12, 125.0, 48.0, 0.15, 0.48, 19)
	ping = Assets.make_sound(0.24, 1060.0, 910.0, 0.08, 0.22, 83)
	reset_range()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key >= KEY_0 and key <= KEY_7:
		stage = (key - KEY_0) as Stage
		reset_range()
	elif key == KEY_R:
		reset_range()
	elif key == KEY_H:
		guide.visible = not guide.visible


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"wall_shot"):
		fire(true)
	elif Input.is_action_just_pressed(&"fire"):
		fire(false)


func reset_range() -> void:
	if shot_tween != null:
		shot_tween.kill()
	if hit_tween != null:
		hit_tween.kill()
	flash.hide()
	tracer.hide()
	kick.position = kick_rest
	barrel.position = barrel_rest
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	target.collision_layer = TARGET_LAYER
	target_visual.position = target_rest
	target_visual.scale = Vector3.ONE
	target_visual.mesh.material_override = target_visual.tint
	target_visual.stand()
	for effect in effects.get_children():
		effect.queue_free()
	hp = STARTING_HP
	health.text = str(hp)
	health.show()
	stage_label.text = "%d · %s" % [stage, STAGE_LABELS[stage]]


func fire(at_wall: bool) -> void:
	var origin := muzzle.global_position
	var spread := tan(deg_to_rad(spread_degrees)) if stage >= Stage.TRACER else 0.0
	var aim_x := 0.23 if at_wall else 0.0
	var aim := Vector3(aim_x + randf_range(-spread, spread), randf_range(-spread, spread), -1.0)
	var direction := (muzzle.global_basis * aim).normalized()
	var end := origin + direction * 18.0
	var query := PhysicsRayQueryParameters3D.create(origin, end, WORLD_LAYER | TARGET_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		end = hit.position

	play_shot(origin, end)
	if hit.is_empty():
		return

	if hit.collider == target and hp > 0:
		hit_target(direction)
		if stage >= Stage.DEBRIS:
			burst(paint_burst, end, hit.normal)
			stamp_surfaces(end, direction)
		if stage >= Stage.SOUND:
			play_at(thud, end)
	else:
		if stage >= Stage.TRACER:
			burst(sparks, end, hit.normal)
		if stage >= Stage.SOUND:
			play_at(ping, end)


func play_shot(origin: Vector3, end: Vector3) -> void:
	if stage < Stage.MUZZLE:
		return
	if shot_tween != null:
		shot_tween.kill()
	shot_tween = create_tween().set_parallel()
	flash.show()
	flash.rotation.z = randf() * TAU
	flash.scale = Vector3.ONE * randf_range(0.85, 1.15)
	barrel.position = barrel_rest + Vector3.BACK * 0.08
	shot_tween.tween_callback(flash.hide).set_delay(0.04)
	shot_tween.tween_property(barrel, "position", barrel_rest, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	burst(smoke, origin, -muzzle.global_basis.z)

	if stage >= Stage.TRACER:
		tracer.global_position = origin.lerp(end, 0.5)
		tracer.look_at(end, Vector3.UP)
		tracer.scale = Vector3(1.0, 1.0, origin.distance_to(end))
		tracer.set_instance_shader_parameter(&"tail", 0.0)
		tracer.show()
		shot_tween.tween_callback(tracer.hide).set_delay(0.06)
		shot_tween.tween_property(tracer, "scale:x", 0.2, 0.06)
		shot_tween.tween_property(tracer, "scale:y", 0.2, 0.06)
		shot_tween.tween_property(tracer, "instance_shader_parameters/tail", 1.0, 0.06)

	if stage >= Stage.RECOIL:
		kick.position = kick_rest + Vector3.BACK * 0.12
		camera.h_offset = 0.035
		camera.v_offset = 0.055
		shot_tween.tween_property(kick, "position", kick_rest, 0.13).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		shot_tween.tween_property(camera, "h_offset", 0.0, 0.10)
		shot_tween.tween_property(camera, "v_offset", 0.0, 0.10)
	if stage >= Stage.DEBRIS:
		eject_casing()
	if stage >= Stage.SOUND:
		play_at(crack, origin)
		play_at(whiz, origin.lerp(end, 0.7))


func hit_target(direction: Vector3) -> void:
	hp -= 1
	health.text = str(hp)
	if hp == 0:
		health.hide()
		target.collision_layer = 0
		if hit_tween != null:
			hit_tween.kill()
		if stage < Stage.FINISH:
			# Without the finishing layer the body just drops where it stood.
			target_visual.scale = Vector3.ONE
			target_visual.go_limp(direction * 1.4, Vector3.UP.cross(direction) * 3.0)
			return
	if stage < Stage.HIT:
		return
	if hit_tween != null:
		hit_tween.kill()

	target_visual.mesh.material_override = white_flash
	target_visual.position = target_rest + direction * 0.12
	target_visual.scale = Vector3(1.13, 0.83, 1.13)
	hit_tween = create_tween()
	hit_tween.tween_interval(0.055)
	hit_tween.tween_callback(func(): target_visual.mesh.material_override = target_visual.tint)

	if hp > 0:
		hit_tween.set_parallel()
		hit_tween.tween_property(target_visual, "position", target_rest, 0.13)
		hit_tween.tween_property(target_visual, "scale", Vector3.ONE, 0.13)
		return

	# Hold the struck pose, then knock the ragdoll up and over along the shot.
	hit_tween.tween_callback(func():
		target_visual.scale = Vector3.ONE
		target_visual.go_limp(direction * 3.2 + Vector3.UP * 3.2, Vector3.UP.cross(direction) * 14.0))


func burst(scene: PackedScene, point: Vector3, normal: Vector3) -> void:
	var particles := scene.instantiate() as GPUParticles3D
	effects.add_child(particles)
	particles.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), point + normal * 0.02)
	particles.restart()
	for part: GPUParticles3D in particles.get_children():
		part.restart()
	get_tree().create_timer(1.5).timeout.connect(particles.queue_free)


func eject_casing() -> void:
	var casing := CASING.instantiate() as RigidBody3D
	effects.add_child(casing)
	casing.global_transform = eject.global_transform
	casing.linear_velocity = muzzle.global_basis * Vector3(1.7, 1.9, 0.25)
	casing.angular_velocity = Vector3(7.0, 3.0, 10.0)
	get_tree().create_timer(6.0).timeout.connect(casing.queue_free)


func stamp_surfaces(point: Vector3, direction: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	for end: Vector3 in [point + direction * 2.8, point + Vector3.DOWN * 1.5]:
		var query := PhysicsRayQueryParameters3D.create(point, end, WORLD_LAYER)
		var surface := space.intersect_ray(query)
		if surface.is_empty():
			continue
		var decal := Decal.new()
		decal.size = Vector3(0.75, 0.16, 0.75)
		decal.texture_albedo = splatter
		var normal: Vector3 = surface.normal
		effects.add_child(decal)
		decal.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, normal)), surface.position)
		get_tree().create_timer(12.0).timeout.connect(decal.queue_free)


func play_at(stream: AudioStream, point: Vector3) -> void:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	effects.add_child(player)
	player.global_position = point
	player.finished.connect(player.queue_free)
	player.play()
