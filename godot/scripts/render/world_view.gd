class_name WorldView
extends Node3D
## 웹 world.js: 내 우리 + 이웃 우리 + 동물샵·교배집·도서관. 플레이어가 걸어 다니며 다가가면 메뉴가 열림.
## hooks: on_pen_anchor(dict), on_zone(id, clicked), on_location(zones), on_journey(id), on_cat(id), on_focus(id), on_clean(id)

const CAT_SCALE := 0.7
const BOUNDS := {"minX": -36.0, "maxX": 36.0, "minZ": -26.0, "maxZ": 22.0}

var hooks := {}
var camera: Camera3D
var colliders: Array = []
var zones: Array = []
var pens := {}
var cat_objs := {}
var npc_avatars: Array = []
var pulsers: Array = []
var clickables: Array = []
var keys := {}
var target = null              # Vector2 또는 null
var waypoints: Array = []
var destination = null
var enabled := true
var suspended := false
var inside := {}
var stick := Vector2.ZERO
var player: Node3D
var cam_pos := Vector3.ZERO
var view_distance := 15.5
var orbit := 0.0
var follow_cat_id = null
var location_key := ""
var npc_positions := [-24, -12, 0, 12, 24]
var npcs_built := false
var pen_level := 1
var litter_tray: Node3D
var litter_piles: Node3D
var litter_label: LabelSprite
var litter_key = null
var pen_sign: LabelSprite
var pen_sign_key = null
var ground_size := Vector2(170, 130)
var elapsed := 0.0
var _down = null
var _last_x := 0.0


func _ready() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("bfe6f5")
	env.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(env)
	camera = Camera3D.new()
	camera.fov = 36
	camera.near = 0.1
	camera.far = 200
	add_child(camera)
	camera.current = true
	_build_ground()
	_build_decor()
	_build_buildings()
	_build_pens()
	player = make_avatar(0xf1e3c8, 0xffffff, 0x3a4a63, 0x4a5f8a, 0xf3c9a6)
	player.position = Vector3(-1, 0, 13)
	add_child(player)
	snap_camera()


func _hook(name: String, args := []) -> void:
	if hooks.has(name):
		hooks[name].callv(args)


static func _box(w: float, h: float, d: float, color, x := 0.0, y := 0.0, z := 0.0, parent: Node3D = null) -> MeshInstance3D:
	var m := ToonMat.mesh_node(ThreeGeo.box(w, h, d), ToonMat.toon(color), Vector3(x, y + h / 2.0, z))
	if parent:
		parent.add_child(m)
	return m


# ───── 지형·장식 ─────
func _grass_texture() -> ImageTexture:
	var r := Raster.new(256, 256)
	r.fill(Color("#79c277"))
	var rng := Rng.new("grass")
	for i in 260:
		var x := rng.range_f(0, 256)
		var y := rng.range_f(0, 256)
		var s := rng.range_f(8, 16)
		var c := Color("#86cd80") if rng.chance(0.5) else Color("#6dba6c")
		r.fill_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + s, y), Vector2(x + s / 2, y - s * 0.9)]), c)
	return r.texture()


func _build_ground() -> void:
	var ground := ToonMat.mesh_node(ThreeGeo.plane(170, 130), ToonMat.basic(Color(1, 1, 1), {"map": _grass_texture(), "map_repeat": Vector2(26, 20)}), Vector3.ZERO, Vector3.ONE, Vector3(-PI / 2, 0, 0))
	add_child(ground)
	var dirt := ToonMat.toon(0xe8d3a2)
	var path := func(x: float, z: float, w: float, d: float):
		add_child(ToonMat.mesh_node(ThreeGeo.box(w, 0.04, d), dirt, Vector3(x, 0.02, z)))
	path.call(0, 13, 64, 3); path.call(-9, 9, 3, 6); path.call(6, 11, 3, 4); path.call(20, 8.5, 3, 9); path.call(0, -2, 3, 30)
	for x in [-24, -12, 0, 12, 24]:
		path.call(x, -9, 3, 5)
	path.call(0, -10.4, 54, 2.4)


