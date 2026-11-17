class_name GameAudio
extends Node
## 웹 audio.js: 직접 합성한 삼각파 음표(외부 음원·자동 재생 없음). 배경음악과 효과음 음량을 따로 조절.
## 음표마다 지수 엔벨로프를 입힌 짧은 PCM을 미리 만들어 두고(캐시) 플레이어 풀로 재생한다.

const MELODY := [0, 4, 7, 11, 9, 7, 4, 2, 0, 4, 9, 7, 4, 2, -1, 2]
const EFFECTS := {"care": [72, 76, 79], "yarn": [79, 76, 81], "feed": [67, 72], "clean": [76, 84], "income": [72, 79, 84], "breed": [64, 67, 72], "birth": [72, 76, 79, 84]}
const RATE := 22050
const MASTER := 0.075

var enabled := false
var hidden := false
var volumes := Preferences.DEFAULT_AUDIO.duplicate()
var music_running := false
var clock := 0.0
var next_note := 0.0
var step := 0
var pending: Array = []        # {at, stream, channel}
var _cache := {}
var _players: Array = []


func _ready() -> void:
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


static func frequency(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)


## 0.0001 → volume (25ms) → 0.0001 (duration) 지수 램프
static func _env(t: float, dur: float, vol: float) -> float:
	if t < .025:
		return 0.0001 * pow(vol / 0.0001, t / .025)
	return vol * pow(0.0001 / vol, minf(1.0, (t - .025) / (dur - .025)))


func _sample(midi: float, dur: float, vol: float) -> AudioStreamWAV:
	var key := "%f|%f|%f" % [midi, dur, vol]
	if _cache.has(key):
		return _cache[key]
	var n := int((dur + .02) * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var f := frequency(midi)
	for i in n:
		var t := float(i) / RATE
		var phase := fmod(t * f, 1.0)
		var tri := 1.0 - 4.0 * absf(phase - 0.5)
		var v := clampf(tri * _env(t, dur, vol) * MASTER, -1, 1)
		data.encode_s16(i * 2, int(v * 32767))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	_cache[key] = wav
	return wav


func _play_now(stream: AudioStreamWAV, channel: String) -> void:
	var vol: float = volumes[channel]
	if vol <= 0:
		return
	for p in _players:
		if not p.playing:
			p.stream = stream
			p.volume_db = linear_to_db(vol)
			p.set_meta("channel", channel)
			p.play()
			return


func set_volumes(value) -> void:
	var previous: float = volumes["music"]
	volumes = Preferences.audio_preferences(value)
	for p in _players:
		if p.playing and p.has_meta("channel"):
			var v: float = volumes[p.get_meta("channel")]
			if v <= 0:
				p.stop()
			else:
				p.volume_db = linear_to_db(v)
	if volumes["music"] == 0:
		music_running = false
		pending = pending.filter(func(x): return x["channel"] != "music")
	elif previous == 0 and enabled and not hidden:
		next_note = clock + .05
		music_running = true


func set_enabled(on: bool) -> bool:
	enabled = on
	if not on:
		music_running = false
		pending = []
		for p in _players:
			p.stop()
		return false
	next_note = clock + .05
	music_running = not hidden and volumes["music"] > 0
	return true


func play(effect := "care") -> void:
	if not enabled or volumes["effects"] == 0 or hidden:
		return
	var notes: Array = EFFECTS.get(effect, EFFECTS["care"])
	for i in notes.size():
		pending.append({"at": clock + i * .11, "stream": _sample(notes[i], .28, .22), "channel": "effects"})


func visibility(is_hidden: bool) -> void:
	hidden = is_hidden
	if not enabled:
		return
	if is_hidden:
		music_running = false
		pending = []
		for p in _players:
			p.stop()
	else:
		next_note = clock + .05
		music_running = volumes["music"] > 0


func _process(delta: float) -> void:
	clock += delta
	if not enabled or hidden:
		return
	if music_running:
		if next_note < clock:
			next_note = clock + .05
		while next_note < clock + 1.5:
			pending.append({"at": next_note, "stream": _sample(60 + MELODY[step % MELODY.size()], 1.1, .11), "channel": "music"})
			if step % 4 == 0:
				pending.append({"at": next_note, "stream": _sample(48 + (0 if step % 16 < 8 else 5), 2.4, .055), "channel": "music"})
			step += 1
			next_note += .8
	var due := pending.filter(func(x): return x["at"] <= clock)
	pending = pending.filter(func(x): return x["at"] > clock)
	for x in due:
		_play_now(x["stream"], x["channel"])
