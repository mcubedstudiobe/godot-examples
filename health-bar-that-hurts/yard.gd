extends Node3D
## A plush hides behind a pillow fort in a sunny backyard while a tennis-ball pitching machine
## bonks it. Every bonk costs the same health, at every stage. What changes from stage to stage
## is how the health bar shows it (health_bar.gd): the stage is the bar's layer.

enum Throw { LOB, QUICK }

const Effects := preload("res://effects.gd")
const THUNK := preload("res://sounds/machine_thunk.wav")
const BONK := preload("res://sounds/ball_bonk.wav")
const THUMP := preload("res://sounds/cushion_thump.wav")
const OOF := preload("res://sounds/oof.wav")
const BOUNCE := preload("res://sounds/ball_bounce.wav")
const WHIRR := preload("res://sounds/whirr.wav")
const STAGE_LABELS := [
	"0 · The polite bar", "1 · The receipt", "2 · The jolt", "3 · The colour", "4 · The warning",
]

## Every bonk costs this much, at every stage. Three of them leave the plush under a quarter of its
## health, and the fourth knocks it out.
const MAX_HP := 100.0
const DAMAGE := 30.0
## The machine. A lob winds up slowly and drops onto the cushions. A quick shot winds up for a
## moment, and is at the plush before it has finished ducking.
const LOB_WIND_UP_SECONDS := 0.6
const LOB_FLIGHT_SECONDS := 0.55
const QUICK_WIND_UP_SECONDS := 0.24
const QUICK_FLIGHT_SECONDS := 0.24
const BALL_RADIUS := 0.09
const MAX_BALLS := 16
## How close a ball has to come to the middle of the plush's head to bonk it.
const HEAD_RADIUS := 0.55
## The plush: how hard a bonk staggers it, and how hard the camera kicks.
const STAGGER := 0.9
const SQUASH := Vector3(1.14, 0.84, 1.14)
const CAMERA_KICK := 0.03
## With auto-fire on the machine keeps shooting by itself, then resets after a knockout.
const AUTO_FIRE_GAP_SECONDS := 2.6
const AUTO_RESET_SECONDS := 3.4

@export var stage: HealthBar.Layer = HealthBar.Layer.WARNING:
	set(value):
		stage = value
		if hud != null:
			hud.layer = value
		if stage_label != null:
			stage_label.text = STAGE_LABELS[value]
@export var auto_fire := true
## Where the camera looks. Its position is the camera node's own.
@export var look_at_point := Vector3(-0.5, 0.85, 0.1)

var camera: Camera3D
var plush: Plush
var machine: Machine
var scenery: Node3D
var hud: HealthBar
var guide: CanvasLayer
var stage_label: Label
var effects: Node3D
var hp := MAX_HP
var hits := 0
var down := false
var epoch := 0
var balls: Array[RigidBody3D] = []
var phase := &"idle"
var phase_time := 0.0
var throw_kind := Throw.LOB
var idle_time := 0.0
var down_time := 0.0
var queue := 0
var bonk_effect: PackedScene
var dust_effect: PackedScene
var muzzle_effect: PackedScene
var sweat: GPUParticles3D
var squash_tween: Tween
var kick_tween: Tween
var holding := false
var plush_rest: Vector3
var aim_point := Vector3.ZERO


func _ready() -> void:
	camera = $Camera3D
	camera.look_at(look_at_point)
	plush = $Plush
	machine = $Machine
	scenery = $Scenery
	effects = $Effects
	plush_rest = plush.position
	_world()
	_hud()
	bonk_effect = Effects.make_bonk()
	dust_effect = Effects.make_dust()
	muzzle_effect = Effects.make_muzzle()
	sweat = Effects.make_sweat()
	sweat.position = Vector3(0.0, 0.35, 0.0)
	plush.head_bone.add_child(sweat)
	# The plush looks half at the camera and half at the machine, so its face is always in view.
	var to_machine := (machine.global_position - plush.global_position) * Vector3(1.0, 0.0, 1.0)
	var to_camera := (camera.global_position - plush.global_position) * Vector3(1.0, 0.0, 1.0)
	plush.rotation.y = atan2(to_machine.x + to_camera.x * 1.4, to_machine.z + to_camera.z * 1.4)
	plush.motion.watch_yaw = rad_to_deg(wrapf(atan2(to_machine.x, to_machine.z) - plush.rotation.y, -PI, PI))
	hud.heartbeat.connect(_on_heartbeat)
	stage = stage
	reset_yard()


