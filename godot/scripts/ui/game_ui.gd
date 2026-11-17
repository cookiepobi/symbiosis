class_name GameUI
extends Control
## 웹 ui.js + index.html + style.css: 상단바, 장소 패널(우리집·교배·도감·동물샵·이웃), 모달, 토스트, 탭, 조이스틱.

var g: GameState
var world: WorldView
var audio: GameAudio
var dev := false
var U := {"tab": "home", "sel": null, "breed": {"father": null, "mother": null, "slot": "father", "src": "mine"},
	"open": false, "npc": null, "dexPage": 1, "dexGrade": -1, "dexSearch": "", "busy": false, "toolsOpen": false, "goalKey": ""}

# 노드
var top_bar: PanelContainer
var clock_label: Label
var brand: Label
var proto: Control
var clock_pill: Control
var top_row: HBoxContainer
var pills: Array = []
var income_btn: Button
var coins_label: Label
var sound_btn: Button
var hint_pill: Control
var panel: PanelContainer
var panel_scroll: ScrollContainer
var panel_body: VBoxContainer
var close_btn: Button
var tabs_box: HBoxContainer
var tab_buttons := {}
var modal: Control
var modal_dialog: PanelContainer
var modal_body: VBoxContainer
var toasts: VBoxContainer
var fx_layer: Control
var journey_bar: PanelContainer
var journey_label: Label
var watching_bar: PanelContainer
var watching_label: Label
var watching_id = null
var pen_button: Button
var stick: Control
var stick_knob: Panel
var breed_overlay: Control
var breed_stage: BreedStage
var lab_layer: Control

var countdowns: Array = []       # {label, until}
var cooldown_buttons: Array = []  # {button, until}
var activity_labels: Array = []   # {label, id}
var litter_label: Label
var pending_confirm: Callable
var dex_timer: Timer
var stick_touch := -1
var narrow := false


func setup(game: GameState, w: WorldView, a: GameAudio, development: bool) -> void:
	g = game
	world = w
	audio = a
	dev = development


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.base_theme()
	_build_layout()
	audio.set_volumes(Preferences.load_audio(g.storage))
	world.hooks = {
		"on_pen_anchor": _on_pen_anchor,
		"on_zone": func(id, _clicked): _handle_zone(id),
		"on_location": func(_z): _update_location_menus(),
		"on_journey": func(id):
			journey_bar.visible = id != null
			journey_label.text = "%s · 이동 중" % Locations.destination_name(id, g.npcs) if id != null else " ",
		"on_cat": _on_world_cat,
		"on_focus": func(id):
			watching_bar.visible = id != null
			watching_id = id
			watching_label.text = "%s 관찰 중 · %s" % [g.cat(id)["name"], world.activity_of(id)] if id != null else "",
		"on_clean": func(id):
			var r := g.care_daily(id, "clean")
			if r["ok"]:
				audio.play("clean")
				fx("🧹")
				toast("%s의 화장실을 치웠어요" % g.cat(id)["name"])
				render()
			else:
				toast(r["msg"]),
	}
	world.setup_npcs(g.npcs)
	world.check_zones()
	if U["sel"] == null or g.cat(U["sel"]) == null:
		U["sel"] = g.mine[0] if not g.mine.is_empty() else null
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_every_second)
	add_child(timer)
	dex_timer = Timer.new()
	dex_timer.one_shot = true
	dex_timer.wait_time = 0.18
	dex_timer.timeout.connect(func(): if U["open"] and U["tab"] == "dex": render())
	add_child(dex_timer)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	render()
	_show_capacity_notice()


# ───────────────────────── 레이아웃 ─────────────────────────
func _pill(child: Control, bg := "#ffffff") -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(bg, 99, 3, "#ffffff", Vector4(16, 4, 16, 4), 3, Color(0, 0, 0, 0.1)))
	p.add_child(child)
	return p


func _pill_button(text: String, cb: Callable, bg := "#ffffff") -> Button:
	var b := Button.new()
	b.text = text
	var st := UIKit.sb(bg, 99, 3, "#ffffff", Vector4(16, 4, 16, 4), 3, Color(0, 0, 0, 0.1))
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(k, st)
	b.add_theme_font_override("font", Fonts.title())
	b.add_theme_font_size_override("font_size", 16)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color(UIKit.INK))
	b.pressed.connect(cb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func _build_layout() -> void:
	# 상단바
	top_bar = PanelContainer.new()
	var top_style := UIKit.sb(UIKit.LEAF, 0, 0, "#ffffff", Vector4(20, 10, 20, 10))
	top_style.border_width_bottom = 5
	top_style.border_color = Color(UIKit.LEAF_D)
	top_bar.add_theme_stylebox_override("panel", top_style)
	add_child(top_bar)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 16)
	top_row = top
	top_bar.add_child(top)
	brand = UIKit.label("🐾 냥냥 유전 하우스", 22, "#ffffff", true, false)
	top.add_child(brand)
	proto = PanelContainer.new()
	proto.add_theme_stylebox_override("panel", UIKit.sb(Color(1, 1, 1, 0.25), 99, 0, "#ffffff", Vector4(8, 2, 8, 2)))
	proto.add_child(UIKit.label("prototype", 11, "#ffffff", true, false))
	proto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(proto)
	clock_label = UIKit.label("", 14, "#ffffff", true, false)
	clock_pill = PanelContainer.new()
	clock_pill.add_theme_stylebox_override("panel", UIKit.sb(Color(1, 1, 1, 0.2), 99, 0, "#ffffff", Vector4(14, 4, 14, 4)))
	clock_pill.add_child(clock_label)
	clock_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(clock_pill)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fill)
	sound_btn = _pill_button("🔇", _toggle_sound)
	sound_btn.tooltip_text = "소리 켜기"
	top.add_child(sound_btn)
	income_btn = _pill_button("🐾 수입 받기 +0냥", _collect_income, "#fff6d6")
	top.add_child(income_btn)
	coins_label = UIKit.label("🐾 0냥", 16, UIKit.PEACH_D, true, false)
	var coins_pill := _pill(coins_label)
	top.add_child(coins_pill)
	pills = [sound_btn, income_btn, coins_label]
	if dev:
		var devrow := HBoxContainer.new()
		devrow.modulate.a = 0.7
		for d in [["+1시간", func(): _dev("1h")], ["+1일", func(): _dev("1d")], ["새 게임", func(): _dev("reset")]]:
			var b := UIKit.button(d[0], d[1], "gray" if d[0] != "새 게임" else "peach", true)
			b.add_theme_font_size_override("font_size", 11)
			devrow.add_child(b)
		top.add_child(devrow)

	# 안내 문구
	var hint_label := UIKit.label("🕹️ WASD·방향키 또는 클릭으로 이동 · 고양이를 클릭하면 돌보기 · 🛍️동물샵 / 💞교배집 / 이웃 우리에 다가가 보세요", 13, UIKit.INK2, false, false)
	hint_pill = PanelContainer.new()
	hint_pill.add_theme_stylebox_override("panel", UIKit.sb(Color("#fffaf0e0"), 99, 3, "#ffffff", Vector4(18, 4, 18, 4)))
	hint_pill.add_child(hint_label)
	hint_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint_pill)

	# 월드 위 우리 업그레이드 버튼
	pen_button = Button.new()
	var pst := UIKit.sb("#fff8dc", 16, 3, "#73a94e", Vector4(13, 9, 13, 9), 4, Color(0.19, 0.28, 0.14, 0.27))
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		pen_button.add_theme_stylebox_override(k, pst)
	pen_button.add_theme_font_override("font", Fonts.title())
	pen_button.add_theme_font_size_override("font_size", 14)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		pen_button.add_theme_color_override(k, Color("#334b24"))
	pen_button.pressed.connect(func(): _act("upgradepen"))
	pen_button.visible = false
	add_child(pen_button)

	# 장소 패널
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.sb(UIKit.PANEL, 32, 6, "#ffffff", Vector4(18, 34, 10, 18), 6))
	panel.visible = false
	add_child(panel)
	panel_scroll = ScrollContainer.new()
	panel_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(panel_scroll)
	panel_body = VBoxContainer.new()
	panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_body.add_theme_constant_override("separation", 8)
	panel_scroll.add_child(panel_body)
	var x := Button.new()
	x.text = "✕"
	var xs := UIKit.sb(UIKit.PEACH, 18, 3, "#ffffff", Vector4(0, 0, 0, 0), 3, Color(UIKit.PEACH_D))
	for k in ["normal", "hover", "pressed", "focus"]:
		x.add_theme_stylebox_override(k, xs)
	x.add_theme_color_override("font_color", Color.WHITE)
	x.custom_minimum_size = Vector2(36, 36)
	x.pressed.connect(_close_panel)
	close_btn = x
	add_child(x)

	# 관찰 중 표시
	watching_bar = PanelContainer.new()
	watching_bar.add_theme_stylebox_override("panel", UIKit.sb(Color("#fffaf0ed"), 20, 3, "#ffffff", Vector4(14, 8, 14, 8)))
	var wrow := HBoxContainer.new()
	wrow.add_theme_constant_override("separation", 10)
	watching_label = UIKit.label("", 13, UIKit.INK, true, false)
	wrow.add_child(watching_label)
	wrow.add_child(UIKit.button("집사에게 돌아가기", func(): world.stop_watching(), "gray", true))
	wrow.add_child(UIKit.label("화면을 드래그하면 회전해요", 11, UIKit.INK2, false, false))
	watching_bar.add_child(wrow)
	watching_bar.visible = false
	add_child(watching_bar)

	# 이동 중 표시
	journey_bar = PanelContainer.new()
	journey_bar.add_theme_stylebox_override("panel", UIKit.sb(Color("#fffaf0eb"), 20, 3, "#ffffff", Vector4(15, 9, 15, 9)))
	var jrow := HBoxContainer.new()
	jrow.add_theme_constant_override("separation", 10)
	journey_label = UIKit.label("", 13, UIKit.INK, true, false)
	jrow.add_child(journey_label)
	jrow.add_child(UIKit.button("이동 취소", func(): world.cancel_journey(), "gray", true))
	journey_bar.add_child(jrow)
	journey_bar.visible = false
	add_child(journey_bar)

	# 하단 탭
	tabs_box = HBoxContainer.new()
	tabs_box.add_theme_constant_override("separation", 5)
	add_child(tabs_box)
	for t in [["home", "🐱", "내 고양이"], ["breed", "💞", "교배"], ["shop", "🛍️", "동물샵"], ["npc", "🏘️", "이웃"], ["dex", "📖", "도감"], ["map", "🧭", "지도"]]:
		var b := Button.new()
		b.text = "%s\n%s" % [t[1], t[2]]
		b.add_theme_font_override("font", Fonts.title())
		b.add_theme_font_size_override("font_size", 14)
		b.custom_minimum_size = Vector2(0, 58)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var tab: String = t[0]
		b.pressed.connect(func():
			if tab == "map":
				_act("mapguide")
			elif not U["busy"] and not modal.visible:
				_goto_tab(tab))
		tabs_box.add_child(b)
		tab_buttons[t[0]] = b

	# 효과 레이어·토스트
	fx_layer = Control.new()
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	toasts = VBoxContainer.new()
	toasts.alignment = BoxContainer.ALIGNMENT_END
	toasts.add_theme_constant_override("separation", 8)
	toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toasts)

	# 터치 조이스틱
	stick = Panel.new()
	stick.custom_minimum_size = Vector2(116, 116)
	stick.size = Vector2(116, 116)
	stick.add_theme_stylebox_override("panel", UIKit.sb(Color(1, 1, 1, 0.4), 58, 3, Color(1, 1, 1, 0.6)))
	stick_knob = Panel.new()
	stick_knob.size = Vector2(48, 48)
	stick_knob.position = Vector2(31, 31)
	stick_knob.add_theme_stylebox_override("panel", UIKit.sb(Color("#ffffffe8"), 24, 2, "#c4d5ad"))
	stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stick.add_child(stick_knob)
	var cap := UIKit.label("이동", 11, "#506d4e", true, false)
	cap.position = Vector2(0, 96)
	cap.size = Vector2(116, 16)
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stick.add_child(cap)
	stick.gui_input.connect(_on_stick_input)
	add_child(stick)

	# 교배 연출
	breed_overlay = Control.new()
	breed_overlay.visible = false
	var grad_tex := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.62, 0.6201, 1.0])
	grad.colors = PackedColorArray([Color("#e7f5ff"), Color("#fff6df"), Color("#f4d8b0"), Color("#f4d8b0")])
	grad_tex.gradient = grad
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	var bg := TextureRect.new()
	bg.texture = grad_tex
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	breed_overlay.add_child(bg)
	var svc := SubViewportContainer.new()
	svc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	breed_stage = BreedStage.new()
	svc.add_child(breed_stage)
	breed_overlay.add_child(svc)
	var cap2 := _pill(UIKit.label("두근두근… 💞", 28, UIKit.INK, true, false), UIKit.PANEL)
	cap2.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	cap2.position.y = 90
	breed_overlay.add_child(cap2)
	cap2.resized.connect(func(): cap2.position.x = (breed_overlay.size.x - cap2.size.x) / 2)
	var skip := UIKit.button("연출 건너뛰기", func(): breed_stage.clear(), "gray")
	breed_overlay.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	breed_overlay.resized.connect(func():
		skip.position = Vector2((breed_overlay.size.x - skip.size.x) / 2, breed_overlay.size.y - 40 - skip.size.y)
		cap2.position.x = (breed_overlay.size.x - cap2.size.x) / 2)
	add_child(breed_overlay)

	# 모달
	modal = Control.new()
	modal.visible = false
	var dim := ColorRect.new()
	dim.color = Color(90 / 255.0, 60 / 255.0, 30 / 255.0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_close_modal())
	modal.add_child(dim)
	modal_dialog = PanelContainer.new()
	modal_dialog.add_theme_stylebox_override("panel", UIKit.sb(UIKit.PANEL, 32, 6, "#ffffff", Vector4(22, 22, 14, 22), 6))
	var ms := ScrollContainer.new()
	ms.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal_dialog.add_child(ms)
	modal_body = VBoxContainer.new()
	modal_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	modal_body.add_theme_constant_override("separation", 8)
	ms.add_child(modal_body)
	modal.add_child(modal_dialog)
	add_child(modal)

	lab_layer = Control.new()
	lab_layer.visible = false
	add_child(lab_layer)


