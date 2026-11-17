class_name ClickCard
extends PanelContainer
## 웹 .card / .slot / .care 버튼: 자식을 담을 수 있는 클릭 가능한 패널.

signal pressed

var disabled := false
var normal_style: StyleBox
var hover_style: StyleBox


func setup(normal: StyleBox, hover: StyleBox, is_disabled := false) -> ClickCard:
	normal_style = normal
	hover_style = hover
	disabled = is_disabled
	add_theme_stylebox_override("panel", normal)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_ARROW if is_disabled else Control.CURSOR_POINTING_HAND
	modulate.a = 0.5 if is_disabled else 1.0
	mouse_entered.connect(func(): if not disabled: add_theme_stylebox_override("panel", hover_style))
	mouse_exited.connect(func(): add_theme_stylebox_override("panel", normal_style))
	return self


func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if get_global_rect().has_point(event.global_position):
			pressed.emit()
			accept_event()
	elif event.is_action_pressed("ui_accept"):
		pressed.emit()
		accept_event()