## The sky, the sun and the air.
func _world() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = load("res://sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.7
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.8
	environment.ssao_intensity = 1.5
	environment.glow_enabled = true
	environment.glow_intensity = 0.3
	environment.glow_bloom = 0.02
	environment.glow_hdr_threshold = 1.2
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.fog_enabled = true
	environment.fog_light_color = Color(0.78, 0.88, 1.0)
	environment.fog_density = 0.006
	environment.fog_sky_affect = 0.1
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.04
	var world := WorldEnvironment.new()
	world.environment = environment
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 8.5
	attributes.dof_blur_far_transition = 6.0
	attributes.dof_blur_amount = 0.05
	world.camera_attributes = attributes
	add_child(world)
	# The sun: warm, high and a little to the left, behind the camera, with soft shadows.
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.94, 0.82)
	sun.light_energy = 1.9
	sun.light_angular_distance = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 24.0
	sun.position = Vector3(0, 6, 6)
	add_child(sun)
	sun.look_at(sun.position + Vector3(0.5, -0.62, -0.6), Vector3.UP)
	# A cool rim from behind, so the plush's edge glows against the fort.
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.78, 0.88, 1.0)
	rim.light_energy = 0.7
	rim.light_specular = 1.4
	add_child(rim)
	rim.look_at_from_position(Vector3.ZERO, Vector3(-0.35, -0.3, 0.9), Vector3.UP)


func _hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Hud"
	add_child(layer)
	hud = HealthBar.new()
	hud.max_hp = MAX_HP
	hud.layer = stage
	layer.add_child(hud)
	guide = CanvasLayer.new()
	guide.name = "Guide"
	add_child(guide)
	stage_label = Label.new()
	stage_label.position = Vector2(24.0, 860.0)
	stage_label.add_theme_font_size_override(&"font_size", 22)
	stage_label.add_theme_constant_override(&"outline_size", 8)
	stage_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	guide.add_child(stage_label)
	var keys := Label.new()
	keys.position = Vector2(24.0, 24.0 + 120.0)
	keys.text = "Space  shoot\nL  lob\n0-4  bar layer\nR  reset\nP  pause\nA  auto-fire\nH  hide this"
	keys.add_theme_font_size_override(&"font_size", 18)
	keys.add_theme_constant_override(&"outline_size", 6)
	keys.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	guide.add_child(keys)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key >= KEY_0 and key <= KEY_4:
		stage = (key - KEY_0) as HealthBar.Layer
		reset_yard()
	elif key == KEY_SPACE:
		fire(Throw.QUICK)
	elif key == KEY_L:
		fire(Throw.LOB)
	elif key == KEY_R:
		reset_yard()
	elif key == KEY_A:
		auto_fire = not auto_fire
	elif key == KEY_P:
		hold(not holding)
	elif key == KEY_H:
		guide.visible = not guide.visible


## Pause the game. The plush keeps breathing, blinking and reacting, and sounds that have
## started play out.
func hold(on: bool) -> void:
	holding = on
	get_tree().paused = on
	plush.keep_alive(on)
	for node: Node in effects.get_children():
		if node is AudioStreamPlayer3D:
			node.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT


# ---------- the machine ----------

## Start a shot. A second one is ignored while the machine is busy.
func fire(kind: Throw) -> void:
	if down or phase != &"idle":
		return
	throw_kind = kind
	phase = &"winding"
	phase_time = 0.0
	var wind := LOB_WIND_UP_SECONDS if kind == Throw.LOB else QUICK_WIND_UP_SECONDS
	machine.wind_up(wind)
	plush.motion.warn()
	var whirr := play_at(WHIRR, machine.global_position + Vector3.UP, -6.0)
	whirr.pitch_scale = 1.35 if kind == Throw.QUICK else 1.0


