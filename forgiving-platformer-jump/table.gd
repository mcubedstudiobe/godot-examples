extends Node3D
## A breakfast table, side-on: a plush runs a ledge course over a lake of hot cocoa while a pale
## see-through ghost plush beside it is fed exactly the same inputs with every cheat off. The four
## cheats live in jumper.gd as constants; this script feeds the inputs, runs the two lanes and
## stages the fall. Number keys pick how many cheats the player has.

enum Stage { NONE, COYOTE, BUFFER, VARIABLE, FALL }

const PLUSH_SCENE := preload("res://plush.tscn")
const JUMP_SOUND := preload("res://sounds/hop.wav")
const LAND_SOUND := preload("res://sounds/land.wav")
const PLOP_SOUND := preload("res://sounds/plop.wav")
const BOP_SOUND := preload("res://sounds/bop.wav")
const CHIME_SOUND := preload("res://sounds/chime.wav")
const STAGE_LABELS := ["No cheats", "Coyote time", "Jump buffer", "Variable height", "Fall faster"]
const CHEAT_NAMES := ["Coyote time", "Jump buffer", "Variable height", "Fall faster"]

## The ghost runs one lane behind the player.
const GHOST_LANE_Z := -4.0
## ...and this far to the side, so the two never hide each other.
const GHOST_LANE_X := -1.0
## After a reset both characters wait this long, so everything settles first.
const READY_TICKS := 60
## How the player and ghost stand: turned this far towards the camera as they face their way.
const FACE_TOWARDS_CAMERA := 0.7
## The plush is drawn this much larger than its collision capsule, so it reads on a phone.
const PLUSH_SCALE := 1.3
## What a plush does in the cocoa: how far it sinks, and how long before it pops back up.
const SINK_DEPTH := 0.55
const POP_BACK_SECONDS := 2.8
const DAZED_SECONDS := 0.8
## The marshmallow lands on the sunk plush's head this long after the splash.
const MARSHMALLOW_DELAY := 0.55

class Rider extends RefCounted:
	var body: Jumper
	var plush: Plush
	var tag: Label
	var lane_z := 0.0
	var lane_x := 0.0
	var sunk := false
	var sunk_time := 0.0 ## the sunk plush's animation clock; it keeps running while the game is held
	var sunk_wait := 0.0 ## how long it has sat in the cocoa as gameplay time, which a pause freezes
	var sunk_from := 0.0
	var sunk_yaw := 0.0
	var marshmallow: Node3D
	var was_on_floor := true
	var last_jumps := 0
	var yaw := 0.0
	var dazed_left := 0.0
	var jumped_in_air := false

@export var stage: Stage = Stage.FALL
@export var ledge := 0

## Levers the capture driver pulls instead of the keyboard.
var virtual_right := false
var virtual_left := false
var virtual_jump := false
## Press Enter to replay the ledge's scripted run, the very one the video shows.
var autoplay := false

var camera: Camera3D
var key_light: DirectionalLight3D
var effects := Node3D.new()
var platforms := Node3D.new()
var scenery: Node3D
var player_world := Node3D.new()
var ghost_world := Node3D.new()
var player: Rider
var ghost: Rider
var input_log: Array[InputFrame] = []
var tick := 0
var locked := 0
var prev_held := false
var goal_timer := 0.0
var guide := CanvasLayer.new()
var tags := CanvasLayer.new()
var title_label := Label.new()
var cheat_label := Label.new()
## Turn off to keep a sunk plush in the cocoa until the next reset (the capture driver does).
var auto_pop := true
## Turn off to stay on a ledge after the player has reached its end (the capture driver does).
var auto_advance := true
var holding := false
var bob_time := 0.0
var since_reset := 0.0
## The "YOU" and "STRICT GHOST" tags are there to start with, then fade out.
const TAG_SECONDS := 3.2
## The camera glides along with the player, this far from where it started.
var cam_offset := 0.0
var cam_follow := 0.3
var cam_reach := 0.8
## The "Coyote jump!" words that pop up where a cheat fires; the capture turns them off.
var popups_visible := true
var sound_players: Array[AudioStreamPlayer3D] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_actions()
	_make_environment()
	_make_camera_and_lights()
	add_child(platforms)
	add_child(player_world)
	add_child(ghost_world)
	add_child(effects)
	scenery = Scenery.build_set(self, Course.LAKE_Y)
	_scatter_marshmallows()
	player = _make_rider("YOU", 0.0, false)
	ghost = _make_rider("STRICT GHOST", GHOST_LANE_Z, true)
	ghost.lane_x = GHOST_LANE_X
	add_child(tags)
	_build_guide()
	load_ledge(ledge)


