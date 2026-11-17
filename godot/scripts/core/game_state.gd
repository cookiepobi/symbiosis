class_name GameState
extends RefCounted
## 웹 game.js: 보유 고양이, 동물샵, 이웃(NPC, 교환·교배 신청 목업), 도감, 재화, 저장.
## 실행 중인 게임은 GameState.current 하나를 공유한다.

const KEY := "catgene-save-v1"
const NPC_DEF := [
	{"id": "n1", "name": "밤토리", "icon": "🌰"}, {"id": "n2", "name": "하늘이", "icon": "☁️"}, {"id": "n3", "name": "복순이", "icon": "🍑"},
	{"id": "n4", "name": "달고나", "icon": "🍬"}, {"id": "n5", "name": "미루", "icon": "🎀"},
]

static var current: GameState

var storage: Storage
var coins: float = 0
var income_remainder: float = 0
var pen_level: int = 1
var cats: Dictionary = {}
var mine: Array = []
var shop: Array = []
var npcs: Array = []
var dex: Dictionary = {}
var last_collect: float = 0
var shop_refresh_at: float = 0
var offset: float = 0
var seq: int = 0
var event_log: Array = []
var save_error := ""
var load_issue = null   # {raw, message}


## localStorage 대신 쓰는 저장소. 기본은 user:// 파일
class Storage:
	func get_item(key: String):
		var path := "user://%s.json" % key
		if not FileAccess.file_exists(path):
			return null
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			push_error("저장 파일을 열 수 없음")
			return null
		return f.get_as_text()

	func set_item(key: String, value: String) -> bool:
		var path := "user://%s.json" % key
		var tmp := path + ".tmp"
		var f := FileAccess.open(tmp, FileAccess.WRITE)
		if f == null:
			return false
		f.store_string(value)
		f.close()
		return DirAccess.rename_absolute(tmp, path) == OK

	func remove_item(key: String) -> void:
		var path := "user://%s.json" % key
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## 테스트용 메모리 저장소
class MemoryStorage extends Storage:
	var data := {}
	var fail_writes := false

	func get_item(key: String):
		return data.get(key)

	func set_item(key: String, value: String) -> bool:
		if fail_writes:
			return false
		data[key] = value
		return true

	func remove_item(key: String) -> void:
		data.erase(key)


func _init(store: Storage = null) -> void:
	storage = store if store != null else Storage.new()


## 실제 시각(ms). 테스트에서 바꿔 끼울 수 있다 (웹 테스트의 Date.now 대체)
var clock: Callable = func() -> float: return Time.get_unix_time_from_system() * 1000.0


func now() -> float:
	return clock.call() + offset


func _uid() -> String:
	return Rng.random_seed_string()


func add_cat(c: Dictionary) -> Dictionary:
	cats[c["id"]] = c
	return c


func make_founder(prefix: String, opts: Dictionary = {}) -> Dictionary:
	var o := {"birthTime": now() - 2 * Params.GROWTH_WINDOW_MS}
	o.merge(opts, true)
	return add_cat(CatEngine.create_founder("%s-%s" % [prefix, _uid()], o))


func new_game() -> void:
	offset = 0
	coins = Params.START_COINS
	income_remainder = 0
	pen_level = 1
	cats = {}
	mine = []
	shop = []
	npcs = []
	dex = {}
	last_collect = now()
	shop_refresh_at = now() + Params.SHOP_REFRESH_MS
	seq = 0
	event_log = []
	for sex in ["M", "F", "M", "F"]:
		var c := make_founder("start", {"sex": sex, "specialChance": 0.0})
		mine.append(c["id"])
		register_dex(c, true)
	refill_shop()
	for n in NPC_DEF:
		var entry: Dictionary = n.duplicate()
		var ids := []
		for i in 3:
			var sex = "M" if i == 0 else ("F" if i == 1 else null)
			ids.append(make_founder("npc" + n["id"], {"sex": sex})["id"])
		entry["cats"] = ids
		npcs.append(entry)
	save()