func _process(delta: float) -> void:
	var from_head := plush.head_point()
	if phase == &"winding":
		phase_time += delta
		var wind := LOB_WIND_UP_SECONDS if throw_kind == Throw.LOB else QUICK_WIND_UP_SECONDS
		machine.aim((_target(from_head) - machine.muzzle.global_position).normalized())
		if phase_time >= wind:
			_launch()
			phase = &"idle"
			idle_time = 0.0
	else:
		idle_time += delta
	if down and auto_fire:
		down_time += delta
		if down_time > AUTO_RESET_SECONDS:
			reset_yard()
	elif auto_fire and phase == &"idle" and idle_time > AUTO_FIRE_GAP_SECONDS:
		queue += 1
		fire(Throw.LOB if queue % 3 == 1 else Throw.QUICK)
	# The warning layer: the plush trembles when the bar says it is nearly out.
	plush.motion.fear_goal = 1.0 if hud.is_low() and not down else 0.0


## Where a shot is going: the cushions for a lob, the plush's head for a quick shot.
func _target(head: Vector3) -> Vector3:
	if throw_kind == Throw.LOB:
		return Vector3(-0.15, 0.45, 0.95)
	# Aim where the head will be when the ball gets there: the plush is already ducking.
	var flight := QUICK_FLIGHT_SECONDS
	var then := plush.motion.height_in(flight)
	return head + Vector3.UP * (then - plush.motion.height) * PlushMotion.HEAD_DROP * Plush.SCALE


func _launch() -> void:
	var seconds := LOB_FLIGHT_SECONDS if throw_kind == Throw.LOB else QUICK_FLIGHT_SECONDS
	var from := machine.muzzle.global_position
	var to := _target(plush.head_point())
	var gravity := Vector3(0.0, -float(ProjectSettings.get_setting("physics/3d/default_gravity")), 0.0)
	var ball := _make_ball()
	ball.global_position = from
	ball.linear_velocity = (to - from - 0.5 * gravity * seconds * seconds) / seconds
	ball.angular_velocity = Vector3(0.0, 0.0, -18.0).rotated(Vector3.UP, machine.rotation.y)
	ball.set_meta(&"flying", throw_kind == Throw.QUICK)
	ball.set_meta(&"lob", throw_kind == Throw.LOB)
	play_at(THUNK, from, 0.0)
	machine.fire()
	_burst(muzzle_effect, from, machine.global_basis.x, 1)
	while balls.size() > MAX_BALLS:
		var old: RigidBody3D = balls.pop_front()
		old.queue_free()


func _make_ball() -> RigidBody3D:
	var ball := RigidBody3D.new()
	ball.mass = 0.06
	ball.collision_layer = 2
	ball.collision_mask = 1
	ball.continuous_cd = true
	ball.linear_damp = 0.12
	ball.angular_damp = 0.5
	ball.contact_monitor = true
	ball.max_contacts_reported = 4
	var physics := PhysicsMaterial.new()
	physics.bounce = 0.7
	physics.friction = 0.9
	ball.physics_material_override = physics
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = BALL_RADIUS
	shape.shape = sphere
	ball.add_child(shape)
	ball.add_child(Machine.make_ball(BALL_RADIUS))
	ball.body_entered.connect(_on_ball_touched.bind(ball))
	effects.add_child(ball)
	balls.append(ball)
	return ball


func _physics_process(_delta: float) -> void:
	var head := plush.head_point()
	for ball in balls:
		if is_instance_valid(ball) and ball.get_meta(&"flying", false) \
				and ball.global_position.distance_to(head) < HEAD_RADIUS + BALL_RADIUS:
			ball.set_meta(&"flying", false)
			_bonk(ball, head)


# ---------- the hit ----------

func _bonk(ball: RigidBody3D, head: Vector3) -> void:
	hits += 1
	hp = maxf(hp - DAMAGE, 0.0)
	hud.take_hit(hp)
	var away := ball.global_position - head
	var contact := head + away.normalized() * HEAD_RADIUS
	var side := plush.global_basis.x.dot(ball.linear_velocity.normalized())
	play_at(BONK, contact, 2.0)
	play_at(OOF, head, -3.0)
	_burst(bonk_effect, contact, away, hits)
	# The ball bounces off the plush, away and up, and rolls round the lawn.
	var back := Vector3(away.x, 0.0, away.z).normalized()
	ball.linear_velocity = (back * 2.6 + Vector3(-0.8, 3.6, 1.0)) * (1.0 + 0.12 * hits)
	ball.angular_velocity = Vector3(11.0, 4.0, -9.0)
	_squash()
	_kick_camera(ball.linear_velocity.normalized())
	plush.motion.hit(STAGGER, -side)
	if hp <= 0.0:
		knock_out()


