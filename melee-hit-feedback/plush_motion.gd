class_name PlushMotion
extends SkeletonModifier3D
## Keeps a plush alive on top of its held pose: a guarding, breathing knight who swings a
## sword, a wary dummy who reacts to the swing, and blinking for both. A SkeletonModifier3D only
## adds to the pose for this frame, so the held pose underneath never drifts. Plush switches it
## off when the ragdoll takes over.
##
## The knight's swing is procedural. yard.gd says which of the three attacks is running and
## how many seconds of it have passed; this node turns that into arm bones every frame, so
## the swing slows down with Engine.time_scale (hit-stop) and holds when the game pauses,
## while the breathing and the blinking carry on.
##
## The dummy is wary, never frozen. It watches the knight, shifts its weight and glances away
## now and then; flinches while the sword winds up; staggers when it lands, leaning into the
## plush's own tilt poses; and gets woozier as its health drops. Every reaction is a pure
## function of what yard.gd tells it (the swing phase, the hit, the health) and of its own
## clock, with no randomness, so the same game state always looks the same.

enum Mode { GUARD, WARY }

## One attack is a list of keys: [seconds, alpha, beta, lunge, lift, twist, ease].
## The blade points alpha degrees from straight up towards the front (90 is level) and beta
## degrees from straight ahead towards the knight's left. lunge slides the body forward and
## lift raises it, both in metres. twist turns the hips about the vertical, in degrees.
## ease shapes the way in from the previous key: above 1 starts slowly and ends fast.
## The third key is the contact: the blade is on the bucket and yard.gd resolves the hit.
const ATTACKS := [
	# 1: a chop from above.
	[[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
	[0.22, -35.0, -12.0, -0.04, 0.03, -10.0, 0.4],
	[0.30, 52.0, 19.0, 0.2, 0.0, 14.0, 3.0],
	[0.46, 116.0, 24.0, 0.26, -0.02, 20.0, 0.4],
	[0.84, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
	# 2: a backhand slash across the front.
	[[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
	[0.20, 82.0, 78.0, -0.03, 0.0, -18.0, 0.4],
	[0.27, 70.0, 19.0, 0.2, 0.0, 12.0, 3.0],
	[0.44, 80.0, -62.0, 0.26, 0.0, 26.0, 0.4],
	[0.80, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
	# 3: the finisher. A bigger wind-up with a hop, then a lunge.
	[[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
	[0.36, -62.0, 0.0, -0.1, 0.16, -14.0, 0.45],
	[0.46, 52.0, 19.0, 0.34, 0.0, 16.0, 3.5],
	[0.68, 130.0, 22.0, 0.4, -0.03, 24.0, 0.4],
	[1.24, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
]
const BLADE_GUARD := Vector2(14.0, -6.0)

@export var mode := Mode.GUARD
@export var tempo := 116.0 ## beats per minute

## The plush's shader material, for blinking.
var material: ShaderMaterial
var time := 0.0
var next_blink := 1.7
var blink := 0.0
## The attack in progress (-1 for none) and the seconds of game time it has run.
var attack := -1
var attack_time := 0.0

## The wary dummy, set by yard.gd.
## Degrees the knight stands to the dummy's side of the way it faces.
var watch_yaw := 0.0
## 0 to 1: how far into the knight's wind-up the swing is (0 when no swing is coming).
var threat := 0.0
## 0 to 1: how beaten up it is. Slows the recovery and adds the woozy tilt.
var daze := 0.0
## The plush's tilt_l and tilt_r poses: a rotation per bone and the hips' position, sampled once.
var tilts := {}
var threat_now := 0.0
var hit_time := 99.0
var hit_amount := 0.0
var hit_side := 1.0
var shake_time := 99.0
var squint := 0.0


## Seconds into an attack at which the blade meets the target.
static func contact_time(index: int) -> float:
	return ATTACKS[index][2][0]


## Seconds an attack takes from the first move to the guard again.
static func duration(index: int) -> float:
	return ATTACKS[index][-1][0]


## Which way the blade points, in the knight's own space, for these angles in radians.
static func blade_direction(alpha: float, beta: float) -> Vector3:
	return Vector3(0.0, cos(alpha), sin(alpha)).rotated(Vector3.UP, beta)


## Which way the blade is travelling at the moment of contact, in the knight's own space.
static func swing_direction(index: int) -> Vector3:
	var keys: Array = ATTACKS[index]
	var at: float = keys[2][0]
	var before := _sample(keys, at - 0.03)
	var after := _sample(keys, at + 0.03)
	var from := blade_direction(deg_to_rad(before[0]), deg_to_rad(before[1]))
	var to := blade_direction(deg_to_rad(after[0]), deg_to_rad(after[1]))
	# The tip travels the way the blade turns; the middle of the blade is what meets the bucket.
	return (to - from).normalized()


func _process_modification_with_delta(delta: float) -> void:
	time += delta
	var skeleton := get_skeleton()
	var beat := time * tempo / 60.0 * TAU
	if mode == Mode.WARY:
		_wary(skeleton, delta)
	else:
		_knight(skeleton, beat)
	_blink(delta)


func _knight(skeleton: Skeleton3D, beat: float) -> void:
	var breath := sin(beat * 0.25)
	var alpha := BLADE_GUARD.x + breath * 1.5
	var beta := BLADE_GUARD.y
	var lunge := 0.0
	var lift := 0.0
	var twist := 0.0
	if attack >= 0:
		var key := _sample(ATTACKS[attack], attack_time)
		alpha = key[0]
		beta = key[1]
		lunge = key[2]
		lift = key[3]
		twist = key[4]
	# The body: a slow breath at rest, and the hips driving the swing.
	_lift(skeleton, Vector3(0.0, (breath * 0.5 + 0.5) * 0.016 + lift, lunge))
	_turn(skeleton, &"DEF-hips", Vector3(0.0, twist, 0.0))
	_turn(skeleton, &"DEF-head", Vector3(breath * 3.5 + lunge * 20.0, 0.0, 0.0))
	_sword_arm(skeleton, deg_to_rad(alpha), deg_to_rad(beta))
	_off_arm(skeleton, breath)


## Sword arm. The blade direction comes first; the forearm is turned square to it so the
## sword crosses the paw, and the upper arm bends to meet the forearm.
func _sword_arm(skeleton: Skeleton3D, alpha: float, beta: float) -> void:
	var blade := blade_direction(alpha, beta)
	var right := Vector3.LEFT
	var forearm := (blade.cross(right) + Vector3(0.0, 0.0, 0.25))
	forearm = (forearm - blade * forearm.dot(blade)).normalized()
	var upper := (Vector3(-0.75, -0.7, 0.0) + forearm * 0.7).normalized()
	_aim(skeleton, &"DEF-upper_arm.R", upper)
	_aim(skeleton, &"DEF-forearm.R", forearm)
	_frame(skeleton, &"DEF-hand.R", forearm, blade)


## The other arm: a fist bent up in front of the chest, breathing with the knight.
func _off_arm(skeleton: Skeleton3D, breath: float) -> void:
	var upper := Vector3(0.55, -0.55, 0.45).normalized()
	var forearm := Vector3(-0.25, 0.45 + breath * 0.03, 0.85).normalized()
	_aim(skeleton, &"DEF-upper_arm.L", upper)
	_aim(skeleton, &"DEF-forearm.L", forearm)
	_frame(skeleton, &"DEF-hand.L", forearm, Vector3.RIGHT)


## A hit has landed: stagger by `amount` (1 is a full lean into a tilt pose), leaning to `side`
## (positive to the plush's left).
func hit(amount: float, side: float) -> void:
	hit_time = 0.0
	hit_amount = amount
	hit_side = 1.0 if side >= 0.0 else -1.0


## Shake it off: a quick head shake that dies away, then back to watching the knight.
func shake() -> void:
	shake_time = 0.0


## Forget every reaction (a reset): the wary stance, nothing in progress.
func calm() -> void:
	threat = 0.0
	threat_now = 0.0
	hit_time = 99.0
	shake_time = 99.0
	daze = 0.0


func _wary(skeleton: Skeleton3D, delta: float) -> void:
	threat_now = move_toward(threat_now, threat, delta * 8.0)
	hit_time += delta
	shake_time += delta
	var breath := sin(time * 3.0)
	var sway := sin(time * 0.9)
	# A stagger: the plush's tilt poses, alternating, shrinking as the wobble settles. A dazed
	# plush takes longer to settle and wobbles more slowly.
	var settle := 1.0 / (0.3 + 0.5 * daze)
	var envelope := hit_amount * exp(-hit_time * settle)
	var wobble := envelope * cos(hit_time * TAU * (2.7 - 1.1 * daze)) * hit_side
	_tilt(skeleton, wobble * 0.8)
	# The first instant of a hit throws the head back and the arms out.
	var jolt := hit_amount * exp(-hit_time * 9.0)
	var flail := hit_amount * exp(-hit_time * 5.0)
	# Wary: weight shifts from foot to foot, and every few seconds a nervous glance away.
	var glance := maxf(_pulse(5.3, 2.9, 0.8), _pulse(8.9, 6.1, 0.7))
	var calm_ness := 1.0 - threat_now
	var look := watch_yaw * (0.85 + 0.15 * threat_now) - glance * (watch_yaw * 0.9 + 10.0) * calm_ness
	look += sin(time * 11.0) * (0.8 + 4.0 * threat_now)
	if shake_time < 1.0:
		look += sin(shake_time * TAU * 3.5) * 24.0 * (1.0 - shake_time)
	var woozy := daze * sin(time * 2.3)
	_lift(skeleton, Vector3(sway * 0.008, (breath * 0.5 + 0.5) * 0.012, 0.0))
	_turn(skeleton, &"DEF-hips", Vector3(-threat_now * 14.0 - jolt * 10.0, watch_yaw * 0.3 + daze * 6.0 * sin(time * 1.7), sway * 2.5))
	_turn(skeleton, &"DEF-head", Vector3(breath * 2.5 - threat_now * 8.0 - jolt * 22.0 + daze * 4.0 * sin(time * 1.4),
			look - watch_yaw * 0.3, -wobble * 12.0 + daze * 12.0 + woozy * 12.0))
	# Arms: up and bent across the face against the swing, flung out by the hit.
	var arms := threat_now * 70.0 + flail * 45.0
	var elbows := threat_now * 95.0 + flail * 20.0
	_turn(skeleton, &"DEF-upper_arm.L", Vector3(0.0, 0.0, arms))
	_turn(skeleton, &"DEF-upper_arm.R", Vector3(0.0, 0.0, -arms))
	_turn(skeleton, &"DEF-forearm.L", Vector3(0.0, 0.0, elbows))
	_turn(skeleton, &"DEF-forearm.R", Vector3(0.0, 0.0, -elbows))
	squint = threat_now * 0.85


## A smooth 0 to 1 pulse: `length` seconds long, starting `start` seconds into every `period`.
func _pulse(period: float, start: float, length: float) -> float:
	var at := fmod(time, period) - start
	if at < 0.0 or at > length:
		return 0.0
	return pow(sin(PI * at / length), 2.0)


## Blend the bones towards the plush's tilt_l pose (positive weight) or its tilt_r pose (negative).
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


## The values between two keys of an attack at this time, eased.
static func _sample(keys: Array, at: float) -> Array:
	var last: Array = keys[-1]
	if at >= last[0]:
		return last.slice(1, 6)
	for i in range(1, keys.size()):
		var to: Array = keys[i]
		if at <= to[0]:
			var from: Array = keys[i - 1]
			var along := ease(inverse_lerp(from[0], to[0], at), to[6])
			var out := []
			for k in range(1, 6):
				out.append(lerpf(from[k], to[k], along))
			return out
	return last.slice(1, 6)


func _turn(skeleton: Skeleton3D, bone: StringName, degrees: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	var turn := Quaternion.from_euler(degrees * PI / 180.0)
	skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * turn)


func _lift(skeleton: Skeleton3D, offset: Vector3) -> void:
	skeleton.set_bone_pose_position(0, skeleton.get_bone_pose_position(0) + offset)


## Point a bone's own Y axis (the way the limb runs) along a direction in skeleton space.
func _aim(skeleton: Skeleton3D, bone: StringName, direction: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(i)
	pose.basis = Basis(Quaternion(pose.basis.y.normalized(), direction)) * pose.basis
	skeleton.set_bone_global_pose(i, pose)


## Set a bone's whole frame: Y along the limb, X as close to the hint as that allows.
func _frame(skeleton: Skeleton3D, bone: StringName, along: Vector3, across: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(i)
	var x := (across - along * across.dot(along)).normalized()
	pose.basis = Basis(x, along, x.cross(along))
	skeleton.set_bone_global_pose(i, pose)
