extends "res://tests/test_case.gd"
## 웹 tests/game, pen, income, litter, navigation, behavior, guidance, preferences, controls 테스트 이식.

var mem: GameState.MemoryStorage
var g: GameState
var time := 2000000000000.0


func _fresh() -> GameState:
	mem = GameState.MemoryStorage.new()
	g = GameState.new(mem)
	g.clock = func() -> float: return time
	g.new_game()
	return g


func _rate() -> float:
	var r := 0.0
	for id in g.mine:
		r += CatEngine.income_per_hour(g.cats[id])
	return r


func _state_without_save_time() -> String:
	return g.export_save().get_slice("\"savedAt\"", 0)


# ───── game.test.js ─────
func test_save_round_trip() -> void:
	_fresh()
	var before := g.export_save()
	var ids := g.mine.duplicate()
	g.coins = 0
	check_eq(g.import_save(before), "")
	check_eq(g.mine, ids)
	check(g.coins > 0, "재화 복원")
	check(g.load_game(), "load")


func test_invalid_import_is_atomic() -> void:
	_fresh()
	var coins := g.coins
	var ids := g.mine.duplicate()
	var data = JSON.parse_string(g.export_save())
	data["coins"] = 9999
	data["mine"].append("missing")
	check(g.import_save(JSON.stringify(data)) != "", "거부")
	check_eq(g.coins, coins)
	check_eq(g.mine, ids)


func test_empty_household_valid() -> void:
	_fresh()
	for id in g.mine.duplicate():
		g.sell(id)
	check(g.load_game(), "빈 우리도 유효")
	check_eq(g.mine.size(), 0)


func test_new_game_resets_time() -> void:
	_fresh()
	g.skip_time(86400e3)
	g.new_game()
	check_eq(g.offset, 0.0)


func test_sold_cat_cannot_breed() -> void:
	_fresh()
	var f = g.cats[g.mine[0]]
	var m = g.cats[g.mine[1]]
	g.sell(f["id"])
	check(g.check_breed(f, m) != "", "판매한 고양이")
	check(g.check_breed(null, m) != "", "없는 고양이")


func test_care_rejects_invalid() -> void:
	_fresh()
	check_eq(g.care(g.shop[0], "feed")["ok"], false)
	check_eq(Personality.apply_care(null, "feed", g.now())["ok"], false)
	check_eq(Personality.apply_care(g.cats[g.mine[0]], "bad", g.now())["ok"], false)


func test_daily_care_cooldown() -> void:
	_fresh()
	var c = g.cats[g.mine[0]]
	var p = c["personality"]
	var t := g.now()
	check_eq(Wellbeing.daily_care(c, "clean", t)["ok"], true)
	check_eq(Wellbeing.comfort(c, t).filter(func(x): return x["id"] == "clean")[0]["value"], 100)
	check_eq(Wellbeing.daily_care(c, "clean", t + 1)["ok"], false)
	check_eq(Wellbeing.daily_care(c, "clean", t + 60e3)["ok"], true)
	check_eq(c["personality"], p)


func test_personality_odds_finite() -> void:
	var c := {"birthTime": 0.0, "care": {"scores": [10000, 10000, 10000, 10000, 10000, 10000, 10000, 10000], "last": {}, "log": []}}
	var odds := Personality.personality_odds(c)
	var total := 0.0
	for o in odds:
		check(is_finite(o), "유한")
		total += o
	check_near(total, 1.0, 1e-10, "합 1")


func test_storage_failure_observable() -> void:
	_fresh()
	mem.fail_writes = true
	check_eq(g.save(), false)
	mem.fail_writes = false


func test_shop_refresh() -> void:
	_fresh()
	var previous := g.shop.duplicate()
	var deadline := g.shop_refresh_at
	check_eq(g.refresh_shop(deadline - 1), false)
	check_eq(g.refresh_shop(deadline), true)
	check_eq(g.shop.size(), 8)
	for id in g.shop:
		check(not previous.has(id), "새 입고")
	for id in previous:
		check(g.cats.has(id), "기록 보존")
	check_eq(g.refresh_shop(deadline + 1), false)
	var f = g.cats[g.mine[0]]
	for id in previous:
		if g.cats[id]["sex"] == "F":
			check(g.check_breed(f, g.cats[id]) != "", "이전 재고는 부모 불가")
			break


