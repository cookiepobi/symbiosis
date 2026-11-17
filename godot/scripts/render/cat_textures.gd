class_name CatTextures
extends RefCounted
## 웹 appearance.js + textures.js 대응. 유전 가이드의 3좌위에는 태비·토티·포인트·장모·실버·농도가 없으므로
## 몸색(4종) + 흰 반점(바이컬러) + SPECIAL(스핑크스 피부) + 판타지 팔레트만 그린다.

const BASE_HEX := {"black": "#292c30", "blue": "#858f9e", "chocolate": "#865640", "lilac": "#ae97aa"}
const EYES := ["#e0a030", "#8fc060", "#c97a35", "#d9b43c"]
const FANTASY_PALETTE := {
	"mint": ["#6dffc2", "#b9ffe3", "#3fd9a0"],
	"galaxy": ["#2b1b5e", "#7d4fd6", "#d6a8ff"],
	"holo": ["#ff9ad5", "#9ae7ff", "#fff29a"],
	"aurora": ["#4aa8ff", "#5dffb0", "#b27cff"],
}
const SIZES := {"body": [256, 128], "head": [256, 128], "legs": [128, 64], "thigh": [128, 64], "tail": [256, 64], "ears": [32, 32]}
const INK := "#2f2222"

static var _part_cache := {}     # key → {part: ImageTexture}
static var _part_order := []     # LRU (웹 ResourcePool 16개 유지와 같은 역할)
static var _eye_cache := {}
static var _mouth: ImageTexture
static var _heart: ImageTexture


static func resolve(cat: Dictionary) -> Dictionary:
	var ph: Dictionary = cat["ph"]
	var body := BASE_HEX[ph["base"]] as String
	var h := Rng.hash_seed(str(cat.get("seed", "x")))
	var app := {
		"body": body,
		"white": "bicolor" if ph["bicolor"] else "none",
		"eye": EYES[h % EYES.size()],
		"special": cat.get("special"),
		"fantasy": cat.get("fantasy"),
		"hairless": cat.get("special") == "sphynx",
	}
	app["renderSig"] = "%s|%s|%s|%s" % [body, app["white"], str(app["special"]), str(app["fantasy"])]
	return app


static func _mix(a: Color, b: Color, t: float) -> Color:
	return Color(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)


# ───── 흰 반점 마스크 (web whiteLayer, lv=1 바이컬러) ─────
static func _white_mask(part: String, app: Dictionary, W: int, H: int, rng: Rng) -> Raster:
	if app["white"] == "none" or part == "ears" or part == "thigh":
		return null
	var r := Raster.new(W, H)
	var black := Color(0, 0, 0, 1)
	var blob := func(x: float, y: float, rx: float, ry: float): r.fill_ellipse(x, y, rx, ry, rng.range_f(-0.4, 0.4), black)
	if part == "body":
		r.fill_rect(W * 0.07, 0, W * 0.36, H, black)
		blob.call(W * 0.25, H * 0.08, W * 0.16, H * 0.14)
		var i := 0
		while i < rng.int_below(3):     # 웹: 반복 조건에서 매번 rng.int(3)을 새로 뽑는다
			var bx := rng.range_f(0.6 * W, 0.95 * W)
			var by := rng.range_f(H * 0.15, H * 0.85)
			blob.call(bx, by, W * 0.05, H * 0.1)
			i += 1
	elif part == "head":
		blob.call(W * 0.25, H * 0.72, W * 0.1, H * 0.2)
		if rng.chance(0.5):
			r.fill_rect(W * 0.25 - 5, H * 0.1, 10, H * 0.5, black)
	elif part == "legs":
		r.fill_rect(0, H * 0.55, W, H * 0.45, black)
	elif part == "tail":
		r.fill_rect(W * 0.8, 0, W * 0.2, H, black)
	return r