func knock_out() -> void:
	down = true
	down_time = 0.0
	plush.set_dead(true)
	plush.motion.ko_goal = 1.0
	plush.motion.fear_goal = 0.0


func _squash() -> void:
	if squash_tween != null:
		squash_tween.kill()
	plush.scale = SQUASH
	squash_tween = create_tween()
	squash_tween.tween_property(plush, "scale", Vector3.ONE, 0.55) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _kick_camera(direction: Vector3) -> void:
	if kick_tween != null:
		kick_tween.kill()
	camera.h_offset = direction.dot(camera.global_basis.x) * CAMERA_KICK
	camera.v_offset = direction.dot(camera.global_basis.y) * CAMERA_KICK
	kick_tween = create_tween().set_parallel()
	kick_tween.tween_property(camera, "h_offset", 0.0, 0.18)
	kick_tween.tween_property(camera, "v_offset", 0.0, 0.18)


func _on_heartbeat() -> void:
	plush.motion.pulse = 1.0
	sweat.restart()


## A ball touched something: the cushions thump and squash, the lawn bounces.
func _on_ball_touched(body: Node, ball: RigidBody3D) -> void:
	var speed := ball.linear_velocity.length()
	if body in scenery.cushions:
		if speed < 1.0:
			return
		play_at(THUMP, ball.global_position, clampf(speed * 1.2 - 12.0, -10.0, 0.0))
		_squash_cushion(body)
		if ball.get_meta(&"lob", false):
			ball.set_meta(&"lob", false)
			_burst(dust_effect, ball.global_position, Vector3.UP, 3)
			plush.motion.all_clear()
	elif body.name == &"Ground" and speed > 1.4:
		var player := play_at(BOUNCE, ball.global_position, clampf(speed * 1.5 - 14.0, -16.0, -3.0))
		player.pitch_scale = 0.9 + 0.2 * fmod(ball.global_position.x * 7.0, 1.0)


func _squash_cushion(cushion: StaticBody3D) -> void:
	var visual := cushion.get_node("Visual") as Node3D
	visual.scale = Vector3(1.1, 0.78, 1.1)
	var tween := create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


# ---------- reset ----------

func reset_yard() -> void:
	var was_down := down
	epoch += 1
	phase = &"idle"
	idle_time = 0.0
	down = false
	down_time = 0.0
	hp = MAX_HP
	hits = 0
	queue = 0
	holding = false
	get_tree().paused = false
	plush.keep_alive(false)
	for ball in balls:
		if is_instance_valid(ball):
			ball.queue_free()
	balls.clear()
	for effect in effects.get_children():
		if not effect is RigidBody3D:
			effect.queue_free()
	machine.idle()
	plush.set_dead(false)
	plush.motion.calm()
	plush.scale = Vector3.ONE
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	hud.reset()
	hud.layer = stage
	if was_down:
		_pop_up()


## A knocked-out plush pops back up dazed: squashed flat, stretching out, shaking its head.
func _pop_up() -> void:
	plush.motion.shake()
	plush.motion.daze = 1.0
	plush.scale = Vector3(1.3, 0.1, 1.3)
	if squash_tween != null:
		squash_tween.kill()
	squash_tween = create_tween()
	squash_tween.tween_property(plush, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	squash_tween.tween_property(plush.motion, "daze", 0.0, 2.5)


# ---------- helpers ----------

func _burst(scene: PackedScene, point: Vector3, direction: Vector3, seed_value: int) -> void:
	var particles := scene.instantiate() as GPUParticles3D
	effects.add_child(particles)
	particles.global_transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())), point)
	var all: Array[GPUParticles3D] = [particles]
	for child in particles.get_children():
		all.append(child)
	for part in all:
		part.seed = 100 + seed_value * 7
		part.restart()
	get_tree().create_timer(2.0, false).timeout.connect(particles.queue_free)


func play_at(stream: AudioStream, point: Vector3, volume_db := 0.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.unit_size = 12.0
	effects.add_child(player)
	player.global_position = point
	player.finished.connect(player.queue_free)
	player.play()
	return player