func _on_resize() -> void:
	var vp := get_viewport_rect().size
	position = Vector2.ZERO
	size = vp
	for full in [modal, breed_overlay, lab_layer, fx_layer]:
		full.position = Vector2.ZERO
		full.size = vp
	narrow = vp.x < 760
	# 웹 @media (max-width:760px): 시계·prototype 숨김, 글자 축소
	proto.visible = not narrow
	clock_pill.visible = not narrow
	brand.add_theme_font_size_override("font_size", 13 if narrow else 22)
	top_row.add_theme_constant_override("separation", 4 if narrow else 16)
	for pc in pills:
		pc.add_theme_font_size_override("font_size", 11 if narrow else 16)
	top_bar.get_theme_stylebox("panel").content_margin_left = 10 if narrow else 20
	top_bar.get_theme_stylebox("panel").content_margin_right = 10 if narrow else 20
	var top_h := top_bar.get_combined_minimum_size().y
	top_bar.position = Vector2.ZERO
	top_bar.size = Vector2(vp.x, top_h)
	hint_pill.visible = not narrow
	hint_pill.position = Vector2((vp.x - hint_pill.get_combined_minimum_size().x) / 2, 62)
	var tabs_min := tabs_box.get_combined_minimum_size()
	tabs_box.position = Vector2((vp.x - tabs_min.x) / 2, vp.y - tabs_min.y - 6)
	tabs_box.size = tabs_min
	if narrow:
		panel.position = Vector2(8, 56)
		panel.size = Vector2(vp.x - 16, vp.y - 56 - 100)
	else:
		var w := minf(440.0, vp.x - 32)
		panel.position = Vector2(vp.x - 16 - w, top_h + 8)
		panel.size = Vector2(w, vp.y - (top_h + 8) - 104)
	close_btn.position = panel.position + Vector2(panel.size.x - 14 - 36, 10)
	close_btn.size = Vector2(36, 36)
	var jm := journey_bar.get_combined_minimum_size()
	journey_bar.position = Vector2((vp.x - jm.x) / 2, vp.y - 100 - jm.y)
	var wm := watching_bar.get_combined_minimum_size()
	watching_bar.position = Vector2((vp.x - wm.x) / 2, 62 if narrow else 105)
	toasts.size = Vector2(vp.x, 300)
	toasts.position = Vector2(0, vp.y - 110 - 300)
	stick.position = Vector2(22, vp.y - 116 - 116)
	var dw := minf(640.0, vp.x * 0.94)
	modal_dialog.size = Vector2(dw, 0)
	_fit_modal()


func _fit_modal() -> void:
	var vp := get_viewport_rect().size
	var dw := modal_dialog.size.x
	var content_h := modal_body.get_combined_minimum_size().y + 44 + 12
	var h := minf(content_h, vp.y * 0.9)
	modal_dialog.size = Vector2(dw, h)
	modal_dialog.position = Vector2((vp.x - dw) / 2, (vp.y - h) / 2)


func _panel_width() -> float:
	return panel.size.x - 28 - 12


# ───────────────────────── 공통 ─────────────────────────
func toast(msg: String) -> void:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sb(UIKit.PANEL, 99, 4, "#ffffff", Vector4(22, 10, 22, 10), 6))
	p.add_child(UIKit.label(msg, 17, UIKit.INK, true, false))
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toasts.add_child(p)
	p.modulate.a = 0
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.3)
	get_tree().create_timer(3.2).timeout.connect(func(): if is_instance_valid(p): p.queue_free())


func fx(emoji: String, n := 5) -> void:
	var r := get_viewport_rect().size
	for i in n:
		var l := UIKit.label(emoji, 34, UIKit.INK, false, false)
		l.position = Vector2(r.x * (0.35 + randf() * 0.3), r.y * (0.45 + randf() * 0.2))
		l.modulate.a = 0
		l.scale = Vector2(0.6, 0.6)
		fx_layer.add_child(l)
		var tw := create_tween()
		tw.tween_interval(i * 0.08)
		tw.tween_property(l, "modulate:a", 1.0, 0.2)
		tw.parallel().tween_property(l, "scale", Vector2(1.1, 1.1), 0.2)
		tw.parallel().tween_property(l, "position:y", l.position.y - 20, 0.2)
		tw.tween_property(l, "position:y", l.position.y - 140, 1.1)
		tw.parallel().tween_property(l, "modulate:a", 0.0, 1.1)
		tw.tween_callback(l.queue_free)


