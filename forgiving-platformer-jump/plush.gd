class_name Plush
extends Node3D
## One Godot Plush Character (Tibo, MIT). Its own clips are blended in an AnimationTree: idle
## and run by speed, up and fall by vertical speed, and the air against the ground by whether the
## feet are down. PlushMotion adds breathing, blinking and a few procedural poses on top.

const SHADER := preload("res://plush.gdshader")
const GHOST_SHADER := preload("res://plush_ghost.gdshader")
const GHOST_DEPTH := preload("res://ghost_depth.gdshader")
const ALBEDO := preload("res://plush/godot_plush_albedo.png")
const NORMAL := preload("res://plush/godot_plush_normal.png")
const RUN_SPEED := 4.5
const AIR_BLEND_RATE := 16.0

## The ghost is pale and see-through.
@export var ghost := false
## Colour wheel turn for the body (0 keeps the Godot blue).
@export var hue_shift := 0.0
@export var saturation := 1.0
@export var brightness := 1.0

@onready var skeleton: Skeleton3D = $Model/Rig/Skeleton3D
@onready var mesh: MeshInstance3D = $Model/Rig/Skeleton3D/GodotPlushMesh
@onready var player: AnimationPlayer = $Model/AnimationPlayer

## The material that holds the colours and the eyes.
var tint := ShaderMaterial.new()
var motion := PlushMotion.new()
var tree := AnimationTree.new()
var run_blend := 0.0
var air_blend := 0.0
var fall_blend := 0.0
var last_jumps := 0


func _ready() -> void:
	tint.shader = GHOST_SHADER if ghost else SHADER
	tint.set_shader_parameter(&"albedo_texture", ALBEDO)
	tint.set_shader_parameter(&"normal_texture", NORMAL)
	tint.set_shader_parameter(&"hue_shift", hue_shift)
	tint.set_shader_parameter(&"saturation", saturation)
	tint.set_shader_parameter(&"brightness", brightness)
	if ghost:
		var depth := ShaderMaterial.new()
		depth.shader = GHOST_DEPTH
		depth.next_pass = tint
		mesh.material_override = depth
	else:
		mesh.material_override = tint
	motion.material = tint
	skeleton.add_child(motion)
	_build_tree()


## Blend the plush's clips: idle to run by speed, up to fall by vertical speed, ground to air.
func _build_tree() -> void:
	for clip: StringName in [&"idle", &"run", &"fall"]:
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.get_animation(&"up").loop_mode = Animation.LOOP_NONE
	var root := AnimationNodeBlendTree.new()
	for clip: StringName in [&"idle", &"run", &"up", &"fall"]:
		var node := AnimationNodeAnimation.new()
		node.animation = clip
		root.add_node(clip, node)
	root.add_node(&"up_seek", AnimationNodeTimeSeek.new())
	root.add_node(&"ground", AnimationNodeBlend2.new())
	root.add_node(&"air", AnimationNodeBlend2.new())
	root.add_node(&"main", AnimationNodeBlend2.new())
	root.connect_node(&"ground", 0, &"idle")
	root.connect_node(&"ground", 1, &"run")
	root.connect_node(&"up_seek", 0, &"up")
	root.connect_node(&"air", 0, &"up_seek")
	root.connect_node(&"air", 1, &"fall")
	root.connect_node(&"main", 0, &"ground")
	root.connect_node(&"main", 1, &"air")
	root.connect_node(&"output", 0, &"main")
	tree.tree_root = root
	$Model.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.active = true


## Feed the tree from the body's motion; called once per physics tick.
func drive(on_floor: bool, speed: float, vy: float, jumps: int, delta: float) -> void:
	run_blend = move_toward(run_blend, clampf(absf(speed) / RUN_SPEED, 0.0, 1.0), delta * 14.0)
	air_blend = move_toward(air_blend, 0.0 if on_floor else 1.0, delta * AIR_BLEND_RATE)
	fall_blend = move_toward(fall_blend, clampf(0.5 - vy / 5.0, 0.0, 1.0), delta * 10.0)
	tree.set(&"parameters/ground/blend_amount", run_blend)
	tree.set(&"parameters/air/blend_amount", fall_blend)
	tree.set(&"parameters/main/blend_amount", air_blend)
	if jumps != last_jumps:
		last_jumps = jumps
		tree.set(&"parameters/up_seek/seek_request", 0.0)


## Keep the plush moving while the game is paused (breathing, blinking, the clips).
func keep_alive(on: bool) -> void:
	var mode := Node.PROCESS_MODE_ALWAYS if on else Node.PROCESS_MODE_INHERIT
	skeleton.process_mode = mode
	tree.process_mode = mode


func set_pose(pose: PlushMotion.Pose) -> void:
	motion.pose = pose


func set_dead(dead: bool) -> void:
	tint.set_shader_parameter(&"dead", 1.0 if dead else 0.0)