func _make_actions() -> void:
	var map := {
		&"move_left": [KEY_A, KEY_LEFT],
		&"move_right": [KEY_D, KEY_RIGHT],
		&"jump": [KEY_SPACE, KEY_W, KEY_UP, KEY_Z],
	}
	for action: StringName in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: Key in map[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)


func _make_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://sky.gdshader")
	var sky := Sky.new()
	sky.sky_material = sky_material
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.65
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 5.0
	environment.ssao_enabled = true
	environment.ssao_radius = 0.7
	environment.ssao_intensity = 1.3
	environment.ssr_enabled = true
	environment.ssr_max_steps = 128
	environment.ssr_fade_in = 0.1
	environment.ssr_fade_out = 1.5
	environment.ssr_depth_tolerance = 0.25
	environment.glow_enabled = true
	environment.glow_intensity = 0.35
	environment.glow_bloom = 0.03
	environment.glow_hdr_threshold = 1.5
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	environment.fog_enabled = true
	environment.fog_light_color = Color(1.0, 0.86, 0.72)
	environment.fog_density = 0.002
	environment.fog_sky_affect = 0.3
	environment.fog_aerial_perspective = 0.35
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.15
	environment.adjustment_contrast = 1.1
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 32.0
	attributes.dof_blur_far_transition = 22.0
	attributes.dof_blur_amount = 0.12
	world_environment.camera_attributes = attributes
	add_child(world_environment)


func _make_camera_and_lights() -> void:
	camera = Camera3D.new()
	# Side-on and orthographic: jump heights read as heights, and the two lanes stay the same size.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = 6.6
	camera.position = Vector3(0.0, 3.7, 20.0)
	add_child(camera)
	camera.look_at(Vector3(0.0, 0.3, -1.6))
	camera.current = true
	key_light = DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.86, 0.68)
	key_light.light_energy = 2.0
	key_light.light_angular_distance = 1.4
	key_light.shadow_enabled = true
	key_light.shadow_blur = 1.5
	key_light.directional_shadow_max_distance = 70.0
	add_child(key_light)
	key_light.basis = Basis.looking_at(Vector3(5.0, -8.0, -7.0).normalized())
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(1.0, 0.92, 0.82)
	rim.light_energy = 1.0
	rim.light_specular = 0.35
	add_child(rim)
	rim.basis = Basis.looking_at(Vector3(-3.0, -2.5, 8.0).normalized())


func _make_rider(label: String, lane_z: float, is_ghost: bool) -> Rider:
	var rider := Rider.new()
	rider.lane_z = lane_z
	var body := Jumper.new()
	body.cheats = Cheats.new()
	body.axis_lock_linear_z = true
	body.collision_layer = 0
	body.collision_mask = 2 if is_ghost else 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.2
	capsule.height = 1.1
	shape.shape = capsule
	shape.position.y = 0.55
	body.add_child(shape)
	var plush: Plush = PLUSH_SCENE.instantiate()
	plush.ghost = is_ghost
	plush.hue_shift = 0.0
	plush.saturation = 1.0
	plush.brightness = 1.0
	plush.scale = Vector3.ONE * PLUSH_SCALE
	body.add_child(plush)
	(ghost_world if is_ghost else player_world).add_child(body)
	rider.body = body
	rider.plush = plush
	rider.tag = Label.new()
	rider.tag.text = label
	rider.tag.add_theme_font_size_override(&"font_size", 30)
	rider.tag.add_theme_constant_override(&"outline_size", 10)
	rider.tag.add_theme_color_override(&"font_outline_color", Color(0.1, 0.05, 0.02, 0.85))
	rider.tag.add_theme_color_override(&"font_color", Color(1.0, 0.98, 0.9) if not is_ghost else Color(0.8, 0.9, 1.0))
	rider.tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rider.tag.size = Vector2(300.0, 40.0)
	tags.add_child(rider.tag)
	return rider


