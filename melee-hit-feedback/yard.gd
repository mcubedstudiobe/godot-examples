extends Node3D
## A plush knight, a plush training dummy and a three-hit combo. Each stage adds one kind of
## feedback on top of the last. Everything the demo's script talks about is a constant here.

enum Stage { BARE, TIME, TARGET, ROOM, EAR, FINISH }

const Assets := preload("res://demo_assets.gd")
const Props := preload("res://props.gd")
const WHOOSH := preload("res://sounds/whoosh.wav")
const CRUNCH := preload("res://sounds/crunch.wav")
const CLANG := preload("res://sounds/clang.wav")
const THUD := preload("res://sounds/thud.wav")
const STAGE_LABELS := [
	"Damage only", "Time: hit-stop", "The target: flash, squash and shove",
	"The room: sparks and camera kick", "The ear: crunch and rising pitch",
	"The finisher: double everything",
]

## Every hit does the same damage, at every stage. Three hits take the dummy down.
const DAMAGE := 10
const COMBO_HITS := 3
const STARTING_HP := DAMAGE * COMBO_HITS
## Time. On contact the game crawls for about sixty milliseconds of real time.
const HIT_STOP_SECONDS := 0.06
const HIT_STOP_SCALE := 0.05
## The target. A flash of pure white, a squash of its mesh and a shove away from the blade.
const FLASH_SECONDS := 0.05
const SQUASH := Vector3(1.13, 0.83, 1.13)
const SHOVE_METRES := 0.12
## The room. Sparks along the swing and a small kick of the camera.
const SPARK_COUNT := 26
const CAMERA_KICK := 0.035
## The ear. Each hit of the combo plays the crunch a notch higher.
const PITCH_STEP_SEMITONES := 2.0
const CRUNCH_DB := -3.0
## The finisher. The last hit of the combo multiplies all of the above.
const FINISHER_MULTIPLIER := 2.0

@export var stage: Stage = Stage.FINISH
## Where the camera looks. Its position is the camera node's own.
@export var look_at_point := Vector3(0.0, 1.15, -0.2)

@onready var camera: Camera3D = $Camera3D
@onready var knight: Plush = $Knight
@onready var dummy: Plush = $Stand/Dummy
@onready var stand: Node3D = $Stand
@onready var thrown_bucket: RigidBody3D = $Bucket
@onready var hp_label: Label3D = $Stand/Health
@onready var effects: Node3D = $Effects
@onready var guide: CanvasLayer = $Guide
@onready var stage_label: Label = $Guide/Stage
@onready var dummy_rest: Vector3 = dummy.position

var hp := STARTING_HP
var hits := 0
## The attack the knight is swinging (-1 for none) and whether its hit has landed yet.
var attack := -1
var attack_time := 0.0
var landed := false
var whooshed := false
## Bumped on every reset, so a hit-stop that outlives a reset knows to stop.
var epoch := 0
var hit_tween: Tween
var kick_tween: Tween
var bucket_tween: Tween
var sparks: PackedScene
var dust: PackedScene
var clang_gap := 0.0
var last_fall := 0.0
var thudded := false
var worn_bucket: Node3D


func _ready() -> void:
	camera.look_at(look_at_point)
	sparks = Assets.make_sparks()
	dust = Assets.make_dust()
	face(knight, dummy.global_position - knight.global_position)
	# The dummy looks half at the knight and half at the camera, so its face and its X eyes
	# are always in view.
	var to_knight := (knight.global_position - dummy.global_position).normalized()
	var to_camera := (camera.global_position - dummy.global_position) * Vector3(1.0, 0.0, 1.0)
	face(dummy, to_knight + to_camera.normalized())
	dress_knight()
	wear_bucket()
	reset_yard()


## Turn a plush about the vertical to face a direction. The model looks along +Z.
func face(plush: Node3D, direction: Vector3) -> void:
	plush.rotation.y = atan2(direction.x, direction.z)


## The sword rides a BoneAttachment3D on the knight's right hand bone, so the arm bones the
## swing turns carry it. The grip sits in the paw and the blade runs across the forearm.
func dress_knight() -> void:
	var grip := BoneAttachment3D.new()
	grip.bone_name = &"DEF-hand.R"
	knight.skeleton.add_child(grip)
	grip.add_child(Props.make_sword())
	# A helmet on the head bone, so the knight looks the part.
	var head := BoneAttachment3D.new()
	head.bone_name = &"DEF-head"
	knight.skeleton.add_child(head)
	head.add_child(Props.make_helm())