func refill_shop() -> void:
	shop = shop.filter(func(id): return cats.has(id))
	while shop.size() < Params.SHOP_SIZE:
		shop.append(make_founder("shop")["id"])


func refresh_shop(t: float = -1) -> bool:
	if t < 0:
		t = now()
	if shop_refresh_at == 0:
		shop_refresh_at = t + Params.SHOP_REFRESH_MS
		return false
	if t < shop_refresh_at:
		return false
	shop = []
	refill_shop()
	shop_refresh_at = t + Params.SHOP_REFRESH_MS
	save()
	return true


func save() -> bool:
	if load_issue != null:
		save_error = "기존 저장을 보호하고 있어요. 복구 화면에서 진행 방법을 선택해 주세요."
		return false
	if storage.set_item(KEY, export_save()):
		save_error = ""
		return true
	save_error = "저장 공간에 기록하지 못했어요. 진행 백업을 내려받아 주세요."
	return false


func snapshot() -> Dictionary:
	return {"coins": coins, "incomeRemainder": income_remainder, "penLevel": pen_level, "cats": cats, "mine": mine, "shop": shop,
		"npcs": npcs, "dex": dex, "lastCollect": last_collect, "shopRefreshAt": shop_refresh_at, "offset": offset, "seq": seq,
		"log": event_log, "version": 1, "savedAt": clock.call()}


func export_save() -> String:
	return JSON.stringify(snapshot(), "  ")


## JSON 숫자는 float로 읽히므로 정수 필드를 되돌린다.
static func _normalize_cat(c: Dictionary) -> Dictionary:
	var out := c.duplicate(true)
	if out.get("personality") != null:
		out["personality"] = int(out["personality"])
	if out.get("lastBreedAt") == null:
		out["lastBreedAt"] = -1e15
	if out.get("care") is Dictionary:
		var scores := []
		for s in out["care"]["scores"]:
			scores.append(float(s))
		out["care"]["scores"] = scores
	return CatEngine.finalize_cat(out)


## 실패하면 오류 메시지, 성공하면 ""
func import_save(raw) -> String:
	if not (raw is String):
		return SaveData.ERR
	var json := JSON.new()
	if json.parse(raw) != OK:
		return SaveData.ERR
	var data = json.data
	var err := SaveData.validate(data)
	if err != "":
		return err
	var new_cats := {}
	for id in data["cats"]:
		new_cats[id] = _normalize_cat(data["cats"][id])
	# 검사·재계산이 모두 끝난 뒤에만 교체한다
	coins = float(data["coins"])
	income_remainder = float(data.get("incomeRemainder", 0) if data.get("incomeRemainder") != null else 0)
	pen_level = int(data["penLevel"]) if data.get("penLevel") != null else 1
	cats = new_cats
	mine = data["mine"].duplicate()
	shop = data["shop"].duplicate()
	npcs = data["npcs"].duplicate(true)
	dex = data["dex"].duplicate(true)
	last_collect = float(data["lastCollect"])
	offset = float(data["offset"])
	var sra = data.get("shopRefreshAt")
	shop_refresh_at = float(sra) if SaveData._num(sra) else clock.call() + offset + Params.SHOP_REFRESH_MS
	seq = int(data.get("seq", 0) if data.get("seq") != null else 0)
	event_log = data["log"] if data.get("log") is Array else []
	load_issue = null
	save()
	return ""


func load_game() -> bool:
	load_issue = null
	var raw = storage.get_item(KEY)
	if raw == null:
		return false
	var err := import_save(raw)
	if err != "":
		load_issue = {"raw": raw, "message": "기존 저장 파일을 읽지 못했어요. 원본을 덮어쓰지 않고 보호하고 있습니다."}
		return false
	return true


func reset() -> void:
	load_issue = null
	storage.remove_item(KEY)
	new_game()


