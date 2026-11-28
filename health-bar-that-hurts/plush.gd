class_name Plush
extends Node3D
## One Godot Plush Character (Tibo, MIT): tints it and keeps it moving. What it does on top of
## its idle pose is plush_motion.gd.

const SHADER := preload("res://plush.gdshader")
const ALBEDO := preload("res://plush/godot_plush_albedo.png")
const NORMAL := preload("res://plush/godot_plush_normal.png")

## How much bigger than the model it is drawn: the plush is the star of the yard.
const SCALE := 1.3

## Colour wheel turn for the body (0 keeps the Godot blue).
@export var hue_shift := 0.0
@export var saturation := 1.0

@onready var mesh: MeshInstance3D = $Model/Rig/Skeleton3D/GodotPlushMesh
@onready var skeleton: Skeleton3D = $Model/Rig/Skeleton3D
@onready var player: AnimationPlayer = $Model/AnimationPlayer

## The tinted plush material. Its dead parameter draws X's for eyes.
var tint := ShaderMaterial.new()
var motion := PlushMotion.new()
## Follows the head bone as it is posed, so the head's place in the world is always current.
var head_bone := BoneAttachment3D.new()


func _ready() -> void:
	$Model.scale = Vector3.ONE * SCALE
	tint.shader = SHADER
	tint.set_shader_parameter(&"albedo_texture", ALBEDO)
	tint.set_shader_parameter(&"normal_texture", NORMAL)
	tint.set_shader_parameter(&"hue_shift", hue_shift)
	tint.set_shader_parameter(&"saturation", saturation)
	mesh.material_override = tint
	motion.material = tint
	motion.tilts = {&"l": sample_pose(&"tilt_l"), &"r": sample_pose(&"tilt_r")}
	skeleton.add_child(motion)
	head_bone.bone_name = &"DEF-head"
	skeleton.add_child(head_bone)
	player.play(&"idle")
	player.seek(0.0, true)
	player.pause()


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


## Where the middle of the head is, in the world.
func head_point() -> Vector3:
	return head_bone.to_global(Vector3(0.0, 0.36, 0.0))


func set_dead(dead: bool) -> void:
	tint.set_shader_parameter(&"dead", 1.0 if dead else 0.0)


## Keep the plush moving while the game is paused (breathing, blinking, reacting).
func keep_alive(on: bool) -> void:
	skeleton.process_mode = Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
