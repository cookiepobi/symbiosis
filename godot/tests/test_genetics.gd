extends "res://tests/test_case.gd"
## 고양이 유전 가이드 이미지의 규칙과 예시를 검증한다.

const G = preload("res://scripts/genetics/genetics.gd")


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func test_eight_basic_cats_from_patterns() -> void:
	var cases := {
		"BBDDss": "black", "BbDdSs": "black_bicolor", "bbDdss": "chocolate",
		"Bbddss": "blue", "bbDDSS": "chocolate_bicolor", "BBddSs": "blue_bicolor",
		"bbddss": "lilac", "bbddSs": "lilac_bicolor",
	}
	for genotype in cases:
		check_eq(G.phenotype_id(G.parse_genotype(genotype)), cases[genotype], genotype)


func test_grades_follow_rarity() -> void:
	var expected := {
		"black_bicolor": "common", "black": "uncommon", "chocolate_bicolor": "uncommon",
		"blue_bicolor": "uncommon", "chocolate": "rare", "blue": "rare", "lilac_bicolor": "rare",
		"lilac": "epic",
	}
	for id in expected:
		check_eq(G.PHENOTYPES[id]["grade"], expected[id], id)
	# 등급이 높을수록 BbDdSs × BbDdSs에서 더 드물어야 한다
	var dist := G.offspring_distribution(G.parse_genotype("BbDdSs"), G.parse_genotype("BbDdSs"))
	for id in dist:
		var rank := G.GRADE_ORDER.find(G.PHENOTYPES[id]["grade"])
		check_near(dist[id], pow(3, 3 - rank) / 64.0, 1e-9, "희귀도와 등급 일치: " + id)


func test_genotype_string_puts_dominant_first() -> void:
	var genome := {"B": ["b", "B"], "D": ["d", "d"], "S": ["s", "S"]}
	check_eq(G.genotype_string(genome), "BbddSs")


func test_child_alleles_come_from_parents() -> void:
	var father := G.parse_genotype("BBddSS")
	var mother := G.parse_genotype("bbDDss")
	var rng := _rng(7)
	for i in 200:
		var child := G.cross(father, mother, rng)
		check_eq(G.genotype_string(child), "BbDdSs", "부모가 동형접합이면 자손은 항상 같은 이형접합")


# 가계도 예시 1: 블랙 × 블랙(D가 이형접합) → 블랙 75%, 블루 25%
func test_example_black_x_black() -> void:
	var dist := G.offspring_distribution(G.parse_genotype("BBDdss"), G.parse_genotype("BBDdss"))
	check_near(dist["black"], 0.75, 1e-9, "블랙")
	check_near(dist["blue"], 0.25, 1e-9, "블루")


# 예시 2: 블랙 바이컬러 × 블랙 바이컬러(Ss × Ss) → 바이컬러 75%, 단색 25%
func test_example_bicolor_x_bicolor() -> void:
	var dist := G.offspring_distribution(G.parse_genotype("BBDDSs"), G.parse_genotype("BBDDSs"))
	check_near(dist["black_bicolor"], 0.75, 1e-9, "블랙 바이컬러")
	check_near(dist["black"], 0.25, 1e-9, "블랙 단색")


# 예시 3: 초콜릿(bbDdss) × 블루(Bbddss) → 네 색 각 25%
func test_example_chocolate_x_blue() -> void:
	var dist := G.offspring_distribution(G.parse_genotype("bbDdss"), G.parse_genotype("Bbddss"))
	for id in ["black", "blue", "chocolate", "lilac"]:
		check_near(dist[id], 0.25, 1e-9, id)


# 예시 4: BbDdSs × BbDdSs. 멘델 비율 27:9:9:9:3:3:3:1 (/64).
# 주의: 가이드 이미지는 블랙(42.19%)과 블랙 바이컬러(14.06%) 등 일부 라벨이 서로 바뀌어 있다.
func test_example_all_heterozygous() -> void:
	var dist := G.offspring_distribution(G.parse_genotype("BbDdSs"), G.parse_genotype("BbDdSs"))
	var expected := {
		"black_bicolor": 27, "black": 9, "chocolate_bicolor": 9, "blue_bicolor": 9,
		"chocolate": 3, "blue": 3, "lilac_bicolor": 3, "lilac": 1,
	}
	var total := 0.0
	for id in expected:
		check_near(dist[id], expected[id] / 64.0, 1e-9, id)
		total += dist[id]
	check_near(total, 1.0, 1e-9, "합계")


func test_random_breeding_matches_exact_distribution() -> void:
	var father := G.parse_genotype("BbDdSs")
	var mother := G.parse_genotype("BbDdSs")
	var exact := G.offspring_distribution(father, mother)
	var counts := {}
	var rng := _rng(20261117)
	var n := 20000
	for i in n:
		var id := G.phenotype_id(G.cross(father, mother, rng))
		counts[id] = counts.get(id, 0) + 1
	for id in exact:
		check_near(float(counts.get(id, 0)) / n, exact[id], 0.012, id)


func test_costume_chance_by_grade() -> void:
	check_near(G.costume_chance("common", "common"), 0.01, 1e-9, "커먼×커먼")
	check_near(G.costume_chance("uncommon", "uncommon"), 0.07, 1e-9, "언커먼×언커먼")
	check_near(G.costume_chance("rare", "rare"), 0.10, 1e-9, "레어×레어")
	check_near(G.costume_chance("epic", "epic"), 0.15, 1e-9, "에픽×에픽")
	check_eq(G.costume_chance("common", "rare"), 0.0, "등급이 다르면 의상 없음")


func test_costume_rate_and_genome_unchanged() -> void:
	var parent := G.parse_genotype("bbddss")  # 라일락(에픽) 동형접합
	var rng := _rng(42)
	var n := 8000
	var with_costume := 0
	for i in n:
		var kid := G.breed(parent, parent, rng)
		check_eq(kid["phenotype"], "lilac", "의상과 무관하게 기본 외형은 부모와 같음")
		if kid["costume"] != "":
			with_costume += 1
			check(kid["costume"] in G.COSTUMES, "알 수 없는 의상 " + kid["costume"])
	check_near(float(with_costume) / n, 0.15, 0.015, "에픽×에픽 의상 확률")


func test_breeding_is_deterministic_with_seed() -> void:
	var father := G.parse_genotype("BbDdSs")
	var mother := G.parse_genotype("bbDdss")
	var a := []
	var b := []
	var r1 := _rng(99)
	var r2 := _rng(99)
	for i in 50:
		a.append(G.breed(father, mother, r1))
		b.append(G.breed(father, mother, r2))
	check_eq(a, b, "같은 seed면 같은 결과")
