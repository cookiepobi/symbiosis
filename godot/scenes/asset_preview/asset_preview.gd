extends Node3D
## 에셋 미리보기: 동기화된 .glb를 게임 기준 모형(집사·고양이·울타리·문) 옆에 세워 크기를 비교한다.
## 마우스 드래그로 회전, 휠로 확대/축소.

const MODELS_DIR := "res://assets/models"
const RULES_PATH := "res://assets/asset_rules.json"
const REF_COLOR := Color(0.35, 0.55, 0.95, 0.45)

var rules: Dictionary = {}
var model_paths: Array[String] = []
var current: Node3D
var anim_player: AnimationPlayer
var anim_index := 0

var camera: Camera3D
var focus := Vector3(0, 0.6, 0)
var yaw := 0.7
var pitch := -0.3
var distance := 4.0
var dragging := false

var list: ItemList
var info: RichTextLabel
var anim_button: Button
var coat_select: OptionButton


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	rules = parsed if parsed is Dictionary else {}
	_build_environment()
	_build_references()
	_build_ui()
	_scan_models()


# ───── 환경 ─────
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("fff4e0")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.97, 0.92)
	env.ambient_light_energy = 0.6
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	ground.material_override = _flat(Color("e8dcc0"))
	add_child(ground)
	add_child(_grid(10))

	camera = Camera3D.new()
	camera.fov = 40
	add_child(camera)
	_update_camera()


func _grid(half: int) -> MeshInstance3D:
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(-half, half + 1):
		im.surface_add_vertex(Vector3(i, 0.002, -half))
		im.surface_add_vertex(Vector3(i, 0.002, half))
		im.surface_add_vertex(Vector3(-half, 0.002, i))
		im.surface_add_vertex(Vector3(half, 0.002, i))
	im.surface_end()
	var mi := MeshInstance3D.new()
	mi.mesh = im
	mi.material_override = _flat(Color(0.55, 0.45, 0.35, 0.5), true)
	return mi


# ───── 기준 모형 (asset_rules.json의 references) ─────
func _build_references() -> void:
	var refs: Dictionary = rules.get("references", {})
	var x := -0.6
	for key in ["kitten", "cat_adult", "caretaker", "door", "fence"]:
		if not refs.has(key):
			continue
		var r: Dictionary = refs[key]
		var size := Vector3(r["width"], r["height"], r["depth"])
		x -= size.x / 2.0 + 0.25
		var mi := MeshInstance3D.new()
		if key == "caretaker":
			var capsule := CapsuleMesh.new()
			capsule.height = size.y
			capsule.radius = size.x / 2.0
			mi.mesh = capsule
		else:
			var box := BoxMesh.new()
			box.size = size
			mi.mesh = box
		mi.position = Vector3(x, size.y / 2.0, 0)
		mi.material_override = _flat(REF_COLOR, true)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

		var label := Label3D.new()
		label.text = "%s\n%.2fm" % [r["label"], size.y]
		label.font_size = 28
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(x, size.y + 0.15, 0)
		label.modulate = Color("3b4a7a")
		add_child(label)
		x -= size.x / 2.0


# ───── UI ─────
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	panel.custom_minimum_size = Vector2(320, 0)
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)

	var title := Label.new()
	title.text = "에셋 미리보기 (기준 모형과 크기 비교)"
	box.add_child(title)

	list = ItemList.new()
	list.custom_minimum_size = Vector2(300, 220)
	list.item_selected.connect(_on_model_selected)
	box.add_child(list)

	coat_select = OptionButton.new()
	coat_select.add_item("털색: 원본 머티리얼")
	for id in Genetics.PHENOTYPE_ORDER:
		coat_select.add_item("털색: " + Genetics.PHENOTYPES[id]["name"])
	coat_select.item_selected.connect(func(_i): _apply_coat())
	coat_select.tooltip_text = "고양이 모델의 'coat' 머티리얼을 유전 표현형 색으로 바꿔 봅니다 (임시 셰이더)"
	box.add_child(coat_select)

	anim_button = Button.new()
	anim_button.text = "애니메이션 없음"
	anim_button.disabled = true
	anim_button.pressed.connect(_next_animation)
	box.add_child(anim_button)

	info = RichTextLabel.new()
	info.bbcode_enabled = true
	info.fit_content = true
	info.custom_minimum_size = Vector2(300, 0)
	box.add_child(info)


func _scan_models() -> void:
	model_paths = _list_models(MODELS_DIR)
	model_paths.sort()
	for path in model_paths:
		list.add_item(path.trim_prefix(MODELS_DIR + "/"))
	if model_paths.is_empty():
		info.text = "아직 동기화된 에셋이 없습니다.\n%s/<카테고리>/ 에 .glb가 들어오면 여기에 표시됩니다." % MODELS_DIR
	else:
		list.select(0)
		_on_model_selected(0)


