class_name Plush
extends Node3D
## One Godot Plush Character (Tibo, MIT): poses it, tints it, keeps it moving, and on
## the target runs its ragdoll. The ragdoll is the PhysicalBoneSimulator3D named Ragdoll
## under the skeleton; target.tscn adds it, the shooter has none.

const SHADER := preload("res://plush.gdshader")
const ALBEDO := preload("res://plush/godot_plush_albedo.png")
const NORMAL := preload("res://plush/godot_plush_normal.png")

## The base pose: this second of the idle animation, held.
@export var hold_at := 0.0
## Extra bone rotations in degrees (X, Y, Z), keyed by bone name, applied to the held pose.
@export var bone_turns: Dictionary[StringName, Vector3] = {}
## What the plush does on top of the held pose.
@export var motion_mode := PlushMotion.Mode.STANCE
## Colour wheel turn for the body (0 keeps the Godot blue).
@export var hue_shift := 0.0
@export var saturation := 1.0

@onready var mesh: MeshInstance3D = $Model/Rig/Skeleton3D/GodotPlushMesh
@onready var skeleton: Skeleton3D = $Model/Rig/Skeleton3D
@onready var player: AnimationPlayer = $Model/AnimationPlayer
@onready var ragdoll: PhysicalBoneSimulator3D = skeleton.get_node_or_null(^"Ragdoll")

## The tinted plush material. Swap mesh.material_override away and back for a hit flash.
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
	skeleton.add_child(motion)
	stand()


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
	for bone: StringName in bone_turns:
		var i := skeleton.find_bone(bone)
		var turn := Quaternion.from_euler(bone_turns[bone] * PI / 180.0)
		skeleton.set_bone_pose_rotation(i, skeleton.get_bone_pose_rotation(i) * turn)
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