## A handful of marshmallows drifting on the cocoa, away from where anyone lands.
func _scatter_marshmallows() -> void:
	var spots := [Vector3(-6.5, 0.0, -6.5), Vector3(5.5, 0.0, -7.5), Vector3(-3.2, 0.0, -8.0),
			Vector3(7.2, 0.0, -3.0), Vector3(-7.5, 0.0, -1.5), Vector3(1.8, 0.0, -8.6),
			Vector3(-2.4, 0.0, 3.4), Vector3(3.4, 0.0, 4.2), Vector3(-5.6, 0.0, 2.6)]
	for i in spots.size():
		var m := Scenery.make_marshmallow(0.8 + 0.25 * float(i % 3), float(i) * 3.7, 0.5 if i % 4 == 0 else 0.0)
		m.position = spots[i] + Vector3(0.0, Course.LAKE_Y + 0.1, 0.0)
		m.rotation.y = float(i) * 1.1
		m.set_meta(&"base_y", m.position.y)
		m.set_meta(&"phase", float(i) * 1.7)
		scenery.add_child(m)
		m.add_to_group(&"bobbers")


func _build_guide() -> void:
	add_child(guide)
	for label: Label in [title_label, cheat_label]:
		label.add_theme_font_size_override(&"font_size", 26)
		label.add_theme_constant_override(&"outline_size", 8)
		label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
		guide.add_child(label)
	title_label.position = Vector2(24, 18)
	cheat_label.position = Vector2(24, 62)
	cheat_label.add_theme_font_size_override(&"font_size", 22)
	var keys := Label.new()
	keys.text = "A/D or arrows  run     Space  jump     0-4  how many cheats     Enter  replay the scripted run\nN  next ledge     R  reset     P  pause     H  hide this guide"
	keys.add_theme_font_size_override(&"font_size", 18)
	keys.add_theme_constant_override(&"outline_size", 8)
	keys.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
	keys.anchor_top = 1.0
	keys.anchor_bottom = 1.0
	keys.offset_left = 24.0
	keys.offset_top = -66.0
	guide.add_child(keys)


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode
	if key >= KEY_0 and key <= KEY_4:
		stage = (key - KEY_0) as Stage
		reset_ledge()
	elif key == KEY_R:
		reset_ledge()
	elif key == KEY_N:
		load_ledge((ledge + 1) % Course.LEDGES.size())
	elif key == KEY_H:
		guide.visible = not guide.visible
	elif key == KEY_P:
		hold(not holding)
	elif key == KEY_ENTER:
		reset_ledge()
		autoplay = true


## Build the platforms of one ledge for both lanes, then start it.
func load_ledge(index: int) -> void:
	ledge = index
	for child in platforms.get_children():
		child.queue_free()
	for world in [player_world, ghost_world]:
		for child in world.get_children():
			if child is StaticBody3D:
				child.queue_free()
	var data: Dictionary = Course.LEDGES[ledge]
	var kinds: Array = data["kinds"]
	for lane in 2:
		var z := 0.0 if lane == 0 else GHOST_LANE_Z
		var shift := 0.0 if lane == 0 else GHOST_LANE_X
		var lane_data := data.duplicate()
		var shifted: Array = []
		for p: Array in data["platforms"]:
			var q := p.duplicate()
			q[0] += shift
			q[1] += shift
			shifted.append(q)
		lane_data["platforms"] = shifted
		var bodies := Course.build_colliders(lane_data, z, player_world if lane == 0 else ghost_world)
		for body in bodies:
			body.collision_layer = 1 if lane == 0 else 2
		for i in data["platforms"].size():
			var p: Array = data["platforms"][i]
			platforms.add_child(Scenery.make_platform(kinds[i], p[0] + shift, p[1] + shift, p[2] if p.size() > 2 else 0.0, z, float(ledge * 7 + i) + float(lane) * 0.5))
	reset_ledge()