func _build_decor() -> void:
	var rng := Rng.new("decor")
	var keep_out := [[-16, -3, 7.5, 7], [0, 12, 12, 12], [14, 27, -2, 8], [-30, 30, -19, -8]]
	var free := func(x: float, z: float) -> bool:
		if not (absf(x) > 27 or z < -20):
			return false
		for k in keep_out:
			if x > k[0] - 2 and x < k[1] + 2 and z > k[2] - 2 and z < k[3] + 2:
				return false
		return absf(z - 13) > 2.5 and absf(x) > 3
	var green := [0x5faa5a, 0x74bd68, 0x6cb865]
	var trunk_geo := ThreeGeo.cylinder(0.3, 0.42, 2.2, 8)
	var orange := ThreeGeo.sphere(0.2, 8, 6)
	for i in 90:
		var x := rng.range_f(-40, 40)
		var z := rng.range_f(-30, 25)
		if not free.call(x, z) or absf(x) < 3:
			continue
		var g := ToonMat.group(Vector3(x, 0, z))
		g.add_child(ToonMat.mesh_node(trunk_geo, ToonMat.toon(0xb07c4f), Vector3(0, 1.1, 0)))
		var c = rng.pick(green)
		var s := rng.range_f(0.9, 1.35)
		for blob in [[0, 3.1, 0, 1.5], [0.8, 2.6, 0.3, 1.05], [-0.7, 2.7, -0.2, 1.1]]:
			g.add_child(ToonMat.mesh_node(CatModel._cached("tree%f" % blob[3], func(): return ThreeGeo.sphere(blob[3], 14, 10)), ToonMat.toon(c), Vector3(blob[0], blob[1], blob[2])))
		if rng.chance(0.18):
			for k in 4:
				var ox := rng.range_f(-1, 1)
				var oy := rng.range_f(2.5, 3.5)
				var oz := 1.0 + rng.range_f(0, 0.5)
				g.add_child(ToonMat.mesh_node(orange, ToonMat.toon(0xf08a2c), Vector3(ox, oy, oz)))
		g.scale = Vector3.ONE * s
		add_child(g)
	var fc := [0xffd23f, 0xff8fa3, 0xffffff, 0xb28cff]
	var flower := ThreeGeo.sphere(0.14, 8, 6)
	for i in 160:
		var x2 := rng.range_f(-40, 40)
		var z2 := rng.range_f(-30, 24)
		if not free.call(x2, z2):
			continue
		add_child(ToonMat.mesh_node(flower, ToonMat.toon(rng.pick(fc)), Vector3(x2, 0.14, z2)))


# ───── 건물 ─────
func house(cx: float, cz: float, w: float, d: float, wall, roof_c, title: String, zone_id: String) -> Node3D:
	var g := ToonMat.group(Vector3(cx, 0, cz))
	_box(w, 3.4, d, wall, 0, 0, 0, g)
	var roof := ToonMat.mesh_node(ThreeGeo.cone(maxf(w, d) * 0.78, 2.4, 4), ToonMat.toon(roof_c), Vector3(0, 4.6, 0),
		Vector3(w / maxf(w, d), 1, d / maxf(w, d)), Vector3(0, PI / 4, 0))
	g.add_child(roof)
	_box(1.4, 2.2, 0.15, 0x8a5a3c, 0, 0, d / 2 + 0.05, g)
	_box(1.1, 1.0, 0.12, 0xbfe4f5, -w / 2 + 1.3, 1.5, d / 2 + 0.05, g)
	_box(1.1, 1.0, 0.12, 0xbfe4f5, w / 2 - 1.3, 1.5, d / 2 + 0.05, g)
	g.add_child(ToonMat.mesh_node(ThreeGeo.box(w * 0.7, 0.14, 1.5), ToonMat.toon(0xf4a7a0), Vector3(0, 2.7, d / 2 + 0.6), Vector3.ONE, Vector3(0.28, 0, 0)))
	var lb := LabelSprite.make(title, "#fffaf0", "#6b4f3a", 1.1)
	lb.position = Vector3(0, 7.4, 0)
	g.add_child(lb)
	add_child(g)
	colliders.append([cx - w / 2, cx + w / 2, cz - d / 2, cz + d / 2])
	var zx := cx
	var zz := cz + d / 2 + 1.6
	zones.append({"id": zone_id, "x": zx, "z": zz, "r": 1.9})
	var ring := ToonMat.mesh_node(ThreeGeo.ring(1.1, 1.45, 28), ToonMat.basic(0xffe27a, {"transparent": true, "opacity": 0.85, "double_sided": true}), Vector3(zx, 0.07, zz), Vector3.ONE, Vector3(-PI / 2, 0, 0))
	add_child(ring)
	pulsers.append(ring)
	g.set_meta("zoneId", zone_id)
	clickables.append(g)
	return g


func _build_buildings() -> void:
	house(-23, 4, 5.8, 4, 0xf1ead5, 0x8daf9c, "📖 유전 도서관", "dex")
	house(20, 3, 6.5, 4.6, 0xfbeed1, 0xe58a6a, "🛍️ 동물샵", "shop")
	house(6, 8, 5.4, 4, 0xffe0e6, 0xf08a9b, "💞 교배집", "breed")


