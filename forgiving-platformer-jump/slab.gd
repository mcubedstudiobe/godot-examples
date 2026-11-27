class_name Slab
extends RefCounted
## Builds a rounded slab: a rounded rectangle in plan (a disc when the corner radius is half the
## width), a flat top and bottom, and a softly rounded edge all the way round, with smooth normals.
## Toast, waffles, pancakes and marshmallows are all slabs; their shaders add the surface.

const CORNER_SEGMENTS := 10
const EDGE_STEPS := 6


## The outline of the rounded rectangle, anticlockwise from above, with outward normals.
static func outline(width: float, depth: float, radius: float) -> Array[Vector4]:
	var points: Array[Vector4] = [] # x, z, normal x, normal z
	var hx := width * 0.5 - radius
	var hz := depth * 0.5 - radius
	var centres := [Vector2(hx, hz), Vector2(-hx, hz), Vector2(-hx, -hz), Vector2(hx, -hz)]
	for corner in 4:
		for s in CORNER_SEGMENTS + 1:
			var a := (corner + float(s) / CORNER_SEGMENTS) * PI * 0.5
			var n := Vector2(cos(a), sin(a))
			var c: Vector2 = centres[corner]
			points.append(Vector4(c.x + n.x * radius, c.y + n.y * radius, n.x, n.y))
	return points


## width along x, depth along z, height along y (the slab is centred on the origin).
static func make(width: float, depth: float, height: float, radius: float, bevel: float) -> ArrayMesh:
	radius = minf(radius, minf(width, depth) * 0.5)
	bevel = minf(bevel, minf(radius, height * 0.5))
	var ring := outline(width, depth, radius)
	var half := height * 0.5
	# The profile from the middle of the top, over the rounded edge, down the side and under.
	# Each entry is inset, y, outward normal share, upward normal share.
	var profile: Array[Vector4] = []
	for i in EDGE_STEPS + 1:
		var t := float(i) / EDGE_STEPS * PI * 0.5
		profile.append(Vector4(bevel - bevel * sin(t), half - bevel + bevel * cos(t), sin(t), cos(t)))
	for i in EDGE_STEPS + 1:
		var t := float(i) / EDGE_STEPS * PI * 0.5
		profile.append(Vector4(bevel * (1.0 - cos(t)), -half + bevel - bevel * sin(t), cos(t), -sin(t)))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var n_ring := ring.size()
	for p in profile:
		for o in ring:
			var inward := Vector2(o.z, o.w) * p.x
			vertices.append(Vector3(o.x - inward.x, p.y, o.y - inward.y))
			normals.append(Vector3(o.z * p.z, p.w, o.w * p.z).normalized())
	for k in profile.size() - 1:
		for i in n_ring:
			var a := k * n_ring + i
			var b := k * n_ring + (i + 1) % n_ring
			var c := (k + 1) * n_ring + i
			var d := (k + 1) * n_ring + (i + 1) % n_ring
			indices.append_array([a, c, b, b, c, d])
	# The two flat faces, as fans from their centres.
	for face in 2:
		var first := 0 if face == 0 else (profile.size() - 1) * n_ring
		var centre := vertices.size()
		vertices.append(Vector3(0.0, half if face == 0 else -half, 0.0))
		normals.append(Vector3.UP if face == 0 else Vector3.DOWN)
		for i in n_ring:
			var a := first + i
			var b := first + (i + 1) % n_ring
			if face == 0:
				indices.append_array([centre, a, b])
			else:
				indices.append_array([centre, b, a])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