## Back to the start of the ledge: both characters standing, the log cleared. A plush that was in
## the cocoa pops back up dazed.
func reset_ledge() -> void:
	var data: Dictionary = Course.LEDGES[ledge]
	var start := Course.start_of(data)
	for rider: Rider in [player, ghost]:
		var was_sunk := rider.sunk
		rider.sunk = false
		rider.sunk_time = 0.0
		rider.sunk_wait = 0.0
		if rider.marshmallow != null:
			rider.marshmallow.queue_free()
			rider.marshmallow = null
		rider.plush.position = Vector3.ZERO
		rider.plush.rotation = Vector3.ZERO
		rider.plush.scale = Vector3.ONE * PLUSH_SCALE
		rider.plush.set_dead(false)
		rider.body.cheats = Cheats.for_stage(stage) if rider == player else Cheats.new()
		rider.body.respawn(Vector3(start.x + rider.lane_x, start.y, rider.lane_z))
		rider.yaw = atan2(1.0, FACE_TOWARDS_CAMERA)
		rider.plush.rotation.y = rider.yaw
		rider.was_on_floor = true
		rider.last_jumps = 0
		rider.jumped_in_air = false
		rider.dazed_left = DAZED_SECONDS if was_sunk else 0.0
		rider.plush.set_pose(PlushMotion.Pose.DAZED if was_sunk else PlushMotion.Pose.LIVE)
		if was_sunk:
			_pop(rider)
	input_log.clear()
	tick = 0
	# Glide the camera straight to where it belongs on this ledge.
	var snap := clampf(start.x * cam_follow, -cam_reach, cam_reach)
	camera.global_translate(Vector3(snap - cam_offset, 0.0, 0.0))
	cam_offset = snap
	locked = READY_TICKS
	since_reset = 0.0
	prev_held = false
	autoplay = false
	goal_timer = 0.0
	_update_guide()


## The pop of a plush that comes back up: squashed flat, then springing up to its full height.
func _pop(rider: Rider) -> void:
	rider.plush.scale = Vector3(1.25, 0.2, 1.25) * PLUSH_SCALE
	var tween := rider.plush.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rider.plush, "scale", Vector3.ONE * PLUSH_SCALE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	Effects.droplets(effects, rider.body.global_position + Vector3(0.0, 0.1, 0.0), 0.6)


## Pause the game while both characters keep breathing, blinking and moving their clips.
func hold(on: bool) -> void:
	holding = on
	get_tree().paused = on
	for rider: Rider in [player, ghost]:
		rider.plush.keep_alive(on)
	for node: Node in effects.get_children():
		if node is AudioStreamPlayer3D:
			node.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT


func _update_guide() -> void:
	title_label.text = "%d  %s" % [stage, STAGE_LABELS[stage]]
	var lines := []
	for i in CHEAT_NAMES.size():
		lines.append("%s  %s" % ["on " if stage > i else "off", CHEAT_NAMES[i]])
	cheat_label.text = "\n".join(lines)


## The input for this tick: the keyboard, the capture driver's levers or the scripted run.
func _read_input() -> InputFrame:
	var frame := InputFrame.new()
	var held := Input.is_action_pressed(&"jump") or virtual_jump
	var move := Input.get_axis(&"move_left", &"move_right")
	if virtual_right:
		move += 1.0
	if virtual_left:
		move -= 1.0
	if autoplay:
		var scripted := _scripted(tick)
		move = scripted.x
		held = scripted.y > 0.5
	frame.move = clampf(move, -1.0, 1.0)
	frame.jump_held = held
	frame.jump_pressed = held and not prev_held
	frame.jump_released = prev_held and not held
	prev_held = held
	return frame