func test_legacy_shop_deadline() -> void:
	_fresh()
	var data = JSON.parse_string(g.export_save())
	data.erase("shopRefreshAt")
	g.import_save(JSON.stringify(data))
	check(g.shop_refresh_at > g.now(), "기본 마감 설정")


func test_unsafe_names_rejected() -> void:
	_fresh()
	var data = JSON.parse_string(g.export_save())
	data["cats"][data["mine"][0]]["name"] = "<img onerror=alert(1)>"
	check(g.import_save(JSON.stringify(data)) != "", "이름 거부")
	data["cats"][data["mine"][0]]["name"] = "모찌"
	data["cats"][data["mine"][0]]["fatherId"] = "__proto__"
	check(g.import_save(JSON.stringify(data)) != "", "조상 거부")


func test_corrupt_save_preserved() -> void:
	_fresh()
	var valid := g.export_save()
	for invalid in ["", "{broken", JSON.stringify({"version": 99})]:
		mem.data[GameState.KEY] = invalid
		check_eq(g.load_game(), false)
		check_eq(g.load_issue["raw"], invalid)
		check_eq(g.save(), false)
		check_eq(mem.data[GameState.KEY], invalid)
		check(g.import_save("{invalid") != "", "깨진 JSON")
		check_eq(g.save(), false)
		g.import_save(valid)
		check_eq(g.load_issue, null)
		check(g.load_game(), "복구 후 로드")


# ───── pen.test.js ─────
func test_pen_start() -> void:
	_fresh()
	check_eq(g.pen_status()["capacity"], 6)
	check_eq(g.pen_status()["count"], 4)
	for i in range(1, Params.PEN_LEVELS.size()):
		check(Params.PEN_LEVELS[i]["capacity"] - Params.PEN_LEVELS[i - 1]["capacity"] in [1, 2], "증가폭")
	check_eq(g.pen_status()["next"]["cost"], 240)
	check_eq(g.upgrade_pen()["ok"], false)
	check_eq(g.coins, 200.0)


func test_pen_upgrade_once() -> void:
	_fresh()
	g.coins = 1000
	check_eq(g.upgrade_pen(1)["ok"], true)
	check_eq(g.coins, 760.0)
	check_eq(g.pen_status()["capacity"], 7)
	check_eq(g.upgrade_pen(1)["ok"], false)
	var raw := g.export_save()
	g.pen_level = 1
	g.import_save(raw)
	check_eq(g.pen_level, 2)
	g.pen_level = Params.PEN_LEVELS.size()
	var before := g.coins
	check_eq(g.upgrade_pen()["ok"], false)
	check_eq(g.coins, before)


func _overfull_raw() -> Dictionary:
	var raw = JSON.parse_string(g.export_save())
	for npc in raw["npcs"]:
		raw["mine"].append(npc["cats"].pop_front())
	return raw


func test_pen_legacy_migration() -> void:
	_fresh()
	var raw := _overfull_raw()
	raw.erase("penLevel")
	g.import_save(JSON.stringify(raw))
	check_eq(g.pen_level, 1)
	check_eq(g.mine.size(), 9)
	check_eq(g.pen_status()["over"], 3)
	for level in [-1, 0, 1.5, 99, "2"]:
		var invalid: Dictionary = raw.duplicate(true)
		invalid["penLevel"] = level
		check(g.import_save(JSON.stringify(invalid)) != "", "레벨 거부 %s" % str(level))
		check_eq(g.mine.size(), 9)


func test_full_pen_blocks_birth() -> void:
	_fresh()
	var father: String = g.mine[0]
	var mother: String = g.mine[1]
	g.coins = 9999
	for i in 2:
		g.skip_time(86400e3)
		check(g.do_breed(father, mother).has("kitten"), "교배 %d" % i)
	check_eq(g.mine.size(), 6)
	g.skip_time(86400e3)
	var before := _state_without_save_time()
	check(str(g.do_breed(father, mother).get("error", "")).contains("정원"), "정원 오류")
	check_eq(_state_without_save_time(), before)
	check(g.sell(g.mine[-1]) > 0, "판매")
	check(g.do_breed(father, mother).has("kitten"), "빈자리 후 교배")
	g.skip_time(86400e3)
	check_eq(g.upgrade_pen()["ok"], true)
	check(g.do_breed(father, mother).has("kitten"), "확장 후 교배")
	check_eq(g.mine.size(), 7)