func cat(id) -> Variant:
	return cats.get(id) if id != null else null


func my_cats() -> Array:
	return mine.map(func(id): return cats.get(id)).filter(func(c): return c != null)


func shop_cats() -> Array:
	return shop.map(func(id): return cats.get(id)).filter(func(c): return c != null)


func pen_status() -> Dictionary:
	var cur: Dictionary = Params.PEN_LEVELS[pen_level - 1]
	var nxt = Params.PEN_LEVELS[pen_level] if pen_level < Params.PEN_LEVELS.size() else null
	return {"level": pen_level, "capacity": cur["capacity"], "count": mine.size(), "over": maxi(0, mine.size() - cur["capacity"]), "next": nxt}


func upgrade_pen(expected_level: int = -1) -> Dictionary:
	if expected_level < 0:
		expected_level = pen_level
	var status := pen_status()
	if expected_level != pen_level:
		return {"ok": false, "msg": "우리 레벨이 바뀌었어요. 다시 확인해 주세요"}
	if status["next"] == null:
		return {"ok": false, "msg": "이미 가장 넓은 우리예요"}
	var cost: int = status["next"]["cost"]
	if coins < cost:
		return {"ok": false, "msg": "냥이 부족해요 (필요 %d냥, 부족 %d냥)" % [cost, cost - int(coins)]}
	coins -= cost
	pen_level += 1
	save()
	var r := pen_status()
	r["ok"] = true
	r["cost"] = cost
	return r


# ───── 도감 ─────
func dex_totals() -> Dictionary:
	var keys := dex.keys()
	return {"found": keys.size(),
		"normal": keys.filter(func(k): return not k.begins_with("special:") and not k.begins_with("fantasy:")).size(),
		"special": keys.filter(func(k): return k.begins_with("special:")).size(),
		"fantasy": keys.filter(func(k): return k.begins_with("fantasy:")).size()}


func register_dex(c: Dictionary, silent := false) -> int:
	if dex.has(c["catalogId"]):
		return 0
	var before := dex.size()
	dex[c["catalogId"]] = {"first": now(), "catId": c["id"]}
	var reward: int = Params.DEX_REWARD_SPECIAL if CatEngine.is_special(c) else Params.DEX_REWARD_BY_GRADE[c["grade"]]
	if c.get("fantasy") != null:
		reward += 500
	if (before + 1) % Params.DEX_MILESTONE_EVERY == 0:
		reward += Params.DEX_MILESTONE_REWARD
	if not silent:
		coins += reward
	return 0 if silent else reward


# ───── 수입 ─────
func _income_total(t: float) -> float:
	var total := income_remainder
	for c in my_cats():
		var since: float = c.get("incomeSince", c["birthTime"]) if c.get("incomeSince") != null else float(c["birthTime"])
		var start := maxf(maxf(float(c["birthTime"]), since), last_collect)
		var hours := minf(Params.INCOME_CAP_HOURS, maxf(0.0, (t - start) / 3600e3))
		total += CatEngine.income_per_hour(c) * hours
	return total


static func _whole(total: float) -> int:
	return int(floor(total + 2.220446049250313e-16 * maxf(1.0, total) * 4.0))


func pending_income() -> int:
	return _whole(_income_total(now()))


func collect_income() -> int:
	var t := now()
	var total := _income_total(t)
	var n := _whole(total)
	income_remainder = maxf(0.0, total - n)
	coins += n
	last_collect = t
	save()
	return n


# ───── 시간 / 성격 확정 ─────
func tick() -> Array:
	var t := now()
	var done := []
	refresh_shop(t)
	for c in my_cats():
		if Personality.finalize_personality(c, t):
			done.append(c)
	if not done.is_empty():
		save()
	return done


func skip_time(ms: float) -> void:
	offset += ms
	save()