## The scripted run of the current ledge as (move, jump held) at a tick.
func _scripted(at: int) -> Vector2:
	var moving := 0.0
	var held := 0.0
	for event: Array in Course.RUNS[ledge]:
		if event[0] > at:
			continue
		match event[1]:
			"right": moving = 1.0
			"stop": moving = 0.0
			"press": held = 1.0
			"release": held = 0.0
	return Vector2(moving, held)


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
	var frame: InputFrame
	if locked > 0:
		locked -= 1
		frame = InputFrame.new()
	else:
		frame = _read_input()
		input_log.append(frame)
		tick += 1
	for rider: Rider in [player, ghost]:
		_step_rider(rider, frame, delta)
	_pop_back()
	_check_goal(delta)


func _step_rider(rider: Rider, frame: InputFrame, delta: float) -> void:
	if rider.sunk:
		return
	var body := rider.body
	if rider.dazed_left > 0.0:
		# A plush that has just popped back up ignores its inputs until its head clears.
		rider.dazed_left -= delta
		if rider.dazed_left <= 0.0:
			rider.plush.set_pose(PlushMotion.Pose.LIVE)
		frame = InputFrame.new()
	body.physics_step(frame, delta)
	var on_floor := body.is_on_floor()
	rider.plush.drive(on_floor, body.velocity.x, body.velocity.y, body.jumps, delta)
	if body.jumps != rider.last_jumps:
		rider.last_jumps = body.jumps
		rider.jumped_in_air = true
		_play(JUMP_SOUND, body.global_position, 0.0, 1.0)
		if body.jump_kind != "jump":
			_play(CHIME_SOUND, body.global_position, -6.0, 1.0)
			_pop_text(body.global_position + Vector3(0.0, 1.75, 0.0), "%s jump!" % body.jump_kind.capitalize())
	if on_floor and not rider.was_on_floor:
		_play(LAND_SOUND, body.global_position, -4.0, 1.0)
		rider.jumped_in_air = false
	if on_floor:
		rider.jumped_in_air = false
	rider.was_on_floor = on_floor
	if absf(frame.move) > 0.1:
		var target := atan2(signf(frame.move), FACE_TOWARDS_CAMERA)
		rider.yaw = lerp_angle(rider.yaw, target, 0.25)
		rider.plush.rotation.y = rider.yaw
	_react_to_doom(rider)
	if body.global_position.y < Course.LAKE_Y + 0.1:
		_sink(rider)


## Does this plush have a landing ahead of it? If not it flails (walked off) or looks dismayed.
func _react_to_doom(rider: Rider) -> void:
	var body := rider.body
	if body.is_on_floor() or rider.dazed_left > 0.0:
		rider.plush.set_pose(PlushMotion.Pose.LIVE if rider.dazed_left <= 0.0 else PlushMotion.Pose.DAZED)
		return
	var doomed := not _will_land(body, rider.lane_x)
	var falling := body.velocity.y < 0.5
	if doomed and falling:
		var low := _lowest_top() - 0.35
		if rider.jumped_in_air or body.global_position.y < low:
			rider.plush.set_pose(PlushMotion.Pose.DISMAY)
		else:
			rider.plush.set_pose(PlushMotion.Pose.FLAIL)
	else:
		rider.plush.set_pose(PlushMotion.Pose.LIVE)


func _lowest_top() -> float:
	var lowest := 0.0
	for p: Array in Course.LEDGES[ledge]["platforms"]:
		lowest = minf(lowest, p[2] if p.size() > 2 else 0.0)
	return lowest


