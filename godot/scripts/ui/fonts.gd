class_name Fonts
extends RefCounted
## 제목·버튼·주요 표시: Jua(귀여운 글꼴), 본문: 고운돋움. 둘 다 SIL OFL.
## 이모지는 시스템 이모지 글꼴로 대체(Windows: Segoe UI Emoji).

static var _title: Font
static var _body: Font


static func _fallbacks() -> Array[Font]:
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(["Malgun Gothic", "Apple SD Gothic Neo", "Noto Sans KR", "sans-serif"])
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Segoe UI Emoji", "Apple Color Emoji", "Noto Color Emoji"])
	return [emoji, sys]


static func title() -> Font:
	if _title == null:
		var f: FontFile = (load("res://assets/fonts/Jua-Regular.ttf") as FontFile).duplicate()
		f.fallbacks = _fallbacks()
		_title = f
	return _title


static func body() -> Font:
	if _body == null:
		var f: FontFile = (load("res://assets/fonts/GowunDodum-Regular.ttf") as FontFile).duplicate()
		f.fallbacks = _fallbacks()
		_body = f
	return _body
