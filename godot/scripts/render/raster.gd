class_name Raster
extends RefCounted
## 웹에서 HTML canvas 2D로 그리던 텍스처(털 무늬·눈·입·잔디·하트 등)를 같은 좌표로 그리는 작은 래스터라이저.
## 픽셀마다 도형까지의 거리로 안티에일리어싱(약 1px)을 계산해 canvas와 비슷한 가장자리를 만든다.
## 색은 sRGB 0~1 값, 알파는 straight. 좌표계는 canvas와 같음(왼쪽 위 원점, y 아래로).

var w: int
var h: int
var px: PackedFloat32Array   # r,g,b,a
var xf := Transform2D.IDENTITY
var clip_poly: PackedVector2Array = PackedVector2Array()   # 비어 있으면 clip 없음 (이미 변환된 좌표)
var mode := "source-over"     # 또는 "destination-out"
var dirty := Rect2i()          # 그려진 영역 (빠른 합성용)
var _dirty_init := false


func _init(width: int, height: int) -> void:
	w = width
	h = height
	px = PackedFloat32Array()
	px.resize(w * h * 4)


static func hex(c: String, alpha := 1.0) -> Color:
	var col := Color(c)
	col.a = alpha
	return col


func fill(color: Color) -> void:
	var one := PackedFloat32Array([color.r, color.g, color.b, color.a])
	var row := PackedFloat32Array()
	for i in w:
		row.append_array(one)
	px = PackedFloat32Array()
	for y in h:
		px.append_array(row)


func _blend(i: int, color: Color, cov: float) -> void:
	if cov <= 0.0:
		return
	var a := color.a * minf(cov, 1.0)
	var k := i * 4
	var cell := Rect2i(i % w, i / w, 1, 1)
	if _dirty_init:
		dirty = dirty.merge(cell)
	else:
		dirty = cell
		_dirty_init = true
	if mode == "destination-out":
		px[k + 3] *= 1.0 - a
		return
	var da := px[k + 3]
	var oa := a + da * (1.0 - a)
	if oa <= 0.0:
		return
	px[k] = (color.r * a + px[k] * da * (1.0 - a)) / oa
	px[k + 1] = (color.g * a + px[k + 1] * da * (1.0 - a)) / oa
	px[k + 2] = (color.b * a + px[k + 2] * da * (1.0 - a)) / oa
	px[k + 3] = oa


func _bbox(points: PackedVector2Array, pad: float) -> Rect2i:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in points:
		mn = mn.min(p)
		mx = mx.max(p)
	var x0 := clampi(int(floor(mn.x - pad)), 0, w)
	var y0 := clampi(int(floor(mn.y - pad)), 0, h)
	var x1 := clampi(int(ceil(mx.x + pad)), 0, w)
	var y1 := clampi(int(ceil(mx.y + pad)), 0, h)
	return Rect2i(x0, y0, x1 - x0, y1 - y0)


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	var t := 0.0 if l2 == 0 else clampf((p - a).dot(ab) / l2, 0, 1)
	return p.distance_to(a + ab * t)


static func _inside(p: Vector2, poly: PackedVector2Array) -> bool:
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a := poly[i]
		var b := poly[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			inside = not inside
		j = i
	return inside


func _clip_cov(p: Vector2) -> float:
	if clip_poly.is_empty():
		return 1.0
	return 1.0 if _inside(p, clip_poly) else 0.0


## 변환을 적용한 다각형 채우기. color_fn: (Vector2 원래 좌표) -> Color 로 그라디언트 지원
func fill_polygon(points: PackedVector2Array, color: Color, color_fn: Callable = Callable()) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(xf * p)
	if pts.size() < 3:
		return
	var box := _bbox(pts, 1.0)
	var inv := xf.affine_inverse()
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := Vector2(x + 0.5, y + 0.5)
			var d := INF
			var j := pts.size() - 1
			for i in pts.size():
				d = minf(d, _seg_dist(p, pts[i], pts[j]))
				j = i
			var cov := 0.5 + d if _inside(p, pts) else 0.5 - d
			cov = clampf(cov, 0, 1) * _clip_cov(p)
			if cov > 0:
				_blend(y * w + x, color_fn.call(inv * p) if color_fn.is_valid() else color, cov)


## 선 그리기 (lineCap round). 구간별로 가까운 픽셀만 계산하고 최대 덮임으로 한 번만 칠한다.
func stroke(points: PackedVector2Array, width: float, color: Color, closed := false) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(xf * p)
	if pts.size() < 2:
		return
	var scale := (absf(xf.get_scale().x) + absf(xf.get_scale().y)) * 0.5
	var half := width * 0.5 * scale
	var box := _bbox(pts, half + 1.0)
	if box.size.x <= 0 or box.size.y <= 0:
		return
	var cov := PackedFloat32Array()
	cov.resize(box.size.x * box.size.y)
	var segs := pts.size() - (0 if closed else 1)
	for i in segs:
		var a := pts[i]
		var b := pts[(i + 1) % pts.size()]
		var sb := _bbox(PackedVector2Array([a, b]), half + 1.0)
		for y in range(sb.position.y, sb.end.y):
			for x in range(sb.position.x, sb.end.x):
				var c := clampf(half - _seg_dist(Vector2(x + 0.5, y + 0.5), a, b) + 0.5, 0, 1)
				var k := (y - box.position.y) * box.size.x + (x - box.position.x)
				if c > cov[k]:
					cov[k] = c
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var c2 := cov[(y - box.position.y) * box.size.x + (x - box.position.x)]
			if c2 > 0:
				_blend(y * w + x, color, c2 * _clip_cov(Vector2(x + 0.5, y + 0.5)))


func fill_rect(x: float, y: float, rw: float, rh: float, color: Color) -> void:
	fill_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + rw, y), Vector2(x + rw, y + rh), Vector2(x, y + rh)]), color)