## The bucket sits on the dummy's head bone, tipped back so its face shows. When the last hit
## lands, this one hides and the RigidBody3D takes its place at the same pose.
func wear_bucket() -> void:
	var head := BoneAttachment3D.new()
	head.bone_name = &"DEF-head"
	dummy.skeleton.add_child(head)
	worn_bucket = Props.make_bucket(false)
	head.add_child(worn_bucket)
	thrown_bucket.add_child(Props.make_bucket(true))
	thrown_bucket.body_entered.connect(_on_bucket_landed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key >= KEY_0 and key <= KEY_5:
		stage = (key - KEY_0) as Stage
		reset_yard()
	elif key == KEY_R:
		reset_yard()
	elif key == KEY_H:
		guide.visible = not guide.visible
	elif key == KEY_SPACE:
		strike()


## Space: swing the next attack of the combo. Once the dummy is down it stands it back up.
func strike() -> void:
	if hp <= 0:
		reset_yard()
	elif attack < 0:
		attack = hits
		attack_time = 0.0
		landed = false
		whooshed = false


func _process(delta: float) -> void:
	clang_gap += delta
	if attack < 0:
		return
	attack_time += delta
	knight.motion.attack = attack
	knight.motion.attack_time = attack_time
	var contact := PlushMotion.contact_time(attack)
	if stage >= Stage.EAR and not whooshed and attack_time >= contact - 0.27:
		whooshed = true
		play_at(WHOOSH, knight.global_position + Vector3.UP * 0.9, -2.0)
	if not landed and attack_time >= contact:
		landed = true
		resolve_hit()
	if attack_time >= PlushMotion.duration(attack):
		attack = -1
		knight.motion.attack = -1


func _physics_process(_delta: float) -> void:
	# The dummy's thud: the hips fall, then stop.
	if hp > 0 or thudded or dummy.ragdoll == null:
		return
	var hips: PhysicalBone3D = dummy.ragdoll.get_child(0)
	var fall := hips.linear_velocity.y
	if last_fall < -1.5 and fall > last_fall + 1.5:
		thudded = true
		if stage >= Stage.EAR:
			play_at(THUD, hips.global_position, 0.0)
		burst(dust, hips.global_position + Vector3.DOWN * 0.2, Vector3.UP, 1.0)
	last_fall = fall


func resolve_hit() -> void:
	hits += 1
	hp -= DAMAGE
	hp_label.text = str(maxi(hp, 0))
	var finisher := stage >= Stage.FINISH and hits == COMBO_HITS
	var boost := FINISHER_MULTIPLIER if finisher else 1.0
	var swing := knight.global_basis * PlushMotion.swing_direction(attack)
	var point := worn_bucket.global_position
	var away := dummy.global_position - knight.global_position
	away.y = 0.0
	var push := (away.normalized() + swing * 0.4).normalized()

	if stage >= Stage.EAR:
		var crunch := play_at(CRUNCH, point, CRUNCH_DB + linear_to_db(boost))
		crunch.pitch_scale = pow(2.0, PITCH_STEP_SEMITONES * (hits - 1) / 12.0)
		play_at(CLANG, point, -4.0 + linear_to_db(boost))
	if stage >= Stage.ROOM:
		burst(sparks, point, swing, boost)
		kick_camera(swing, boost)
	if stage >= Stage.TARGET:
		react(push, boost)
	if stage >= Stage.TIME:
		await hit_stop(HIT_STOP_SECONDS * boost)
	if hp <= 0:
		knock_out(push, finisher)


## Hit-stop: the game crawls, and a timer that ignores the crawl says when it is over.
## The timer is set to keep running while the tree is paused, so pausing the game in the
## middle of a hit-stop cannot leave it stuck.
func hit_stop(seconds: float) -> void:
	var mine := epoch
	Engine.time_scale = HIT_STOP_SCALE
	# process_always = true, process_in_physics = false, ignore_time_scale = true.
	await get_tree().create_timer(seconds, true, false, true).timeout
	if mine == epoch:
		Engine.time_scale = 1.0


## The target: white (the plush shader's flash), squashed and shoved. It moves the dummy's
## root only; nothing here touches a collision shape.
func react(push: Vector3, boost: float) -> void:
	if hit_tween != null:
		hit_tween.kill()
	dummy.tint.set_shader_parameter(&"flash", 1.0)
	dummy.position = dummy_rest + push * SHOVE_METRES * boost
	dummy.scale = Vector3.ONE.lerp(SQUASH, boost)
	var mine := epoch
	# Real time again, so the flash is as long as it says even in the middle of a hit-stop.
	get_tree().create_timer(FLASH_SECONDS * boost, true, false, true).timeout.connect(func():
		if mine == epoch and hp > 0:
			dummy.tint.set_shader_parameter(&"flash", 0.0))
	hit_tween = create_tween().set_parallel()
	hit_tween.tween_property(dummy, "position", dummy_rest, 0.14)
	hit_tween.tween_property(dummy, "scale", Vector3.ONE, 0.14)
	# The bucket rings: knocked back on the head, then settling.
	if bucket_tween != null:
		bucket_tween.kill()
	worn_bucket.rotation_degrees.x = Props.BUCKET_TIP - 22.0 * boost
	bucket_tween = create_tween()
	bucket_tween.tween_property(worn_bucket, "rotation_degrees:x", Props.BUCKET_TIP, 0.5) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func kick_camera(swing: Vector3, boost: float) -> void:
	if kick_tween != null:
		kick_tween.kill()
	camera.h_offset = swing.dot(camera.global_basis.x) * CAMERA_KICK * boost
	camera.v_offset = swing.dot(camera.global_basis.y) * CAMERA_KICK * boost
	kick_tween = create_tween().set_parallel()
	kick_tween.tween_property(camera, "h_offset", 0.0, 0.14)
	kick_tween.tween_property(camera, "v_offset", 0.0, 0.14)


## The last hit: the bucket leaves and the dummy goes limp with X's for eyes. The bucket is
## a RigidBody3D that picks up from the worn bucket's pose.
func knock_out(push: Vector3, finisher: bool) -> void:
	dummy.scale = Vector3.ONE
	dummy.tint.set_shader_parameter(&"flash", 0.0)
	hp_label.hide()
	thudded = false
	last_fall = 0.0
	var big := FINISHER_MULTIPLIER if finisher else 1.0
	thrown_bucket.global_transform = worn_bucket.global_transform
	worn_bucket.hide()
	thrown_bucket.show()
	thrown_bucket.freeze = false
	thrown_bucket.collision_layer = 16
	thrown_bucket.linear_velocity = (push * 0.6 + Vector3.UP * 2.2) * big if finisher \
			else push * 0.6 + Vector3.UP * 1.4
	thrown_bucket.angular_velocity = Vector3(7.0, 2.0, 11.0) * big
	# Roll it around the way it faces, so it lands on its side with the X eyes in view.
	dummy.go_limp(push * (1.3 if finisher else 0.8) + Vector3.UP * (3.0 if finisher else 0.5),
			-dummy.global_basis.z * (10.0 if finisher else 6.0) + Vector3.UP * 3.0)


func reset_yard() -> void:
	var was_down := hp <= 0
	epoch += 1
	Engine.time_scale = 1.0
	for tween in [hit_tween, kick_tween, bucket_tween]:
		if tween != null:
			tween.kill()
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	attack = -1
	knight.motion.attack = -1
	dummy.position = dummy_rest
	dummy.scale = Vector3.ONE
	dummy.tint.set_shader_parameter(&"flash", 0.0)
	dummy.stand()
	worn_bucket.rotation_degrees.x = Props.BUCKET_TIP
	worn_bucket.show()
	thrown_bucket.freeze = true
	thrown_bucket.collision_layer = 0
	thrown_bucket.hide()
	for effect in effects.get_children():
		effect.queue_free()
	hp = STARTING_HP
	hits = 0
	thudded = false
	hp_label.text = str(hp)
	hp_label.show()
	stage_label.text = "%d · %s" % [stage, STAGE_LABELS[stage]]
	if was_down:
		pop_up()


## A downed dummy springs back up, squashed flat and then stretching out, dancing again.
func pop_up() -> void:
	dummy.scale = Vector3(1.35, 0.05, 1.35)
	worn_bucket.rotation_degrees.x = Props.BUCKET_TIP - 50.0
	hit_tween = create_tween().set_parallel()
	hit_tween.tween_property(dummy, "scale", Vector3.ONE, 0.8) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	hit_tween.tween_property(worn_bucket, "rotation_degrees:x", Props.BUCKET_TIP, 0.9) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _on_bucket_landed(_body: Node) -> void:
	# Only a real knock makes it ring, and not twice inside one bounce.
	var speed := thrown_bucket.linear_velocity.length()
	if stage >= Stage.EAR and speed > 1.2 and clang_gap > 0.12:
		clang_gap = 0.0
		play_at(CLANG, thrown_bucket.global_position, clampf(speed - 9.0, -14.0, -3.0))
		burst(dust, thrown_bucket.global_position + Vector3.DOWN * 0.15, Vector3.UP, 0.6)


## One-shot particles at a point, pointing along a direction. The seed is the hit number, so
## each hit sprays differently and the same hit always sprays the same.
func burst(scene: PackedScene, point: Vector3, direction: Vector3, boost: float) -> void:
	var particles := scene.instantiate() as GPUParticles3D
	effects.add_child(particles)
	particles.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())), point)
	var all: Array[GPUParticles3D] = [particles]
	for child in particles.get_children():
		all.append(child)
	for part in all:
		part.seed = 100 + hits * 7
		if part.name == &"Flash":
			# Its own copy of the material: the packed scene shares one between every burst.
			var star := part.process_material.duplicate() as ParticleProcessMaterial
			star.scale_min = boost
			star.scale_max = boost
			part.process_material = star
		else:
			part.amount = int(part.amount * boost)
		part.restart()
	get_tree().create_timer(2.0, false).timeout.connect(particles.queue_free)


func play_at(stream: AudioStream, point: Vector3, volume_db := 0.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	effects.add_child(player)
	player.global_position = point
	player.finished.connect(player.queue_free)
	player.play()
	return player