## Follow the current motion ahead with plain ballistics: does it come down on a platform?
func _will_land(body: Jumper, lane_x: float) -> bool:
	var pos := Vector2(body.global_position.x - lane_x, body.global_position.y)
	var vel := Vector2(body.velocity.x, body.velocity.y)
	for i in 120:
		var g := Jumper.GRAVITY
		if body.cheats.fall_gravity and vel.y < 0.0:
			g *= Jumper.FALL_GRAVITY_MULTIPLIER
		vel.y -= g / 60.0
		pos += vel / 60.0
		for p: Array in Course.LEDGES[ledge]["platforms"]:
			var top: float = p[2] if p.size() > 2 else 0.0
			if vel.y < 0.0 and pos.y <= top and pos.y > top - 0.5 and pos.x >= p[0] - 0.15 and pos.x <= p[1] + 0.15:
				return true
		if pos.y < Course.LAKE_Y:
			return false
	return false


## Into the cocoa: a splash and a ripple, the plush floats up with X eyes, and a marshmallow lands
## on its head.
func _sink(rider: Rider) -> void:
	rider.sunk = true
	rider.sunk_time = 0.0
	rider.sunk_wait = 0.0
	var body := rider.body
	body.velocity = Vector3.ZERO
	rider.sunk_from = rider.plush.global_position.y
	rider.sunk_yaw = rider.plush.rotation.y
	var at := Vector3(body.global_position.x, Course.LAKE_Y, rider.lane_z)
	Effects.ripple(effects, at, 6.0, 2.2)
	Effects.ripple(effects, at, 3.4, 1.4)
	Effects.droplets(effects, at, 1.0)
	_play(PLOP_SOUND, at, 0.0, 1.0)
	rider.plush.set_pose(PlushMotion.Pose.FLOAT)
	rider.plush.set_dead(true)
	rider.marshmallow = Scenery.make_marshmallow(0.55, 9.0, 0.45)
	rider.marshmallow.visible = false
	rider.plush.add_child(rider.marshmallow)


func _process(delta: float) -> void:
	for rider: Rider in [player, ghost]:
		_animate_sunk(rider, delta)
		var tag_y := 1.8
		var head := rider.plush.global_position + Vector3(0.0, tag_y + (0.5 if rider.sunk and rider.marshmallow != null and rider.marshmallow.visible else 0.0), 0.0)
		var screen := camera.unproject_position(head)
		# Keep the label's size in step with the picture's height.
		var view := get_viewport().get_visible_rect().size
		var scale_to := minf(view.x / 1100.0, view.y / 900.0)
		rider.tag.scale = Vector2.ONE * scale_to
		var anchor_y := rider.tag.size.y
		rider.tag.position = screen - Vector2(rider.tag.size.x * 0.5, anchor_y) * scale_to
	var want := clampf(player.body.global_position.x * cam_follow, -cam_reach, cam_reach)
	var next := lerpf(cam_offset, want, 1.0 - exp(-delta * 3.0))
	camera.global_translate(Vector3(next - cam_offset, 0.0, 0.0))
	cam_offset = next
	bob_time += delta
	since_reset += delta
	var tag_alpha := clampf(TAG_SECONDS - since_reset, 0.0, 0.6) / 0.6
	for rider: Rider in [player, ghost]:
		rider.tag.modulate.a = tag_alpha
	var t := bob_time
	for plat: Node3D in platforms.get_children():
		if not plat.has_meta(&"base_y"):
			plat.set_meta(&"base_y", plat.position.y)
		plat.position.y = float(plat.get_meta(&"base_y")) + sin(t * 1.1 + plat.position.x * 1.7 + plat.position.z) * 0.02
	for m: Node3D in get_tree().get_nodes_in_group(&"bobbers"):
		var ph: float = m.get_meta(&"phase")
		m.position.y = float(m.get_meta(&"base_y")) + sin(t * 1.3 + ph) * 0.05
		m.rotation.z = sin(t * 0.9 + ph) * 0.05


