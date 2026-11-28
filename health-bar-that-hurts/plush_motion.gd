class_name PlushMotion
extends SkeletonModifier3D
## Keeps the plush alive and lets it react to the situation. It never dances and is never frozen:
## it breathes, blinks and watches the machine all the time, peeks over the fort warily, ducks when
## the machine winds up, braces, staggers and rubs its head when a ball bonks it, trembles when it
## is nearly out of health and slumps over the cushions when it is out.
##
## A SkeletonModifier3D only adds to the pose for this frame, so the held idle pose underneath never
## drifts. Every reaction is a pure function of what yard.gd tells it and of its own clock, with no
## randomness, so the same game state always looks the same.

## How far the plush sinks behind the fort when it is fully ducked, in metres.
const DROP := 0.47
## How far the middle of the head goes down for a full duck.
const HEAD_DROP := 0.47
## It starts to duck this long after the machine winds up, and ducks at this speed (heights per second).
const REACT_SECONDS := 0.2
const DUCK_RATE := 2.4
const RISE_RATE := 1.2
## How hard a hit staggers it, and how long the stagger and the rub last.
const STAGGER_SECONDS := 1.1
const RUB_START := 0.55
const RUB_SECONDS := 1.5

## 0 is ducked right down, 1 is standing tall.
var height := 0.86
## Seconds since the machine began its wind-up (negative when nothing is coming).
var alarm := -1.0
var clear := -1.0
var cower := 0.0
## 0 to 1: how afraid it is. Under a quarter of its health this rises and it trembles.
var fear := 0.0
var fear_goal := 0.0
## 1 on a heartbeat, falling away (set by yard.gd from the bar).
var pulse := 0.0
## 0 to 1: knocked out, slumped over the cushions.
var ko := 0.0
var ko_goal := 0.0
var daze := 0.0
## Degrees the machine is to the plush's side of the way it faces.
var watch_yaw := 0.0
var material: ShaderMaterial
## The plush's tilt_l and tilt_r poses: a rotation per bone and the hips' position, sampled once.
var tilts := {}

var time := 0.0
var next_blink := 1.7
var blink := 0.0
var squint := 0.0
var hit_time := 99.0
var hit_amount := 0.0
var hit_side := 1.0
var shake_time := 99.0
var wide := 0.0


## The height it will have this many seconds from now: yard.gd aims a quick shot at where the
## head will be, because the plush is already ducking by the time the ball arrives.
func height_in(seconds: float) -> float:
	var wait := REACT_SECONDS if alarm < 0.0 else maxf(REACT_SECONDS - alarm, 0.0)
	return maxf(0.0, height - DUCK_RATE * maxf(seconds - wait, 0.0))


## The machine has started winding up.
func warn() -> void:
	alarm = 0.0
	clear = -1.0


## The ball has landed on the fort: it waits a moment, then peeks again.
func all_clear() -> void:
	clear = 0.0


## A ball has bonked it: stagger by `amount` (1 is a full lean into a tilt pose) to `side`.
func hit(amount: float, side: float) -> void:
	hit_time = 0.0
	hit_amount = amount
	hit_side = 1.0 if side >= 0.0 else -1.0
	alarm = -1.0
	clear = -1.0
	cower = 1.0


## A head shake, for popping back up dazed.
func shake() -> void:
	shake_time = 0.0


func calm() -> void:
	alarm = -1.0
	clear = -1.0
	cower = 0.0
	fear = 0.0
	fear_goal = 0.0
	ko = 0.0
	ko_goal = 0.0
	pulse = 0.0
	hit_time = 99.0
	shake_time = 99.0
	daze = 0.0
	height = 0.86


func _process_modification_with_delta(delta: float) -> void:
	time += delta
	var skeleton := get_skeleton()
	_think(delta)
	_pose(skeleton)
	_blink(delta)