func test_overcapacity_blocks_until_space() -> void:
	_fresh()
	g.import_save(JSON.stringify(_overfull_raw()))
	var father: String = g.mine[0]
	var mother: String = g.mine[1]
	check_eq(g.mine.size(), 9)
	var before := _state_without_save_time()
	check(str(g.do_breed(father, mother).get("error", "")).contains("정원"), "초과 차단")
	check_eq(_state_without_save_time(), before)
	check_eq(g.trade(g.mine[0], g.npcs[0]["id"], g.npcs[0]["cats"][0]), false)
	while g.mine.size() > 6:
		g.sell(g.mine[-1])
	check(str(g.do_breed(father, mother).get("error", "")).contains("정원"), "가득 참")
	g.sell(g.mine[-1])
	check(g.do_breed(father, mother).has("kitten"), "자리 생김")
	check_eq(g.mine.size(), 6)


# ───── income.test.js ─────
func test_income_fraction_kept() -> void:
	_fresh()
	var rate := _rate()
	var start := g.coins
	for i in 10:
		time += 360000
		g.collect_income()
	check_near(g.coins - start, rate, 1e-9, "합계")
	check(g.income_remainder < 1e-10, "나머지 0")
	check_eq(g.collect_income(), 0)


func test_income_carry_saved() -> void:
	_fresh()
	time += 123456
	g.collect_income()
	var carry := g.income_remainder
	check(carry > 0 and carry < 1, "나머지")
	var snap := g.export_save()
	g.income_remainder = 0
	g.import_save(snap)
	check_near(g.income_remainder, carry, 1e-12, "복원")
	var legacy = JSON.parse_string(snap)
	legacy.erase("incomeRemainder")
	g.import_save(JSON.stringify(legacy))
	check_eq(g.income_remainder, 0.0)
	legacy["incomeRemainder"] = 1
	check(g.import_save(JSON.stringify(legacy)) != "", "1 이상 거부")


func test_income_cap() -> void:
	_fresh()
	var rate := _rate()
	time += 72 * 3600e3
	check_eq(g.pending_income(), int(rate * 24))
	check_eq(g.collect_income(), int(rate * 24))


func test_sell_settles_income() -> void:
	_fresh()
	var rate := _rate()
	var id: String = g.mine[0]
	var price := CatEngine.sell_price(g.cats[id])
	var start := g.coins
	time += 123456
	g.sell(id)
	check_near(g.coins - start - price + g.income_remainder, rate * 123456 / 3600e3, 1e-9, "정산")


func test_traded_cat_income() -> void:
	_fresh()
	time += 3600e3
	var npc: Dictionary = g.npcs[0]
	check_eq(g.trade(g.mine[0], npc["id"], npc["cats"][0]), true)
	check_eq(g.pending_income(), 0)
	var rate := _rate()
	time += 3600e3
	check_eq(g.collect_income(), int(rate))


# ───── litter.test.js ─────
func test_litter_boundaries() -> void:
	var c := {"id": "a", "seed": "a", "birthTime": 0.0}
	var L := Wellbeing.LITTER_INTERVAL_MS
	check_eq(Wellbeing.litter_state([c], L - 1)["total"], 0)
	check_eq(Wellbeing.litter_state([c], L)["total"], 1)
	check_eq(Wellbeing.litter_state([c], L * 2)["total"], 2)
	check_eq(Wellbeing.litter_state([c], L * 1000)["total"], 3)
	check_eq(Wellbeing.litter_state([c], -1)["total"], 0)


func test_litter_clean_one_cat() -> void:
	var a := {"id": "a", "seed": "a", "birthTime": 0.0}
	var b := {"id": "b", "seed": "b", "birthTime": 0.0}
	var t := Wellbeing.LITTER_INTERVAL_MS * 3
	check_eq(Wellbeing.litter_state([a, b], t)["total"], 6)
	check_eq(Wellbeing.daily_care(a, "clean", t)["ok"], true)
	var restored = JSON.parse_string(JSON.stringify([a, b]))
	check_eq(Wellbeing.litter_state(restored, t)["total"], 3)
	for item in Wellbeing.litter_state(restored, t)["items"]:
		check_eq(item["catId"], "b")
	check_eq(Wellbeing.litter_state(restored, t + Wellbeing.LITTER_INTERVAL_MS)["total"], 4)