func _personality_chip(c: Dictionary) -> Control:
	if c.get("personality") == null:
		return UIKit.chip("🍼 성장 중")
	var p: Dictionary = Personality.PERSONALITIES[c["personality"]]
	return UIKit.chip("%s %s" % [p["emoji"], p["name"]])


func _tags(c: Dictionary) -> Array:
	var t := []
	if c.get("special") != null:
		t.append(UIKit.chip("⭐ " + CatEngine.SPECIALS[c["special"]]))
	if c.get("fantasy") != null:
		t.append(UIKit.chip("✨ " + CatEngine.FANTASY[c["fantasy"]]))
	if c.get("costume") != null:
		t.append(UIKit.chip("👒 " + CatEngine.costume_name(c["costume"])))
	return t


func _badge(c: Dictionary) -> Control:
	return UIKit.badge(CatEngine.grade_label(c), CatEngine.grade_color(c))


func _desc(c: Dictionary) -> String:
	var s := ""
	if c.get("special") != null:
		s += CatEngine.SPECIALS[c["special"]] + " · "
	if c.get("fantasy") != null:
		s += CatEngine.FANTASY[c["fantasy"]] + " · "
	return s + CatEngine.phenotype_name(c)


func _card(c: Dictionary, opts := {}) -> Control:
	var sel: bool = opts.get("sel", false)
	var dis: bool = opts.get("dis", false)
	var normal := UIKit.sb("#fff3ea" if sel else "#ffffff", 22, 3, UIKit.PEACH if sel else UIKit.LINE, Vector4(8, 8, 8, 8))
	var hover := UIKit.sb("#fff3ea" if sel else "#ffffff", 22, 3, UIKit.PEACH if sel else UIKit.LEAF, Vector4(8, 8, 8, 8))
	var card := ClickCard.new().setup(normal, hover, dis)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var img := UIKit.thumb_bg(c, 130, 100)
	v.add_child(img)
	var nm := UIKit.rich("[center]%s %s[/center]" % [c["name"], UIKit.sex_text(c)], 15)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nm)
	var brow := CenterContainer.new()
	brow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brow.add_child(_badge(c))
	v.add_child(brow)
	if opts.has("meta_node"):
		v.add_child(opts["meta_node"])
	else:
		var meta := UIKit.label(opts.get("meta", ""), 12, UIKit.INK2)
		meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		meta.custom_minimum_size = Vector2(0, 16)
		v.add_child(meta)
	if opts.has("actions"):
		var ar := UIKit.row(opts["actions"], 4)
		ar.alignment = FlowContainer.ALIGNMENT_CENTER
		v.add_child(ar)
		card.mouse_filter = Control.MOUSE_FILTER_PASS
	card.add_child(v)
	if opts.has("on"):
		card.pressed.connect(opts["on"])
	return card


func _countdown(until: float, prefix := "", suffix := "") -> Label:
	var l := UIKit.label(prefix + UIKit.fmt(maxf(0, until - g.now())) + suffix, 12, UIKit.INK2)
	countdowns.append({"label": l, "until": until, "prefix": prefix, "suffix": suffix})
	return l


func _litter_summary(state: Dictionary) -> String:
	if state["total"]:
		return "🧹 화장실 청소 %d개 · 우리 안 화장실을 클릭하거나 아래 청소 버튼을 눌러 주세요." % state["total"]
	return "✨ 우리 안 화장실이 깨끗해요."


# ───────────────────────── 렌더 ─────────────────────────
func render() -> void:
	_update_location_menus()
	stick.visible = (narrow or DisplayServer.is_touchscreen_available()) and not U["open"] and not U["busy"] and not modal.visible
	for t in tab_buttons:
		if t == "map":
			_style_tab(tab_buttons[t], false)
			continue
		_style_tab(tab_buttons[t], U["open"] and U["tab"] == t)
	coins_label.text = "🐾 %s냥" % _comma(int(g.coins))
	income_btn.text = "🐾 수입 받기 +%s냥" % _comma(g.pending_income())
	_update_clock()
	countdowns = countdowns.filter(func(c): return is_instance_valid(c["label"]) and c["label"].is_inside_tree() and not panel.is_ancestor_of(c["label"]))
	cooldown_buttons = cooldown_buttons.filter(func(c): return is_instance_valid(c["button"]) and not panel.is_ancestor_of(c["button"]))
	activity_labels = activity_labels.filter(func(c): return is_instance_valid(c["label"]) and not panel.is_ancestor_of(c["label"]))
	close_btn.visible = U["open"]
	if not U["open"]:
		panel.visible = false
	else:
		var scroll := panel_scroll.scroll_vertical
		for ch in panel_body.get_children():
			ch.queue_free()
		panel.visible = true
		match U["tab"]:
			"home":
				_home_view()
			"breed":
				_breed_view()
			"dex":
				_dex_view()
			"shop":
				_shop_view()
			"npc":
				_npc_view()
		await get_tree().process_frame
		panel_scroll.scroll_vertical = scroll
	_sync_world()


func _style_tab(b: Button, on: bool) -> void:
	var st := UIKit.sb(UIKit.PEACH if on else "#fff8e6", 24, 4, "#ffffff", Vector4(14, 6, 14, 6), 5, Color(UIKit.PEACH_D) if on else Color(0.71, 0.55, 0.35, 0.2))
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, st)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color.WHITE if on else Color(UIKit.INK))


static func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


func _sync_world() -> void:
	var pen := g.pen_status()
	world.sync_pen(pen["level"], pen["capacity"], pen["count"])
	pen_button.text = "⬆ 업그레이드" if pen["next"] != null else "✓ 확장 완료"
	pen_button.disabled = pen["next"] == null
	var d := []
	for c in g.my_cats():
		d.append({"cat": c, "pen": "mine"})
	for n in g.npcs:
		for id in n["cats"]:
			var c = g.cat(id)
			if c != null:
				d.append({"cat": c, "pen": "npc:" + n["id"]})
	world.sync(d)
	world.sync_litter(Wellbeing.litter_state(g.my_cats(), g.now()))


func _on_pen_anchor(p: Dictionary) -> void:
	pen_button.visible = p["visible"] and not U["open"] and not U["busy"] and not modal.visible
	var s := pen_button.get_combined_minimum_size()
	pen_button.position = Vector2(p["x"] - s.x / 2, p["y"] - s.y)


func _update_clock() -> void:
	var d := Time.get_datetime_dict_from_unix_time(int(g.now() / 1000.0 + Time.get_time_zone_from_system()["bias"] * 60))
	clock_label.text = "🕒 %d/%d %02d:%02d" % [d["month"], d["day"], d["hour"], d["minute"]]


func _current_goal(cats: Array = []) -> Dictionary:
	if cats.is_empty():
		cats = g.my_cats().duplicate()
		cats.reverse()
	var baby = null
	for c in cats:
		if c.get("personality") == null:
			baby = c["id"]
			break
	var ready := false
	for f in cats:
		if f["sex"] != "M":
			continue
		for m in cats:
			if m["sex"] == "F" and g.check_breed(f, m) == "":
				ready = true
	return Locations.next_step(g.pen_status(), int(g.coins), g.pending_income(), baby, ready)