## Where it wants its head, and how it gets there.
func _think(delta: float) -> void:
	fear = move_toward(fear, fear_goal, delta * 1.5)
	ko = move_toward(ko, ko_goal, delta * 3.2)
	cower = move_toward(cower, 0.0, delta * 0.7)
	var peek := (0.86 + 0.05 * sin(time * 0.8) + 0.04 * sin(time * 2.1)) * (1.0 - 0.16 * fear)
	var target := peek
	if alarm >= 0.0:
		alarm += delta
		if alarm > REACT_SECONDS:
			target = 0.0
	if clear >= 0.0:
		clear += delta
		if clear > 0.7:
			alarm = -1.0
			clear = -1.0
	target = minf(target, 1.0 - cower * 0.78)
	if ko > 0.0:
		target = lerpf(target, 0.82, ko)
	var rate := DUCK_RATE if target < height else RISE_RATE
	height = move_toward(height, target, rate * delta)
	hit_time += delta
	shake_time += delta
	pulse = maxf(pulse - delta * 5.5, 0.0)
	wide = move_toward(wide, 1.0 if (alarm >= 0.0 or fear > 0.3) and ko < 0.5 else 0.0, delta * 6.0)


func _pose(skeleton: Skeleton3D) -> void:
	var breath := sin(time * 3.0)
	var sway := sin(time * 0.9)
	var ducked := 1.0 - height
	var alert := 0.0
	if alarm >= 0.0:
		alert = clampf(alarm / 0.25, 0.0, 1.0)
	# A hit: the plush's own tilt poses, alternating and settling, and a snap of the head.
	var envelope := hit_amount * exp(-hit_time * 3.2)
	var wobble := envelope * cos(hit_time * TAU * 2.4) * hit_side
	_tilt(skeleton, wobble * 0.85 * (1.0 - ko))
	var jolt := hit_amount * exp(-hit_time * 8.0)
	var flail := hit_amount * exp(-hit_time * 4.5)
	# Trembling: a fast shiver whose size follows the fear, and a thump of the chest on each beat.
	var shiver := fear * (1.0 - ko)
	var tremble := Vector3(sin(time * 83.0), sin(time * 71.0 + 1.0), sin(time * 97.0 + 2.0)) * shiver
	var thump := pulse * fear * (1.0 - ko)
	# Where it looks: the machine, with a nervous glance away every so often.
	var glance := maxf(_pulse(4.7, 2.6, 0.9), _pulse(7.9, 5.4, 0.8))
	var look := watch_yaw * 0.85 - glance * (watch_yaw * 0.9 + 14.0) * (1.0 - alert)
	look += sin(time * 5.0) * (0.8 + 3.0 * alert)
	if shake_time < 1.2:
		look += sin(shake_time * TAU * 3.0) * 26.0 * (1.0 - shake_time / 1.2)
	var woozy := (daze + (1.0 if hit_time < STAGGER_SECONDS else 0.0) * 0.4) * sin(time * 2.7)
	# Body: sunk behind the cushions by how ducked it is, leaning in when it peeks.
	var lean := -ducked * 6.0 - ko * 30.0
	_lift(skeleton, Vector3(sway * 0.006 + tremble.x * 0.03, \
			-ducked * DROP + (breath * 0.5 + 0.5) * 0.012 + thump * 0.02 + tremble.y * 0.016 - ko * 0.1 - jolt * 0.04,
			-ko * 0.12 + ducked * -0.08))
	_turn(skeleton, &"DEF-hips", Vector3(lean - alert * 8.0 - jolt * 12.0, watch_yaw * 0.2 + daze * 6.0 * sin(time * 1.7),
			sway * 2.0 + tremble.z * 6.0 + ko * 14.0))
	_turn(skeleton, &"DEF-head", Vector3(breath * 2.0 + ducked * 20.0 - jolt * 24.0 - ko * 26.0 + tremble.x * 1.5,
			look - watch_yaw * 0.2 + tremble.y * 2.0 - ko * 14.0, -wobble * 11.0 + woozy * 10.0 + ko * 28.0 + tremble.z * 2.0))
	# Arms. Peeking, the hands grip the top of the wall; alarmed, they fly up across the face;
	# hit, they are flung out; afraid, they clutch in and shiver; rubbing, one paw works the
	# sore spot on the head; out cold, they hang.
	var rub := _rub()
	var grip := (1.0 - alert) * (1.0 - cower) * (1.0 - ko) * (1.0 - rub * 0.0)
	var up := alert * 128.0 + flail * 55.0 + fear * 26.0
	var elbow := alert * 60.0 + flail * 20.0 + fear * 52.0
	var shake_a := tremble.x * 6.0 * fear
	_turn(skeleton, &"DEF-upper_arm.L", Vector3(grip * -34.0 + ko * -20.0, grip * 16.0, up * (1.0 - ko) + shake_a))
	_turn(skeleton, &"DEF-upper_arm.R", Vector3(grip * -34.0 + ko * -20.0, grip * -16.0, -up * (1.0 - ko) - shake_a))
	_turn(skeleton, &"DEF-forearm.L", Vector3(grip * -20.0, 0.0, elbow * (1.0 - ko)))
	_turn(skeleton, &"DEF-forearm.R", Vector3(grip * -20.0, 0.0, -elbow * (1.0 - ko)))
	if rub > 0.0:
		_rub_arm(skeleton, rub)
	squint = maxf(hit_amount * exp(-hit_time * 2.0) * 0.9, 0.0) * (1.0 - ko)


