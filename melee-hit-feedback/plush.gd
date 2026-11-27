class_name Plush
extends Node3D
## One Godot Plush Character (Tibo, MIT): poses it, tints it, keeps it moving, and on
## the dummy runs its ragdoll. The ragdoll is the PhysicalBoneSimulator3D named Ragdoll
## under the skeleton; dummy.tscn adds it, the knight has none.

const SHADER := preload("res://plush.gdshader")
const ALBEDO := preload("res://plush/godot_plush_albedo.png")
const NORMAL := preload("res://plush/godot_plush_normal.png")

## The base pose: this second of the idle animation, held.
@export var hold_at := 0.0
## What the plush does on top of the held pose.
@export var motion_mode := PlushMotion.Mode.GUARD
## Colour wheel turn for the body (0 keeps the Godot blue).
@export var hue_shift := 0.0
@export var saturation := 1.0

@onready var mesh: MeshInstance3D = $Model/Rig/Skeleton3D/GodotPlushMesh
@onready var skeleton: Skeleton3D = $Model/Rig/Skeleton3D
@onready var player: AnimationPlayer = $Model/AnimationPlayer
@onready var ragdoll: PhysicalBoneSimulator3D = skeleton.get_node_or_null(^"Ragdoll")

## The tinted plush material. Its flash parameter washes the plush white for a hit.
var tint := ShaderMaterial.new()
var motion := PlushMotion.new()


func _ready() -> void:
	tint.shader = SHADER
	tint.set_shader_parameter(&"albedo_texture", ALBEDO)
	tint.set_shader_parameter(&"normal_texture", NORMAL)
	tint.set_shader_parameter(&"hue_shift", hue_shift)
	tint.set_shader_parameter(&"saturation", saturation)
	mesh.material_override = tint
	motion.mode = motion_mode
	motion.material = tint
	motion.tilts = {&"l": sample_pose(&"tilt_l"), &"r": sample_pose(&"tilt_r")}
	skeleton.add_child(motion)
	stand()


## The pose of one animation's first frame: a rotation per bone and the hips' position.
func sample_pose(clip: StringName) -> Dictionary:
	player.play(clip)
	player.seek(0.0, true)
	player.advance(0.0)
	player.pause()
	var rotations: Array[Quaternion] = []
	for bone in skeleton.get_bone_count():
		rotations.append(skeleton.get_bone_pose_rotation(bone))
	return {"rotations": rotations, "hips": skeleton.get_bone_pose_position(0)}


## Back on its feet: stop the ragdoll and restart the pose.
func stand() -> void:
	if ragdoll != null:
		ragdoll.physical_bones_stop_simulation()
		# Out of the physics world while standing: the bodies would otherwise follow
		# the animated, squashed bones, and physics bodies cannot take a squash.
		ragdoll.process_mode = Node.PROCESS_MODE_DISABLED
	player.play(&"idle")
	player.seek(hold_at, true)
	player.pause()
	motion.calm()
	motion.active = true
	tint.set_shader_parameter(&"dead", 0.0)


## Hand every body part to physics and give them all the same push.
func go_limp(velocity: Vector3, spin := Vector3.ZERO) -> void:
	motion.active = false
	tint.set_shader_parameter(&"dead", 1.0)
	tint.set_shader_parameter(&"blink", 0.0)
	for bone in skeleton.get_bone_count():
		skeleton.set_bone_pose_scale(bone, Vector3.ONE)
	ragdoll.process_mode = Node.PROCESS_MODE_INHERIT
	ragdoll.physical_bones_start_simulation()
	for body: PhysicalBone3D in ragdoll.get_children():
		body.linear_velocity = velocity
		body.angular_velocity = spin