# ───── 우리집 ─────
func _home_view() -> void:
	var cats := g.my_cats().duplicate()
	cats.reverse()
	var c = g.cat(U["sel"])
	var t := g.now()
	var daily := 0.0
	for x in cats:
		daily += CatEngine.income_per_hour(x) * 24
	var head := UIKit.row([UIKit.h2("🏠 우리집"), UIKit.hint("고양이 %d마리 · 하루 수입 %d" % [cats.size(), roundi(daily)])], 8, false)
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	panel_body.add_child(head)
	var litter := Wellbeing.litter_state(cats, t)
	var pen := g.pen_status()
	var goal := _current_goal(cats)
	U["goalKey"] = JSON.stringify(goal)
	var pen_items := [UIKit.label("🌿 우리 Lv.%d · %d/%d마리" % [pen["level"], pen["count"], pen["capacity"]], 16, UIKit.INK2, true)]
	if pen["over"] > 0:
		pen_items.append(UIKit.label("정원 %d마리 초과 · 판매 또는 확장 후 추가 교배할 수 있어요." % pen["over"], 13, "#d6644a"))
	else:
		pen_items.append(UIKit.label("빈자리 %d마리 · 새끼가 지낼 빈자리가 있어야 교배할 수 있어요." % (pen["capacity"] - pen["count"]), 13))
	if pen["next"] != null:
		var nx: Dictionary = pen["next"]
		pen_items.append(UIKit.row([UIKit.button("우리 확장 · %d마리 (+%d) · %d냥" % [nx["capacity"], nx["capacity"] - pen["capacity"], nx["cost"]], func(): _act("upgradepen"), "leaf", true, g.coins < nx["cost"])]))
		if g.coins < nx["cost"]:
			pen_items.append(UIKit.hint("%d냥 더 모으면 확장할 수 있어요." % (nx["cost"] - int(g.coins))))
	else:
		pen_items.append(UIKit.label("가장 넓은 우리예요.", 13))
	if pen["over"] > 0:
		pen_items.append(UIKit.row([UIKit.button("🛍️ 판매하러 동물샵 가기", func(): _navigate("shop"), "gray", true)]))
	panel_body.add_child(UIKit.box(pen_items, "#eef3e5", "#d4dfc3", 16, 2, 12))
	litter_label = UIKit.hint(_litter_summary(litter))
	panel_body.add_child(litter_label)
	var gbtn := UIKit.button(goal["label"], func(): _act(goal["act"], goal), "gray", true)
	panel_body.add_child(UIKit.box([UIKit.label("다음 할 일 · " + goal["title"], 13, UIKit.INK, true), UIKit.label(goal["text"], 12), UIKit.row([gbtn])], "#fff0d5", "#fff0d5", 14, 0, 11))
	if g.save_error != "":
		panel_body.add_child(UIKit.label(g.save_error, 14, "#d6644a"))
	if c != null:
		panel_body.add_child(_detail_box(c, t))
	panel_body.add_child(UIKit.h3("우리 고양이들"))
	var cards := []
	for x in cats:
		var gr := Personality.growth_remaining(x, t)
		var id: String = x["id"]
		var opts := {"sel": id == U["sel"], "on": func(): U["sel"] = id; render()}
		if gr > 0:
			opts["meta_node"] = _countdown(float(x["birthTime"]) + Params.GROWTH_WINDOW_MS, "🍼 ")
			opts["meta_node"].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var p: Dictionary = Personality.PERSONALITIES[x["personality"]]
			opts["meta"] = "%s %s" % [p["emoji"], p["name"]]
		cards.append(_card(x, opts))
	panel_body.add_child(UIKit.grid(cards, _panel_width()))
	if cats.is_empty():
		panel_body.add_child(UIKit.label("우리집이 비었어요. 도감은 그대로 보관됩니다. 진행을 백업하거나 새 게임을 시작할 수 있어요.", 13, UIKit.INK2))
		panel_body.add_child(UIKit.row([UIKit.button("새 게임 시작", func(): _dev("reset"), "gray", true)]))
	var tools_btn := Button.new()
	tools_btn.text = ("▼ " if U["toolsOpen"] else "▶ ") + "우리 확장 계획 · 진행 백업 · 설정"
	tools_btn.flat = true
	tools_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tools_btn.add_theme_font_override("font", Fonts.title())
	tools_btn.add_theme_color_override("font_color", Color(UIKit.INK))
	tools_btn.add_theme_color_override("font_hover_color", Color(UIKit.INK))
	tools_btn.pressed.connect(func(): U["toolsOpen"] = not U["toolsOpen"]; render())
	panel_body.add_child(UIKit.spacer(10))
	panel_body.add_child(tools_btn)
	if U["toolsOpen"]:
		panel_body.add_child(UIKit.row([
			UIKit.button("🌿 우리 확장 계획", _show_pen_levels, "gray", true),
			UIKit.button("🧭 장소 안내", _show_map, "gray", true),
			UIKit.button("💾 진행 백업", _backup, "gray", true),
			UIKit.button("📂 백업 불러오기", _restore, "gray", true),
			UIKit.button("🎵 소리 설정", _show_audio_settings, "gray", true),
			UIKit.button("새 게임", func(): _dev("reset"), "gray", true)]))


func _detail_box(c: Dictionary, t: float) -> Control:
	var gr := Personality.growth_remaining(c, t)
	var items := []
	items.append(UIKit.row([_badge(c), _personality_chip(c)] + _tags(c), 4))
	items.append(UIKit.hint(_desc(c)))
	var act := UIKit.label("🐾 " + world.activity_of(c["id"]), 13, "#58724c")
	activity_labels.append({"label": act, "id": c["id"]})
	items.append(UIKit.box([act], "#edf3e5", "#edf3e5", 12, 0, 7))
	var id: String = c["id"]
	if gr > 0:
		var p := 1.0 - gr / Params.GROWTH_WINDOW_MS
		var line := HBoxContainer.new()
		var lt := UIKit.label("🍼 성격 형성 중 (탄생 후 1시간 돌봄)", 14, UIKit.INK, false, false)
		lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(lt)
		line.add_child(_countdown(float(c["birthTime"]) + Params.GROWTH_WINDOW_MS))
		items.append(line)
		items.append(UIKit.bar(p))
		var care_cards := []
		for a in Personality.CARE_ACTIONS:
			var cd := Personality.care_cooldown(c, a["id"], t)
			var aid: String = a["id"]
			var cc := _care_button(a["icon"], a["name"], UIKit.fmt(cd) if cd > 0 else " ", cd > 0, func(): _do_care(id, aid))
			if cd > 0:
				cooldown_buttons.append({"button": cc, "until": t + cd})
			care_cards.append(cc)
		items.append(UIKit.grid(care_cards, _panel_width() - 30, 130, 8))
		items.append(UIKit.hint("어떻게 돌보느냐에 따라 확률적으로 성격이 정해져요. (같은 돌봄이라도 결과는 달라질 수 있어요)"))
	else:
		var pp: Dictionary = Personality.PERSONALITIES[c["personality"]]
		items.append(UIKit.box([UIKit.rich("%s [b]%s[/b] — %s" % [pp["emoji"], pp["name"], pp["desc"]], 14), UIKit.hint(pp["act"])], "#ffffff", UIKit.LINE, 22, 3, 12))
	items.append(UIKit.h3("오늘의 돌봄"))
	var daily := []
	for a in Wellbeing.comfort(c, t):
		if gr > 0 and a["id"] != "clean":
			continue
		var aid2: String = a["id"]
		daily.append(_care_button(a["icon"], a["name"], "편안함 %d%%" % a["value"], false, func(): _do_daily(id, aid2)))
	items.append(UIKit.grid(daily, _panel_width() - 30, 130, 8))
	items.append(UIKit.hint("성장 후에도 매일 돌볼 수 있어요. 편안함은 성격·유전·교배 확률에 영향을 주지 않아요."))
	items.append(UIKit.row([
		UIKit.button("🔎 월드에서 보기", func(): world.focus_cat(id); _close_panel(), "leaf", true),
		UIKit.button("🧬 유전자·가계도", func(): _show_detail(id, false), "leaf", true),
		UIKit.button("💞 교배하기", func(): _go_breed(id), "peach", true, gr > 0),
		UIKit.button("판매 %d냥" % CatEngine.sell_price(c), func(): _sell(id), "gray", true)]))
	var cd_left := maxf(0, float(c["lastBreedAt"]) + Params.BREED_COOLDOWN_MS - t)
	var info := HBoxContainer.new()
	info.add_child(UIKit.hint("하루 수입 %d냥 · " % int(CatEngine.income_per_hour(c) * 24)))
	if gr > 0:
		info.add_child(UIKit.hint("성장 후 교배 가능"))
	elif cd_left > 0:
		info.add_child(_countdown(float(c["lastBreedAt"]) + Params.BREED_COOLDOWN_MS, "교배 쿨다운 "))
	else:
		info.add_child(UIKit.hint("교배 가능"))
	items.append(info)
	return UIKit.box(items)


func _care_button(icon: String, name: String, small: String, disabled: bool, cb: Callable) -> Control:
	var card := ClickCard.new().setup(UIKit.sb("#ffffff", 18, 3, UIKit.LINE, Vector4(8, 8, 8, 8)), UIKit.sb("#ffffff", 18, 3, UIKit.LEAF, Vector4(8, 8, 8, 8)), disabled)
	if disabled:
		card.modulate.a = 0.45
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for l in [UIKit.label(icon, 26, UIKit.INK, false, false), UIKit.label(name, 14, UIKit.INK, true, false), UIKit.label(small, 12, UIKit.INK2, false, false)]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
	card.add_child(v)
	card.pressed.connect(cb)
	return card


# ───── 교배 ─────
func _candidate_list(slot: String, src: String) -> Array:
	var need := "M" if slot == "father" else "F"
	var other = g.cat(U["breed"]["mother"] if slot == "father" else U["breed"]["father"])
	var t := g.now()
	var list: Array
	if src == "mine":
		list = g.my_cats()
	elif src == "shop":
		list = g.shop_cats()
	else:
		list = []
		for n in g.npcs:
			for id in n["cats"]:
				list.append(g.cat(id))
	var out := []
	for c in list:
		if c["sex"] != need:
			continue
		var reason := ""
		if c.get("personality") == null:
			reason = "아기"
		elif src != "shop" and t - float(c["lastBreedAt"]) < Params.BREED_COOLDOWN_MS:
			reason = "쿨다운"
		elif other != null and CatEngine.is_forbidden_pair(c, other) != "":
			reason = "근친"
		out.append({"c": c, "reason": reason})
	return out


func _src_label(c: Dictionary) -> String:
	var s := g.source_of(c["id"])
	if s == "mine":
		return "내 고양이"
	if s == "shop":
		return "동물샵 · %d냥" % CatEngine.shop_breed_price(c)
	if s.begins_with("npc"):
		for n in g.npcs:
			if "npc:" + n["id"] == s:
				return n["name"] + "의 고양이"
	return ""