func test_litter_bounded() -> void:
	var many := []
	for i in 500:
		many.append({"id": "c%d" % i, "seed": "seed%d" % i, "birthTime": 0.0})
	var state := Wellbeing.litter_state(many, Wellbeing.LITTER_INTERVAL_MS * 3)
	check_eq(state["total"], 1500)
	check_eq(state["items"].size(), 12)
	check_eq(Wellbeing.litter_state([], 0)["total"], 0)


# ───── navigation.test.js ─────
const NB := {"minX": -10.0, "maxX": 10.0, "minZ": -10.0, "maxZ": 10.0}


func test_location_menus() -> void:
	var zones := [{"id": "shop", "x": 0.0, "z": 0.0, "r": 2.0}, {"id": "npc:n1", "x": 8.0, "z": 0.0, "r": 2.0}]
	check_eq(Locations.can_open_at("home", Vector2(50, 50), zones), true)
	check_eq(Locations.can_open_at("shop", Vector2(5, 5), zones), false)
	check_eq(Locations.can_open_at("shop", Vector2(1, 1), zones), true)
	check_eq(Locations.can_open_at("npc", Vector2(8, 0), zones), true)
	check_eq(Locations.can_open_at("breed", Vector2(0, 0), zones), false)
	check_eq(Locations.nearby_zones(Vector2(0, 0), zones).size(), 1)


func _path_ok(start: Vector2, path: Array, walls: Array) -> bool:
	var prev := start
	for p in path:
		if not Navigation.segment_clear(prev, p, walls):
			return false
		prev = p
	return true


func test_navigation_around_walls() -> void:
	var start := Vector2(-7, 0)
	var end := Vector2(7, 0)
	var walls := [[-1.0, 1.0, -5.0, 5.0]]
	check_eq(Navigation.segment_clear(start, end, walls), false)
	var path := Navigation.find_path(start, end, walls, NB)
	check(path.size() >= 3, "우회 경로")
	check(_path_ok(start, path, walls), "선분 여유")
	check_eq(path[-1], end)


func test_navigation_thin_fence_and_enclosed() -> void:
	var start := Vector2(-5, 0)
	var end := Vector2(5, 0)
	check_eq(Navigation.segment_clear(start, end, [[0.0, .1, -10.0, 10.0]]), false)
	check_eq(Navigation.find_path(start, end, [[0.0, .1, -10.0, 10.0]], NB), [])
	check_eq(Navigation.find_path(start, Vector2(30, 0), [], NB), [])
	check_eq(Navigation.find_path(start, Vector2(0, 0), [[-1.0, 1.0, -1.0, 1.0]], NB), [])


func test_navigation_gate() -> void:
	var walls := [[-5.0, 5.0, -5.1, -4.9], [-5.1, -4.9, -5.0, 5.0], [4.9, 5.1, -5.0, 5.0], [-5.0, -.9, 4.9, 5.1], [.9, 5.0, 4.9, 5.1]]
	var path := Navigation.find_path(Vector2.ZERO, Vector2(0, 9), walls, NB)
	check(path.size() > 0, "문 통과")
	check(_path_ok(Vector2.ZERO, path, walls), "울타리 관통 없음")


# ───── behavior.test.js ─────
const PEN := {"minX": -4.0, "maxX": 4.0, "minZ": -3.0, "maxZ": 3.0}


func test_behavior_bounds() -> void:
	var rng := Rng.new("behavior-bounds")
	var rnd := func() -> float: return rng.next()
	for p in [null, 0, 1, 2, 3, 4, 5, 6, 7]:
		for i in 300:
			var plan := Behavior.choose_activity(p, Vector2.ZERO, [{"id": "x", "pos": Vector2(3, 2)}], PEN, rnd)
			check(is_finite(plan["duration"]) and plan["duration"] > 0, "기간")
			if plan.has("target"):
				var t: Vector2 = plan["target"]
				check(t.x >= -4 and t.x <= 4 and t.y >= -3 and t.y <= 3, "우리 안")


func test_behavior_shy_corner() -> void:
	var plan := Behavior.choose_activity(1, Vector2.ZERO, [{"id": "x", "pos": Vector2(3, 2)}], PEN, func(): return .1)
	check_eq(plan["kind"], "hide")
	check_eq(plan["target"], Vector2(-4, -3))


