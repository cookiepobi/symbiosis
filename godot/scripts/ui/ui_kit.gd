class_name UIKit
extends RefCounted
## 웹 style.css의 모양(버튼·칩·카드·박스·막대 등)을 Godot Control로 만드는 도우미.

const CREAM := "#fdf3dc"
const LEAF := "#86c995"
const LEAF_D := "#5fae74"
const PEACH := "#f6a98d"
const PEACH_D := "#e98c6c"
const INK := "#6b4f3a"
const INK2 := "#9a7e66"
const PANEL := "#fffaf0"
const LINE := "#f0dcb8"
const BLUE := "#8cc7ee"


static func sb(bg, radius := 0, border := 0, border_color = "#ffffff", pad := Vector4(0, 0, 0, 0), shadow := 0, shadow_color := Color(0.71, 0.55, 0.35, 0.18)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(bg) if bg is String else bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = Color(border_color) if border_color is String else border_color
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	if shadow > 0:
		s.shadow_color = shadow_color
		s.shadow_size = 1
		s.shadow_offset = Vector2(0, shadow)
	return s


## 입력창·선택 상자·스크롤바 등 기본 위젯을 웹의 밝은 색감으로
static func base_theme() -> Theme:
	var t := Theme.new()
	t.default_font = Fonts.body()
	t.default_font_size = 14
	var field := sb("#fffdf8", 12, 2, LINE, Vector4(12, 8, 12, 8))
	var focus := sb("#fffdf8", 12, 3, "#397f84", Vector4(12, 8, 12, 8))
	for type in ["LineEdit", "OptionButton"]:
		t.set_stylebox("normal", type, field)
		t.set_stylebox("focus", type, focus)
		t.set_stylebox("hover", type, field)
		t.set_stylebox("pressed", type, field)
		t.set_stylebox("read_only", type, field)
		t.set_color("font_color", type, Color(INK))
		t.set_color("font_hover_color", type, Color(INK))
		t.set_color("font_pressed_color", type, Color(INK))
		t.set_color("font_focus_color", type, Color(INK))
		t.set_color("font_placeholder_color", type, Color(INK2))
		t.set_color("caret_color", type, Color(INK))
	t.set_stylebox("panel", "PopupMenu", sb("#fffdf8", 10, 2, LINE, Vector4(6, 6, 6, 6)))
	t.set_stylebox("hover", "PopupMenu", sb("#f2ead8", 6))
	t.set_color("font_color", "PopupMenu", Color(INK))
	t.set_color("font_hover_color", "PopupMenu", Color(INK))
	t.set_stylebox("background", "ProgressBar", sb("#e6e1d2", 99))
	t.set_stylebox("fill", "ProgressBar", sb("#658a6c", 99))
	t.set_color("font_color", "ProgressBar", Color(0, 0, 0, 0))
	t.set_stylebox("scroll", "VScrollBar", sb(Color(0, 0, 0, 0), 99, 0, "#ffffff", Vector4(3, 0, 3, 0)))
	t.set_stylebox("grabber", "VScrollBar", sb("#ecd3a6", 99))
	t.set_stylebox("grabber_highlight", "VScrollBar", sb("#e2c28c", 99))
	t.set_stylebox("grabber_pressed", "VScrollBar", sb("#e2c28c", 99))
	t.set_stylebox("slider", "HSlider", sb("#e6e1d2", 99, 0, "#ffffff", Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area", "HSlider", sb("#658a6c", 99, 0, "#ffffff", Vector4(0, 4, 0, 4)))
	t.set_stylebox("grabber_area_highlight", "HSlider", sb("#658a6c", 99, 0, "#ffffff", Vector4(0, 4, 0, 4)))
	t.set_color("font_color", "LinkButton", Color("#426d5a"))
	return t


static func label(text: String, size := 14, color := INK, title := false, wrap := true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Fonts.title() if title else Fonts.body())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(color))
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func rich(bbcode: String, size := 14, color := INK) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.text = bbcode
	r.add_theme_font_override("normal_font", Fonts.body())
	r.add_theme_font_override("bold_font", Fonts.title())
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", Color(color))
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return r


## 줄 안에 넣는 리치 텍스트(자동 줄바꿈 없이 내용 너비만큼)
static func rich_inline(bbcode: String, size := 14, color := INK) -> RichTextLabel:
	var r := rich(bbcode, size, color)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r


static func h2(text: String, size := 22) -> Label:
	var l := label(text, size, INK, true, false)
	return l


static func h3(text: String) -> Label:
	var l := label(text, 16, INK2, true)
	return l


static func hint(text: String) -> Label:
	return label(text, 12, INK2)


const BTN := {
	"leaf": [LEAF, LEAF_D, "#ffffff"], "peach": [PEACH, PEACH_D, "#ffffff"], "gray": ["#cdbfa6", "#b3a287", "#ffffff"],
	"blue": [BLUE, "#6aa9d4", "#ffffff"], "pale": ["#f5eddb", "#cdbfa6", "#4f513c"],
}


static func button(text: String, cb: Callable = Callable(), variant := "leaf", small := false, disabled := false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	var c: Array = BTN[variant]
	var pad := Vector4(12, 5, 12, 5) if small else Vector4(18, 8, 18, 8)
	b.add_theme_stylebox_override("normal", sb(c[0], 99, 0, "#ffffff", pad, 4, Color(c[1])))
	b.add_theme_stylebox_override("hover", sb(Color(c[0]).lightened(0.06), 99, 0, "#ffffff", pad, 5, Color(c[1])))
	b.add_theme_stylebox_override("pressed", sb(c[0], 99, 0, "#ffffff", pad, 1, Color(c[1])))
	b.add_theme_stylebox_override("disabled", sb("#d9cfbd", 99, 0, "#ffffff", pad, 4, Color("#c2b79f")))
	b.add_theme_stylebox_override("focus", sb(Color(0, 0, 0, 0), 99, 3, "#397f84", pad))
	b.add_theme_font_override("font", Fonts.title())
	b.add_theme_font_size_override("font_size", 14 if small else 16)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, Color(c[2]))
	b.add_theme_color_override("font_disabled_color", Color("#f5efe4"))
	b.disabled = disabled
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func chip(text: String, on := false, cb: Callable = Callable()) -> Control:
	var bg := LEAF if on else "#ffffff"
	var border := LEAF if on else LINE
	var color := "#ffffff" if on else INK
	if cb.is_valid():
		var b := Button.new()
		b.text = text
		var st := sb(bg, 99, 2, border, Vector4(10, 2, 10, 2))
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, st)
		b.add_theme_font_override("font", Fonts.title())
		b.add_theme_font_size_override("font_size", 13)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, Color(color))
		b.pressed.connect(cb)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		return b
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, 99, 2, border, Vector4(10, 2, 10, 2)))
	p.add_child(label(text, 13, color, true, false))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func badge(text: String, color: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(color, 99, 0, "#ffffff", Vector4(9, 1, 9, 1)))
	p.add_child(label(text, 12, "#ffffff", true, false))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func box(children: Array, bg := "#ffffff", border := LINE, radius := 22, border_w := 3, pad := 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, radius, border_w, border, Vector4(pad, pad, pad, pad)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	for c in children:
		if c != null:
			v.add_child(c)
	p.add_child(v)
	return p


static func row(children: Array, sep := 8, wrap := true) -> Container:
	var r: Container = HFlowContainer.new() if wrap else HBoxContainer.new()
	r.add_theme_constant_override("h_separation" if wrap else "separation", sep)
	if wrap:
		r.add_theme_constant_override("v_separation", 6)
	for c in children:
		if c != null:
			r.add_child(c)
	return r


static func vbox(children: Array, sep := 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	for c in children:
		if c != null:
			v.add_child(c)
	return v


static func bar(ratio: float, height := 16) -> Control:
	var back := Panel.new()
	back.custom_minimum_size = Vector2(0, height)
	back.add_theme_stylebox_override("panel", sb("#f2e3c4", 99, 2, "#ffffff"))
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := Panel.new()
	fill.add_theme_stylebox_override("panel", sb("#86d494", 99))
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	back.resized.connect(func():
		fill.position = Vector2(2, 2)
		fill.size = Vector2(maxf(0, (back.size.x - 4) * clampf(ratio, 0, 1)), back.size.y - 4))
	return back


static func grid(children: Array, width: float, min_w := 122.0, gap := 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = maxi(1, int(floor((width + gap) / (min_w + gap))))
	g.add_theme_constant_override("h_separation", gap)
	g.add_theme_constant_override("v_separation", gap)
	for c in children:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		g.add_child(c)
	return g


static func thumb(cat: Dictionary, px := 130, display := 0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Thumbnails.get_texture(cat, px)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var d := display if display > 0 else px
	t.custom_minimum_size = Vector2(d, d)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


static func thumb_bg(cat: Dictionary, px := 130, display := 0, radius := 14) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb("#fdeccd", radius))
	p.add_child(thumb(cat, px, display))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func sex_text(c: Dictionary) -> String:
	return "[color=#6bb0e6]♂[/color]" if c["sex"] == "M" else "[color=#f088a8]♀[/color]"


static func fmt(ms: float) -> String:
	var s := ceili(ms / 1000.0)
	if s >= 3600:
		return "%d시간 %d분" % [s / 3600, (s % 3600) / 60]
	return "%d:%02d" % [s / 60, s % 60]


static func spacer(h := 6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