static func make_part(part: String, app: Dictionary, seed_value: String) -> ImageTexture:
	var W: int = SIZES[part][0]
	var H: int = SIZES[part][1]
	var rng := Rng.new(seed_value + ":" + part)
	var out := Raster.new(W, H)
	if app["fantasy"] != null:
		var pal: Array = FANTASY_PALETTE[app["fantasy"]].map(func(c): return Color(c))
		var star := Raster.new(W, H)
		var n := 4 if part == "ears" else 160
		for i in n:
			var sx := rng.range_f(0, W)
			var sy := rng.range_f(0, H)
			var sr := rng.range_f(0.6, 1.8)
			star.fill_ellipse(sx, sy, sr, sr, 0, Color(0, 0, 0, 1))
		for y in H:
			for x in W:
				var t := fmod((float(x) / W) * 2.0 + (float(y) / H) * 0.6, 1.0)
				var f := t * 3.0
				var i0 := int(floor(f)) % 3
				var j0 := (i0 + 1) % 3
				var k := f - floorf(f)
				var c := _mix(pal[i0], pal[j0], k)
				var sp := star.alpha_at(x, y)
				c = _mix(c, Color(1, 1, 1), sp * 0.9)
				var idx := (y * W + x) * 4
				out.px[idx] = c.r
				out.px[idx + 1] = c.g
				out.px[idx + 2] = c.b
				out.px[idx + 3] = 1.0
		return out.texture()
	var base := Color(app["body"])
	out.fill(base)
	var white := _white_mask(part, app, W, H, rng)
	var skin := Color("#eec0b0")
	var wc := Color8(252, 250, 246)
	var region := Rect2i()
	if app["hairless"]:
		region = Rect2i(0, 0, W, H)
	elif white != null and white._dirty_init:
		region = white.dirty
	for y in range(region.position.y, region.end.y):
		for x in range(region.position.x, region.end.x):
			var idx := (y * W + x) * 4
			var c := Color(out.px[idx], out.px[idx + 1], out.px[idx + 2])
			if white != null:
				var wa := white.alpha_at(x, y)
				if wa > 0:
					c = _mix(c, wc, wa)
			if app["hairless"]:
				c = Color(c.r * 0.4 + skin.r * 0.6, c.g * 0.4 + skin.g * 0.6, c.b * 0.4 + skin.b * 0.6)
			out.px[idx] = c.r
			out.px[idx + 1] = c.g
			out.px[idx + 2] = c.b
	if app["hairless"] and part != "ears":   # 주름
		for i in 14:
			var wy := rng.range_f(0, H)
			var line := PackedVector2Array([Vector2(0, wy)])
			var x2 := 0
			while x2 <= W:
				line.append(Vector2(x2, wy + sin(x2 * 0.1 + i) * 4))
				x2 += 16
			out.stroke(line, 2, Color8(160, 100, 95, int(0.35 * 255)))
	return out.texture()


static func part_textures(cat: Dictionary, app: Dictionary) -> Dictionary:
	var key := str(cat["seed"]) + "|" + str(app["renderSig"])
	if _part_cache.has(key):
		_part_order.erase(key)
		_part_order.append(key)
		return _part_cache[key]
	var set := {}
	for part in SIZES:
		set[part] = make_part(part, app, str(cat["seed"]))
	_part_cache[key] = set
	_part_order.append(key)
	while _part_order.size() > 64:
		_part_cache.erase(_part_order.pop_front())
	return set