func test_behavior_affectionate() -> void:
	var plan := Behavior.choose_activity(2, Vector2.ZERO, [{"id": "f", "pos": Vector2(2, 0)}], PEN, func(): return .1)
	check_eq(plan["kind"], "rub")
	check_near(plan["target"].distance_to(Vector2(2, 0)), .8, 1e-6, "0.8 거리")
	var vertical := Behavior.choose_activity(2, Vector2.ZERO, [{"id": "f", "pos": Vector2(0, .2)}], PEN, func(): return .1)
	check_near(vertical["target"].x, 0, 1e-6, "x")
	check_near(vertical["target"].y, -.6, 1e-6, "z")


func test_behavior_nap_alert() -> void:
	check_eq(Behavior.choose_activity(5, Vector2.ZERO, [], PEN, func(): return .9)["kind"], "nap")
	check_eq(Behavior.choose_activity(7, Vector2.ZERO, [{"id": "f", "pos": Vector2(.5, 0)}], PEN, func(): return .1)["kind"], "alert")


func test_behavior_social_alone() -> void:
	for p in [2, 6]:
		check_eq(Behavior.choose_activity(p, Vector2.ZERO, [], PEN, func(): return .1)["kind"], "roam")
		var together := Behavior.choose_activity(p, Vector2.ZERO, [{"id": "f", "pos": Vector2.ZERO}], PEN, func(): return .1)
		check(is_finite(together["target"].x) and is_finite(together["target"].y), "겹침 처리")


func test_behavior_shelter() -> void:
	var shelters := [{"id": "near", "pos": Vector2(3, 2)}, {"id": "far", "pos": Vector2(-3, -2)}]
	var plan := Behavior.choose_activity(1, Vector2.ZERO, [{"id": "x", "pos": Vector2(3, 2)}], PEN, func(): return .9, shelters)
	check_eq(plan["kind"], "shelter")
	check_eq(plan["shelterId"], "far")
	check_eq(plan["target"], Vector2(-3, -2))
	check_eq(shelters[0]["id"], "near")
	check_eq(Behavior.choose_activity(1, Vector2.ZERO, [], PEN, func(): return .9, [])["kind"], "hide")


func test_behavior_social_target() -> void:
	check_eq(Behavior.choose_activity(2, Vector2.ZERO, [{"id": "friend", "pos": Vector2(2, 0)}], PEN, func(): return .1)["partnerId"], "friend")
	check(Behavior.social_target(Vector2.ZERO, Vector2(2, 0), PEN).is_equal_approx(Vector2(1.2, 0)), "추적 지점")
	check(Behavior.social_target(Vector2(10, 3), Vector2(4, 3), PEN).is_equal_approx(Vector2(4, 3)), "울타리에서 멈춤")
	for a in ["nap", "hide", "shelter", "care", "rub", "pounce", "greet"]:
		check_eq(Behavior.can_receive_greeting(a), false)
	check_eq(Behavior.can_receive_greeting("roam"), true)


# ───── guidance.test.js ─────
func _step(o: Dictionary) -> Dictionary:
	var base := {"pen": {"count": 4, "capacity": 6, "over": 0, "next": {"capacity": 7, "cost": 240}}, "coins": 200, "pending": 0, "babyId": null, "ready": true}
	base.merge(o, true)
	return Locations.next_step(base["pen"], base["coins"], base["pending"], base["babyId"], base["ready"])


func test_guidance_overcrowding() -> void:
	var full := {"pen": {"count": 7, "capacity": 6, "over": 1, "next": {"capacity": 7, "cost": 240}}, "babyId": "baby"}
	check_eq(_step(full).get("zone"), "shop")
	var rich := full.duplicate(true)
	rich["coins"] = 300
	check_eq(_step(rich)["act"], "upgradepen")
	var maxed := full.duplicate(true)
	maxed["pen"]["next"] = null
	check_eq(_step(maxed).get("zone"), "shop")
	check_eq(_step({"pen": {"count": 19, "capacity": 19, "over": 0, "next": null}}).get("zone"), "shop")


