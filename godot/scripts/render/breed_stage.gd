class_name BreedStage
extends SubViewport
## 웹 stage.js Stage.playBreed: 두 고양이가 집에 들어가고, 두근두근 후 아기와 함께 등장(약 5초).
## finished 신호로 끝(또는 건너뛰기)을 알린다.

signal finished

var camera: Camera3D
var rug: Node3D
var cats: Array = []
var extras: Array = []
var anim: Callable
var clock := 0.0
var _heart: Texture2D
var playing := false


func _ready() -> void:
	own_world_3d = true
	transparent_bg = true
	msaa_3d = Viewport.MSAA_4X
	camera = Camera3D.new()
	camera.fov = 34
	camera.near = 0.1
	camera.far = 50
	add_child(camera)
	rug = ToonMat.group()
	rug.add_child(ToonMat.mesh_node(ThreeGeo.cylinder(1.7, 1.7, 0.06, 40), ToonMat.toon(0xf3dcc0), Vector3(0, -0.03, 0)))
	rug.add_child(ToonMat.mesh_node(ThreeGeo.torus(1.7 * 0.82, 0.03, 8, 48), ToonMat.toon(0xe9b8a0), Vector3(0, 0.01, 0), Vector3.ONE, Vector3(PI / 2, 0, 0)))
	add_child(rug)
	_heart = CatTextures.heart_texture()


func clear() -> void:
	for o in cats:
		o["root"].queue_free()
	for e in extras:
		e.queue_free()
	cats = []
	extras = []
	anim = Callable()
	if playing:
		playing = false
		finished.emit()


func _add_cat(cat: Dictionary, x: float, z: float, face: float) -> Dictionary:
	var root := CatModel.build(cat)
	root.position = Vector3(x, 0, z)
	root.rotation.y = face
	add_child(root)
	var entry := {"cat": cat, "root": root}
	cats.append(entry)
	return entry


func play_breed(f: Dictionary, m: Dictionary, kitten: Dictionary) -> void:
	clear()
	playing = true
	camera.look_at_from_position(Vector3(0, 2.3, 9.0), Vector3(0, 0.9, 0))
	var house := ToonMat.group(Vector3(0, 0, -1.0))
	house.add_child(ToonMat.mesh_node(ThreeGeo.box(1.7, 1.2, 1.3), ToonMat.toon(0xf6e4c4), Vector3(0, 0.6, 0)))
	house.add_child(ToonMat.mesh_node(ThreeGeo.cone(1.4, 0.8, 4), ToonMat.toon(0xe58a6a), Vector3(0, 1.6, 0), Vector3(1, 1, 0.8), Vector3(0, PI / 4, 0)))
	house.add_child(ToonMat.mesh_node(ThreeGeo.circle(0.28, 20), ToonMat.toon(0x8a5a3c), Vector3(0, 0.34, 0.66)))
	add_child(house)
	extras.append(house)
	var A := _add_cat(f, -3.0, 0.2, PI / 2)
	var B := _add_cat(m, 3.0, 0.2, -PI / 2)
	var st := {"K": null}   # 람다는 지역 변수를 복사해 캡처하므로 상태는 딕셔너리에 둔다
	var hearts := []
	var start := clock
	anim = func(now: float):
		var t := now - start
		var walk := minf(1.0, t / 1.6)
		if t < 1.8:
			var e := walk * walk * (3 - 2 * walk)
			var hop := 1.0 if walk < 1 else 0.0
			A["root"].position = Vector3(-3.0 + 2.75 * e, absf(sin(t * 9)) * 0.12 * hop, 0.2 - 1.15 * e)
			B["root"].position = Vector3(3.0 - 2.75 * e, absf(sin(t * 9 + 1)) * 0.12 * hop, 0.2 - 1.15 * e)
			if t > 1.2:
				var s := maxf(0.0, 1 - (t - 1.2) / 0.6)
				A["root"].scale = Vector3.ONE * maxf(s, 0.0001)
				B["root"].scale = Vector3.ONE * maxf(s, 0.0001)
		else:
			A["root"].visible = false
			B["root"].visible = false
		if t > 1.8 and t < 3.6:
			house.rotation.z = sin(t * 26) * 0.03 * (1 - (t - 1.8) / 1.8)
			house.position.y = absf(sin(t * 6)) * 0.06
			if randf() < 0.18:
				var sp := Sprite3D.new()
				sp.texture = _heart
				sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sp.shaded = false
				sp.pixel_size = (0.28 + randf() * 0.2) / 64.0
				sp.position = Vector3((randf() - 0.5) * 1.2, 1.8, -1.0 + randf() * 0.6)
				sp.set_meta("born", t)
				add_child(sp)
				hearts.append(sp)
				extras.append(sp)
		for hh in hearts:
			if is_instance_valid(hh):
				hh.position.y += 0.012
				hh.modulate.a = maxf(0, 1 - (t - hh.get_meta("born")) / 1.6)
		if t > 3.6 and st["K"] == null:
			house.rotation.z = 0
			house.position.y = 0
			st["K"] = _add_cat(kitten, 0, 1.1, 0)
			st["K"]["root"].scale = Vector3.ONE * 0.01
		var K = st["K"]
		if K != null:
			var k := minf(1.0, (t - 3.6) / 0.7)
			var over := 1 + sin(k * PI) * 0.25
			K["root"].scale = Vector3.ONE * maxf(0.01, k * over)
			K["root"].position.y = sin(minf(1.0, k) * PI) * 0.5
			camera.position = camera.position.lerp(Vector3(0, 1.9, 5.2), 0.03)
			camera.look_at(Vector3(0, 0.8, 0.4))
		if t > 5.0:
			clear()


func _process(delta: float) -> void:
	clock += delta
	for c in cats:
		if is_instance_valid(c["root"]):
			c["root"].tick(clock)
	if anim.is_valid():
		anim.call(clock)
