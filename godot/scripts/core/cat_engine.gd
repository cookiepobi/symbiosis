class_name CatEngine
extends RefCounted
## 웹 engine.js에서 유전자좌 부분만 유전 가이드(Genetics)로 바꾸고 나머지(외형 파라미터 유전, SPECIAL,
## 판타지, 의상, 근친 규칙, 가격·수입)는 같은 규칙으로 옮겼다.

const SPECIALS := {"sphynx": "스핑크스", "manx": "맨스크", "curl": "아메리칸 컬", "singapura": "싱가푸라"}
const SPECIAL_KEYS := ["sphynx", "manx", "curl", "singapura"]
const FANTASY := {"mint": "네온 민트", "galaxy": "은하 보라", "holo": "홀로그램 핑크", "aurora": "오로라 블루"}
const FANTASY_KEYS := ["mint", "galaxy", "holo", "aurora"]
const BODY_KEYS := ["whisker", "ear", "face", "bulk"]
const NAMES := ["모찌", "두부", "호두", "콩이", "보리", "쌀이", "김치", "치즈", "라떼", "구름", "별이", "달이", "밤이", "자두", "망고", "레몬", "푸딩", "쿠키", "마루", "나비", "하루", "솜이", "밍밍", "초코", "복실", "찹쌀", "고구마", "유자", "도토리", "미소"]

static var _id_counter := 1


static func costume_name(id: String) -> String:
	return Genetics.COSTUME_NAMES.get(id, id)


static func draw_allele(rng: Rng, table: Dictionary) -> String:
	var r := rng.next()
	var keys := table.keys()
	for k in keys:
		r -= table[k]
		if r < 0:
			return k
	return keys[keys.size() - 1]


static func random_genome(rng: Rng) -> Dictionary:
	var g := {}
	for loc in Genetics.LOCI:
		g[loc] = [draw_allele(rng, Params.FREQ[loc]), draw_allele(rng, Params.FREQ[loc])]
	return g


static func hidden_carrier_count(genome: Dictionary) -> int:
	var n := 0
	for loc in Genetics.LOCI:
		if genome[loc][0] != genome[loc][1]:
			n += 1
	return n


static func grade_index(genome: Dictionary) -> int:
	return Genetics.GRADE_ORDER.find(Genetics.grade_of(genome))


## 유전자형에서 파생 값(표현형·등급·도감 ID·보인자 수)을 다시 계산한다.
static func finalize_cat(cat: Dictionary) -> Dictionary:
	var id := Genetics.phenotype_id(cat["genome"])
	var info: Dictionary = Genetics.PHENOTYPES[id]
	cat["ph"] = {"id": id, "name": info["name"], "base": info["base"], "bicolor": info["bicolor"],
		"genotype": Genetics.genotype_string(cat["genome"])}
	cat["baseGrade"] = grade_index(cat["genome"])
	var special = cat.get("special")
	var fantasy = cat.get("fantasy")
	cat["grade"] = Params.SPECIAL_GRADE if special != null else cat["baseGrade"]
	if special != null:
		cat["catalogId"] = "special:" + special
	elif fantasy != null:
		cat["catalogId"] = "fantasy:" + fantasy
	else:
		cat["catalogId"] = id
	cat["carriers"] = hidden_carrier_count(cat["genome"])
	return cat


static func is_special(cat: Dictionary) -> bool:
	return cat.get("grade") == Params.SPECIAL_GRADE


static func grade_label(cat: Dictionary) -> String:
	return "SPECIAL" if is_special(cat) else Params.GRADES[cat["grade"]]


static func grade_color(cat: Dictionary) -> String:
	return "#ff6fb0" if is_special(cat) else Params.GRADE_COLORS[cat["grade"]]


static func phenotype_name(cat: Dictionary) -> String:
	return cat["ph"]["name"]


static func random_name(rng: Rng) -> String:
	return rng.pick(NAMES)


static func new_id() -> String:
	var id := "c" + String.num_int64(int(Time.get_unix_time_from_system() * 1000), 36) + String.num_int64(_id_counter, 36)
	_id_counter += 1
	return id


## 창업 개체 (시작·샵·이웃)
static func create_founder(seed_value: String, opts: Dictionary = {}) -> Dictionary:
	var rng := Rng.new(seed_value)
	var sex: String = opts["sex"] if opts.get("sex") != null else ("M" if rng.chance(0.5) else "F")
	var genome := random_genome(rng)
	var body := {}
	for k in BODY_KEYS:
		body[k] = clampf(0.5 + rng.gauss() * 0.2, 0.0, 1.0)
	var special = null
	var special_chance: float = opts.get("specialChance", Params.SPECIAL_CHANCE * 0.5)
	if rng.chance(special_chance):
		special = rng.pick(SPECIAL_KEYS)
	var personality = opts["personality"] if opts.has("personality") else rng.int_below(8)
	var cat := {
		"id": new_id(), "name": random_name(rng), "sex": sex, "genome": genome, "body": body,
		"special": special, "fantasy": null, "costume": null, "fatherId": null, "motherId": null,
		"seed": seed_value, "birthTime": opts.get("birthTime", 0.0), "personality": personality,
		"lastBreedAt": -1e15,
	}
	return finalize_cat(cat)


