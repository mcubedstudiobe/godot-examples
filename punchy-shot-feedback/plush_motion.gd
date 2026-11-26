class_name PlushMotion
extends SkeletonModifier3D
## Keeps a plush alive on top of its held pose: a steady, breathing stance for the shooter, a
## dance for the target, and blinking for both. A SkeletonModifier3D only adds to the pose for
## this frame, so the held pose underneath never drifts. Plush switches it off when the
## ragdoll takes over.

enum Mode { STANCE, DANCE }

@export var mode := Mode.STANCE
@export var tempo := 116.0 ## beats per minute

## The plush's shader material, for blinking.
var material: ShaderMaterial
var time := 0.0
var flinch := 0.0
var next_blink := 1.7
var blink := 0.0


## A short jolt for the stance, for example on a shot.
func kick() -> void:
	flinch = 1.0
	blink = 1.0


func _process_modification_with_delta(delta: float) -> void:
	time += delta
	flinch = move_toward(flinch, 0.0, delta * 6.0)
	var skeleton := get_skeleton()
	var beat := time * tempo / 60.0 * TAU
	if mode == Mode.DANCE:
		_dance(skeleton, beat)
	else:
		_stance(skeleton, beat)
	_blink(delta)


func _stance(skeleton: Skeleton3D, beat: float) -> void:
	# Holds the rifle steady: a slow breath, and a flinch back and up on a shot. The rifle
	# rides the head bone with both arms (range.gd), so the hands never leave it.
	# A slow breath would read as a frozen character in a small or dimmed shot, so it is quick
	# and deep enough to see: about one breath every two seconds.
	var breath := sin(beat * 0.25)
	_lift(skeleton, Vector3(0.0, (breath * 0.5 + 0.5) * 0.016, -flinch * 0.03))
	_turn(skeleton, &"DEF-head", Vector3(breath * 3.5 - flinch * 8.0, 0.0, 0.0))


func _dance(skeleton: Skeleton3D, beat: float) -> void:
	# Bounce on the beat, sway and twist on the bar, arms up and pumping in turn, knees lifting.
	var bounce := absf(sin(beat * 0.5))
	var sway := sin(beat * 0.25)
	var pump := sin(beat * 0.5)
	_lift(skeleton, Vector3(0.0, bounce * 0.07, 0.0))
	_turn(skeleton, &"DEF-hips", Vector3(0.0, sway * 25.0, sway * 12.0))
	_turn(skeleton, &"DEF-head", Vector3(bounce * 8.0, 0.0, -sway * 8.0))
	_turn(skeleton, &"DEF-upper_arm.L", Vector3(0.0, 0.0, 75.0 + pump * 50.0))
	_turn(skeleton, &"DEF-forearm.L", Vector3(0.0, 0.0, 40.0 + pump * 35.0))
	_turn(skeleton, &"DEF-upper_arm.R", Vector3(0.0, 0.0, -75.0 + pump * 50.0))
	_turn(skeleton, &"DEF-forearm.R", Vector3(0.0, 0.0, -40.0 + pump * 35.0))
	_turn(skeleton, &"DEF-thigh.L", Vector3(maxf(pump, 0.0) * -40.0, 0.0, 0.0))
	_turn(skeleton, &"DEF-shin.L", Vector3(maxf(pump, 0.0) * 50.0, 0.0, 0.0))
	_turn(skeleton, &"DEF-thigh.R", Vector3(maxf(-pump, 0.0) * -40.0, 0.0, 0.0))
	_turn(skeleton, &"DEF-shin.R", Vector3(maxf(-pump, 0.0) * 50.0, 0.0, 0.0))


func _blink(delta: float) -> void:
	next_blink -= delta
	if next_blink <= 0.0:
		blink = 1.0
		next_blink = 2.2 + fmod(time * 7.31, 1.6)
	blink = move_toward(blink, 0.0, delta * 7.0)
	if material != null:
		material.set_shader_parameter(&"blink", blink)


func _turn(skeleton: Skeleton3D, bone: StringName, degrees: Vector3) -> void:
	var i := skeleton.find_bone(bone)
	var turn := Quaternion.from_euler(degrees * PI / 180.0)
	skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * turn)


func _lift(skeleton: Skeleton3D, offset: Vector3) -> void:
	skeleton.set_bone_pose_position(0, skeleton.get_bone_pose_position(0) + offset)