# ───── 우리(울타리) ─────
func build_pen(id: String, cx: float, cz: float, w: float, d: float, title: String, color = 0xf2e2b6) -> void:
	var g := ToonMat.group()
	add_child(g)
	var obstacles := []
	g.add_child(ToonMat.mesh_node(ThreeGeo.plane(w, d), ToonMat.basic(color), Vector3(cx, 0.03, cz), Vector3.ONE, Vector3(-PI / 2, 0, 0)))
	var wood := ToonMat.toon(0xc99a66)
	var gate := 1.8
	var post_geo := ThreeGeo.box(0.22, 1.1, 0.22)
	var rail := func(x: float, z: float, lw: float, ld: float):
		for y in [0.45, 0.85]:
			g.add_child(ToonMat.mesh_node(ThreeGeo.box(lw, 0.12, ld), wood, Vector3(x, y, z)))
		var o := [x - lw / 2 - 0.05, x + lw / 2 + 0.05, z - ld / 2 - 0.05, z + ld / 2 + 0.05]
		colliders.append(o)
		obstacles.append(o)
	var post := func(x: float, z: float): g.add_child(ToonMat.mesh_node(post_geo, wood, Vector3(x, 0.55, z)))
	var x0 := cx - w / 2
	var x1 := cx + w / 2
	var z0 := cz - d / 2
	var z1 := cz + d / 2
	rail.call(cx, z0, w, 0.12)
	rail.call(x0, cz, 0.12, d)
	rail.call(x1, cz, 0.12, d)
	var left := (cx - gate / 2) - x0
	var right := x1 - (cx + gate / 2)
	rail.call(x0 + left / 2, z1, left, 0.12)
	rail.call(x1 - right / 2, z1, right, 0.12)
	var x := x0
	while x <= x1 + 0.01:
		if absf(x - cx) > gate / 2 - 0.05:
			post.call(x, z0)
			post.call(x, z1)
		x += 1.5
	var z := z0
	while z <= z1 + 0.01:
		post.call(x0, z)
		post.call(x1, z)
		z += 1.5
	var lb := LabelSprite.make(title, "#fffaf0", "#6b4f3a", 0.95)
	lb.position = Vector3(cx, 3.1, z0 + 0.3)
	g.add_child(lb)
	pens[id] = {"id": id, "cx": cx, "cz": cz, "w": w, "d": d, "group": g, "obstacles": obstacles,
		"minX": x0 + 1, "maxX": x1 - 1, "minZ": z0 + 1, "maxZ": z1 - 1, "gate": Vector2(cx, z1)}
	_build_shelters(pens[id])


func _build_shelters(pen: Dictionary) -> void:
	var list := []
	for index in 2:
		var side := -1 if index == 0 else 1
		var x: float = pen["minX"] + .65 if side < 0 else pen["maxX"] - .65
		var z: float = pen["minZ"] + .55
		var hut := ToonMat.group(Vector3(x, 0, z))
		_box(2.1, .12, 1.75, 0xd6ad83, 0, .04, 0, hut)
		hut.add_child(ToonMat.mesh_node(ThreeGeo.cylinder(.72, .78, .12, 24), ToonMat.toon(0xf4c6cd), Vector3(0, .22, 0), Vector3(1, 1, .8)))
		for dx in [-.91, .91]:
			for dz in [-.7, .7]:
				_box(.12, 1.6, .12, 0xc99a66, dx, .12, dz, hut)
		hut.add_child(ToonMat.mesh_node(ThreeGeo.cone(1.55, .65, 4), ToonMat.toon(0xa9cbb9), Vector3(0, 1.92, 0), Vector3(1, 1, .85), Vector3(0, PI / 4, 0)))
		var sign := LabelSprite.make("🌿 조용한 쉼터", "#fffaf0", "#6b4f3a", .48)
		sign.position = Vector3(0, 2.65, 0)
		hut.add_child(sign)
		add_child(hut)
		list.append({"id": "%s:shelter:%d" % [pen["id"], index], "pos": Vector2(x, z), "object": hut})
	pen["shelters"] = list


func _build_pens() -> void:
	build_pen("mine", -9, 2, 12, 9, "🏠 우리 집", 0xf5e6b8)
	_build_litter_tray()
	pen_level = 1


func sync_pen(level: int, capacity: int, count: int) -> void:
	if pen_level != level:
		var previous: Dictionary = pens["mine"]
		var journey = destination
		cancel_journey()
		colliders = colliders.filter(func(o): return not previous["obstacles"].has(o))
		previous["group"].queue_free()
		for shelter in previous["shelters"]:
			shelter["object"].queue_free()
		litter_tray.queue_free()
		litter_label = null
		litter_key = null
		pen_sign = null
		pen_sign_key = null
		build_pen("mine", -9, 2, 12 + (level - 1) * .8, 9 + (level - 1) * .3, "🏠 우리 집 Lv.%d" % level, 0xe0e8b9 if level >= 5 else 0xf5e6b8)
		_build_litter_tray()
		pen_level = level
		for o in cat_objs.values():
			if o["pen"] == "mine":
				o["shelterId"] = null
				o["partnerId"] = null
				o["moving"] = false
				o["activity"] = "idle"
				o["wait"] = 2.0
		var p := Vector2(player.position.x, player.position.z)
		if not Navigation.segment_clear(p, p, colliders):
			var moved := false
			var r := .5
			while r <= 3 and not moved:
				for i in 16:
					var q := p + Vector2(cos(i * PI / 8), sin(i * PI / 8)) * r
					if Navigation.segment_clear(q, q, colliders):
						player.position = Vector3(q.x, 0, q.y)
						moved = true
						break
				r += .5
		if journey != null:
			go_to_zone(journey)
	var key := "%d:%d:%d" % [level, capacity, count]
	if pen_sign_key == key:
		return
	var pen: Dictionary = pens["mine"]
	if pen_sign != null:
		pen_sign.queue_free()
	pen_sign = LabelSprite.make("우리집", "#fffaf0", "#6b4f3a", .8)
	pen_sign.position = Vector3(pen["cx"] - 3, 2, pen["gate"].y + .1)
	pen["group"].add_child(pen_sign)
	pen_sign_key = key