func _breed_view() -> void:
	var B: Dictionary = U["breed"]
	var f = g.cat(B["father"])
	var m = g.cat(B["mother"])
	panel_body.add_child(UIKit.h2("💞 교배"))
	panel_body.add_child(UIKit.label("수컷 1 + 암컷 1. 새끼는 항상 1마리, 신청자(나)가 데려가요. 교배한 고양이는 24시간 쉬어요.", 13, UIKit.INK2))
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 8)
	slots.add_child(_slot("father", f, "아빠(수컷)"))
	var heart := UIKit.label("💕", 28, UIKit.INK, false, false)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slots.add_child(heart)
	slots.add_child(_slot("mother", m, "엄마(암컷)"))
	panel_body.add_child(slots)
	var pen := g.pen_status()
	if pen["count"] == pen["capacity"]:
		panel_body.add_child(UIKit.label("지금 정원이 가득 찼어요. 판매하거나 우리를 확장해 빈자리를 마련해야 교배할 수 있어요.", 14, "#d6644a"))
	var msg := g.check_breed(f, m) if f != null and m != null else "아빠와 엄마를 골라 주세요"
	var cost := g.breed_cost(f, m) if f != null and m != null else 0
	var mtxt := msg if msg != "" else "교배할 수 있어요! " + ("(샵 비용 %d냥)" % cost if cost else "(무료)")
	panel_body.add_child(UIKit.label(mtxt, 14, "#d6644a" if msg != "" else "#4fa164"))
	panel_body.add_child(UIKit.row([UIKit.button("💞 교배하기", _run_breed, "peach", false, msg != ""), UIKit.button("비우기", func(): B["father"] = null; B["mother"] = null; B["slot"] = "father"; render(), "gray", true)]))
	panel_body.add_child(UIKit.h3("%s 고르기" % ("아빠" if B["slot"] == "father" else "엄마")))
	var srcs := []
	for s in [["mine", "🏠 내 고양이"], ["npc", "🏘️ 이웃"], ["shop", "🛍️ 동물샵"]]:
		var key: String = s[0]
		srcs.append(UIKit.chip(s[1], B["src"] == key, func(): B["src"] = key; render()))
	panel_body.add_child(UIKit.row(srcs, 4))
	var list := _candidate_list(B["slot"], B["src"])
	var cards := []
	for e in list:
		var c: Dictionary = e["c"]
		var id: String = c["id"]
		var meta: String = ("❌ " + e["reason"]) if e["reason"] != "" else ("%d냥" % CatEngine.shop_breed_price(c) if B["src"] == "shop" else ("이웃의 고양이" if B["src"] == "npc" else ""))
		cards.append(_card(c, {"dis": e["reason"] != "", "sel": id == B[B["slot"]], "meta": meta, "on": func():
			B[B["slot"]] = id
			B["slot"] = "mother" if B["slot"] == "father" else "father"
			render()}))
	panel_body.add_child(UIKit.grid(cards, _panel_width()))
	if list.is_empty():
		panel_body.add_child(UIKit.label("후보가 없어요.", 13, UIKit.INK2))


func _slot(key: String, c, title: String) -> Control:
	var B: Dictionary = U["breed"]
	var on: bool = B["slot"] == key
	var st := UIKit.sb("#fff3ea" if on else "#ffffff", 22, 3, UIKit.PEACH if on else UIKit.LINE, Vector4(10, 10, 10, 10))
	var card := ClickCard.new().setup(st, st)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(0, 150)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := UIKit.hint(title)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if c != null:
		var cc := CenterContainer.new()
		cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cc.add_child(UIKit.thumb(c, 110, 96))
		v.add_child(cc)
		var r := UIKit.row([UIKit.label(c["name"], 14, UIKit.INK, true, false), _badge(c)], 4)
		r.alignment = FlowContainer.ALIGNMENT_CENTER
		v.add_child(r)
		var s := UIKit.hint(_src_label(c))
		s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(s)
	else:
		var plus := UIKit.label("＋", 40, UIKit.INK, false, false)
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(plus)
	card.add_child(v)
	card.pressed.connect(func(): B["slot"] = key; render())
	return card


func _run_breed() -> void:
	if U["busy"]:
		return
	if not world.can_open("breed"):
		_navigate("breed")
		return
	var B: Dictionary = U["breed"]
	var f = g.cat(B["father"])
	var m = g.cat(B["mother"])
	var r := g.do_breed(B["father"], B["mother"])
	if r.has("error"):
		toast(r["error"])
		return
	audio.play("breed")
	U["busy"] = true
	world.enabled = false
	world.suspended = true
	U["open"] = false
	render()
	breed_overlay.visible = true
	breed_stage.play_breed(f, m, r["kitten"])
	await breed_stage.finished
	breed_overlay.visible = false
	U["busy"] = false
	world.enabled = true
	world.suspended = false
	B["father"] = null
	B["mother"] = null
	B["slot"] = "father"
	U["sel"] = r["kitten"]["id"]
	U["tab"] = "home"
	U["open"] = true
	render()
	_show_result(r)


func _show_result(r: Dictionary) -> void:
	audio.play("birth")
	var k: Dictionary = r["kitten"]
	var items := [UIKit.h2("🎉 새 가족이 태어났어요!", 24)]
	var pen := g.pen_status()
	if pen["over"] > 0:
		items.append(UIKit.label("정원을 %d마리 초과했어요. 새끼는 임시 보호 중이에요. 동물샵에서 판매하거나 우리를 확장해야 추가 교배할 수 있어요." % pen["over"], 14, "#d6644a"))
	var info := UIKit.vbox([UIKit.row([UIKit.rich_inline("%s %s" % [k["name"], UIKit.sex_text(k)], 22), _badge(k)], 6), UIKit.row(_tags(k), 4), UIKit.hint(_desc(k)),
		UIKit.box([UIKit.label("부: %s · 모: %s" % [r["father"]["name"], r["mother"]["name"]], 14),
			UIKit.label(("비용 %d냥" % r["cost"]) if r["cost"] else "", 14) if r["cost"] else null,
			UIKit.label("📖 새 도감 등록! +%d냥" % r["reward"] if r["reward"] else "이미 도감에 있는 모습이에요", 14)]),
		UIKit.hint("🍼 앞으로 1시간 동안 돌봐 주면 성격이 정해져요.")])
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UIKit.thumb_bg(k, 220, 200, 20))
	row.add_child(info)
	items.append(row)
	var btns := UIKit.row([UIKit.button("우리집에서 돌보기", func(): _close_modal(); _goto_tab("home")), UIKit.button("닫기", _close_modal, "gray")])
	btns.alignment = FlowContainer.ALIGNMENT_END
	items.append(btns)
	_open_modal(items)


# ───── 도감 ─────
func _dex_view() -> void:
	var tot := g.dex_totals()
	var keys := g.dex.keys()
	var next_ms: int = Params.DEX_MILESTONE_EVERY - (keys.size() % Params.DEX_MILESTONE_EVERY)
	var entries := []
	for k in keys:
		var c = g.cat(g.dex[k]["catId"])
		if c != null:
			entries.append({"k": k, "c": c})
	if U["dexGrade"] is int and U["dexGrade"] >= 0:
		entries = entries.filter(func(e): return e["c"]["grade"] == U["dexGrade"])
	if U["dexGrade"] is String and U["dexGrade"] == "S":
		entries = entries.filter(func(e): return e["c"].get("special") != null or e["c"].get("fantasy") != null)
	entries.sort_custom(func(a, b): return g.dex[a["k"]]["first"] > g.dex[b["k"]]["first"])
	var query: String = U["dexSearch"].strip_edges().to_lower()
	if query != "":
		entries = entries.filter(func(e):
			var c: Dictionary = e["c"]
			var pname: String = Personality.PERSONALITIES[c["personality"]]["name"] if c.get("personality") != null else "성장 중"
			return ("%s %s %s %s" % [c["name"], _desc(c), CatEngine.grade_label(c), pname]).to_lower().contains(query))
	var shown := entries.slice(0, U["dexPage"] * 60)
	panel_body.add_child(UIKit.h2("📖 도감"))
	var lab := LinkButton.new()
	lab.text = "🧪 유전 실험실 · 이론 확률과 교배 표본 비교"
	lab.add_theme_color_override("font_color", Color("#426d5a"))
	lab.add_theme_font_override("font", Fonts.body())
	lab.pressed.connect(_open_lab)
	panel_body.add_child(lab)
	panel_body.add_child(UIKit.box([UIKit.rich("발견 [b]%d[/b]종" % tot["found"], 20),
		UIKit.hint("일반 %d/%d종 · 스페셜 %d/4 · 판타지 %d/4\n유전 가이드의 기본 외형 %d종 + 스페셜 4종 + 판타지 4종 · %d종 더 발견하면 보너스 %d냥" % [tot["normal"], Genetics.PHENOTYPE_ORDER.size(), tot["special"], tot["fantasy"], Genetics.PHENOTYPE_ORDER.size(), next_ms, Params.DEX_MILESTONE_REWARD])]))
	var chips := [UIKit.chip("전체", U["dexGrade"] is int and U["dexGrade"] == -1, func(): U["dexGrade"] = -1; U["dexPage"] = 1; render())]
	for i in Params.GRADES.size():
		var gi := i
		chips.append(UIKit.chip(Params.GRADES[i], U["dexGrade"] is int and U["dexGrade"] == i, func(): U["dexGrade"] = gi; U["dexPage"] = 1; render()))
	chips.append(UIKit.chip("⭐스페셜·판타지", U["dexGrade"] is String, func(): U["dexGrade"] = "S"; U["dexPage"] = 1; render()))
	panel_body.add_child(UIKit.row(chips, 4))
	panel_body.add_child(UIKit.label("🔎 도감 검색", 14, UIKit.INK2))
	var search := LineEdit.new()
	search.placeholder_text = "이름, 털색, 무늬, 성격"
	search.max_length = 80
	search.text = U["dexSearch"]
	search.add_theme_stylebox_override("normal", UIKit.sb("#fffdf8", 12, 2, UIKit.LINE, Vector4(12, 10, 12, 10)))
	search.add_theme_stylebox_override("focus", UIKit.sb("#fffdf8", 12, 3, "#397f84", Vector4(12, 10, 12, 10)))
	search.add_theme_color_override("font_color", Color(UIKit.INK))
	search.text_changed.connect(func(text):
		U["dexSearch"] = text
		U["dexPage"] = 1
		dex_timer.start())
	search.text_submitted.connect(func(text):
		dex_timer.stop()
		U["dexSearch"] = text
		U["dexPage"] = 1
		render())
	panel_body.add_child(search)
	if query != "" or search.text != "":
		search.call_deferred("grab_focus")
		search.call_deferred("set_caret_column", search.text.length())
	panel_body.add_child(UIKit.hint("검색 결과 %d종" % entries.size()))
	var cards := []
	for e in shown:
		var id: String = e["c"]["id"]
		cards.append(_card(e["c"], {"on": func(): _show_detail(id, true)}))
	panel_body.add_child(UIKit.grid(cards, _panel_width()))
	if shown.size() < entries.size():
		var more := CenterContainer.new()
		more.add_child(UIKit.button("더 보기", func(): U["dexPage"] += 1; render(), "leaf", true))
		panel_body.add_child(more)
	if entries.is_empty():
		panel_body.add_child(UIKit.label("아직 이 분류의 고양이를 만나지 못했어요.", 13, UIKit.INK2))