## The sunk plush's float and bob, and the marshmallow that drops on it.
func _animate_sunk(rider: Rider, delta: float) -> void:
	if not rider.sunk:
		return
	rider.sunk_time += delta
	if not get_tree().paused:
		rider.sunk_wait += delta
	var t := rider.sunk_time
	var float_y := Course.LAKE_Y - SINK_DEPTH
	var dive := 1.0 - exp(-t * 8.0)
	var overshoot := sin(t * 10.0) * exp(-t * 3.0) * 0.16
	var bob := sin(t * 2.2) * 0.035
	var head_dip := 0.0
	if rider.marshmallow != null and rider.marshmallow.visible:
		head_dip = -0.08 * exp(-(t - MARSHMALLOW_DELAY - 0.45) * 5.0) if t > MARSHMALLOW_DELAY + 0.45 else 0.0
	var y := lerpf(rider.sunk_from, float_y, dive) + overshoot + bob + head_dip
	rider.plush.global_position.y = y
	rider.plush.rotation.y = lerp_angle(rider.sunk_yaw, 0.0, minf(t * 3.0, 1.0))
	rider.plush.rotation.z = sin(t * 1.6) * 0.07 * dive
	# The cocoa carries it a little way off, clear of the ledge it fell from.
	rider.plush.position.x = -0.5 * (1.0 - exp(-t * 1.4))
	if rider.marshmallow != null and not rider.marshmallow.visible and t >= MARSHMALLOW_DELAY:
		_drop_marshmallow(rider)


func _drop_marshmallow(rider: Rider) -> void:
	var m := rider.marshmallow
	m.visible = true
	m.position = Vector3(0.0, 3.4, 0.0)
	var rest := 1.43
	var tween := m.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(m, "position:y", rest, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: _play(BOP_SOUND, m.global_position, 0.0, 1.0))
	tween.tween_property(m, "scale", Vector3(1.25, 0.7, 1.25), 0.06)
	tween.tween_property(m, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## A plush that has sat in the cocoa long enough pops back up: the ghost next to the player when
## it is standing, the player back at the start of the ledge.
func _pop_back() -> void:
	if not auto_pop:
		return
	if player.sunk and player.sunk_wait > POP_BACK_SECONDS:
		reset_ledge()
		return
	if ghost.sunk and ghost.sunk_wait > POP_BACK_SECONDS and player.body.is_on_floor() and not player.sunk:
		var rider := ghost
		rider.sunk = false
		rider.marshmallow.queue_free()
		rider.marshmallow = null
		rider.plush.position = Vector3.ZERO
		rider.plush.rotation = Vector3.ZERO
		rider.plush.set_dead(false)
		var at := player.body.global_position
		rider.body.respawn(Vector3(at.x + rider.lane_x, at.y + 0.02, rider.lane_z))
		rider.dazed_left = DAZED_SECONDS
		rider.plush.set_pose(PlushMotion.Pose.DAZED)
		rider.yaw = atan2(1.0, FACE_TOWARDS_CAMERA)
		rider.plush.rotation.y = rider.yaw
		_pop(rider)


## Standing on the last platform for a moment moves on to the next ledge.
func _check_goal(delta: float) -> void:
	var platforms_data: Array = Course.LEDGES[ledge]["platforms"]
	var last: Array = platforms_data[-1]
	if not player.sunk and player.body.is_on_floor() and player.body.global_position.x > last[0] + 0.2 and tick > 30:
		goal_timer += delta
		if goal_timer > 2.2 and not autoplay and auto_advance:
			load_ledge((ledge + 1) % Course.LEDGES.size())
	else:
		goal_timer = 0.0


## A short floating word where something happens.
func _pop_text(at: Vector3, text: String) -> void:
	if not popups_visible:
		return
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.006
	label.font_size = 56
	label.outline_size = 12
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.92, 0.45)
	effects.add_child(label)
	label.global_position = at
	var tween := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(label, "global_position:y", at.y + 0.5, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tween.chain().tween_callback(label.queue_free)


func _play(stream: AudioStream, at: Vector3, volume_db: float, pitch: float) -> void:
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.volume_db = volume_db
	sound.pitch_scale = pitch
	sound.unit_size = 30.0
	sound.max_distance = 200.0
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
	effects.add_child(sound)
	sound.global_position = at
	sound.play()
	sound.finished.connect(sound.queue_free)
