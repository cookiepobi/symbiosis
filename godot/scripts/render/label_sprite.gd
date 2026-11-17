class_name LabelSprite
extends Sprite3D
## 웹 world.js label(): 둥근 말풍선 캔버스(320×96)를 스프라이트로 띄운다. 항상 위에 그려짐(depthTest false).

var _vp: SubViewport


static func make(text: String, bg := "#fffaf0", fg := "#6b4f3a", scale := 1.0) -> LabelSprite:
	var s := LabelSprite.new()
	s._vp = SubViewport.new()
	s._vp.size = Vector2i(320, 96)
	s._vp.transparent_bg = true
	s._vp.disable_3d = true
	s._vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var panel := Panel.new()
	panel.position = Vector2(4, 4)
	panel.size = Vector2(312, 88)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg)
	style.border_color = Color(1, 1, 1)
	style.set_border_width_all(8)
	style.set_corner_radius_all(44)
	style.anti_aliasing = true
	panel.add_theme_stylebox_override("panel", style)
	s._vp.add_child(panel)
	var label := Label.new()
	label.text = text
	label.position = Vector2(0, 3)
	label.size = Vector2(320, 96)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Fonts.title())
	label.add_theme_font_size_override("font_size", 44)
	label.add_theme_color_override("font_color", Color(fg))
	s._vp.add_child(label)
	s.add_child(s._vp)
	s.texture = s._vp.get_texture()
	s.pixel_size = 3.6 * scale / 320.0
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.no_depth_test = true
	s.render_priority = 20
	s.shaded = false
	s.double_sided = true
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return s