# ───── 동물샵 ─────
func _shop_view() -> void:
	panel_body.add_child(UIKit.h2("🛍️ 동물샵"))
	panel_body.add_child(UIKit.label("마음에 드는 고양이와 교배하면 (냥 지불) 그 고양이는 가게에서 사라지고 새 고양이가 들어와요. 새끼는 항상 1마리, 내가 데려가요.", 13, UIKit.INK2))
	var line := HBoxContainer.new()
	line.add_child(UIKit.hint("다음 입고까지 "))
	line.add_child(_countdown(g.shop_refresh_at))
	line.add_child(UIKit.hint(" · 6시간마다 새 친구가 와요"))
	panel_body.add_child(line)
	var cards := []
	for c in g.shop_cats():
		var id: String = c["id"]
		cards.append(_card(c, {"meta": "%d냥%s" % [CatEngine.shop_breed_price(c), (" · 🧬%d" % c["carriers"]) if c["carriers"] else ""], "on": func(): _show_detail(id, true)}))
	panel_body.add_child(UIKit.grid(cards, _panel_width()))
	panel_body.add_child(UIKit.hint("🧬 숫자 = 겉으로 안 드러나는 열성 유전자 보인자 수 (가격에 반영)"))
	panel_body.add_child(UIKit.h3("우리 고양이 팔기"))
	var mine := []
	for c in g.my_cats():
		var id2: String = c["id"]
		mine.append(_card(c, {"meta": "팔기 %d냥" % CatEngine.sell_price(c), "on": func(): _sell(id2)}))
	panel_body.add_child(UIKit.grid(mine, _panel_width()))


# ───── 이웃 ─────
func _npc_view() -> void:
	panel_body.add_child(UIKit.h2("🏘️ 이웃"))
	panel_body.add_child(UIKit.label("프로토타입: 이웃(NPC)은 교환과 교배 신청을 언제나 수락해요. 횟수 제한 없음.", 13, UIKit.INK2))
	for n in g.npcs:
		if U["npc"] != null and n["id"] != U["npc"]:
			continue
		var cards := []
		for id in n["cats"]:
			var c = g.cat(id)
			var cid: String = id
			var nid: String = n["id"]
			cards.append(_card(c, {"on": func(): _show_detail(cid, true), "actions": [
				UIKit.button("교환", func(): _open_trade(nid, cid), "leaf", true),
				UIKit.button("교배신청", func(): _npc_breed(cid), "peach", true)]}))
		panel_body.add_child(UIKit.box([UIKit.label("%s %s" % [n["icon"], n["name"]], 18, UIKit.INK, true), UIKit.grid(cards, _panel_width() - 30)]))


# ───────────────────────── 모달 ─────────────────────────
func _open_modal(items: Array) -> void:
	pending_confirm = Callable()
	stick_release()
	world.keys = {}
	world.cancel_journey()
	for ch in modal_body.get_children():
		ch.queue_free()
	for it in items:
		if it != null:
			modal_body.add_child(it)
	modal.visible = true
	world.enabled = false
	stick.visible = false
	pen_button.visible = false
	await get_tree().process_frame
	_fit_modal()


func _close_modal() -> void:
	if not modal.visible:
		return
	modal.visible = false
	for ch in modal_body.get_children():
		ch.queue_free()
	pending_confirm = Callable()
	if not U["busy"]:
		world.enabled = true
	stick.visible = (narrow or DisplayServer.is_touchscreen_available()) and not U["open"] and not U["busy"]


func _confirm(title: String, message: String, action: Callable) -> void:
	var btns := UIKit.row([UIKit.button("취소", _close_modal, "gray"), UIKit.button("확인", func():
		var a := pending_confirm
		_close_modal()
		if a.is_valid():
			a.call(), "peach")])
	btns.alignment = FlowContainer.ALIGNMENT_END
	await _open_modal([UIKit.h2(title, 24), UIKit.label(message, 15), btns])
	pending_confirm = action


func _show_capacity_notice() -> void:
	var pen := g.pen_status()
	if pen["over"] <= 0:
		return
	_open_modal([UIKit.h2("📢 우리 정원 변경 안내", 24),
		UIKit.rich("현재 고양이 %d마리 / 정원 %d마리로, [b]%d마리 초과[/b]했어요." % [pen["count"], pen["capacity"], pen["over"]], 15),
		UIKit.label("기존 고양이는 모두 그대로 보호됩니다. 동물샵에서 초과한 고양이를 판매하거나 우리를 확장해 정리해 주세요.", 15),
		UIKit.label("새끼가 지낼 빈자리가 생길 때까지 교배할 수 없습니다. 정원과 같은 마릿수일 때도 교배가 제한됩니다.", 15),
		UIKit.row([UIKit.button("동물샵에서 정리하기", func(): _navigate("shop")), UIKit.button("확인", _close_modal, "gray")])])


func _show_map() -> void:
	var items := [UIKit.h2("🧭 마을 지도", 24), UIKit.hint("아래 목적지를 고르면 실제로 걸어가요. 파란 점은 집사의 현재 위치입니다."),
		VillageMapView.new().setup(world.pens, world.zones, world.player_xz(), g.npcs)]
	var dest := GridContainer.new()
	dest.columns = 2
	dest.add_theme_constant_override("h_separation", 10)
	dest.add_theme_constant_override("v_separation", 10)
	for z in world.zones:
		var zid: String = z["id"]
		var sub := "현재 이곳에 있어요" if world.near_zone(zid) else "%dm · 길찾기" % roundi(world.player_xz().distance_to(Vector2(z["x"], z["z"])))
		var b := UIKit.button("%s\n%s" % [Locations.destination_name(zid, g.npcs), sub], func(): _navigate(zid), "pale")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 55)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dest.add_child(b)
	items.append(dest)
	items.append(UIKit.row([UIKit.button("닫기", _close_modal, "gray")]))
	_open_modal(items)


func _show_pen_levels() -> void:
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 24)
	for h in ["레벨", "정원", "이번 확장 비용"]:
		table.add_child(UIKit.label(h, 14, UIKit.INK, true, false))
	for i in Params.PEN_LEVELS.size():
		var lv: Dictionary = Params.PEN_LEVELS[i]
		var cur := i + 1 == g.pen_level
		table.add_child(UIKit.label("Lv.%d%s" % [i + 1, " · 현재" if cur else ""], 14, UIKit.PEACH_D if cur else UIKit.INK, cur, false))
		table.add_child(UIKit.label("%d마리" % lv["capacity"], 14, UIKit.INK, false, false))
		table.add_child(UIKit.label(_comma(lv["cost"]) + "냥" if i else "시작 우리", 14, UIKit.INK, false, false))
	_open_modal([UIKit.h2("🌿 우리 확장 계획", 24), UIKit.label("현재 Lv.%d · 정원 %d마리" % [g.pen_level, g.pen_status()["capacity"]], 15),
		UIKit.hint("냥은 시간 수입·새 도감 보상·동물샵 판매로 모아요. 시작 4마리, 첫 정원 6마리. 처음 확장하면 1마리, 그다음부터 2마리씩 늘어요."),
		table, UIKit.hint("초과한 고양이를 자동으로 팔거나 삭제하지 않아요. 초과분을 판매하거나 확장하기 전에는 추가 교배·교환을 쉬어 주세요."),
		UIKit.row([UIKit.button("닫기", _close_modal, "gray")])])


