class_name Navigation
extends RefCounted
## 웹 navigation.js: 건물·울타리를 피하는 격자 A* + 연속 선분 검사.
## 점은 Vector2(x, z), 장애물은 [x0, x1, z0, z1], bounds는 {minX,maxX,minZ,maxZ}.


static func segment_clear(a: Vector2, b: Vector2, obstacles: Array, radius := 0.42) -> bool:
	for o in obstacles:
		var low := 0.0
		var high := 1.0
		var separated := false
		for axis in 2:
			var origin: float = a.x if axis == 0 else a.y
			var delta: float = (b.x - a.x) if axis == 0 else (b.y - a.y)
			var mn: float = (o[0] if axis == 0 else o[2]) - radius
			var mx: float = (o[1] if axis == 0 else o[3]) + radius
			if absf(delta) < 1e-9:
				if origin < mn or origin > mx:
					separated = true
					break
			else:
				var u := (mn - origin) / delta
				var v := (mx - origin) / delta
				if u > v:
					var tmp := u
					u = v
					v = tmp
				low = maxf(low, u)
				high = minf(high, v)
				if low > high:
					separated = true
					break
		if not separated and high >= 0 and low <= 1:
			return false
	return true


static func _within(p: Vector2, bounds: Dictionary) -> bool:
	return p.x >= bounds["minX"] and p.x <= bounds["maxX"] and p.y >= bounds["minZ"] and p.y <= bounds["maxZ"]


static func find_path(start: Vector2, end: Vector2, obstacles: Array, bounds: Dictionary, step := 0.75) -> Array:
	if not _within(start, bounds) or not _within(end, bounds) or not segment_clear(start, start, obstacles) or not segment_clear(end, end, obstacles):
		return []
	if segment_clear(start, end, obstacles):
		return [end]
	var point := func(x: int, z: int) -> Vector2: return Vector2(bounds["minX"] + x * step, bounds["minZ"] + z * step)
	var node_near := func(p: Vector2):
		var x := int(round((p.x - bounds["minX"]) / step))
		var z := int(round((p.y - bounds["minZ"]) / step))
		var best = null
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var q: Vector2 = point.call(x + dx, z + dz)
				if _within(q, bounds) and segment_clear(p, q, obstacles):
					var d := p.distance_to(q)
					if best == null or d < best["d"]:
						best = {"x": x + dx, "z": z + dz, "p": q, "d": d}
		return best
	var first = node_near.call(start)
	var last = node_near.call(end)
	if first == null or last == null:
		return []
	var target := Vector2i(last["x"], last["z"])
	var open := [{"x": first["x"], "z": first["z"], "p": first["p"], "g": 0.0, "f": 0.0}]
	var scores := {Vector2i(first["x"], first["z"]): 0.0}
	var parents := {}
	var closed := {}
	var found = null
	const DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if open[i]["f"] < open[bi]["f"]:
				bi = i
		var current: Dictionary = open[bi]
		open.remove_at(bi)
		var id := Vector2i(current["x"], current["z"])
		if closed.has(id):
			continue
		if id == target:
			found = current
			break
		closed[id] = true
		for d in DIRS:
			var x: int = current["x"] + d[0]
			var z: int = current["z"] + d[1]
			var p: Vector2 = point.call(x, z)
			var key := Vector2i(x, z)
			var g: float = current["g"] + Vector2(d[0], d[1]).length() * step
			if closed.has(key) or not _within(p, bounds) or g >= scores.get(key, INF) or not segment_clear(current["p"], p, obstacles):
				continue
			scores[key] = g
			parents[key] = current
			open.append({"x": x, "z": z, "p": p, "g": g, "f": g + p.distance_to(last["p"])})
	if found == null:
		return []
	var route := [end]
	var node = found
	while node != null:
		route.push_front(node["p"])
		node = parents.get(Vector2i(node["x"], node["z"]))
	var compact := []
	var anchor := start
	var index := 0
	while index < route.size():
		var far := index
		while far + 1 < route.size() and segment_clear(anchor, route[far + 1], obstacles):
			far += 1
		compact.append(route[far])
		anchor = route[far]
		index = far + 1
	return compact
