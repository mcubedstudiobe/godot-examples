class_name Soft
extends RefCounted
## Smooth, soft-edged meshes built in code: a rounded box, a pillow and a draped sheet. Every
## vertex carries its true surface normal, so the light slides over them with no flat facets.


## A box with rounded edges and corners (all six faces share one rounding radius).
static func rounded_box(size: Vector3, radius: float, steps := 7) -> ArrayMesh:
	var half := size * 0.5
	radius = minf(radius, minf(half.x, minf(half.y, half.z)) * 0.999)
	var inner := half - Vector3.ONE * radius
	# Sample positions along one axis: the round part gets `steps` samples at each end.
	var axes: Array[PackedFloat32Array] = []
	for a in 3:
		var samples := PackedFloat32Array()
		for i in steps:
			samples.append(-half[a] + radius * float(i) / steps)
		samples.append(-inner[a])
		samples.append(inner[a])
		for i in range(1, steps + 1):
			samples.append(inner[a] + radius * float(i) / steps)
		axes.append(samples)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for face in 6:
		var axis := face / 2
		var sign_ := 1.0 if face % 2 == 0 else -1.0
		var u_axis := (axis + 1) % 3
		var v_axis := (axis + 2) % 3
		var us := axes[u_axis]
		var vs := axes[v_axis]
		var first := vertices.size()
		for v in vs:
			for u in us:
				var c := Vector3.ZERO
				c[axis] = sign_ * half[axis]
				c[u_axis] = u
				c[v_axis] = v
				var core := c.clamp(-inner, inner)
				var n := (c - core).normalized()
				vertices.append(core + n * radius)
				normals.append(n)
		var w := us.size()
		for j in vs.size() - 1:
			for i in w - 1:
				var a := first + j * w + i
				var b := a + 1
				var c2 := a + w
				var d := c2 + 1
				# Wind each triangle so it faces the way its vertex normals point.
				for tri in [[a, b, c2], [b, d, c2]]:
					var cross := (vertices[tri[1]] - vertices[tri[0]]).cross(vertices[tri[2]] - vertices[tri[0]])
					if cross.dot(normals[tri[0]]) <= 0.0:
						indices.append_array(tri)
					else:
						indices.append_array([tri[0], tri[2], tri[1]])
	return _mesh(vertices, normals, indices)


## A cushion: a superellipsoid, soft and square in plan with a rounded, full profile.
## `size` is width, thickness and depth; `square` and `full` (below 1 is squarer) shape it.
static func pillow(size: Vector3, square := 0.5, full := 0.7, rings := 40, around := 72) -> ArrayMesh:
	var half := size * 0.5
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for r in rings + 1:
		var v := -PI * 0.5 + PI * float(r) / rings
		for k in around + 1:
			var u := TAU * float(k) / around
			var cv := cos(v)
			var su := sin(u)
			var cu := cos(u)
			vertices.append(Vector3(
				half.x * _pow(cv, full) * _pow(cu, square),
				half.y * _pow(sin(v), full),
				half.z * _pow(cv, full) * _pow(su, square)))
			var n := Vector3(
				_pow(cv, 2.0 - full) * _pow(cu, 2.0 - square) / half.x,
				_pow(sin(v), 2.0 - full) / half.y,
				_pow(cv, 2.0 - full) * _pow(su, 2.0 - square) / half.z)
			normals.append(n.normalized() if n.length() > 0.0001 else Vector3.UP * signf(v))
	var w := around + 1
	for r in rings:
		for k in around:
			var a := r * w + k
			indices.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	return _mesh(vertices, normals, indices)


## A sheet draped by `shape`, which maps (u, v) in 0..1 to a point. Normals come from the
## shape's own slope, so folds shade smoothly.
static func sheet(shape: Callable, nu := 90, nv := 60) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var e := 0.002
	for j in nv + 1:
		for i in nu + 1:
			var u := float(i) / nu
			var v := float(j) / nv
			var p: Vector3 = shape.call(u, v)
			var du: Vector3 = shape.call(minf(u + e, 1.0), v) - shape.call(maxf(u - e, 0.0), v)
			var dv: Vector3 = shape.call(u, minf(v + e, 1.0)) - shape.call(u, maxf(v - e, 0.0))
			vertices.append(p)
			normals.append(dv.cross(du).normalized())
			uvs.append(Vector2(u, v))
	for j in nv:
		for i in nu:
			var a := j * (nu + 1) + i
			indices.append_array([a, a + 1, a + nu + 1, a + 1, a + nu + 2, a + nu + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static func _pow(x: float, e: float) -> float:
	return signf(x) * pow(absf(x), e)


static func _mesh(vertices: PackedVector3Array, normals: PackedVector3Array,
		indices: PackedInt32Array) -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
