class_name Wellbeing
extends RefCounted
## 웹 wellbeing.js: 편안함(성격·유전과 무관)과 화장실 상태.

const DAILY_CARE := [
	{"id": "feed", "name": "밥 채워 주기", "icon": "🐟", "key": "food", "hours": 8},
	{"id": "yarn", "name": "털실 놀이", "icon": "🧶", "key": "play", "hours": 6},
	{"id": "pet", "name": "쓰다듬기", "icon": "💗", "key": "affection", "hours": 6},
	{"id": "clean", "name": "화장실 치우기", "icon": "🧹", "key": "clean", "hours": 12},
]
const LITTER_INTERVAL_MS := 4.0 * 3600e3


static func _last(cat: Dictionary, key: String):
	var wb = cat.get("wellbeing")
	if wb is Dictionary and wb.has(key):
		return float(wb[key])
	return null


static func comfort(cat: Dictionary, now_ms: float) -> Array:
	var out := []
	for a in DAILY_CARE:
		var last = _last(cat, a["key"])
		if last == null:
			last = float(cat["birthTime"])
		var entry: Dictionary = a.duplicate()
		entry["value"] = int(round(clampf(1.0 - (now_ms - last) / (a["hours"] * 3600e3), 0.0, 1.0) * 100.0))
		out.append(entry)
	return out


static func daily_care(cat, action_id: String, now_ms: float) -> Dictionary:
	var a := {}
	for x in DAILY_CARE:
		if x["id"] == action_id:
			a = x
	if cat == null or a.is_empty():
		return {"ok": false, "msg": "돌봄 대상을 확인해 주세요"}
	var last = _last(cat, a["key"])
	if last != null and now_ms - last < 60e3:
		return {"ok": false, "msg": "조금 쉬었다가 다시 돌봐 주세요 (1분)"}
	if not (cat.get("wellbeing") is Dictionary):
		cat["wellbeing"] = {}
	cat["wellbeing"][a["key"]] = now_ms
	cat["lastInteraction"] = {"action": action_id, "at": now_ms}
	return {"ok": true, "fx": a["icon"]}


static func litter_state(cats: Array, now_ms: float) -> Dictionary:
	var items := []
	var total := 0
	for cat in cats:
		var last = _last(cat, "clean")
		if last == null:
			last = float(cat["birthTime"])
		var count := mini(3, int(floor(maxf(0.0, now_ms - last) / LITTER_INTERVAL_MS)))
		total += count
		for i in count:
			if items.size() >= 12:
				break
			items.append({"catId": cat["id"], "index": i, "seed": "%s:litter:%d" % [cat["seed"], i]})
	return {"total": total, "items": items}