func _build_litter_tray() -> void:
	var pen: Dictionary = pens["mine"]
	var tray := ToonMat.group(Vector3(pen["minX"] + .6, 0, pen["maxZ"] - .4))
	_box(2.1, .18, 1.4, 0x9cbda6, 0, .06, 0, tray)
	_box(1.85, .04, 1.15, 0xe6cfa3, 0, .25, 0, tray)
	for x in [-1, 1]:
		_box(.14, .2, 1.4, 0x9cbda6, x, .12, 0, tray)
	for z in [-.65, .65]:
		_box(2.1, .2, .14, 0x9cbda6, 0, .12, z, tray)
	add_child(tray)
	litter_tray = tray
	litter_piles = ToonMat.group()
	tray.add_child(litter_piles)


func sync_litter(state: Dictionary) -> void:
	var parts := []
	for item in state["items"]:
		parts.append("%s:%d" % [item["catId"], item["index"]])
	var key := "%d|%s" % [state["total"], "|".join(parts)]
	if key == litter_key:
		return
	litter_key = key
	for pile in litter_piles.get_children():
		pile.queue_free()
	if litter_label != null:
		litter_label.queue_free()
	for item in state["items"]:
		var rng := Rng.new(item["seed"])
		var px := rng.range_f(-.75, .75)
		var pz := rng.range_f(-.4, .4)
		var pile := ToonMat.group(Vector3(px, .3, pz))
		pile.set_meta("cleanCatId", item["catId"])
		for i in 3:
			pile.add_child(ToonMat.mesh_node(CatModel._cached("pile%d" % i, func(): return ThreeGeo.sphere(.14 - i * .035, 10, 8)), ToonMat.toon(0x987252), Vector3(i * .015, i * .1, 0), Vector3(1, .65, 1)))
		litter_piles.add_child(pile)
	var total: int = state["total"]
	litter_label = LabelSprite.make("🧹 청소 %d" % total if total else "✨ 깨끗한 화장실", "#ffe5c7" if total else "#edf5df", "#6b4f3a", .62)
	litter_label.position = Vector3(0, 1.6, 0)
	litter_tray.add_child(litter_label)
	if state["items"].is_empty():
		if litter_tray.has_meta("cleanCatId"):
			litter_tray.remove_meta("cleanCatId")
	else:
		litter_tray.set_meta("cleanCatId", state["items"][0]["catId"])


## 이웃 우리는 게임 데이터가 정해진 뒤 만든다
func setup_npcs(npcs: Array) -> void:
	if npcs_built:
		return
	npcs_built = true
	var hairs := [0x7a4a2b, 0x2d2d3a, 0xd9803a, 0xb8a1e0, 0x5aa07a]
	var shirts := [0xf6a98d, 0x8cc7ee, 0xf3d36a, 0xe58fb5, 0xa6d9a0]
	for i in npcs.size():
		var n: Dictionary = npcs[i]
		var cx: float = npc_positions[i]
		build_pen("npc:" + n["id"], cx, -14, 9, 7, "%s %s의 우리" % [n["icon"], n["name"]], 0xf0e0c0)
		var av := make_avatar(hairs[i % 5], shirts[i % 5], shirts[i % 5], 0x6b5a4a, 0xf3c9a6)
		av.position = Vector3(cx + 5.6, 0, -10.3)
		av.rotation.y = 0.3
		av.set_meta("npcId", n["id"])
		add_child(av)
		npc_avatars.append(av)
		zones.append({"id": "npc:" + n["id"], "x": cx + 4.4, "z": -9.4, "r": 2.6})
		var ring := ToonMat.mesh_node(ThreeGeo.ring(0.9, 1.2, 24), ToonMat.basic(0xffffff, {"transparent": true, "opacity": 0.8, "double_sided": true}), Vector3(cx + 5.6, 0.07, -10.3), Vector3.ONE, Vector3(-PI / 2, 0, 0))
		add_child(ring)
		pulsers.append(ring)