func _list_models(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_list_models(dir_path.path_join(sub)))
	for file in dir.get_files():
		var file_name := file.trim_suffix(".import").trim_suffix(".remap")
		var full := dir_path.path_join(file_name)
		if file_name.get_extension() == "glb" and not out.has(full):
			out.append(full)
	return out


# ───── 모델 표시 ─────
func _on_model_selected(index: int) -> void:
	if current:
		current.queue_free()
		current = null
	var path := model_paths[index]
	var scene := load(path) as PackedScene
	if scene == null:
		info.text = "[color=red]불러오기 실패[/color]: " + path
		return
	current = scene.instantiate() as Node3D
	add_child(current)
	_apply_coat()

	var players := current.find_children("*", "AnimationPlayer", true, false)
	anim_player = players[0] if players.size() > 0 else null
	anim_index = 0
	_play_animation()

	var aabb := _world_aabb(current)
	focus = aabb.get_center()
	distance = clampf(maxf(aabb.size.length(), 1.5) * 1.8, 2.5, 30.0)
	_update_camera()
	info.text = _describe(path, aabb)


func _describe(path: String, aabb: AABB) -> String:
	var category := path.trim_prefix(MODELS_DIR + "/").get_slice("/", 0)
	var lines: Array[String] = []
	lines.append("[b]%s[/b]  (카테고리: %s)" % [path.get_file(), category])
	lines.append("크기 W×D×H: %.2f × %.2f × [b]%.2f m[/b]" % [aabb.size.x, aabb.size.z, aabb.size.y])
	var cat_rules: Dictionary = rules.get("categories", {}).get(category, {})
	if cat_rules.has("height"):
		var lo: float = cat_rules["height"][0]
		var hi: float = cat_rules["height"][1]
		var ok := aabb.size.y >= lo and aabb.size.y <= hi
		lines.append("허용 높이 %.2f–%.2f m: %s" % [lo, hi, "[color=green]통과[/color]" if ok else "[color=red]범위 밖[/color]"])
	if absf(aabb.position.y) > rules.get("origin_tolerance_m", 0.02):
		lines.append("[color=orange]바닥이 Y=0에 있지 않음 (%.3f m)[/color]" % aabb.position.y)
	var shapes: Array[String] = []
	for node in current.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh
		if mesh is ArrayMesh:
			for i in (mesh as ArrayMesh).get_blend_shape_count():
				shapes.append(str((mesh as ArrayMesh).get_blend_shape_name(i)))
	if not shapes.is_empty():
		lines.append("Shape key: " + ", ".join(shapes))
	if anim_player:
		lines.append("애니메이션: " + ", ".join(anim_player.get_animation_list()))
	return "\n".join(lines)


func _world_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for node in root.find_children("*", "VisualInstance3D", true, false):
		var vi := node as VisualInstance3D
		# glTF 스킨 메시는 정점이 모델 공간에 있어 메시 노드 자신의 변환을 무시해야 한다.
		var skinned := vi is MeshInstance3D and (vi as MeshInstance3D).skin != null
		var xform := root.global_transform if skinned else vi.global_transform
		var box := xform * vi.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


func _apply_coat() -> void:
	if current == null:
		return
	var choice := coat_select.selected
	if choice <= 0:
		for node in current.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			for i in mi.get_surface_override_material_count():
				mi.set_surface_override_material(i, null)
		return
	var id: String = Genetics.PHENOTYPE_ORDER[choice - 1]
	var cat := {"base": Genetics.PHENOTYPES[id]["base"], "bicolor": Genetics.PHENOTYPES[id]["bicolor"]}
	CatAppearance.apply(current, cat)


func _play_animation() -> void:
	if anim_player == null or anim_player.get_animation_list().is_empty():
		anim_button.text = "애니메이션 없음"
		anim_button.disabled = true
		return
	var names := anim_player.get_animation_list()
	var anim_name: String = names[anim_index % names.size()]
	anim_player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	anim_player.play(anim_name)
	anim_button.disabled = false
	anim_button.text = "▶ %s (눌러서 다음)" % anim_name


func _next_animation() -> void:
	anim_index += 1
	_play_animation()


# ───── 카메라 ─────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			distance = maxf(0.8, distance * 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			distance = minf(40.0, distance * 1.1)
		_update_camera()
	elif event is InputEventMouseMotion and dragging:
		var motion := (event as InputEventMouseMotion).relative
		yaw -= motion.x * 0.008
		pitch = clampf(pitch - motion.y * 0.008, -1.4, 0.2)
		_update_camera()


func _update_camera() -> void:
	if camera == null:
		return
	var offset := Vector3(sin(yaw) * cos(pitch), -sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.position = focus + offset
	camera.look_at(focus, Vector3.UP)


func _flat(color: Color, transparent := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if transparent else BaseMaterial3D.SHADING_MODE_PER_PIXEL
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat
