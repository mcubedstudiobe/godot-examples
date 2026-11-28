class_name PlushMotion
extends SkeletonModifier3D
## Keeps both plushes alive on top of their held pose: a bouncy fighter who swings a rubber
## chicken, and a victim who reacts to the situation. A SkeletonModifier3D only adds to the pose for
## this frame, so the held pose underneath never drifts.
##
## The fighter's swing is procedural. dojo.gd says which attack is running and how many seconds of
## it have passed; this node turns that into arm bones every frame, so a swing holds when the game
## pauses while the breathing and the blinking carry on.
##
## The victim is never frozen and never dances. It keeps a wary guard and watches the fighter,
## flinches while the chicken winds up, staggers and wobbles when it lands (more on a crit), goes
## dazed once it has taken a flurry, and sits down with X eyes if it is knocked out. Every reaction
## is a pure function of what dojo.gd tells it and of its own clock, with no randomness.

enum Mode { FIGHTER, VICTIM }
enum Attack { LIGHT, HIT, HEAVY, CRIT, JAB_LEFT, JAB_RIGHT }

## One attack is a list of keys: [seconds, alpha, beta, lunge, lift, twist, ease].
## The chicken points alpha degrees from straight up towards the front (90 is level) and beta
## degrees from straight ahead towards the fighter's left. lunge slides the body forward and lift
## raises it, both in metres. twist turns the hips about the vertical, in degrees. ease shapes the
## way in from the previous key: above 1 starts slowly and ends fast. The third key is the contact.
const ATTACKS := {
	# A small flick of the wrist.
	Attack.LIGHT: [[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
		[0.16, 20.0, 6.0, -0.02, 0.0, -6.0, 0.5],
		[0.26, 48.0, 14.0, 0.24, 0.0, 8.0, 3.0],
		[0.38, 66.0, 16.0, 0.14, 0.0, 10.0, 0.5],
		[0.66, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
	# A straight chop from above.
	Attack.HIT: [[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
		[0.22, -35.0, -12.0, -0.04, 0.03, -10.0, 0.4],
		[0.30, 44.0, 19.0, 0.32, 0.0, 14.0, 3.0],
		[0.40, 64.0, 22.0, 0.22, -0.02, 18.0, 0.4],
		[0.84, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
	# A big wind-up behind the back, a hop and a slam.
	Attack.HEAVY: [[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
		[0.36, -62.0, 0.0, -0.1, 0.16, -14.0, 0.45],
		[0.46, 40.0, 19.0, 0.42, 0.0, 16.0, 3.5],
		[0.60, 70.0, 22.0, 0.32, -0.03, 22.0, 0.4],
		[1.24, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
	# The crit: a huge wind-up that spins the chicken all the way round, then the hardest slam.
	Attack.CRIT: [[0.0, 14.0, -6.0, 0.0, 0.0, 0.0, 1.0],
		[0.30, -84.0, -24.0, -0.14, 0.2, -26.0, 0.45],
		[0.62, 36.0, 26.0, 0.48, 0.04, 26.0, 4.0],
		[0.80, 74.0, 30.0, 0.38, -0.04, 30.0, 0.4],
		[1.50, 14.0, -6.0, 0.0, 0.0, 0.0, -2.0]],
	# The flurry: short, quick whacks from either side.
	Attack.JAB_LEFT: [[0.0, 40.0, 10.0, 0.0, 0.0, 0.0, 1.0],
		[0.07, 50.0, 66.0, -0.02, 0.0, -14.0, 0.5],
		[0.15, 52.0, 20.0, 0.26, 0.0, 12.0, 2.5],
		[0.2, 62.0, -40.0, 0.2, 0.0, 18.0, 0.5],
		[0.3, 40.0, 10.0, 0.0, 0.0, 0.0, -1.5]],
	Attack.JAB_RIGHT: [[0.0, 40.0, 10.0, 0.0, 0.0, 0.0, 1.0],
		[0.07, 50.0, -48.0, -0.02, 0.0, 16.0, 0.5],
		[0.15, 52.0, 12.0, 0.26, 0.0, -4.0, 2.5],
		[0.2, 62.0, 52.0, 0.2, 0.0, -2.0, 0.5],
		[0.3, 40.0, 10.0, 0.0, 0.0, 0.0, -1.5]],
}
const BLADE_GUARD := Vector2(14.0, -6.0)
## The fighter's weight bounces on its toes at this many beats a minute.
const BOUNCE_BPM := 116.0
## The victim's guard: the fists stay up by its chin.
const GUARD_SWAY := 0.008
## How far its hips sink when it sits down knocked out, in metres of the hips bone.
const KO_SINK := 0.36

@export var mode := Mode.FIGHTER

## The plush's shader material, for blinking.
var material: ShaderMaterial
var time := 0.0
var next_blink := 1.7
var blink := 0.0
## The fighter: the attack in progress (-1 for none) and the seconds of it that have run.
var attack := -1
var attack_time := 0.0
## The victim: degrees the fighter stands to its side of the way it faces.
var watch_yaw := 0.0
## 0 to 1: how far into the fighter's wind-up the swing is (0 when no swing is coming).
var threat := 0.0
## 0 to 1: how beaten up it is. Slows the recovery, sways it and half-closes its eyes.
var daze := 0.0
## 0 to 1: knocked out, sitting with its eyes crossed out.
var ko := 0.0
var ko_goal := 0.0
## The plush's tilt_l and tilt_r poses: a rotation per bone and the hips' position, sampled once.
var tilts := {}
var threat_now := 0.0
var hit_time := 99.0
var hit_amount := 0.0
var hit_side := 1.0
var hit_crit := 0.0
var squint := 0.0


## Seconds into an attack at which the chicken meets the target.
static func contact_time(index: int) -> float:
	return ATTACKS[index][2][0]


## Seconds an attack takes from the first move to the guard again.
static func duration(index: int) -> float:
	return ATTACKS[index][-1][0]


## Which way the chicken points, in the fighter's own space, for these angles in radians.
static func blade_direction(alpha: float, beta: float) -> Vector3:
	return Vector3(0.0, cos(alpha), sin(alpha)).rotated(Vector3.UP, beta)


## Which way the chicken is travelling at the moment of contact, in the fighter's own space.
static func swing_direction(index: int) -> Vector3:
	var keys: Array = ATTACKS[index]
	var at: float = keys[2][0]
	var before := _sample(keys, at - 0.03)
	var after := _sample(keys, at + 0.03)
	var from := blade_direction(deg_to_rad(before[0]), deg_to_rad(before[1]))
	var to := blade_direction(deg_to_rad(after[0]), deg_to_rad(after[1]))
	return (to - from).normalized()


func _process_modification_with_delta(delta: float) -> void:
	time += delta
	var skeleton := get_skeleton()
	if mode == Mode.VICTIM:
		_victim(skeleton, delta)
	else:
		_fighter(skeleton)
	_blink(delta)


func _fighter(skeleton: Skeleton3D) -> void:
	var beat := time * BOUNCE_BPM / 60.0 * TAU
	var breath := sin(beat * 0.25)
	var bounce := (sin(beat) * 0.5 + 0.5)
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
	# The body: a bouncy breath at rest, and the hips driving the swing.
	_lift(skeleton, Vector3(0.0, bounce * 0.03 * (1.0 if attack < 0 else 0.3) + lift, lunge))
	_turn(skeleton, &"DEF-hips", Vector3(0.0, twist, sin(beat * 0.5) * 1.5))
	_turn(skeleton, &"DEF-head", Vector3(breath * 3.5 + lunge * 20.0, -twist * 0.3, 0.0))
	_chicken_arm(skeleton, deg_to_rad(alpha), deg_to_rad(beta))
	_fist_arm(skeleton, &"L", breath, 0.0)


## The chicken arm. The blade direction comes first; the forearm is turned square to it so the
## chicken's legs cross the paw, and the upper arm bends to meet the forearm.
func _chicken_arm(skeleton: Skeleton3D, alpha: float, beta: float) -> void:
	var blade := blade_direction(alpha, beta)
	var right := Vector3.LEFT
	var forearm := (blade.cross(right) + Vector3(0.0, 0.0, 0.25))
	forearm = (forearm - blade * forearm.dot(blade)).normalized()
	var upper := (Vector3(-0.75, -0.7, 0.0) + forearm * 0.7).normalized()
	_aim(skeleton, &"DEF-upper_arm.R", upper)
	_aim(skeleton, &"DEF-forearm.R", forearm)
	_frame(skeleton, &"DEF-hand.R", forearm, blade)


## A fist bent up in front of the chest, breathing. `raise` lifts the forearm across the face.
func _fist_arm(skeleton: Skeleton3D, side: StringName, breath: float, raise: float, flail := Vector3.ZERO) -> void:
	var s := 1.0 if side == &"L" else -1.0
	var upper := Vector3(0.55 * s, -0.55, 0.45).normalized()
	var forearm := Vector3(-0.25 * s, 0.45 + breath * 0.03, 0.85).normalized()
	var guard_forearm := Vector3(-0.55 * s, 0.85, 0.5).normalized()
	forearm = forearm.lerp(guard_forearm, raise).normalized()
	upper = upper.lerp(Vector3(0.7 * s, 0.1, 0.5).normalized(), raise * 0.5).normalized()
	if flail != Vector3.ZERO:
		upper = upper.lerp(Vector3(s * flail.x, flail.y, flail.z).normalized(), clampf(flail.length(), 0.0, 1.0)).normalized()
		forearm = forearm.lerp(Vector3(s * 0.9, 0.3, 0.2).normalized(), clampf(flail.length(), 0.0, 1.0) * 0.8).normalized()
	_aim(skeleton, &"DEF-upper_arm." + side, upper)
	_aim(skeleton, &"DEF-forearm." + side, forearm)
	_frame(skeleton, &"DEF-hand." + side, forearm, Vector3.RIGHT * s)


## A hit has landed: stagger by `amount` (1 is a full lean into a tilt pose), leaning to `side`
## (positive to the plush's left). A crit throws everything about harder.
func hit(amount: float, side: float, crit := false) -> void:
	hit_time = 0.0
	hit_amount = amount * (1.5 if crit else 1.0)
	hit_crit = 1.0 if crit else 0.0
	hit_side = 1.0 if side >= 0.0 else -1.0


## Forget every reaction (a reset): the wary guard, nothing in progress.
func calm() -> void:
	threat = 0.0
	threat_now = 0.0
	hit_time = 99.0
	hit_crit = 0.0
	daze = 0.0
	ko = 0.0
	ko_goal = 0.0


func _victim(skeleton: Skeleton3D, delta: float) -> void:
	threat_now = move_toward(threat_now, threat, delta * 8.0)
	ko = move_toward(ko, ko_goal, delta * 2.6)
	hit_time += delta
	var breath := sin(time * 3.0)
	var sway := sin(time * 0.9)
	var awake := 1.0 - ko
	# A stagger: the plush's tilt poses, alternating, shrinking as the wobble settles. A dazed
	# plush takes longer to settle and wobbles more slowly.
	var settle := 1.0 / (0.3 + 0.5 * daze + 0.15 * hit_crit)
	var envelope := hit_amount * exp(-hit_time * settle)
	var wobble := envelope * cos(hit_time * TAU * (2.7 - 1.1 * daze)) * hit_side
	_tilt(skeleton, wobble * 0.8 * awake)
	# The first instant of a hit throws the head back and the arms out.
	var jolt := hit_amount * exp(-hit_time * 9.0)
	var flail := hit_amount * exp(-hit_time * 5.0)
	# Wary: weight shifts from foot to foot, and every few seconds a nervous glance away.
	var glance := maxf(_pulse(5.3, 2.9, 0.8), _pulse(8.9, 6.1, 0.7))
	var steady := 1.0 - threat_now
	var look := watch_yaw * (0.85 + 0.15 * threat_now) - glance * (watch_yaw * 0.9 + 10.0) * steady
	look += sin(time * 11.0) * (0.8 + 4.0 * threat_now)
	var woozy := daze * sin(time * 2.3) * awake
	var circle := daze * awake
	_lift(skeleton, Vector3(sway * GUARD_SWAY + woozy * 0.03 + circle * cos(time * 1.9) * 0.02,
			(breath * 0.5 + 0.5) * 0.012 - jolt * 0.03 - ko * KO_SINK, -ko * 0.12))
	_turn(skeleton, &"DEF-hips", Vector3(-threat_now * 14.0 - jolt * 10.0 - ko * 14.0 + woozy * 3.0,
			(watch_yaw * 0.3 + daze * 6.0 * sin(time * 1.7)) * awake, sway * 2.5 + woozy * 5.0 + ko * 4.0))
	_turn(skeleton, &"DEF-head", Vector3(breath * 2.5 - threat_now * 8.0 - jolt * 22.0 + daze * 8.0 + ko * 18.0,
			(look - watch_yaw * 0.3) * awake, -wobble * 12.0 + woozy * 12.0 + ko * (24.0 + sin(time * 1.1) * 3.0)))
	# Arms: the guard, with the forearms flying up across the face against the swing, flung out by
	# the hit, drooping with the daze and hanging when out cold.
	var droop := clampf(daze * 0.6 + ko, 0.0, 1.0)
	var flinch := clampf(threat_now + flail * 0.3, 0.0, 1.0)
	var flung := flail * 1.1
	for side in [&"L", &"R"]:
		var s := 1.0 if side == &"L" else -1.0
		_fist_arm(skeleton, side, breath, flinch, Vector3(0.9, -0.2, 0.3) * minf(flung, 1.0))
		if droop > 0.0:
			_blend_aim(skeleton, &"DEF-upper_arm." + side, Vector3(0.35 * s, -1.0, 0.1), droop)
			_blend_aim(skeleton, &"DEF-forearm." + side, Vector3(0.1 * s, -1.0, 0.25), droop)
	if ko > 0.0:
		_sit(skeleton, ko)
	squint = threat_now * 0.85


## Out cold: it sits back on the mat with its legs out in front.
func _sit(skeleton: Skeleton3D, weight: float) -> void:
	for side in [&"L", &"R"]:
		_blend_aim(skeleton, &"DEF-thigh." + side, Vector3(0.0, -0.1, 1.0), weight)
		_blend_aim(skeleton, &"DEF-shin." + side, Vector3(0.0, 0.0, 1.0), weight)
		_blend_aim(skeleton, &"DEF-foot." + side, Vector3(0.0, 0.5, 1.0), weight)


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
		# A dazed plush keeps its eyes half shut and a knocked-out one's are X's.
		var lids := maxf(blink, maxf(squint, daze * 0.4 * (1.0 - ko)))
		material.set_shader_parameter(&"blink", lids)
		var alarmed := maxf(threat_now, hit_crit * exp(-hit_time * 3.0))
		material.set_shader_parameter(&"wide", alarmed * (1.0 - squint))


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
	pose.basis = Basis(Quaternion(pose.basis.y.normalized(), direction.normalized())) * pose.basis
	skeleton.set_bone_global_pose(i, pose)


## Turn a bone's own Y axis towards a direction in skeleton space, by `weight`.
func _blend_aim(skeleton: Skeleton3D, bone: StringName, direction: Vector3, weight: float) -> void:
	var i := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(i)
	var turn := Quaternion(pose.basis.y.normalized(), direction.normalized())
	pose.basis = Basis(Quaternion.IDENTITY.slerp(turn, weight)) * pose.basis
	skeleton.set_bone_global_pose(i, pose)


## Set a bone's whole frame: Y along the limb, X as close to the hint as that allows.
func _frame(skeleton: Skeleton3D, bone: StringName, along: Vector3, across: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	var pose := skeleton.get_bone_global_pose(i)
	var x := (across - along * across.dot(along)).normalized()
	pose.basis = Basis(x, along, x.cross(along))
	skeleton.set_bone_global_pose(i, pose)