func test_guidance_order() -> void:
	check_eq(_step({"coins": 240})["act"], "upgradepen")
	check_eq(_step({"pending": 40})["act"], "income")
	check_eq(_step({"babyId": "first"})["id"], "first")
	check_eq(_step({}).get("zone"), "breed")
	check_eq(_step({"ready": false, "pending": 10})["act"], "income")
	check_eq(_step({"ready": false}).get("zone"), "npc:n1")
	check_eq(_step({"pen": {"count": 0, "capacity": 6, "over": 0, "next": {"capacity": 7, "cost": 240}}})["act"], "backup")


func test_map_names() -> void:
	for p in [Vector2(-36, -26), Vector2(36, 22)]:
		var m := Locations.map_point(p)
		check(m.x > 0 and m.x < 600 and m.y > 0 and m.y < 370, "지도 안")
	check_eq(Locations.destination_name("npc:n2", [{"id": "n2", "name": "하늘이", "icon": "☁️"}]), "☁️ 하늘이의 집")
	check(Locations.destination_name("shop", []).contains("동물샵"), "동물샵")
	check_eq(Locations.destination_name("unknown", []), "마을")


# ───── preferences / controls ─────
func test_volume_preferences() -> void:
	var store := GameState.MemoryStorage.new()
	store.data[GameState.KEY] = "original game"
	check_eq(Preferences.load_audio(store), Preferences.DEFAULT_AUDIO)
	check_eq(Preferences.save_audio(store, {"music": 0, "effects": .27}), true)
	check_eq(Preferences.load_audio(store), {"music": 0.0, "effects": .27})
	check_eq(store.data[GameState.KEY], "original game")
	for music in [NAN, INF, -1, 1.1, "0", null]:
		check_eq(Preferences.audio_preferences({"music": music})["music"], Preferences.DEFAULT_AUDIO["music"])
	store.data[Preferences.AUDIO_KEY] = "{broken"
	check_eq(Preferences.load_audio(store), Preferences.DEFAULT_AUDIO)
	store.fail_writes = true
	check_eq(Preferences.save_audio(store, {"music": .2, "effects": .4}), false)


func test_touch_stick() -> void:
	check_eq(Preferences.stick_vector(2, 2), {"x": 0.0, "y": 0.0, "knobX": 0.0, "knobY": 0.0})
	var v := Preferences.stick_vector(100, -100)
	check_near(sqrt(v["x"] * v["x"] + v["y"] * v["y"]), 1, 1e-12, "최대 1")
	check_near(Vector2(v["knobX"], v["knobY"]).length(), 42, 1e-9, "손잡이 반지름")
	check(Preferences.stick_vector(20, 0)["x"] > 0 and Preferences.stick_vector(20, 0)["x"] < 1, "중간 세기")


# ───── 유전 규칙과 게임 연결 ─────
func test_costume_only_same_grade() -> void:
	var f := CatEngine.create_founder("f", {"sex": "M", "specialChance": 0.0})
	var m := CatEngine.create_founder("m", {"sex": "F", "specialChance": 0.0})
	f["genome"] = Genetics.parse_genotype("BBDDss")   # 언커먼 블랙
	m["genome"] = Genetics.parse_genotype("bbddss")   # 에픽 라일락
	CatEngine.finalize_cat(f)
	CatEngine.finalize_cat(m)
	var any := false
	for i in 2000:
		if CatEngine.breed(f, m, "x%d" % i)["costume"] != null:
			any = true
	check(not any, "등급이 다르면 의상 없음")


func test_costume_same_grade_rate() -> void:
	var f := CatEngine.create_founder("f", {"sex": "M", "specialChance": 0.0})
	var m := CatEngine.create_founder("m", {"sex": "F", "specialChance": 0.0})
	f["genome"] = Genetics.parse_genotype("bbddss")
	m["genome"] = Genetics.parse_genotype("bbddss")
	CatEngine.finalize_cat(f)
	CatEngine.finalize_cat(m)
	var n := 0
	for i in 4000:
		if CatEngine.breed(f, m, "y%d" % i)["costume"] != null:
			n += 1
	check_near(n / 4000.0, 0.15, 0.02, "에픽×에픽 15%")


func test_founders_follow_genetics() -> void:
	for i in 200:
		var c := CatEngine.create_founder("seed%d" % i)
		check(c["ph"]["id"] in Genetics.PHENOTYPE_ORDER, "8종 중 하나")
		check(c["grade"] == Params.SPECIAL_GRADE or (c["grade"] >= 0 and c["grade"] < 4), "4등급")