func _show_audio_settings() -> void:
	var items := [UIKit.h2("🎵 소리 설정", 24), UIKit.hint("음량은 이 기기에 기억해요. 게임을 다시 열면 소리는 직접 켜 주세요.")]
	for kv in [["music", "배경음악"], ["effects", "효과음"]]:
		var key: String = kv[0]
		var value_label := UIKit.label("%d%%" % roundi(audio.volumes[key] * 100), 14, UIKit.INK2, false, false)
		var head := HBoxContainer.new()
		var name := UIKit.label(kv[1], 15, UIKit.INK, true, false)
		name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name)
		head.add_child(value_label)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = roundi(audio.volumes[key] * 100)
		slider.custom_minimum_size = Vector2(0, 32)
		slider.value_changed.connect(func(v):
			var vols: Dictionary = audio.volumes.duplicate()
			vols[key] = v / 100.0
			audio.set_volumes(vols)
			value_label.text = "%d%%" % roundi(audio.volumes[key] * 100)
			if not Preferences.save_audio(g.storage, audio.volumes):
				toast("음량을 저장하지 못했어요. 현재 창에는 적용했어요"))
		items.append(head)
		items.append(slider)
	items.append(UIKit.hint("0%로 내리면 해당 소리만 꺼져요."))
	var toggle := UIKit.button("🔇 소리 끄기" if audio.enabled else "🔊 소리 켜기", func(): _toggle_sound(); _show_audio_settings(), "gray")
	items.append(UIKit.row([toggle, UIKit.button("닫기", _close_modal)]))
	_open_modal(items)


func _toggle_sound() -> void:
	audio.set_enabled(not audio.enabled)
	sound_btn.text = "🔊" if audio.enabled else "🔇"
	sound_btn.tooltip_text = "소리 끄기" if audio.enabled else "소리 켜기"


const LOCI_KO := {"B": "갈색(B)", "D": "희석(D)", "S": "흰반점(S)"}
const REC := {"B": ["b"], "D": ["d"], "S": ["s"]}


func _ped_node(id, depth: int) -> Control:
	var c = g.cat(id) if id != null else null
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIKit.sb("#ffffff", 14, 2, UIKit.LINE, Vector4(4, 4, 4, 4)))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_child(v)
	if c == null:
		for l in [UIKit.label("?", 30, UIKit.INK, false, false), UIKit.label("알 수 없음", 12, UIKit.INK, false, false)]:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			v.add_child(l)
		return box
	var cc := CenterContainer.new()
	cc.add_child(UIKit.thumb(c, 70, 54))
	v.add_child(cc)
	var nm := UIKit.rich("[center]%s %s[/center]" % [c["name"], UIKit.sex_text(c)], 12)
	v.add_child(nm)
	if depth > 1 and (c.get("fatherId") != null or c.get("motherId") != null):
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 4)
		inner.add_child(_ped_node(c.get("fatherId"), depth - 1))
		inner.add_child(_ped_node(c.get("motherId"), depth - 1))
		v.add_child(inner)
	return box


func _show_detail(id: String, _view_only: bool) -> void:
	var c = g.cat(id)
	var owned := g.source_of(id) == "mine"
	var ph: Dictionary = c["ph"]
	var head := UIKit.row([UIKit.rich_inline("%s %s" % [c["name"], UIKit.sex_text(c)], 24), _badge(c), _personality_chip(c)], 8)
	var bars := []
	for kv in [["whisker", "수염 길이"], ["ear", "귀 크기"], ["face", "얼굴 둥글기"], ["bulk", "체형(뚱냥)"]]:
		var r := HBoxContainer.new()
		var l := UIKit.label(kv[1], 13, UIKit.INK, false, false)
		l.custom_minimum_size = Vector2(90, 0)
		r.add_child(l)
		r.add_child(UIKit.bar(c["body"][kv[0]], 12))
		bars.append(r)
	var feats := ["털색 " + {"black": "블랙", "blue": "블루", "chocolate": "초콜릿", "lilac": "라일락"}[ph["base"]],
		"바이컬러" if ph["bicolor"] else "흰반점 없음", "희석색" if ph["base"] in ["blue", "lilac"] else "진한 색", "단모"]
	var right := UIKit.vbox([UIKit.row(_tags(c), 4), UIKit.hint(_desc(c)), UIKit.row(feats.map(func(f): return UIKit.chip(f)), 4), UIKit.vbox(bars, 4)], 6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	top.add_child(UIKit.thumb_bg(c, 220, 190, 20))
	top.add_child(right)
	var ped := HBoxContainer.new()
	ped.add_theme_constant_override("separation", 6)
	ped.add_child(_ped_node(c.get("fatherId"), 2))
	ped.add_child(_ped_node(c.get("motherId"), 2))
	var table := GridContainer.new()
	table.columns = 2
	table.add_theme_constant_override("h_separation", 20)
	for loc in Genetics.LOCI:
		table.add_child(UIKit.label(LOCI_KO[loc], 13, UIKit.INK, false, false))
		var alleles := HBoxContainer.new()
		for a in c["genome"][loc]:
			var rec: bool = a in REC[loc]
			var cell := PanelContainer.new()
			cell.add_theme_stylebox_override("panel", UIKit.sb("#ffe0e6" if rec else "#f6ecd8", 8, 0, "#ffffff", Vector4(5, 0, 5, 0)))
			cell.custom_minimum_size = Vector2(24, 0)
			var al := UIKit.label(a if owned else "?", 13, "#c0485f" if rec and owned else UIKit.INK, true, false)
			al.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cell.add_child(al)
			alleles.add_child(cell)
		table.add_child(alleles)
	var close := UIKit.row([UIKit.button("닫기", _close_modal, "gray")])
	close.alignment = FlowContainer.ALIGNMENT_END
	_open_modal([head, top, UIKit.h3("가계도 (부·모 / 조부모)"), ped,
		UIKit.h3("🧬 유전자형" + ("" if owned else "  (내 고양이만 확인할 수 있어요)")), table,
		UIKit.hint("붉은 칸 = 열성 대립유전자(숨어 있을 수 있어요). 겉모습이 같아도 자손에게 다른 모습이 나올 수 있어요. 숨은 열성 보인자 %d개." % c["carriers"]), close])


func _open_trade(npc_id: String, npc_cat_id: String) -> void:
	if not world.near_zone("npc:" + npc_id):
		_navigate("npc:" + npc_id)
		return
	var n: Dictionary = {}
	for x in g.npcs:
		if x["id"] == npc_id:
			n = x
	var c = g.cat(npc_cat_id)
	var cards := []
	for m in g.my_cats():
		var mid: String = m["id"]
		cards.append(_card(m, {"meta": "이 아이와 교환", "on": func(): _do_trade(mid, npc_id, npc_cat_id)}))
	var close := UIKit.row([UIKit.button("닫기", _close_modal, "gray")])
	close.alignment = FlowContainer.ALIGNMENT_END
	_open_modal([UIKit.h2("🎁 %s와 교환" % n["name"], 24), UIKit.label("%s과(와) 바꿀 내 고양이를 고르세요. 이웃은 무조건 수락해요." % c["name"], 13, UIKit.INK2),
		UIKit.grid(cards, modal_dialog.size.x - 50), close])


func _do_trade(my_id: String, npc_id: String, npc_cat_id: String) -> void:
	if not world.near_zone("npc:" + npc_id):
		_close_modal()
		_navigate("npc:" + npc_id)
		return
	if g.trade(my_id, npc_id, npc_cat_id):
		toast("교환 완료! 이웃이 기뻐해요 🎁")
		_close_modal()
		U["sel"] = npc_cat_id
		render()
	else:
		toast("정원을 초과했어요. 먼저 판매하거나 우리를 확장해 주세요" if g.pen_status()["over"] > 0 else "지금은 교환할 수 없어요")


func _npc_breed(id: String) -> void:
	var c = g.cat(id)
	var B: Dictionary = U["breed"]
	B["father" if c["sex"] == "M" else "mother"] = id
	B["slot"] = "mother" if c["sex"] == "M" else "father"
	B["src"] = "mine"
	toast("💌 교배 신청을 보냈어요! 이웃이 수락했어요 (프로토타입)")
	_goto_tab("breed")


# ───────────────────────── 동작 ─────────────────────────
func _act(act: String, data := {}) -> void:
	if U["busy"]:
		return
	match act:
		"income":
			_collect_income()
		"selectcare":
			U["sel"] = data.get("id")
			render()
		"navigate":
			_navigate(data.get("zone"))
		"mapguide":
			_show_map()
		"backup":
			_backup()
		"upgradepen":
			var pen := g.pen_status()
			if pen["next"] == null:
				return
			var nx: Dictionary = pen["next"]
			if g.coins < nx["cost"]:
				_open_modal([UIKit.h2("🌿 우리 확장", 24), UIKit.label("%d냥로 정원을 %d마리까지 늘릴 수 있어요." % [nx["cost"], nx["capacity"]], 15),
					UIKit.label("현재 %d냥 · %d냥 더 모아 주세요." % [int(g.coins), nx["cost"] - int(g.coins)], 15), UIKit.row([UIKit.button("닫기", _close_modal, "gray")])])
				return
			var level: int = pen["level"]
			_confirm("우리 확장", "%d냥을 사용해 Lv.%d, 정원 %d마리로 확장할까요?" % [nx["cost"], level + 1, nx["capacity"]], func():
				var r := g.upgrade_pen(level)
				toast("🌿 우리 Lv.%d! %d마리를 키울 수 있어요" % [r["level"], r["capacity"]] if r["ok"] else r["msg"])
				render())


func _collect_income() -> void:
	var n := g.collect_income()
	if n > 0:
		audio.play("income")
	toast("🐾 %d냥을 받았어요!" % n if n > 0 else "아직 받을 수입이 없어요")
	render()


func _do_care(id: String, a: String) -> void:
	var r := g.care(id, a)
	if not r["ok"]:
		toast(r["msg"])
	else:
		fx(r["fx"], 5)
		audio.play(a)
		world.react(id, a)
	render()


func _do_daily(id: String, a: String) -> void:
	var r := g.care_daily(id, a)
	if r["ok"]:
		fx(r["fx"])
		audio.play(a)
		world.react(id, a)
	else:
		toast(r["msg"])
	render()


func _sell(id: String) -> void:
	if not world.can_open("shop"):
		_navigate("shop")
		return
	var c = g.cat(id)
	_confirm("고양이 판매", "%s을(를) %d냥에 판매할까요? (되돌릴 수 없어요)" % [c["name"], CatEngine.sell_price(c)], func():
		var p = g.sell(id)
		if p == null:
			toast("지금은 판매할 수 없는 고양이예요")
			return
		toast("🐾 %d냥에 판매했어요" % p)
		if U["sel"] == id:
			U["sel"] = g.mine[0] if not g.mine.is_empty() else null
		var B: Dictionary = U["breed"]
		if B["father"] == id:
			B["father"] = null
		if B["mother"] == id:
			B["mother"] = null
		render())


func _go_breed(id: String) -> void:
	var c = g.cat(id)
	var B: Dictionary = U["breed"]
	B["father" if c["sex"] == "M" else "mother"] = id
	B["slot"] = "mother" if c["sex"] == "M" else "father"
	B["src"] = "mine"
	_goto_tab("breed")


func _dev(v: String) -> void:
	if U["busy"]:
		return
	if v != "reset" and not dev:
		return
	if v == "1h":
		g.skip_time(3600e3)
	elif v == "1d":
		g.skip_time(86400e3)
	else:
		_confirm("새 게임 시작", "저장 데이터를 교체하고 새 게임을 시작할까요? 먼저 진행을 백업해 주세요.", func():
			g.reset()
			U["sel"] = g.mine[0]
			U["breed"] = {"father": null, "mother": null, "slot": "father", "src": "mine"}
			_after_tick()
			render())
		return
	_after_tick()
	render()


func _backup() -> void:
	var d := Time.get_date_dict_from_system()
	var name := "냥냥하우스-%04d-%02d-%02d.json" % [d["year"], d["month"], d["day"]]
	var data := g.export_save()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(data.to_utf8_buffer(), name, "application/json")
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json ; 저장 파일"])
	dlg.current_file = name
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null:
			toast("파일을 저장하지 못했어요")
		else:
			f.store_string(data)
			toast("진행을 백업했어요"))
	add_child(dlg)
	dlg.popup_centered()


