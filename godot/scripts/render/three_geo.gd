class_name ThreeGeo
extends RefCounted
## three.js r160의 기본 도형(Sphere, Capsule, Cylinder/Cone, Torus, Tube, Box, Plane, Ring, Circle)을
## 같은 공식으로 만든다. 정점·법선·UV가 같아야 웹과 같은 텍스처 배치·음영이 나온다.
## 내부는 three 규칙(반시계 앞면, UV 원점 왼쪽 아래)으로 만들고 mesh()에서 Godot 규칙으로 바꾼다.

var positions := PackedVector3Array()
var normals := PackedVector3Array()
var uvs := PackedVector2Array()
var indices := PackedInt32Array()
var _mesh: ArrayMesh


## ArrayMesh는 한 번만 만들어 공유한다 (같은 도형을 여러 고양이가 재사용)
func mesh() -> ArrayMesh:
	if _mesh == null:
		_mesh = _build_mesh()
	return _mesh


func _build_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	var n := PackedVector3Array()
	for v in normals:
		n.append(v.normalized() if v.length_squared() > 0 else Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = n
	var flipped := PackedVector2Array()
	for uv in uvs:
		flipped.append(Vector2(uv.x, 1.0 - uv.y))   # three: v=1이 이미지 윗줄 → Godot: v=0이 윗줄
	arrays[Mesh.ARRAY_TEX_UV] = flipped
	var idx := PackedInt32Array()
	for i in range(0, indices.size(), 3):            # Godot은 시계 방향이 앞면
		idx.append(indices[i])
		idx.append(indices[i + 2])
		idx.append(indices[i + 1])
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m


func rotate_x(angle: float) -> ThreeGeo:
	var b := Basis(Vector3.RIGHT, angle)
	for i in positions.size():
		positions[i] = b * positions[i]
		normals[i] = b * normals[i]
	return self


func translate(offset: Vector3) -> ThreeGeo:
	for i in positions.size():
		positions[i] += offset
	return self


# ───────── Sphere ─────────
static func sphere(radius := 1.0, w_seg := 32, h_seg := 16, phi_start := 0.0, phi_len := TAU, theta_start := 0.0, theta_len := PI) -> ThreeGeo:
	var g := ThreeGeo.new()
	w_seg = maxi(3, w_seg)
	h_seg = maxi(2, h_seg)
	var theta_end := minf(theta_start + theta_len, PI)
	var grid := []
	var index := 0
	for iy in h_seg + 1:
		var row := []
		var v := float(iy) / h_seg
		var u_off := 0.0
		if iy == 0 and theta_start == 0:
			u_off = 0.5 / w_seg
		elif iy == h_seg and theta_end == PI:
			u_off = -0.5 / w_seg
		for ix in w_seg + 1:
			var u := float(ix) / w_seg
			var p := Vector3(
				-radius * cos(phi_start + u * phi_len) * sin(theta_start + v * theta_len),
				radius * cos(theta_start + v * theta_len),
				radius * sin(phi_start + u * phi_len) * sin(theta_start + v * theta_len))
			g.positions.append(p)
			g.normals.append(p.normalized() if p.length_squared() > 0 else Vector3.UP)
			g.uvs.append(Vector2(u + u_off, 1.0 - v))
			row.append(index)
			index += 1
		grid.append(row)
	for iy in h_seg:
		for ix in w_seg:
			var a: int = grid[iy][ix + 1]
			var b: int = grid[iy][ix]
			var c: int = grid[iy + 1][ix]
			var d: int = grid[iy + 1][ix + 1]
			if iy != 0 or theta_start > 0:
				g.indices.append_array([a, b, d])
			if iy != h_seg - 1 or theta_end < PI:
				g.indices.append_array([b, c, d])
	return g


# ───────── Lathe / Capsule ─────────
static func lathe(points: Array, segments := 12, phi_start := 0.0, phi_len := TAU) -> ThreeGeo:
	var g := ThreeGeo.new()
	segments = int(floor(segments))
	var inv := 1.0 / segments
	var init_normals := []
	var prev := Vector3.ZERO
	var count := points.size()
	for j in count:
		if j == 0:
			var dx: float = points[j + 1].x - points[j].x
			var dy: float = points[j + 1].y - points[j].y
			var n := Vector3(dy, -dx, 0)
			prev = n
			init_normals.append(n.normalized())
		elif j == count - 1:
			init_normals.append(prev)
		else:
			var dx2: float = points[j + 1].x - points[j].x
			var dy2: float = points[j + 1].y - points[j].y
			var cur := Vector3(dy2, -dx2, 0)
			init_normals.append((cur + prev).normalized())
			prev = cur
	for i in segments + 1:
		var phi := phi_start + i * inv * phi_len
		var s := sin(phi)
		var c := cos(phi)
		for j in count:
			g.positions.append(Vector3(points[j].x * s, points[j].y, points[j].x * c))
			g.uvs.append(Vector2(float(i) / segments, float(j) / (count - 1)))
			g.normals.append(Vector3(init_normals[j].x * s, init_normals[j].y, init_normals[j].x * c))
	for i in segments:
		for j in count - 1:
			var base := j + i * count
			var a := base
			var b := base + count
			var c2 := base + count + 1
			var d := base + 1
			g.indices.append_array([a, b, d, c2, d, b])
	return g


## three Path.absarc 두 개 + Path.getPoints(capSegments): 원호는 divisions*2개 구간
static func capsule(radius := 1.0, length := 1.0, cap_segments := 4, radial_segments := 8) -> ThreeGeo:
	var pts := []
	var arc := func(cy: float, a0: float, a1: float):
		var res := cap_segments * 2
		for k in res + 1:
			var t := float(k) / res
			var ang := a0 + (a1 - a0) * t
			var p := Vector2(radius * cos(ang), cy + radius * sin(ang))
			if pts.is_empty() or not pts[-1].is_equal_approx(p):
				pts.append(p)
	arc.call(-length / 2.0, PI * 1.5, TAU)   # three ArcCurve: 1.5π → 0 (시계 반대, aEnd=0 → 2π로 정규화)
	pts.append(Vector2(radius, length / 2.0)) # 두 원호 사이 직선(lineTo)
	arc.call(length / 2.0, 0.0, PI * 0.5)
	return lathe(pts, radial_segments)


# ───────── Cylinder / Cone ─────────
static func cylinder(r_top := 1.0, r_bottom := 1.0, height := 1.0, radial := 32, height_seg := 1, open_ended := false, theta_start := 0.0, theta_len := TAU) -> ThreeGeo:
	var g := ThreeGeo.new()
	var half := height / 2.0
	var index_array := []
	var index := 0
	var slope := (r_bottom - r_top) / height
	for y in height_seg + 1:
		var row := []
		var v := float(y) / height_seg
		var radius := v * (r_bottom - r_top) + r_top
		for x in radial + 1:
			var u := float(x) / radial
			var theta := u * theta_len + theta_start
			var st := sin(theta)
			var ct := cos(theta)
			g.positions.append(Vector3(radius * st, -v * height + half, radius * ct))
			g.normals.append(Vector3(st, slope, ct).normalized())
			g.uvs.append(Vector2(u, 1.0 - v))
			row.append(index)
			index += 1
		index_array.append(row)
	for x in radial:
		for y in height_seg:
			var a: int = index_array[y][x]
			var b: int = index_array[y + 1][x]
			var c: int = index_array[y + 1][x + 1]
			var d: int = index_array[y][x + 1]
			if r_top > 0 or y != 0:
				g.indices.append_array([a, b, d])
			if r_bottom > 0 or y != height_seg - 1:
				g.indices.append_array([b, c, d])
	if not open_ended:
		for top in [true, false]:
			var radius2: float = r_top if top else r_bottom
			if radius2 <= 0:
				continue
			var sign := 1.0 if top else -1.0
			var center_start := g.positions.size()
			for x in range(1, radial + 1):
				g.positions.append(Vector3(0, half * sign, 0))
				g.normals.append(Vector3(0, sign, 0))
				g.uvs.append(Vector2(0.5, 0.5))
			var center_end := g.positions.size()
			for x in radial + 1:
				var u2 := float(x) / radial
				var theta2 := u2 * theta_len + theta_start
				var c2 := cos(theta2)
				var s2 := sin(theta2)
				g.positions.append(Vector3(radius2 * s2, half * sign, radius2 * c2))
				g.normals.append(Vector3(0, sign, 0))
				g.uvs.append(Vector2(c2 * 0.5 + 0.5, s2 * 0.5 * sign + 0.5))
			for x in radial:
				var cc := center_start + x
				var ii := center_end + x
				if top:
					g.indices.append_array([ii, ii + 1, cc])
				else:
					g.indices.append_array([ii + 1, ii, cc])
	return g


static func cone(radius := 1.0, height := 1.0, radial := 32, height_seg := 1, open_ended := false, theta_start := 0.0, theta_len := TAU) -> ThreeGeo:
	return cylinder(0, radius, height, radial, height_seg, open_ended, theta_start, theta_len)


# ───────── Torus ─────────
static func torus(radius := 1.0, tube := 0.4, radial := 12, tubular := 48, arc := TAU) -> ThreeGeo:
	var g := ThreeGeo.new()
	for j in radial + 1:
		for i in tubular + 1:
			var u := float(i) / tubular * arc
			var v := float(j) / radial * TAU
			var p := Vector3((radius + tube * cos(v)) * cos(u), (radius + tube * cos(v)) * sin(u), tube * sin(v))
			g.positions.append(p)
			g.normals.append((p - Vector3(radius * cos(u), radius * sin(u), 0)).normalized())
			g.uvs.append(Vector2(float(i) / tubular, float(j) / radial))
	for j in range(1, radial + 1):
		for i in range(1, tubular + 1):
			var a := (tubular + 1) * j + i - 1
			var b := (tubular + 1) * (j - 1) + i - 1
			var c := (tubular + 1) * (j - 1) + i
			var d := (tubular + 1) * j + i
			g.indices.append_array([a, b, d, b, c, d])
	return g


# ───────── Box ─────────
static func box(w := 1.0, h := 1.0, d := 1.0) -> ThreeGeo:
	var g := ThreeGeo.new()
	var plane := func(u: int, v: int, wi: int, udir: float, vdir: float, width: float, height: float, depth: float):
		var start := g.positions.size()
		for iy in 2:
			var y := iy * height - height / 2.0
			for ix in 2:
				var x := ix * width - width / 2.0
				var p := [0.0, 0.0, 0.0]
				p[u] = x * udir
				p[v] = y * vdir
				p[wi] = depth / 2.0
				g.positions.append(Vector3(p[0], p[1], p[2]))
				var n := [0.0, 0.0, 0.0]
				n[wi] = 1.0 if depth > 0 else -1.0
				g.normals.append(Vector3(n[0], n[1], n[2]))
				g.uvs.append(Vector2(ix, 1 - iy))
		var a := start
		var b := start + 2
		var c := start + 3
		var e := start + 1
		g.indices.append_array([a, b, e, b, c, e])
	plane.call(2, 1, 0, -1, -1, d, h, w)   # px
	plane.call(2, 1, 0, 1, -1, d, h, -w)   # nx
	plane.call(0, 2, 1, 1, 1, w, d, h)     # py
	plane.call(0, 2, 1, 1, -1, w, d, -h)   # ny
	plane.call(0, 1, 2, 1, -1, w, h, d)    # pz
	plane.call(0, 1, 2, -1, -1, w, h, -d)  # nz
	return g


# ───────── Plane / Ring / Circle (XY 평면, +Z 법선) ─────────
static func plane(w := 1.0, h := 1.0) -> ThreeGeo:
	var g := ThreeGeo.new()
	for iy in 2:
		for ix in 2:
			g.positions.append(Vector3(ix * w - w / 2.0, -(iy * h - h / 2.0), 0))
			g.normals.append(Vector3(0, 0, 1))
			g.uvs.append(Vector2(ix, 1 - iy))
	g.indices.append_array([0, 2, 1, 2, 3, 1])
	return g


static func ring(inner := 0.5, outer := 1.0, theta_seg := 32, phi_seg := 1) -> ThreeGeo:
	var g := ThreeGeo.new()
	var radius := inner
	var step := (outer - inner) / phi_seg
	for j in phi_seg + 1:
		for i in theta_seg + 1:
			var seg := float(i) / theta_seg * TAU
			var p := Vector3(radius * cos(seg), radius * sin(seg), 0)
			g.positions.append(p)
			g.normals.append(Vector3(0, 0, 1))
			g.uvs.append(Vector2((p.x / outer + 1) / 2.0, (p.y / outer + 1) / 2.0))
		radius += step
	for j in phi_seg:
		var off := j * (theta_seg + 1)
		for i in theta_seg:
			var a := i + off
			var b := a + theta_seg + 1
			var c := a + theta_seg + 2
			var d := a + 1
			g.indices.append_array([a, b, d, b, c, d])
	return g


static func circle(radius := 1.0, segments := 32) -> ThreeGeo:
	var g := ThreeGeo.new()
	g.positions.append(Vector3.ZERO)
	g.normals.append(Vector3(0, 0, 1))
	g.uvs.append(Vector2(0.5, 0.5))
	for s in segments + 1:
		var seg := float(s) / segments * TAU
		g.positions.append(Vector3(radius * cos(seg), radius * sin(seg), 0))
		g.normals.append(Vector3(0, 0, 1))
		g.uvs.append(Vector2((cos(seg) + 1) / 2.0, (sin(seg) + 1) / 2.0))
	for i in range(1, segments + 1):
		g.indices.append_array([i, i + 1, 0])
	return g


# ───────── CatmullRom(centripetal) + Tube ─────────
class CatmullRom:
	var pts: Array
	var lengths := []

	func _init(points: Array) -> void:
		pts = points

	static func _poly(x0: float, x1: float, x2: float, x3: float, dt0: float, dt1: float, dt2: float) -> Array:
		var t1 := (x1 - x0) / dt0 - (x2 - x0) / (dt0 + dt1) + (x2 - x1) / dt1
		var t2 := (x2 - x1) / dt1 - (x3 - x1) / (dt1 + dt2) + (x3 - x2) / dt2
		t1 *= dt1
		t2 *= dt1
		return [x1, t1, -3 * x1 + 3 * x2 - 2 * t1 - t2, 2 * x1 - 2 * x2 + t1 + t2]

	func get_point(t: float) -> Vector3:
		var l := pts.size()
		var p := (l - 1) * t
		var int_point := int(floor(p))
		var weight := p - int_point
		if weight == 0 and int_point == l - 1:
			int_point = l - 2
			weight = 1
		var p0: Vector3
		var p3: Vector3
		if int_point > 0:
			p0 = pts[(int_point - 1) % l]
		else:
			p0 = (pts[0] - pts[1]) + pts[0]
		var p1: Vector3 = pts[int_point % l]
		var p2: Vector3 = pts[(int_point + 1) % l]
		if int_point + 2 < l:
			p3 = pts[(int_point + 2) % l]
		else:
			p3 = (pts[l - 1] - pts[l - 2]) + pts[l - 1]
		var dt0 := pow(p0.distance_squared_to(p1), 0.25)
		var dt1 := pow(p1.distance_squared_to(p2), 0.25)
		var dt2 := pow(p2.distance_squared_to(p3), 0.25)
		if dt1 < 1e-4:
			dt1 = 1.0
		if dt0 < 1e-4:
			dt0 = dt1
		if dt2 < 1e-4:
			dt2 = dt1
		var out := Vector3.ZERO
		for axis in 3:
			var c := _poly(p0[axis], p1[axis], p2[axis], p3[axis], dt0, dt1, dt2)
			out[axis] = c[0] + c[1] * weight + c[2] * weight * weight + c[3] * weight * weight * weight
		return out

	func _lengths() -> Array:
		if lengths.is_empty():
			var divisions := 200
			var last := get_point(0)
			var total := 0.0
			lengths.append(0.0)
			for p in range(1, divisions + 1):
				var cur := get_point(float(p) / divisions)
				total += cur.distance_to(last)
				lengths.append(total)
				last = cur
		return lengths

	func u_to_t(u: float) -> float:
		var arc := _lengths()
		var il := arc.size()
		var target: float = u * arc[il - 1]
		var low := 0
		var high := il - 1
		var i := 0
		while low <= high:
			i = int(floor(low + (high - low) / 2.0))
			var comparison: float = arc[i] - target
			if comparison < 0:
				low = i + 1
			elif comparison > 0:
				high = i - 1
			else:
				high = i
				break
		i = high
		if arc[i] == target:
			return float(i) / (il - 1)
		var before: float = arc[i]
		var after: float = arc[i + 1]
		return (i + (target - before) / (after - before)) / (il - 1)

	func get_point_at(u: float) -> Vector3:
		return get_point(u_to_t(u))

	func get_tangent(t: float) -> Vector3:
		var delta := 0.0001
		var t1 := maxf(0.0, t - delta)
		var t2 := minf(1.0, t + delta)
		return (get_point(t2) - get_point(t1)).normalized()

	func get_tangent_at(u: float) -> Vector3:
		return get_tangent(u_to_t(u))


static func tube(curve: CatmullRom, tubular := 64, radius := 1.0, radial := 8) -> ThreeGeo:
	var g := ThreeGeo.new()
	# Frenet frames (three Curve.computeFrenetFrames, closed=false)
	var tangents := []
	var nrm := []
	var binormals := []
	for i in tubular + 1:
		tangents.append(curve.get_tangent_at(float(i) / tubular))
	var t0: Vector3 = tangents[0]
	var mn := INF
	var normal := Vector3.ZERO
	var tx := absf(t0.x)
	var ty := absf(t0.y)
	var tz := absf(t0.z)
	if tx <= mn:
		mn = tx
		normal = Vector3(1, 0, 0)
	if ty <= mn:
		mn = ty
		normal = Vector3(0, 1, 0)
	if tz <= mn:
		normal = Vector3(0, 0, 1)
	var vec := t0.cross(normal).normalized()
	nrm.append(t0.cross(vec))
	binormals.append(t0.cross(nrm[0]))
	for i in range(1, tubular + 1):
		var n: Vector3 = nrm[i - 1]
		var axis: Vector3 = tangents[i - 1].cross(tangents[i])
		if axis.length() > 1e-6:
			axis = axis.normalized()
			var theta := acos(clampf(tangents[i - 1].dot(tangents[i]), -1, 1))
			n = n.rotated(axis, theta)
		nrm.append(n)
		binormals.append(tangents[i].cross(n))
	for i in tubular + 1:
		var P := curve.get_point_at(float(i) / tubular)
		var N: Vector3 = nrm[i]
		var B: Vector3 = binormals[i]
		for j in radial + 1:
			var v := float(j) / radial * TAU
			var s := sin(v)
			var c := -cos(v)
			var nn := (N * c + B * s).normalized()
			g.normals.append(nn)
			g.positions.append(P + nn * radius)
	for i in tubular + 1:
		for j in radial + 1:
			g.uvs.append(Vector2(float(i) / tubular, float(j) / radial))
	for j in range(1, tubular + 1):
		for i in range(1, radial + 1):
			var a := (radial + 1) * (j - 1) + (i - 1)
			var b := (radial + 1) * j + (i - 1)
			var c2 := (radial + 1) * j + i
			var d := (radial + 1) * (j - 1) + i
			g.indices.append_array([a, b, d, b, c2, d])
	return g