# ───── 아바타 ─────
func make_avatar(hair, shirt, stripe, pants, skin) -> Node3D:
	var g := ToonMat.group()
	var inner := ToonMat.group()
	g.add_child(inner)
	var body_mat: Material = ToonMat.toon(shirt)
	if stripe != shirt:
		var r := Raster.new(8, 32)
		r.fill(ToonMat.color_of(shirt))
		var y := 2
		while y < 32:
			r.fill_rect(0, y, 8, 3, ToonMat.color_of(stripe))
			y += 8
		body_mat = ToonMat.toon(Color(1, 1, 1), {"map": r.texture()})
	inner.add_child(ToonMat.mesh_node(CatModel._cached("avbody", func(): return ThreeGeo.capsule(0.34, 0.5, 6, 12)), body_mat, Vector3(0, 1.05, 0)))
	var legs := []
	for s in [-1, 1]:
		var l := ToonMat.group(Vector3(s * 0.17, 0.62, 0))
		l.add_child(ToonMat.mesh_node(CatModel._cached("avleg", func(): return ThreeGeo.capsule(0.13, 0.35, 4, 8)), ToonMat.toon(pants), Vector3(0, -0.3, 0)))
		l.add_child(ToonMat.mesh_node(CatModel._cached("avshoe", func(): return ThreeGeo.sphere(0.17, 10, 8)), ToonMat.toon(0x3b5ac2), Vector3(0, -0.6, 0.06), Vector3(1, 0.6, 1.4)))
		inner.add_child(l)
		legs.append(l)
	var arms := []
	for s in [-1, 1]:
		var a := ToonMat.group(Vector3(s * 0.44, 1.35, 0))
		a.add_child(ToonMat.mesh_node(CatModel._cached("avarm", func(): return ThreeGeo.capsule(0.1, 0.32, 4, 8)), ToonMat.toon(shirt), Vector3(0, -0.22, 0)))
		inner.add_child(a)
		arms.append(a)
	var head := ToonMat.group(Vector3(0, 1.95, 0))
	inner.add_child(head)
	head.add_child(ToonMat.mesh_node(CatModel._cached("avface", func(): return ThreeGeo.sphere(0.46, 20, 16)), ToonMat.toon(skin), Vector3.ZERO, Vector3(1.08, 1, 1)))
	head.add_child(ToonMat.mesh_node(CatModel._cached("avhair", func(): return ThreeGeo.sphere(0.5, 20, 12, 0, TAU, 0, PI * 0.62)), ToonMat.toon(hair), Vector3(0, 0.07, -0.04), Vector3(1.1, 1.05, 1.06)))
	head.add_child(ToonMat.mesh_node(CatModel._cached("avbangs", func(): return ThreeGeo.sphere(0.47, 16, 8, 0, TAU, 0, PI * 0.32)), ToonMat.toon(hair), Vector3(0, 0.04, 0.1), Vector3.ONE, Vector3(0.4, 0, 0)))
	for s in [-1, 1]:
		head.add_child(ToonMat.mesh_node(CatModel._cached("aveye", func(): return ThreeGeo.sphere(0.06, 8, 6)), ToonMat.basic(0x2a2020), Vector3(s * 0.17, -0.02, 0.42), Vector3(0.9, 1.4, 0.6)))
	head.add_child(ToonMat.mesh_node(CatModel._cached("aveye", func(): return ThreeGeo.sphere(0.06, 8, 6)), ToonMat.toon(0xf08a4c), Vector3(0, -0.12, 0.47)))
	g.set_meta("legs", legs)
	g.set_meta("arms", arms)
	g.set_meta("head", head)
	g.set_meta("inner", inner)
	return g


# ───── 입력 ─────
const MOVE_KEYS := {KEY_W: "w", KEY_A: "a", KEY_S: "s", KEY_D: "d", KEY_UP: "arrowup", KEY_DOWN: "arrowdown", KEY_LEFT: "arrowleft", KEY_RIGHT: "arrowright"}