func _restore() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json ; 저장 파일"])
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			toast("파일을 열지 못했어요")
			return
		if f.get_length() > 10 * 1024 * 1024:
			toast("10MB 이하의 저장 파일을 골라 주세요")
			return
		var raw := f.get_as_text()
		var json := JSON.new()
		if json.parse(raw) != OK or SaveData.validate(json.data) != "":
			toast(SaveData.ERR)
			return
		_confirm("백업 불러오기", "이 백업으로 현재 진행을 교체할까요? 먼저 현재 진행을 백업해 두세요.", func():
			var err := g.import_save(raw)
			if err != "":
				toast(err)
				return
			U["sel"] = g.mine[0] if not g.mine.is_empty() else null
			U["breed"]["father"] = null
			U["breed"]["mother"] = null
			world.setup_npcs(g.npcs)
			render()
			toast("진행을 불러왔어요")
			_show_capacity_notice()))
	add_child(dlg)
	dlg.popup_centered()


func _open_lab() -> void:
	var lab: Control = load("res://scripts/ui/genetics_lab.gd").new()
	for ch in lab_layer.get_children():
		ch.queue_free()
	lab_layer.add_child(lab)
	lab.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lab_layer.visible = true
	world.enabled = false
	lab.closed.connect(func():
		lab_layer.visible = false
		world.enabled = not modal.visible
		lab.queue_free())


# ───────────────────────── 장소·패널 ─────────────────────────
func _on_world_cat(id: String) -> void:
	if g.source_of(id) == "mine":
		U["sel"] = id
		_open_panel("home")
	else:
		var source := g.source_of(id)
		if source.begins_with("npc:") and not world.near_zone(source):
			_navigate(source)
		else:
			_show_detail(id, true)


func _handle_zone(id: String) -> void:
	if U["busy"]:
		return
	if not world.near_zone(id):
		_navigate(id)
		return
	if id == "shop":
		_open_panel("shop")
	elif id == "breed":
		_open_panel("breed")
	elif id == "dex":
		_open_panel("dex")
	elif id.begins_with("npc:"):
		U["npc"] = id.substr(4)
		_open_panel("npc")


func _open_panel(tab: String) -> void:
	if not world.can_open(tab):
		_navigate("npc:" + (U["npc"] if U["npc"] != null else g.npcs[0]["id"]) if tab == "npc" else tab)
		return
	if tab == "npc":
		for z in world.zones:
			if str(z["id"]).begins_with("npc:") and world.near_zone(z["id"]):
				U["npc"] = str(z["id"]).substr(4)
				break
	stick_release()
	world.keys = {}
	world.cancel_journey()
	U["tab"] = tab
	U["open"] = true
	render()


func _close_panel() -> void:
	U["open"] = false
	render()


func _goto_tab(t: String) -> void:
	if U["open"] and U["tab"] == t:
		_close_panel()
		return
	_open_panel(t)


func _update_location_menus() -> void:
	if world == null:
		return
	for t in tab_buttons:
		if t == "map":
			continue
		tab_buttons[t].visible = world.can_open(t)
	if U["open"] and U["tab"] != "home" and not world.can_open(U["tab"]):
		U["open"] = false
		render()
	call_deferred("_on_resize")


func _navigate(id) -> void:
	if U["busy"] or id == null:
		return
	if modal.visible:
		_close_modal()
	U["open"] = false
	stick_release()
	render()
	if world.go_to_zone(id):
		toast("지도의 장소로 이동해요. 도착하면 메뉴가 열려요")
	else:
		toast("이곳에서는 길을 찾지 못했어요. 조금 이동한 뒤 다시 시도해 주세요")


# ───────────────────────── 조이스틱 ─────────────────────────
func _on_stick_input(e: InputEvent) -> void:
	var center := stick.size / 2
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		stick_touch = e.index if e is InputEventScreenTouch else 0
		_stick_move(e.position - center)
	elif e is InputEventScreenDrag or (e is InputEventMouseMotion and stick_touch >= 0):
		if stick_touch >= 0:
			_stick_move(e.position - center)
	elif (e is InputEventScreenTouch and not e.pressed) or (e is InputEventMouseButton and not e.pressed):
		stick_release()


func _stick_move(d: Vector2) -> void:
	var v := Preferences.stick_vector(d.x, d.y)
	stick_knob.position = Vector2(31, 31) + Vector2(v["knobX"], v["knobY"])
	world.stick = Vector2(v["x"], v["y"])
	if v["x"] != 0 or v["y"] != 0:
		world.cancel_journey()


func stick_release() -> void:
	stick_touch = -1
	if stick_knob:
		stick_knob.position = Vector2(31, 31)
	if world:
		world.stick = Vector2.ZERO


# ───────────────────────── 키보드 ─────────────────────────
func handle_escape() -> bool:
	if lab_layer.visible:
		return false
	if U["busy"] and breed_overlay.visible:
		breed_stage.clear()
		return true
	if modal.visible:
		if not U["busy"]:
			_close_modal()
		return true
	if U["open"] and not U["busy"]:
		_close_panel()
		return true
	return false


# ───────────────────────── 초당 갱신 ─────────────────────────
func _after_tick() -> bool:
	var done := g.tick()
	for c in done:
		toast("%s의 성격은 \"%s\"!" % [c["name"], Personality.PERSONALITIES[c["personality"]]["name"]])
	return not done.is_empty()


func _every_second() -> void:
	if U["busy"]:
		return
	var shop_at := g.shop_refresh_at
	var changed := _after_tick()
	_update_clock()
	income_btn.text = "🐾 수입 받기 +%s냥" % _comma(g.pending_income())
	var t := g.now()
	var litter := Wellbeing.litter_state(g.my_cats(), t)
	world.sync_litter(litter)
	if is_instance_valid(litter_label):
		litter_label.text = _litter_summary(litter)
	for a in activity_labels:
		if is_instance_valid(a["label"]):
			a["label"].text = "🐾 " + world.activity_of(a["id"])
	if watching_id != null and g.cat(watching_id) != null:
		watching_label.text = "%s 관찰 중 · %s" % [g.cat(watching_id)["name"], world.activity_of(watching_id)]
	if changed or shop_at != g.shop_refresh_at or (U["open"] and U["tab"] == "home" and not modal.visible and JSON.stringify(_current_goal()) != U["goalKey"]):
		render()
		return
	for c in countdowns:
		if not is_instance_valid(c["label"]):
			continue
		var left: float = c["until"] - t
		if left <= 0:
			render()
			return
		c["label"].text = c["prefix"] + UIKit.fmt(left) + c["suffix"]
	for b in cooldown_buttons:
		if is_instance_valid(b["button"]) and b["until"] <= t:
			render()
			return
