class_name Personality
extends RefCounted
## 웹 personality.js: 탄생 후 1시간 돌봄 점수 → 소프트맥스 확률 추첨. 유전 아님.

const PERSONALITIES := [
	{"id": 0, "name": "활발함", "desc": "에너지가 넘치고 활동적", "act": "자주 뛰어다니고 장난침", "emoji": "⚡"},
	{"id": 1, "name": "소심함", "desc": "겁이 많고 경계심이 강함", "act": "낯선 고양이를 피하고 숨음", "emoji": "🫣"},
	{"id": 2, "name": "애교쟁이", "desc": "친화적이고 관심을 좋아함", "act": "다른 고양이에게 다가가고 비빔", "emoji": "💗"},
	{"id": 3, "name": "도도함", "desc": "독립적이고 자기주장이 강함", "act": "혼자 있는 시간을 즐김", "emoji": "👑"},
	{"id": 4, "name": "호기심쟁이", "desc": "새로운 환경과 물건에 관심이 많음", "act": "주변을 탐색하고 물건을 건드림", "emoji": "🔍"},
	{"id": 5, "name": "느긋함", "desc": "차분하고 여유로움", "act": "자주 눕거나 낮잠을 잠", "emoji": "😴"},
	{"id": 6, "name": "장난꾸러기", "desc": "짓궂고 예측하기 어려움", "act": "다른 고양이를 놀라게 하거나 방해함", "emoji": "😈"},
	{"id": 7, "name": "예민함", "desc": "작은 자극에도 민감하게 반응", "act": "소리나 움직임에 빠르게 반응함", "emoji": "❗"},
]

#                                                         활발 소심 애교 도도 호기심 느긋 장난 예민
const CARE_ACTIONS := [
	{"id": "yarn", "name": "털실로 놀아주기", "icon": "🧶", "cd": 120e3, "w": [2, 0, 1, 0, 1, 0, 2, 0], "fx": "🧶"},
	{"id": "pet", "name": "쓰다듬기", "icon": "🤲", "cd": 120e3, "w": [0, 0, 2, -1, 0, 1, 0, 0], "fx": "💗"},
	{"id": "feed", "name": "먹이 주기", "icon": "🐟", "cd": 300e3, "w": [0, 0, 1, 0, 0, 2, 0, 0], "fx": "🐟"},
	{"id": "novel", "name": "새 물건 보여주기", "icon": "🎁", "cd": 300e3, "w": [0, -1, 0, 0, 2, 0, 1, 1], "fx": "✨"},
	{"id": "quiet", "name": "가만히 두기", "icon": "🌙", "cd": 300e3, "w": [0, 1, 0, 2, 0, 1, 0, 1], "fx": "💤"},
]
const SLOT := 300e3
const IDLE_BONUS := 0.5
const TEMPERATURE := 2.5
const OVERSTIM := 14


static func action(id: String) -> Dictionary:
	for a in CARE_ACTIONS:
		if a["id"] == id:
			return a
	return {}


static func ensure_care(cat: Dictionary) -> Dictionary:
	if not cat.has("care") or cat["care"] == null:
		cat["care"] = {"scores": [0, 0, 0, 0, 0, 0, 0, 0], "last": {}, "log": []}
	if not cat["care"].has("log") or cat["care"]["log"] == null:
		cat["care"]["log"] = []
	return cat["care"]


static func is_baby(cat: Dictionary) -> bool:
	return cat.get("personality") == null


static func growth_remaining(cat: Dictionary, now_ms: float) -> float:
	if not is_baby(cat):
		return 0.0
	return maxf(0.0, float(cat["birthTime"]) + Params.GROWTH_WINDOW_MS - now_ms)


static func care_cooldown(cat, action_id: String, now_ms: float) -> float:
	var a := action(action_id)
	if cat == null or a.is_empty():
		return 0.0
	var last: float = ensure_care(cat)["last"].get(action_id, -1e15)
	return maxf(0.0, last + a["cd"] - now_ms)


static func apply_care(cat, action_id: String, now_ms: float) -> Dictionary:
	if cat == null:
		return {"ok": false, "msg": "고양이를 찾을 수 없어요"}
	var a := action(action_id)
	if a.is_empty():
		return {"ok": false, "msg": "알 수 없는 돌봄이에요"}
	if not is_baby(cat):
		return {"ok": false, "msg": "성격이 이미 정해졌어요"}
	if growth_remaining(cat, now_ms) <= 0:
		return {"ok": false, "msg": "성장 시간이 끝났어요"}
	var care := ensure_care(cat)
	var cd := care_cooldown(cat, action_id, now_ms)
	if cd > 0:
		return {"ok": false, "msg": "아직 쉬는 중이에요 (%d초)" % ceili(cd / 1000.0)}
	care["last"][action_id] = now_ms
	care["log"].append(now_ms)
	for i in 8:
		care["scores"][i] = care["scores"][i] + a["w"][i]
	return {"ok": true, "fx": a["fx"]}


static func personality_odds(cat: Dictionary) -> Array:
	var care := ensure_care(cat)
	var scores: Array = []
	for v in care["scores"]:
		scores.append(float(v))
	var slots := {}
	for t in care["log"]:
		slots[int(floor((float(t) - float(cat["birthTime"])) / SLOT))] = true
	var idle: float = maxf(0.0, round(Params.GROWTH_WINDOW_MS / SLOT) - slots.size())
	for i in [1, 3, 5]:
		scores[i] += idle * IDLE_BONUS
	if care["log"].size() > OVERSTIM:
		scores[7] += 3
	var peak: float = scores.max()
	var ex: Array = []
	var total := 0.0
	for s in scores:
		var e := exp((s - peak) / TEMPERATURE)
		ex.append(e)
		total += e
	for i in ex.size():
		ex[i] /= total
	return ex


## 1시간이 지난 아기의 성격을 확정. 확정되면 true
static func finalize_personality(cat: Dictionary, now_ms: float) -> bool:
	if not is_baby(cat):
		return false
	if growth_remaining(cat, now_ms) > 0:
		return false
	var odds := personality_odds(cat)
	cat["personality"] = Rng.new(str(cat["seed"]) + ":personality").weighted(odds)
	return true