func care(id: String, action_id: String) -> Dictionary:
	if not mine.has(id):
		return {"ok": false, "msg": "내 고양이만 돌볼 수 있어요"}
	var c = cat(id)
	var r := Personality.apply_care(c, action_id, now())
	if r["ok"]:
		Wellbeing.daily_care(c, action_id, now())
		save()
	return r


func care_daily(id: String, action_id: String) -> Dictionary:
	if not mine.has(id):
		return {"ok": false, "msg": "내 고양이만 돌볼 수 있어요"}
	var r := Wellbeing.daily_care(cat(id), action_id, now())
	if r["ok"]:
		save()
	return r


func sell(id: String):
	var c = cat(id)
	if c == null or not mine.has(id):
		return null
	collect_income()
	var price := CatEngine.sell_price(c)
	coins += price
	mine.erase(id)
	save()
	return price


func trade(my_id: String, npc_id: String, npc_cat_id: String) -> bool:
	if pen_status()["over"] > 0:
		return false
	var npc = null
	for n in npcs:
		if n["id"] == npc_id:
			npc = n
	if npc == null or not mine.has(my_id) or not npc["cats"].has(npc_cat_id):
		return false
	collect_income()
	cat(npc_cat_id)["incomeSince"] = now()
	mine.erase(my_id)
	mine.append(npc_cat_id)
	npc["cats"].erase(npc_cat_id)
	npc["cats"].append(my_id)
	register_dex(cat(npc_cat_id))
	save()
	return true


func source_of(id) -> String:
	if mine.has(id):
		return "mine"
	if shop.has(id):
		return "shop"
	for n in npcs:
		if n["cats"].has(id):
			return "npc:" + n["id"]
	return ""


func breed_cost(a: Dictionary, b: Dictionary) -> int:
	var cost := 0
	for c in [a, b]:
		if source_of(c["id"]) == "shop":
			cost += CatEngine.shop_breed_price(c)
	return cost


func check_breed(father, mother) -> String:
	var pen := pen_status()
	if pen["over"] > 0:
		return "우리 정원보다 %d마리 많아요. 동물샵에서 판매하거나 우리를 확장해 주세요" % pen["over"]
	if pen["count"] >= pen["capacity"]:
		return "우리 정원이 가득 찼어요. 새끼가 지낼 빈자리를 마련한 뒤 교배해 주세요"
	if father == null or mother == null or source_of(father["id"]) == "" or source_of(mother["id"]) == "":
		return "현재 교배할 수 있는 고양이를 골라 주세요"
	var msg := CatEngine.can_breed(father, mother, now())
	if msg != "":
		return msg
	var owned := [father, mother].filter(func(c): return source_of(c["id"]) == "mine").size()
	if owned == 0:
		return "내 고양이가 한 마리는 있어야 해요"
	var shop_count := [father, mother].filter(func(c): return source_of(c["id"]) == "shop").size()
	if shop_count == 2:
		return "샵 고양이끼리는 교배할 수 없어요"
	var cost := breed_cost(father, mother)
	if cost > coins:
		return "냥이 부족해요 (필요 %d냥)" % cost
	return ""


## 교배: 새끼 1마리는 항상 신청자(나)가 데려감. 샵 개체는 사라지고 새 개체 입고
func do_breed(father_id: String, mother_id: String) -> Dictionary:
	var f = cat(father_id)
	var m = cat(mother_id)
	var err := check_breed(f, m)
	if err != "":
		return {"error": err}
	var cost := breed_cost(f, m)
	var kitten := CatEngine.breed(f, m, "k-" + _uid(), now())
	add_cat(kitten)
	coins -= cost
	var t := now()
	for p in [f, m]:
		if source_of(p["id"]) == "shop":
			shop.erase(p["id"])
		else:
			p["lastBreedAt"] = t
	mine.append(kitten["id"])
	var reward := register_dex(kitten)
	refill_shop()
	save()
	return {"kitten": kitten, "cost": cost, "reward": reward, "father": f, "mother": m}
