class_name PlushMotion
extends SkeletonModifier3D
## Keeps a plush alive on top of whatever the AnimationTree is playing: it breathes and blinks all
## the time, and a few procedural poses can be blended in for the moments a clip does not cover:
## flailing at an edge, a dismayed look just before a fall, floating in the cocoa, and a dazed
## wobble. A SkeletonModifier3D only adds to the pose for this frame, so nothing drifts.

enum Pose { LIVE, FLAIL, DISMAY, FLOAT, DAZED }

const HEAD := 1
const UPPER_ARM_L := 2
const FOREARM_L := 3
const UPPER_ARM_R := 5
const FOREARM_R := 6
const THIGH_L := 8
const THIGH_R := 12
const SHIN_L := 9
const SHIN_R := 13
const BLEND_RATE := 9.0

## The shader material, for blinking and the eyes.
var material: ShaderMaterial
var pose := Pose.LIVE
var time := 0.0
var next_blink := 1.6
var blink := 0.0
var weights := {Pose.FLAIL: 0.0, Pose.DISMAY: 0.0, Pose.FLOAT: 0.0, Pose.DAZED: 0.0}


func _process_modification_with_delta(delta: float) -> void:
	time += delta
	var skeleton := get_skeleton()
	for p: Pose in weights:
		weights[p] = move_toward(weights[p], 1.0 if p == pose else 0.0, BLEND_RATE * delta)
	# Breathing: the whole plush swells a touch.
	var breath := sin(time * TAU * 0.28)
	skeleton.set_bone_pose_scale(0, Vector3.ONE * (1.0 + breath * 0.012))
	var flail: float = weights[Pose.FLAIL]
	var dismay: float = weights[Pose.DISMAY]
	var floating: float = weights[Pose.FLOAT]
	var dazed: float = weights[Pose.DAZED]
	var t := time
	# Arms: raised and windmilling when flailing, up and trembling when dismayed, out and loose
	# when floating. Positive turns lift the plush's left arm, negative lift its right.
	var arm_l := flail * (1.5 + 0.8 * sin(t * 19.0)) + dismay * (1.75 + 0.06 * sin(t * 43.0)) \
			+ floating * (0.95 + 0.12 * sin(t * 2.1)) + dazed * 0.18 * sin(t * 2.4)
	var arm_r := flail * (1.5 + 0.8 * sin(t * 19.0 + 1.9)) + dismay * (1.75 + 0.06 * sin(t * 43.0 + 1.0)) \
			+ floating * (0.95 + 0.12 * sin(t * 2.1 + 1.0)) + dazed * 0.18 * sin(t * 2.4 + 2.0)
	_turn(skeleton, UPPER_ARM_L, Vector3.BACK, arm_l)
	_turn(skeleton, UPPER_ARM_R, Vector3.BACK, -arm_r)
	_turn(skeleton, FOREARM_L, Vector3.BACK, flail * 0.5 * sin(t * 19.0 + 1.0) + dismay * 0.25)
	_turn(skeleton, FOREARM_R, Vector3.BACK, -(flail * 0.5 * sin(t * 19.0 + 2.5) + dismay * 0.25))
	# Legs kick when flailing and dangle when floating.
	var kick := sin(t * 15.0) * flail * 0.7
	_turn(skeleton, THIGH_L, Vector3.RIGHT, kick)
	_turn(skeleton, THIGH_R, Vector3.RIGHT, -kick)
	# The head trembles when dismayed and wobbles when dazed.
	_turn(skeleton, HEAD, Vector3.BACK, dismay * 0.05 * sin(t * 34.0) + dazed * 0.26 * sin(t * 3.4) + flail * 0.12 * sin(t * 11.0))
	_turn(skeleton, HEAD, Vector3.RIGHT, dazed * 0.16 * cos(t * 3.4) + floating * 0.06 * sin(t * 1.7))
	_blink(delta, dazed)
	if material != null:
		material.set_shader_parameter(&"wide", clampf(dismay + flail * 0.6, 0.0, 1.0))


## Turn a bone about one of its own axes, on top of its animated pose.
func _turn(skeleton: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
	if absf(angle) < 0.0001:
		return
	skeleton.set_bone_pose_rotation(bone, skeleton.get_bone_pose_rotation(bone) * Quaternion(axis, angle))


func _blink(delta: float, dazed: float) -> void:
	next_blink -= delta
	if next_blink <= 0.0:
		blink = 1.0
		next_blink = 2.6 + 1.1 * sin(time * 0.7)
	blink = move_toward(blink, 0.0, delta * 7.0)
	if material != null:
		material.set_shader_parameter(&"blink", maxf(blink, dazed * 0.55))
