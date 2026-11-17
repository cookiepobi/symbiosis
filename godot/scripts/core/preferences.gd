class_name Preferences
extends RefCounted
## 웹 preferences.js(음량 저장) + touch-controls.js의 조이스틱 계산.

const AUDIO_KEY := "catgene-audio-v1"
const DEFAULT_AUDIO := {"music": .55, "effects": .8}


static func audio_preferences(value) -> Dictionary:
	var out := {}
	for key in DEFAULT_AUDIO:
		var v = value.get(key) if value is Dictionary else null
		var ok: bool = (v is float or v is int) and is_finite(float(v)) and float(v) >= 0 and float(v) <= 1
		out[key] = float(v) if ok else DEFAULT_AUDIO[key]
	return out


static func load_audio(storage) -> Dictionary:
	var raw = storage.get_item(AUDIO_KEY)
	if raw == null:
		return DEFAULT_AUDIO.duplicate()
	var json := JSON.new()
	if json.parse(raw) != OK:
		return DEFAULT_AUDIO.duplicate()
	return audio_preferences(json.data)


static func save_audio(storage, value) -> bool:
	return storage.set_item(AUDIO_KEY, JSON.stringify(audio_preferences(value)))


## 데드존 15%, 반지름 42px로 정규화한 조이스틱 벡터
static func stick_vector(dx: float, dy: float, radius := 42.0) -> Dictionary:
	var length := sqrt(dx * dx + dy * dy)
	if length == 0 or length < radius * .15:
		return {"x": 0.0, "y": 0.0, "knobX": 0.0, "knobY": 0.0}
	var bounded := minf(radius, length)
	var strength := minf(1.0, (length / radius - .15) / .85)
	return {"x": dx / length * strength, "y": dy / length * strength, "knobX": dx / length * bounded, "knobY": dy / length * bounded}