static func ellipse_points(cx: float, cy: float, rx: float, ry: float, rot := 0.0, a0 := 0.0, a1 := TAU, seg := 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := maxi(8, int(seg * absf(a1 - a0) / TAU))
	for i in n + 1:
		var a := a0 + (a1 - a0) * float(i) / n
		var p := Vector2(rx * cos(a), ry * sin(a)).rotated(rot)
		out.append(Vector2(cx, cy) + p)
	return out


## 타원은 근사 부호 거리(IQ 공식)로 빠르게 계산한다.
func _ellipse_sdf(q: Vector2, rx: float, ry: float) -> float:
	var k0 := Vector2(q.x / rx, q.y / ry).length()
	var k1 := Vector2(q.x / (rx * rx), q.y / (ry * ry)).length()
	return 0.0 if k1 == 0 else k0 * (k0 - 1.0) / k1


func _ellipse_pass(cx: float, cy: float, rx: float, ry: float, rot: float, color: Color, color_fn: Callable, ring_half: float) -> void:
	var outline := ellipse_points(cx, cy, rx + maxf(ring_half, 0), ry + maxf(ring_half, 0), rot, 0, TAU, 16)
	var pts := PackedVector2Array()
	for p in outline:
		pts.append(xf * p)
	var box := _bbox(pts, 2.0)
	var inv := xf.affine_inverse()
	var scale := (absf(xf.get_scale().x) + absf(xf.get_scale().y)) * 0.5
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var p := Vector2(x + 0.5, y + 0.5)
			var local := inv * p
			var q := (local - Vector2(cx, cy)).rotated(-rot)
			var d := _ellipse_sdf(q, rx, ry) * scale
			var cov: float
			if ring_half >= 0:
				cov = clampf(ring_half * scale - absf(d) + 0.5, 0, 1)
			else:
				cov = clampf(0.5 - d, 0, 1)
			cov *= _clip_cov(p)
			if cov > 0:
				_blend(y * w + x, color_fn.call(local) if color_fn.is_valid() else color, cov)


func fill_ellipse(cx: float, cy: float, rx: float, ry: float, rot: float, color: Color, color_fn: Callable = Callable()) -> void:
	_ellipse_pass(cx, cy, rx, ry, rot, color, color_fn, -1.0)


func stroke_ellipse(cx: float, cy: float, rx: float, ry: float, width: float, color: Color) -> void:
	_ellipse_pass(cx, cy, rx, ry, 0.0, color, Callable(), width * 0.5)


static func quad(p0: Vector2, c: Vector2, p1: Vector2, seg := 20) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg + 1:
		var t := float(i) / seg
		out.append(p0 * (1 - t) * (1 - t) + c * 2 * (1 - t) * t + p1 * t * t)
	return out


static func bezier(p0: Vector2, c0: Vector2, c1: Vector2, p1: Vector2, seg := 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in seg + 1:
		var t := float(i) / seg
		var u := 1 - t
		out.append(p0 * u * u * u + c0 * 3 * u * u * t + c1 * 3 * u * t * t + p1 * t * t * t)
	return out


## canvas clip(): 현재 변환을 적용한 다각형으로 이후 그리기를 제한
func set_clip(points: PackedVector2Array) -> void:
	var pts := PackedVector2Array()
	for p in points:
		pts.append(xf * p)
	clip_poly = pts


func clear_clip() -> void:
	clip_poly = PackedVector2Array()


func alpha_at(x: int, y: int) -> float:
	return px[(y * w + x) * 4 + 3]


func image() -> Image:
	var img := Image.create_from_data(w, h, false, Image.FORMAT_RGBAF, px.to_byte_array())
	img.convert(Image.FORMAT_RGBA8)
	return img


func texture(mipmaps := true) -> ImageTexture:
	var img := image()
	if mipmaps:
		img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
