class_name CatModel
extends Node3D
## 웹 cat3d.js buildCat: 구·캡슐·튜브로 만든 프로시저럴 툰 고양이 + 걷기/행동 애니메이션 + 의상.
## (유전 가이드에 장모 좌위가 없으므로 솜털 셸은 쓰지 않는다)

static var _geo_cache := {}

var app: Dictionary
var cat_data: Dictionary
var rig: Node3D
var head: Node3D
var tail_group: Node3D
var body_layers: Array = []
var front_parts: Array = []
var hind_parts: Array = []
var eyes: Array = []
var yarn: MeshInstance3D
var behavior: Dictionary
var size_mul := 1.0
var baby := false
var wK := 0.0
var hK := 0.0
var dK := 0.0
var walk_blend := 0.0
var walk_phase := 0.0
var reaction = null        # {action, start(ms)}
var t0 := 0.0


static func _cached(key: String, make: Callable) -> ThreeGeo:
	if not _geo_cache.has(key):
		_geo_cache[key] = make.call()
	return _geo_cache[key]


static func sphere_geo(r := 1.0) -> ThreeGeo:
	return _cached("sphere%f" % r, func(): return ThreeGeo.sphere(r, 28, 20))


func _part(parent: Node3D, geo: ThreeGeo, mat: Material, pos := Vector3.ZERO, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := ToonMat.mesh_node(geo, mat, pos, scale, rot)
	parent.add_child(m)
	return m


static func build(cat: Dictionary) -> CatModel:
	var m := CatModel.new()
	m._build(cat)
	return m


func _build(cat: Dictionary) -> void:
	cat_data = cat
	app = CatTextures.resolve(cat)
	var tex := CatTextures.part_textures(cat, app)
	var b: Dictionary = cat["body"]
	rig = ToonMat.group()
	add_child(rig)
	var white := Color(1, 1, 1)
	var mat_body := ToonMat.toon(white, {"map": tex["body"]})
	var mat_head := ToonMat.toon(white, {"map": tex["head"]})
	var mat_legs := ToonMat.toon(white, {"map": tex["legs"]})
	var mat_tail := ToonMat.toon(white, {"map": tex["tail"]})
	var mat_ears := ToonMat.toon(white, {"map": tex["ears"]})
	var mat_thigh := ToonMat.toon(white, {"map": tex["thigh"]})
	var hairless: bool = app["hairless"]
	wK = 0.55 * (0.88 + 0.5 * b["bulk"])
	hK = 0.62
	dK = 0.84
	var earK: float = 0.8 + 0.6 * b["ear"] + (0.4 if hairless else 0.0)
	var fw: float = 0.95 + 0.3 * b["face"]

	# 몸통: 극을 앞뒤축으로 (등 중앙선 UV)
	var body_geo := _cached("body", func(): return ThreeGeo.sphere(1, 28, 20).rotate_x(PI / 2))
	var body := _part(rig, body_geo, mat_body, Vector3(0, 0.62, 0), Vector3(wK, hK, dK))
	body_layers = [body]
	var leg_geo := _cached("leg", func(): return ThreeGeo.capsule(0.11, 0.32, 6, 12))
	for s in [-1, 1]:
		var lx: float = s * 0.2 * pow(wK / 0.55, 0.5)
		var leg := _part(rig, leg_geo, mat_legs, Vector3(lx, 0.32, 0.5))
		var paw := _part(rig, sphere_geo(), mat_legs, Vector3(lx, 0.08, 0.58), Vector3(0.14, 0.09, 0.19))
		front_parts.append({"leg": leg, "paw": paw, "side": s})
		var thigh := _part(rig, sphere_geo(), mat_thigh, Vector3(s * wK * 0.78, 0.34, -0.2), Vector3(0.27, 0.33, 0.44))
		var paw_back := _part(rig, sphere_geo(), mat_legs, Vector3(s * wK * 0.7, 0.08, 0.2), Vector3(0.14, 0.09, 0.22))
		hind_parts.append({"layers": [thigh], "paw": paw_back, "side": s})

	# 꼬리
	tail_group = ToonMat.group(Vector3(0, 0.25, -0.62))
	rig.add_child(tail_group)
	if app["special"] == "manx":
		_part(tail_group, sphere_geo(), mat_body, Vector3(0, 0.12, -0.08), Vector3(0.15, 0.15, 0.15))
	else:
		var r := 0.05 if hairless else 0.075
		var curve := ThreeGeo.CatmullRom.new([Vector3(0, 0, 0), Vector3(0, -0.02, -0.35), Vector3(0.22, 0.12, -0.55), Vector3(0.38, 0.55, -0.45), Vector3(0.28, 0.95, -0.25)])
		_part(tail_group, _cached("tail%f" % r, func(): return ThreeGeo.tube(curve, 28, r, 10)), mat_tail)
		var end := curve.get_point(1.0)
		_part(tail_group, sphere_geo(), mat_tail, end, Vector3(r, r, r))

	# 머리
	head = ToonMat.group(Vector3(0, 1.28, 0.2))
	rig.add_child(head)
	_part(head, sphere_geo(), mat_head, Vector3.ZERO, Vector3(0.55 * fw, 0.47, 0.5))
	var curl: bool = app["special"] == "curl"
	var ear_geo := _cached("earcurl", func(): return ThreeGeo.torus(0.11, 0.07, 8, 14, PI * 1.5)) if curl else _cached("ear", func(): return ThreeGeo.cone(0.17, 0.32, 4))
	for s in [-1, 1]:
		var eg := ToonMat.group(Vector3(s * 0.33 * fw, 0.36, -0.02))
		if curl:
			eg.rotation = Vector3(-0.5, s * 0.9, s * -0.25)
			_part(eg, ear_geo, mat_ears, Vector3(0, 0.04, 0), Vector3(earK, earK, earK), Vector3(0, 0, 2.0 if s > 0 else 1.2))
		else:
			eg.rotation = Vector3(-0.12, 0, s * -0.38)
			_part(eg, ear_geo, mat_ears, Vector3(0, 0.12 * earK, 0), Vector3(earK, earK, earK * 0.7))
		head.add_child(eg)
	# 눈 (성격별 모양)
	var eye_size := 0.25 * (1.4 if app["special"] == "singapura" else 1.0)
	var personality: int = -1 if cat.get("personality") == null else int(cat["personality"])
	for s in [-1, 1]:
		var mat := ToonMat.basic(Color(1, 1, 1), {"map": CatTextures.eye_texture(personality, app["eye"], s > 0), "transparent": true, "view_bias": 0.004})
		var e := _part(head, _cached("eye%f" % eye_size, func(): return ThreeGeo.plane(eye_size, eye_size)), mat, Vector3(s * 0.23 * fw, 0.0, 0.455), Vector3.ONE, Vector3(0, s * 0.28, 0))
		eyes.append(e)
	# 코/입
	_part(head, sphere_geo(), ToonMat.toon(0xe58f94), Vector3(0, -0.1, 0.49), Vector3(0.04, 0.03, 0.03))
	var mouth_mat := ToonMat.basic(Color(1, 1, 1), {"map": CatTextures.mouth_texture(), "transparent": true, "view_bias": 0.004})
	_part(head, _cached("mouth", func(): return ThreeGeo.plane(0.16, 0.08)), mouth_mat, Vector3(0, -0.15, 0.482))

	# SPECIAL 보정
	if app["special"] == "singapura":
		head.scale = Vector3.ONE * 1.18
		size_mul = 0.7
	if app["special"] == "sphynx":
		head.scale = Vector3.ONE * 1.04
	# 판타지: 은은한 발광
	if app["fantasy"] != null:
		var glow := Color(CatTextures.FANTASY_PALETTE[app["fantasy"]][0])
		for m in [mat_body, mat_head, mat_legs, mat_tail]:
			m.set_shader_parameter("emissive", glow)
			m.set_shader_parameter("emissive_intensity", 0.18)
			m.set_shader_parameter("emissive_from_map", true)
	if cat.get("costume") != null:
		_add_costume(cat["costume"], fw)
	baby = cat.get("personality") == null
	rig.scale = Vector3.ONE * ((0.62 if baby else 1.0) * size_mul)
	if baby:
		head.scale *= 1.22
	behavior = Behavior.of(cat.get("personality"))
	yarn = _part(rig, sphere_geo(0.18), ToonMat.toon(0xf09fbc), Vector3(0, .2, 1.35))
	yarn.visible = false
	t0 = randf() * 10.0


func react(action: String) -> void:
	reaction = {"action": action, "start": Time.get_ticks_msec()}


static func _lerp(a: float, b: float, t: float) -> float:
	return a + (b - a) * t


## 웹 root.userData.tick과 같은 계산
func tick(t: float, activity := "idle", moving := false, dt := 1.0 / 60.0) -> void:
	var s := t + t0
	var blend := 1.0 - exp(-minf(.05, dt) * 9.0)
	walk_blend = _lerp(walk_blend, 1.0 if moving else 0.0, blend)
	if moving:
		walk_phase += minf(.05, dt) * (6.0 + behavior["speed"] * 3.0)
	for layer in body_layers:
		layer.position.y = .62 + walk_blend * .12
		layer.scale.y = hK * (1 - walk_blend * .28) * (1 + sin(s * 1.8) * .014)
		layer.scale.z = dK * (1 + walk_blend * .1)
	head.rotation.z = sin(s * 0.9) * behavior["sway"]
	head.position.y = 1.28 - walk_blend * .18 + sin(s * 1.8) * .01
	head.position.z = .2 + walk_blend * .43
	tail_group.position.y = .25 + walk_blend * .3
	tail_group.rotation.y = sin(s * behavior["speed"] * 1.6) * behavior["tail"]
	var blink := 0.1 if fmod(s, 4.2) > 4.05 else 1.0
	for e in eyes:
		e.scale.y = blink
	var elapsed: float = (Time.get_ticks_msec() - reaction["start"]) / 1000.0 if reaction != null else 99.0
	var active := elapsed < 5
	yarn.visible = active and reaction["action"] == "yarn"
	var pose := {"x": 0.0, "z": 0.0, "y": 0.0, "px": 0.0}
	head.rotation.x = 0
	head.rotation.y = 0
	for fp in front_parts:
		var swing: float = sin(walk_phase + fp["side"] * PI / 2) * walk_blend
		fp["leg"].rotation.x = swing * .45
		fp["leg"].position.y = .32
		fp["leg"].position.z = .5 + walk_blend * .15 + swing * .08
		fp["paw"].position = Vector3(fp["paw"].position.x, .08 + maxf(0, swing) * .15, .58 + walk_blend * .14 + swing * .2)
	for hp in hind_parts:
		var swing2: float = -sin(walk_phase + hp["side"] * PI / 2) * walk_blend
		for layer in hp["layers"]:
			layer.position.z = -.2 - walk_blend * .35 + swing2 * .06
			layer.position.y = .34 + walk_blend * .02
			layer.scale = Vector3(.27 - walk_blend * .07, .33, .44 - walk_blend * .18)
			layer.rotation.x = swing2 * .35
		hp["paw"].position = Vector3(hp["paw"].position.x, .08 + maxf(0, swing2) * .15, .2 - walk_blend * .78 + swing2 * .2)
	if not active and not moving:
		match activity:
			"nap":
				pose["z"] = -1.2
				pose["y"] = .5
				for e in eyes:
					e.scale.y = .12
				tail_group.rotation.y = sin(s) * .04
			"groom":
				front_parts[0]["leg"].rotation.x = -.8
				front_parts[0]["leg"].position.y = .5
				front_parts[0]["paw"].position.y = .72
				front_parts[0]["paw"].position.z = .7
				head.rotation.x = .28 + sin(s * 5) * .08
				head.rotation.z = -.12
			"hide", "shelter":
				pose["x"] = .2
				head.rotation.x = .18
				for e in eyes:
					e.scale.y = .65
			"rub", "greet":
				pose["z"] = sin(s * 2) * .18
				pose["px"] = sin(s * 2) * .1
				for e in eyes:
					e.scale.y = .4
			"pounce":
				pose["x"] = -.12 + sin(s * 4) * .1
				pose["y"] = absf(sin(s * 4)) * .13
			"watch", "explore":
				head.rotation.y = sin(s * .7) * .4
			"alert":
				head.rotation.y = sin(s * 2) * .35
				tail_group.rotation.y = sin(s * 7) * .3
	if active:
		match reaction["action"]:
			"yarn":
				yarn.position = Vector3(sin(elapsed * 4) * .5, .2 + absf(sin(elapsed * 5)) * .1, 1.25)
				yarn.rotation.z = elapsed * 5
				head.rotation.z = sin(elapsed * 4) * .18
				pose["x"] = sin(elapsed * 6) * .06
			"feed":
				head.rotation.x = .15 + sin(elapsed * 5) * .08
			"pet":
				pose["z"] = sin(elapsed * 2) * .12
				for e in eyes:
					e.scale.y = .35
	rig.rotation.x = _lerp(rig.rotation.x, pose["x"], blend)
	rig.rotation.z = _lerp(rig.rotation.z, pose["z"], blend)
	rig.position.x = _lerp(rig.position.x, pose["px"], blend)
	rig.position.y = _lerp(rig.position.y, pose["y"], blend)


# ───── 스페셜 의상 (유전 가이드 7종) ─────
func _add_costume(id: String, fw: float) -> void:
	var top := 0.43
	var g := ToonMat.group()
	head.add_child(g)
	var T := func(c) -> Material: return ToonMat.toon(c)
	match id:
		"chef":
			var w: Material = T.call(0xffffff)
			_part(g, ThreeGeo.cylinder(0.28, 0.3, 0.14, 20), w, Vector3(0, top + 0.02, -0.02))
			_part(g, sphere_geo(), w, Vector3(0, top + 0.2, -0.02), Vector3(0.36, 0.26, 0.36))
			_part(g, sphere_geo(), w, Vector3(0.22, top + 0.14, -0.02), Vector3(0.16, 0.16, 0.16))
			_part(g, sphere_geo(), w, Vector3(-0.22, top + 0.14, -0.02), Vector3(0.16, 0.16, 0.16))
		"wizard":
			var p: Material = T.call(0x6a4fb3)
			_part(g, ThreeGeo.cylinder(0.5, 0.5, 0.03, 24), p, Vector3(0, top - 0.02, 0))
			_part(g, ThreeGeo.cone(0.3, 0.7, 20), p, Vector3(0, top + 0.34, -0.05), Vector3.ONE, Vector3(-0.18, 0, 0.1))
			for i in 4:
				_part(g, sphere_geo(0.035), T.call(0xffe27a), Vector3(sin(i * 1.7) * 0.15, top + 0.14 + i * 0.12, 0.1 + (i % 2) * 0.02 - i * 0.025))
		"crown":
			var gold: Material = T.call(0xf6c945)
			_part(g, ThreeGeo.cylinder(0.24, 0.26, 0.14, 16, 1, true), gold, Vector3(0, top + 0.03, 0))
			for i in 5:
				var a := i / 5.0 * TAU
				_part(g, ThreeGeo.cone(0.05, 0.14, 6), gold, Vector3(sin(a) * 0.25, top + 0.17, cos(a) * 0.25))
			_part(g, sphere_geo(0.045), T.call(0xe8484f), Vector3(0, top + 0.03, 0.27))
		"captain":
			var navy: Material = T.call(0x2c4a7c)
			_part(g, ThreeGeo.sphere(0.36, 22, 12, 0, TAU, 0, PI / 2), navy, Vector3(0, top - 0.04, -0.02), Vector3(1, 0.8, 1))
			_part(g, ThreeGeo.cylinder(0.37, 0.37, 0.08, 22), T.call(0xffffff), Vector3(0, top - 0.04, -0.02))
			_part(g, ThreeGeo.cylinder(0.4, 0.4, 0.02, 20, 1, false, -PI / 2 + 0.3, PI - 0.6), T.call(0x1d1d24), Vector3(0, top - 0.07, 0.04))
			_part(g, ThreeGeo.torus(0.05, 0.015, 6, 12), T.call(0xf6c945), Vector3(0, top + 0.1, 0.33))
		"detective":
			var br: Material = T.call(0xa57145)
			var dk: Material = T.call(0x6b4a2c)
			_part(g, ThreeGeo.sphere(0.36, 22, 12, 0, TAU, 0, PI / 2), br, Vector3(0, top - 0.06, -0.02), Vector3(1, 0.78, 1))
			_part(g, ThreeGeo.box(0.34, 0.025, 0.2), dk, Vector3(0, top - 0.06, 0.4), Vector3.ONE, Vector3(0.15, 0, 0))
			_part(g, ThreeGeo.box(0.34, 0.025, 0.2), dk, Vector3(0, top - 0.06, -0.42), Vector3.ONE, Vector3(-0.15, 0, 0))
			_part(g, ThreeGeo.torus(0.06, 0.018, 6, 12), T.call(0xd8d8d8), Vector3(0.3, -0.25, 0.4))
			_part(g, ThreeGeo.cylinder(0.01, 0.01, 0.12, 6), T.call(0x4a3330), Vector3(0.34, -0.33, 0.4), Vector3.ONE, Vector3(0, 0, 0.6))
		"santa":
			var red: Material = T.call(0xd9363e)
			var wh: Material = T.call(0xfafafa)
			_part(g, ThreeGeo.cone(0.3, 0.55, 20), red, Vector3(0, top + 0.22, -0.1), Vector3.ONE, Vector3(-0.45, 0, 0))
			_part(g, ThreeGeo.torus(0.3, 0.07, 10, 22), wh, Vector3(0, top - 0.02, 0), Vector3.ONE, Vector3(PI / 2, 0, 0))
			_part(g, sphere_geo(0.09), wh, Vector3(0, top + 0.37, -0.36))
		"explorer":
			# 가이드의 '탐험가' (웹에 없던 의상): 카키 탐험 모자 + 갈색 띠 + 챙
			var khaki: Material = T.call(0xd2b98a)
			_part(g, ThreeGeo.sphere(0.34, 22, 12, 0, TAU, 0, PI / 2), khaki, Vector3(0, top - 0.05, -0.02), Vector3(1, 0.85, 1))
			_part(g, ThreeGeo.cylinder(0.35, 0.35, 0.07, 22), T.call(0x6b4a2c), Vector3(0, top - 0.02, -0.02))
			_part(g, ThreeGeo.cylinder(0.52, 0.52, 0.025, 24), T.call(0xc2a874), Vector3(0, top - 0.06, -0.02))
			_part(g, sphere_geo(0.04), T.call(0xb08a52), Vector3(0, top + 0.24, -0.02))
