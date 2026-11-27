class_name Course
extends RefCounted
## The four ledges. Each is one set piece, laid out the same way: platforms along x, each
## [x_from, x_to] with its top at y = 0 or [x_from, x_to, top_y], and the x the runner starts at.
## Every ledge needs exactly one of the four cheats. The lake is below, where a miss ends.

const PLATFORM_DEPTH := 2.4
const PLATFORM_THICKNESS := 0.42
const LAKE_Y := -1.7

const LEDGES := [
	{
		# Walk off the edge, press jump a moment late.
		"name": "Coyote ledge",
		"start": -3.0,
		"platforms": [[-3.8, -1.5], [1.0, 3.8]],
		"kinds": ["toast", "waffle"],
	},
	{
		# Drop onto a short platform and jump again straight away.
		"name": "Buffer ledge",
		"start": -3.0,
		"platforms": [[-3.8, -2.2, 1.2], [-1.2, 0.4], [1.9, 3.8]],
		"kinds": ["waffle", "toast", "waffle"],
	},
	{
		# A tap hops onto the island; a full jump sails over it.
		"name": "Hop ledge",
		"start": -3.0,
		"platforms": [[-3.8, -1.5], [0.2, 1.3], [2.35, 3.8]],
		"kinds": ["toast", "marshmallow", "toast"],
	},
	{
		# Down onto a stone and straight on: a floaty landing comes too late for the next press.
		"name": "Fall ledge",
		"start": -3.0,
		"platforms": [[-3.8, -1.5], [1.3, 2.4, -0.9], [2.9, 3.8, -0.9]],
		"kinds": ["waffle", "pancake", "pancake"],
	},
]

## The scripted run of each ledge, as [tick, event]: "right" and "stop" start and stop running,
## "press" and "release" are the jump button. The same list drives the player and, through the
## input frames, the ghost.
const RUNS := [
	[[0, "right"], [29, "press"], [75, "release"], [76, "stop"]],
	[[0, "right"], [30, "press"], [85, "release"], [84, "stop"]],
	[[0, "right"], [24, "press"], [28, "release"], [56, "press"], [60, "release"], [88, "stop"]],
	[[0, "right"], [24, "press"], [58, "release"], [68, "press"], [70, "release"], [88, "stop"]],
]


## Where the runner starts: standing on the platform that holds the ledge's start x.
static func start_of(ledge: Dictionary) -> Vector3:
	var x: float = ledge["start"]
	for p: Array in ledge["platforms"]:
		if x >= p[0] and x <= p[1]:
			return Vector3(x, p[2] if p.size() > 2 else 0.0, 0.0)
	return Vector3(x, 0.0, 0.0)


## Static colliders for the platforms of a ledge, in the lane at depth z.
static func build_colliders(ledge: Dictionary, z: float, parent: Node3D) -> Array[StaticBody3D]:
	var bodies: Array[StaticBody3D] = []
	for p: Array in ledge["platforms"]:
		var top: float = p[2] if p.size() > 2 else 0.0
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(p[1] - p[0], PLATFORM_THICKNESS, PLATFORM_DEPTH)
		shape.shape = box
		body.add_child(shape)
		parent.add_child(body)
		body.position = Vector3((p[0] + p[1]) * 0.5, top - PLATFORM_THICKNESS * 0.5, z)
		bodies.append(body)
	return bodies