func handle_key(event: InputEventKey) -> bool:
	var k = MOVE_KEYS.get(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	if k == null:
		return false
	if not event.pressed:
		keys.erase(k)
		return true
	keys[k] = true
	cancel_journey()
	return true


func handle_pointer(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = event.position
			_last_x = event.position.x
		else:
			var start = _down
			_down = null
			if start == null or start.distance_to(event.position) > 6:
				return
			if not enabled:
				return
			pick(event.position)
	elif event is InputEventMouseMotion and _down != null and follow_cat_id != null:
		orbit += (event.position.x - _last_x) * .012
		_last_x = event.position.x


func release_pointer() -> void:
	_down = null


func pick(screen: Vector2) -> void:
	var origin := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var roots: Array = []
	for o in cat_objs.values():
		roots.append(o["holder"])
	roots.append_array(npc_avatars)
	roots.append(litter_tray)
	roots.append_array(clickables)
	var best_t := INF
	var best: Node = null
	for r in roots:
		for mi in r.find_children("*", "MeshInstance3D", true, false):
			var aabb: AABB = mi.global_transform * mi.get_aabb()
			var hit = aabb.intersects_ray(origin, dir)
			if hit != null:
				var t: float = (hit - origin).length()
				if t < best_t:
					best_t = t
					best = mi
	var o: Node = best
	while o != null:
		if o.has_meta("cleanCatId"):
			_hook("on_clean", [o.get_meta("cleanCatId")])
			return
		if o.has_meta("catId"):
			_hook("on_cat", [o.get_meta("catId")])
			return
		if o.has_meta("npcId"):
			_hook("on_zone", ["npc:" + o.get_meta("npcId"), true])
			return
		if o.has_meta("zoneId"):
			_hook("on_zone", [o.get_meta("zoneId"), true])
			return
		o = o.get_parent()
		if o == self:
			break
	if absf(dir.y) > 1e-6:
		var t2 := -origin.y / dir.y
		if t2 > 0:
			var gp := origin + dir * t2
			if absf(gp.x) <= ground_size.x / 2 and absf(gp.z) <= ground_size.y / 2:
				stop_watching()
				cancel_journey()
				set_route(Vector2(gp.x, gp.z))


func snap_camera() -> void:
	cam_pos = Vector3(player.position.x, 0, player.position.z)
	place_camera()


func place_camera() -> void:
	var o := orbit if follow_cat_id != null else 0.0
	camera.position = Vector3(cam_pos.x + sin(o) * view_distance * .97, view_distance, cam_pos.z + cos(o) * view_distance * .97)
	camera.look_at(Vector3(cam_pos.x, 1, cam_pos.z - 0.5))


func teleport(x: float, z: float) -> void:
	player.position = Vector3(x, 0, z)
	cancel_journey()
	snap_camera()


func player_xz() -> Vector2:
	return Vector2(player.position.x, player.position.z)


func can_open(tab: String) -> bool:
	return Locations.can_open_at(tab, player_xz(), zones)


func near_zone(id: String) -> bool:
	for z in Locations.nearby_zones(player_xz(), zones):
		if z["id"] == id:
			return true
	return false


func go_to_zone(id: String) -> bool:
	var zone = null
	for z in zones:
		if z["id"] == id:
			zone = z
	if zone == null:
		return false
	stop_watching()
	keys = {}
	if not set_route(Vector2(zone["x"], zone["z"])):
		return false
	destination = id
	_hook("on_journey", [id])
	return true


func set_route(end: Vector2) -> bool:
	waypoints = Navigation.find_path(player_xz(), end, colliders, BOUNDS)
	target = waypoints.pop_front() if not waypoints.is_empty() else null
	return target != null


func cancel_journey() -> void:
	target = null
	waypoints = []
	destination = null
	_hook("on_journey", [null])


# ───── 고양이 동기화 ─────
func key_of(c: Dictionary) -> String:
	return "%s|%s|%s" % [c["id"], "baby" if c.get("personality") == null else str(c["personality"]), str(c.get("costume")) if c.get("costume") != null else ""]


## desired: [{cat, pen}]
func sync(desired: Array) -> void:
	var want := {}
	for d in desired:
		want[d["cat"]["id"]] = d
	for id in cat_objs.keys():
		var o: Dictionary = cat_objs[id]
		var d = want.get(id)
		if d == null or d["pen"] != o["pen"] or o["key"] != key_of(d["cat"]):
			o["holder"].queue_free()
			cat_objs.erase(id)
	for d in desired:
		if cat_objs.has(d["cat"]["id"]) or not pens.has(d["pen"]):
			continue
		var pen: Dictionary = pens[d["pen"]]
		var root := CatModel.build(d["cat"])
		var holder := ToonMat.group()
		holder.add_child(root)
		holder.scale = Vector3.ONE * CAT_SCALE
		holder.position = Vector3(lerpf(pen["minX"], pen["maxX"], randf()), 0, lerpf(pen["minZ"], pen["maxZ"], randf()))
		holder.rotation.y = randf() * 6.28
		holder.set_meta("catId", d["cat"]["id"])
		add_child(holder)
		var behavior := Behavior.of(d["cat"].get("personality"))
		cat_objs[d["cat"]["id"]] = {"id": d["cat"]["id"], "holder": holder, "root": root, "behavior": behavior,
			"personality": d["cat"].get("personality"), "activity": "idle", "duration": behavior["rest"], "pen": d["pen"],
			"key": key_of(d["cat"]), "wait": randf() * behavior["rest"], "tx": 0.0, "tz": 0.0, "moving": false,
			"speed": behavior["speed"], "partnerId": null, "shelterId": null, "socialUntil": 0.0, "chaseUntil": 0.0}
	if follow_cat_id != null and not cat_objs.has(follow_cat_id):
		stop_watching()


func react(id: String, action: String) -> void:
	var o = cat_objs.get(id)
	if o == null:
		return
	o["root"].react(action)
	o["moving"] = false
	o["wait"] = 5.0
	o["activity"] = "care"
	o["partnerId"] = null
	o["shelterId"] = null


func activity_of(id) -> String:
	var o = cat_objs.get(id)
	if o != null and o["moving"] and o["activity"] == "shelter":
		return "조용한 쉼터로 가요"
	if o != null and o["moving"] and o["partnerId"] != null:
		return "친구에게 다가가요"
	return Behavior.ACTIVITY_NAMES.get(o["activity"] if o != null else "idle", Behavior.ACTIVITY_NAMES["idle"])


func focus_cat(id: String) -> void:
	if cat_objs.has(id):
		follow_cat_id = id
		orbit = 0
		target = null
		keys = {}
		_hook("on_focus", [id])


func stop_watching() -> void:
	if follow_cat_id == null:
		return
	follow_cat_id = null
	_hook("on_focus", [null])


# ───── 프레임 ─────
func _process(delta: float) -> void:
	if suspended:
		return
	var dt := minf(0.1, delta)
	elapsed += dt
	var t := elapsed
	_move_player(dt, t)
	var followed = cat_objs.get(follow_cat_id) if follow_cat_id != null else null
	var anchor: Vector3 = followed["holder"].position if followed != null else player.position
	cam_pos = cam_pos.lerp(Vector3(anchor.x, 0, anchor.z), 1 - exp(-dt * 4))
	view_distance = lerpf(view_distance, 7.5 if followed != null else 15.5, 1 - exp(-dt * 4))
	place_camera()
	var pen: Dictionary = pens["mine"]
	var marker := Vector3(pen["maxX"], 2.3, pen["gate"].y)
	var vp := get_viewport().get_visible_rect().size
	var sp := camera.unproject_position(marker)
	var visible := not camera.is_position_behind(marker) and sp.x >= 0 and sp.x <= vp.x and sp.y >= 0 and sp.y <= vp.y
	_hook("on_pen_anchor", [{"x": sp.x, "y": sp.y, "visible": visible}])
	_update_cats(dt, t)
	for av in npc_avatars:
		av.get_meta("inner").position.y = sin(t * 2 + av.position.x) * 0.03
		av.get_meta("head").rotation.z = sin(t * 1.3 + av.position.x) * 0.06
	for p in pulsers:
		var s := 1 + sin(t * 3) * 0.12
		p.scale = Vector3(s, s, 1)
	check_zones()


func _move_player(dt: float, t: float) -> void:
	var p := player
	var dx := 0.0
	var dz := 0.0
	var follows_route := false
	if enabled:
		dx = stick.x
		dz = stick.y
		if keys.has("w") or keys.has("arrowup"):
			dz -= 1
		if keys.has("s") or keys.has("arrowdown"):
			dz += 1
		if keys.has("a") or keys.has("arrowleft"):
			dx -= 1
		if keys.has("d") or keys.has("arrowright"):
			dx += 1
		if dx == 0 and dz == 0 and target != null:
			follows_route = true
			var ex: float = target.x - p.position.x
			var ez: float = target.y - p.position.z
			var dist := sqrt(ex * ex + ez * ez)
			if dist < 0.1:
				target = waypoints.pop_front() if not waypoints.is_empty() else null
			else:
				dx = ex / dist
				dz = ez / dist
	var moving := dx != 0 or dz != 0
	if moving:
		stop_watching()
		var l := sqrt(dx * dx + dz * dz)
		if l > 1:
			dx /= l
			dz /= l
		var spd := 6.2 * dt
		if follows_route and target != null:
			spd = minf(6.2 * dt, Vector2(target.x - p.position.x, target.y - p.position.z).length())
		_try_move(dx * spd, 0)
		_try_move(0, dz * spd)
		var ang := atan2(dx, dz)
		var da := ang - p.rotation.y
		da = atan2(sin(da), cos(da))
		p.rotation.y += da * minf(1, dt * 12)
	var sw := sin(t * 12) * 0.7 if moving else 0.0
	var legs: Array = p.get_meta("legs")
	var arms: Array = p.get_meta("arms")
	legs[0].rotation.x = sw
	legs[1].rotation.x = -sw
	arms[0].rotation.x = -sw * 0.8
	arms[1].rotation.x = sw * 0.8
	p.get_meta("inner").position.y = absf(sin(t * 12)) * 0.08 if moving else sin(t * 2) * 0.015


func _try_move(dx: float, dz: float) -> void:
	var nx := clampf(player.position.x + dx, BOUNDS["minX"], BOUNDS["maxX"])
	var nz := clampf(player.position.z + dz, BOUNDS["minZ"], BOUNDS["maxZ"])
	var r := 0.4
	for c in colliders:
		if nx > c[0] - r and nx < c[1] + r and nz > c[2] - r and nz < c[3] + r:
			return
	player.position.x = nx
	player.position.z = nz


func _update_cats(dt: float, t: float) -> void:
	for o in cat_objs.values():
		var pen: Dictionary = pens[o["pen"]]
		var h: Node3D = o["holder"]
		var root: CatModel = o["root"]
		var behavior: Dictionary = o["behavior"]
		var hp := Vector2(h.position.x, h.position.z)
		if not o["moving"]:
			o["wait"] -= dt
			root.position.y = 0
			root.rotation.z = 0
			if o["wait"] <= 0:
				var neighbors := cat_objs.values().filter(func(q): return q != o and q["pen"] == o["pen"])
				var peers := []
				for q in neighbors:
					var social: bool = o["personality"] in [2, 6]
					if not social or (o["socialUntil"] <= t and Behavior.can_receive_greeting(q["activity"]) and q["socialUntil"] <= t):
						peers.append({"id": q["id"], "pos": Vector2(q["holder"].position.x, q["holder"].position.z)})
				var shelters: Array = pen["shelters"].filter(func(s): return not neighbors.any(func(q): return q["shelterId"] == s["id"]))
				var plan := Behavior.choose_activity(o["personality"], hp, peers, pen, func(): return randf(), shelters)
				o["activity"] = plan["kind"]
				o["duration"] = plan["duration"]
				o["partnerId"] = plan.get("partnerId")
				o["shelterId"] = plan.get("shelterId")
				o["chaseUntil"] = t + 8
				o["wait"] = plan["duration"]
				if plan.has("target"):
					o["tx"] = plan["target"].x
					o["tz"] = plan["target"].y
					o["moving"] = true
		else:
			if o["partnerId"] != null:
				var friend = cat_objs.get(o["partnerId"])
				if friend == null or friend["pen"] != o["pen"] or not Behavior.can_receive_greeting(friend["activity"]) or friend["socialUntil"] > t or t > o["chaseUntil"]:
					o["partnerId"] = null
					o["moving"] = false
					o["activity"] = "idle"
					o["wait"] = 1.0
				else:
					var dest := Behavior.social_target(hp, Vector2(friend["holder"].position.x, friend["holder"].position.z), pen)
					o["tx"] = dest.x
					o["tz"] = dest.y
			if not o["moving"]:
				root.tick(t, o["activity"], false, dt)
				continue
			var ex: float = o["tx"] - h.position.x
			var ez: float = o["tz"] - h.position.z
			var dist := sqrt(ex * ex + ez * ez)
			if dist < 0.15:
				o["moving"] = false
				o["wait"] = o["duration"]
				root.position.y = 0
				root.rotation.z = 0
				var friend2 = cat_objs.get(o["partnerId"]) if o["partnerId"] != null else null
				if friend2 != null:
					friend2["moving"] = false
					friend2["activity"] = "greet"
					friend2["wait"] = o["duration"]
					friend2["partnerId"] = null
					friend2["shelterId"] = null
					friend2["socialUntil"] = t + o["duration"] + 6
					o["socialUntil"] = friend2["socialUntil"]
					h.rotation.y = atan2(friend2["holder"].position.x - h.position.x, friend2["holder"].position.z - h.position.z)
					friend2["holder"].rotation.y = h.rotation.y + PI
				o["partnerId"] = null
			else:
				var ang := atan2(ex, ez)
				var da := ang - h.rotation.y
				da = atan2(sin(da), cos(da))
				h.rotation.y += da * minf(1, dt * 6)
				var step := minf(dist, o["speed"] * dt)
				h.position.x += ex / dist * step
				h.position.z += ez / dist * step
				root.position.y = absf(sin(t * 9 + o["speed"] * 10)) * behavior["bounce"]
				root.rotation.z = sin(t * 9 + o["speed"] * 10) * behavior["sway"]
		root.tick(t, o["activity"], o["moving"], dt)


func check_zones() -> void:
	var p := player_xz()
	var nearby := Locations.nearby_zones(p, zones)
	var key := "|".join(nearby.map(func(z): return z["id"]))
	if location_key != key:
		location_key = key
		_hook("on_location", [nearby])
	if destination != null and nearby.any(func(z): return z["id"] == destination):
		var id = destination
		cancel_journey()
		if enabled:
			_hook("on_zone", [id, false])
	for z in zones:
		var d := p.distance_to(Vector2(z["x"], z["z"]))
		var is_inside: bool = d < z["r"]
		if is_inside and not inside.get(z["id"], false):
			inside[z["id"]] = true
			if enabled and (destination == null or destination == z["id"]):
				_hook("on_zone", [z["id"], false])
		elif not is_inside and d > z["r"] + 0.8:
			inside[z["id"]] = false