## How much the plush is rubbing its head: 0 to 1, in the seconds after the stagger.
func _rub() -> float:
	if hit_time < RUB_START or hit_time > RUB_START + RUB_SECONDS or ko > 0.1:
		return 0.0
	return sin(PI * (hit_time - RUB_START) / RUB_SECONDS)


func _rub_arm(skeleton: Skeleton3D, rub: float) -> void:
	var rubbing := sin(time * 19.0) * 0.25
	var upper := Vector3(-0.55, 0.45, 0.15).normalized()
	var forearm := Vector3(-0.15 + rubbing, 0.9, 0.4).normalized()
	_blend_aim(skeleton, &"DEF-upper_arm.R", upper, rub)
	_blend_aim(skeleton, &"DEF-forearm.R", forearm, rub)


func _pulse(period: float, start: float, length: float) -> float:
	var at := fmod(time, period) - start
	if at < 0.0 or at > length:
		return 0.0
	return pow(sin(PI * at / length), 2.0)


func _tilt(skeleton: Skeleton3D, weight: float) -> void:
	if tilts.is_empty() or absf(weight) < 0.001:
		return
	var pose: Dictionary = tilts[&"l" if weight > 0.0 else &"r"]
	var w := minf(absf(weight), 1.0)
	for i in skeleton.get_bone_count():
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i).slerp(pose.rotations[i], w))
	skeleton.set_bone_pose_position(0, skeleton.get_bone_pose_position(0).lerp(pose.hips, w))


func _blink(delta: float) -> void:
	next_blink -= delta
	if next_blink <= 0.0:
		blink = 1.0
		next_blink = 2.2 + fmod(time * 7.31, 1.6)
	blink = move_toward(blink, 0.0, delta * 7.0)
	if material != null:
		material.set_shader_parameter(&"blink", maxf(blink, squint))
		material.set_shader_parameter(&"wide", wide * (1.0 - squint))
		var worried := clampf(maxf(fear * 0.9, (1.0 - height) * 0.6), 0.0, 1.0) * (1.0 - ko)
		material.set_shader_parameter(&"worry", worried * 0.75)


func _turn(skeleton: Skeleton3D, bone: StringName, degrees: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	var turn := Quaternion.from_euler(degrees * PI / 180.0)
	skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * turn)


func _lift(skeleton: Skeleton3D, offset: Vector3) -> void:
	skeleton.set_bone_pose_position(0, skeleton.get_bone_pose_position(0) + offset)


## Turn a bone's own Y axis (the way the limb runs) towards a direction in skeleton space, by `weight`.
func _blend_aim(skeleton: Skeleton3D, bone: StringName, direction: Vector3, weight: float) -> void:
	var i := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(i)
	var turn := Quaternion(pose.basis.y.normalized(), direction.normalized())
	pose.basis = Basis(Quaternion.IDENTITY.slerp(turn, weight)) * pose.basis
	skeleton.set_bone_global_pose(i, pose)