## 금지: 부모↔자식, 형제자매(동복·이복 포함)
static func is_forbidden_pair(a: Dictionary, b: Dictionary) -> String:
	if a["id"] == b["id"]:
		return "자기 자신과는 교배할 수 없어요"
	if a.get("fatherId") == b["id"] or a.get("motherId") == b["id"] or b.get("fatherId") == a["id"] or b.get("motherId") == a["id"]:
		return "부모와 자식은 교배할 수 없어요"
	if (a.get("fatherId") != null and a.get("fatherId") == b.get("fatherId")) or (a.get("motherId") != null and a.get("motherId") == b.get("motherId")):
		return "형제자매는 교배할 수 없어요"
	return ""


static func can_breed(father, mother, now_ms: float) -> String:
	if father == null or mother == null:
		return "부모를 선택하세요"
	if father["sex"] != "M" or mother["sex"] != "F":
		return "수컷 1마리와 암컷 1마리가 필요해요"
	var bad := is_forbidden_pair(father, mother)
	if bad != "":
		return bad
	for c in [father, mother]:
		if c.get("personality") == null:
			return "%s은(는) 아직 아기라서 성장이 끝나야 해요 (1시간)" % c["name"]
		if now_ms - float(c["lastBreedAt"]) < Params.BREED_COOLDOWN_MS:
			return "%s은(는) 쿨다운 중이에요" % c["name"]
	return ""


static func breed(father: Dictionary, mother: Dictionary, seed_value: String, now_ms: float = 0.0) -> Dictionary:
	var rng := Rng.new(seed_value)
	var genome := {}
	for loc in Genetics.LOCI:
		genome[loc] = [father["genome"][loc][rng.int_below(2)], mother["genome"][loc][rng.int_below(2)]]
	var sex := "M" if rng.chance(0.5) else "F"
	var body := {}
	for k in BODY_KEYS:
		var mid: float = (father["body"][k] + mother["body"][k]) / 2.0
		var spread: float = absf(father["body"][k] - mother["body"][k]) / 2.0
		body[k] = clampf(mid + (rng.next() - 0.5) * 2.0 * spread * 0.6 + rng.gauss() * Params.BODY_MUTATION_SIGMA, 0.0, 1.0)
	var special = rng.pick(SPECIAL_KEYS) if rng.chance(Params.SPECIAL_CHANCE) else null
	var cat := finalize_cat({
		"id": new_id(), "name": random_name(rng), "sex": sex, "genome": genome, "body": body,
		"special": special, "fantasy": null, "costume": null, "fatherId": father["id"], "motherId": mother["id"],
		"seed": seed_value, "birthTime": now_ms, "personality": null, "lastBreedAt": -1e15,
		"care": {"scores": [0, 0, 0, 0, 0, 0, 0, 0], "last": {}, "log": []},
	})
	if special == null and cat["baseGrade"] == Params.GRADES.size() - 1 and rng.chance(Params.FANTASY_CHANCE_ON_TOP):
		cat["fantasy"] = rng.pick(FANTASY_KEYS)
		cat = finalize_cat(cat)
	# 의상: 부모 등급이 같을 때만(둘 다 SPECIAL 아님). 유전 엔진과 독립 RNG
	var cr := Rng.new(seed_value + ":costume")
	if not is_special(father) and not is_special(mother) and father["grade"] == mother["grade"]:
		var g: String = Genetics.GRADE_ORDER[father["grade"]]
		if cr.chance(Genetics.costume_chance(g, g)):
			cat["costume"] = cr.pick(Genetics.COSTUMES)
	return cat


static func sell_price(cat: Dictionary) -> int:
	var base: float = Params.SELL_SPECIAL if is_special(cat) else Params.SELL_PRICE_BY_GRADE[cat["grade"]]
	if cat.get("fantasy") != null:
		base *= Params.FANTASY_PRICE_MULT
	if cat.get("costume") != null:
		base *= 1.3
	base *= 1.0 + Params.CARRIER_BONUS_RATE * cat["carriers"]
	return int(round(base))


static func shop_breed_price(cat: Dictionary) -> int:
	return int(round(sell_price(cat) * Params.SHOP_BREED_MULT))


static func income_per_hour(cat: Dictionary) -> float:
	if is_special(cat):
		return Params.INCOME_SPECIAL_PER_HOUR
	return Params.INCOME_PER_HOUR_BY_GRADE[cat["grade"]] * (2 if cat.get("fantasy") != null else 1)