# ───── 눈: 성격별 8종 + 갓 태어남 ─────
static func eye_texture(personality: int, color_hex: String, mirror: bool) -> ImageTexture:
	var key := "%d|%s|%d" % [personality, color_hex, 1 if mirror else 0]
	if _eye_cache.has(key):
		return _eye_cache[key]
	if mirror:   # 좌우 반전은 그린 이미지를 뒤집어 재사용
		var img := eye_texture(personality, color_hex, false).get_image()
		img.clear_mipmaps()
		img.flip_x()
		img.generate_mipmaps()
		var flipped := ImageTexture.create_from_image(img)
		_eye_cache[key] = flipped
		return flipped
	const S := 128
	var r := Raster.new(S, S)
	r.xf = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(S / 2.0, S / 2.0))
	var color := Color(color_hex)
	var ink := Color(INK)
	var top_c := _mix(color, Color(1, 1, 1), 0.25)
	var bot_c := _mix(color, Color(0, 0, 0), 0.2)
	var iris := func(rx: float, ry: float, pr: float, pry: float, ox: float, oy: float):
		if pry < 0:
			pry = pr
		r.fill_ellipse(0, 0, rx, ry, 0, top_c, func(p: Vector2) -> Color: return _mix(top_c, bot_c, clampf((p.y + ry) / (2 * ry), 0, 1)))
		r.fill_ellipse(ox, oy, pr, pry, 0, ink)
		r.stroke_ellipse(0, 0, rx, ry, 6, ink)
	var hl := func(x: float, y: float, rad: float): r.fill_ellipse(x, y, rad, rad, 0, Color(1, 1, 1))
	var rect := func(x: float, y: float, rw: float, rh: float) -> PackedVector2Array: return PackedVector2Array([Vector2(x, y), Vector2(x + rw, y), Vector2(x + rw, y + rh), Vector2(x, y + rh)])
	match personality:
		0:
			iris.call(48, 48, 22, -1, 0, 0); hl.call(-15, -17, 11); hl.call(15, 14, 5)
		1:
			iris.call(50, 50, 13, -1, 0, 0); hl.call(-16, -16, 7); hl.call(10, 14, 4); hl.call(18, -6, 3)
			r.stroke(Raster.quad(Vector2(-48, -52), Vector2(0, -64), Vector2(44, -40)), 6, ink)
		2:
			iris.call(50, 52, 26, -1, 0, 0); hl.call(-16, -16, 12); hl.call(16, 16, 6)
			r.fill_polygon(PackedVector2Array([Vector2(18, -22), Vector2(22, -12), Vector2(32, -10), Vector2(23, -4), Vector2(26, 6), Vector2(18, -1), Vector2(10, 6), Vector2(13, -4), Vector2(4, -10), Vector2(14, -12)]), Color(1, 1, 1))
		3:
			r.set_clip(rect.call(-60, -8, 120, 80)); iris.call(46, 46, 11, 24, 0, 0); hl.call(-14, 2, 6); r.clear_clip()
			r.stroke(PackedVector2Array([Vector2(-50, -8), Vector2(50, -12)]), 9, ink)
		4:
			iris.call(40, 54, 26, -1, 0, 0); hl.call(-12, -20, 12); hl.call(12, 18, 6)
		5:
			r.stroke(Raster.ellipse_points(0, -8, 38, 38, 0, 0.15 * PI, 0.85 * PI, 40), 10, ink)
		6:
			r.set_clip(rect.call(-60, -14, 120, 90)); iris.call(46, 46, 18, 18, 14, 8); hl.call(-6, -2, 6); r.clear_clip()
			r.stroke(PackedVector2Array([Vector2(-50, -26), Vector2(50, -10)]), 9, ink)
			r.stroke(PackedVector2Array([Vector2(-40, -52), Vector2(34, -64)]), 6, ink)
		7:
			r.fill_ellipse(0, 0, 54, 54, 0, Color(1, 1, 1))
			iris.call(40, 44, 6, 32, 0, 0); hl.call(-12, -14, 5)
			r.stroke_ellipse(0, 0, 54, 54, 6, ink)
		_:
			r.fill_ellipse(0, 0, 20, 20, 0, ink)
	var tex := r.texture()
	_eye_cache[key] = tex
	return tex


static func mouth_texture() -> ImageTexture:
	if _mouth == null:
		var r := Raster.new(128, 64)
		var ink := Color("#4a3330")
		r.stroke(PackedVector2Array([Vector2(64, 4), Vector2(64, 20)]), 7, ink)
		r.stroke(Raster.quad(Vector2(64, 20), Vector2(48, 40), Vector2(30, 24)), 7, ink)
		r.stroke(Raster.quad(Vector2(64, 20), Vector2(80, 40), Vector2(98, 24)), 7, ink)
		_mouth = r.texture()
	return _mouth


static func heart_texture() -> ImageTexture:
	if _heart == null:
		var r := Raster.new(64, 64)
		var pts := Raster.bezier(Vector2(32, 56), Vector2(4, 36), Vector2(6, 8), Vector2(32, 20))
		pts.append_array(Raster.bezier(Vector2(32, 20), Vector2(58, 8), Vector2(60, 36), Vector2(32, 56)))
		r.fill_polygon(pts, Color("#ff7d9b"))
		_heart = r.texture()
	return _heart
