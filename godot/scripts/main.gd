extends Node
## 웹 main.js + recovery.js: 저장을 불러오고(실패하면 원본을 보호하는 복구 화면) 월드와 UI를 시작한다.

var g: GameState
var world: WorldView
var ui: GameUI
var audio: GameAudio
var layer: CanvasLayer
var dev := false


func _ready() -> void:
	var scale := DisplayServer.screen_get_scale()
	if OS.has_feature("web"):
		scale = float(JavaScriptBridge.eval("window.devicePixelRatio || 1", true))
	get_window().content_scale_factor = maxf(1.0, scale)
	add_child(Thumbnails.new())
	audio = GameAudio.new()
	add_child(audio)
	layer = CanvasLayer.new()
	add_child(layer)
	dev = "--dev" in OS.get_cmdline_user_args()
	if OS.has_feature("web"):
		var host := str(JavaScriptBridge.eval("location.hostname", true))
		var q := str(JavaScriptBridge.eval("location.search", true))
		dev = host in ["localhost", "127.0.0.1", "[::1]"] and q.contains("dev=1")
	var capture := OS.get_environment("NYANG_CAPTURE") != ""
	g = GameState.new(GameState.MemoryStorage.new() if capture else null)   # 화면 캡처 실행은 실제 저장을 건드리지 않음
	GameState.current = g
	if g.load_game():
		_start()
	elif g.load_issue != null:
		_show_recovery()
	else:
		g.new_game()
		_start()


func _start() -> void:
	g.tick()
	g.save()
	world = WorldView.new()
	add_child(world)
	await get_tree().process_frame
	ui = GameUI.new()
	ui.setup(g, world, audio, dev)
	layer.add_child(ui)
	if OS.get_environment("NYANG_CAPTURE") != "":
		_capture_steps(OS.get_environment("NYANG_CAPTURE"), OS.get_environment("NYANG_STEPS"))


## 개발용: NYANG_CAPTURE=파일경로 NYANG_STEPS="home,shot,breed,shot" 로 화면을 찍고 종료
func _capture_steps(path: String, steps: String) -> void:
	var n := 0
	for step in (steps if steps != "" else "shot").split(","):
		await get_tree().create_timer(1.5).timeout
		match step:
			"shot":
				get_viewport().get_texture().get_image().save_png(path.replace(".png", "_%d.png" % n))
				n += 1
			"home", "breed", "shop", "dex", "npc":
				if step == "home":
					ui._open_panel("home")
				else:
					world.teleport({"breed": Vector2(6, 11.6), "shop": Vector2(20, 6.9), "dex": Vector2(-23, 7.6), "npc": Vector2(-19.6, -9.4)}[step].x, {"breed": Vector2(6, 11.6), "shop": Vector2(20, 6.9), "dex": Vector2(-23, 7.6), "npc": Vector2(-19.6, -9.4)}[step].y)
			"close":
				ui._close_panel()
				ui._close_modal()
			"map":
				ui._show_map()
			"detail":
				ui._show_detail(g.mine[0], false)
			"lab":
				ui._open_lab()
				await get_tree().process_frame
			"labrun":
				var lab = ui.lab_layer.get_child(0)
				lab._preset("all")
				lab.count_opt.select(2)
				await lab._run()
				await get_tree().process_frame
				lab.get_child(1).scroll_vertical = 1400
			"breedrun":
				g.coins = 9999
				var f = g.my_cats().filter(func(c): return c["sex"] == "M")[0]
				var m = g.my_cats().filter(func(c): return c["sex"] == "F")[0]
				ui.U["breed"]["father"] = f["id"]
				ui.U["breed"]["mother"] = m["id"]
				ui._run_breed()
			"skip":
				g.skip_time(86400e3)
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if ui == null or world == null:
		return
	if event is InputEventKey:
		if event.pressed and event.keycode == KEY_ESCAPE:
			if ui.handle_escape():
				get_viewport().set_input_as_handled()
			return
		if (not event.pressed or world.enabled) and world.handle_key(event):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		world.handle_pointer(event)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if world:
			world.keys = {}
		if ui:
			ui.stick_release()
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if audio:
			audio.visibility(true)
	if what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		if audio:
			audio.visibility(false)


# ───── 복구 화면 ─────
func _show_recovery() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.base_theme()
	layer.add_child(root)
	var bg := ColorRect.new()
	bg.color = Color("#e8eedf")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var status := UIKit.label("", 14, "#d6644a")
	var confirm_box := UIKit.vbox([UIKit.label("원본을 먼저 내려받아 보관해 주세요. 새 게임을 시작하면 기존 저장을 교체합니다.", 15)])
	confirm_box.visible = false
	var raw = g.load_issue["raw"]
	var download := UIKit.button("원본 저장 내려받기", func(): _save_file(str(raw), "냥냥-원본저장-복구용.json"))
	download.disabled = raw == null
	var restore := UIKit.button("백업으로 복구", func(): _open_file(func(text):
		var err := g.import_save(text)
		if err != "":
			status.text = err
			return
		root.queue_free()
		_start()))
	var fresh := UIKit.button("새 게임 시작", func(): confirm_box.visible = true, "gray")
	confirm_box.add_child(UIKit.row([UIKit.button("취소", func(): confirm_box.visible = false, "gray"), UIKit.button("원본 교체하고 새 게임 시작", func():
		g.reset()
		root.queue_free()
		_start(), "peach")]))
	var dialog := UIKit.box([UIKit.h2("💾 저장 파일을 보호하고 있어요", 24), UIKit.label(g.load_issue["message"], 15),
		UIKit.hint("원본을 내려받거나, 이전에 백업한 정상 저장을 불러올 수 있어요. 새 게임을 선택하기 전까지 기존 저장은 바뀌지 않습니다."),
		UIKit.row([download, restore, fresh]), confirm_box, status], UIKit.PANEL, "#ffffff", 32, 6, 22)
	dialog.custom_minimum_size = Vector2(minf(640, get_viewport().get_visible_rect().size.x * 0.94), 0)
	center.add_child(dialog)


func _save_file(text: String, name: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(text.to_utf8_buffer(), name, "application/json")
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.current_file = name
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(text))
	add_child(dlg)
	dlg.popup_centered()


func _open_file(cb: Callable) -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json"])
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f and f.get_length() <= 10 * 1024 * 1024:
			cb.call(f.get_as_text()))
	add_child(dlg)
	dlg.popup_centered()
