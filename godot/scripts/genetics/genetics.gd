class_name Genetics
extends RefCounted
## 고양이 유전 가이드(8종 기본 고양이 + 스페셜 의상) 구현.
##
## 좌위 3개, 각 좌위는 독립 유전(멘델 법칙):
##   B/b  열색 색소   B: 검정 계열(eumelanin) > b: 초콜릿 계열
##   D/d  희석        D: 진한 색 > d: 희석(블루·라일락)
##   S/s  흰 반점     S: 흰 반점 있음(바이컬러) > s: 없음(단색)
## 유전자형은 { "B": ["B","b"], "D": [...], "S": [...] } 형태의 Dictionary.
## 순수 데이터·함수만 두어 화면 없이 테스트할 수 있게 한다.

const LOCI: Array[String] = ["B", "D", "S"]

## 표현형 8종. 등급은 희귀도(모든 좌위 이형접합 교배 BbDdSs × BbDdSs의 멘델 비율 27:9:3:1) 기준.
##   커먼 27/64 · 언커먼 9/64 · 레어 3/64 · 에픽 1/64
const PHENOTYPES := {
	"black": {"name": "블랙", "grade": "uncommon", "base": "black", "bicolor": false, "pattern": "B_D_ss"},
	"black_bicolor": {"name": "블랙 바이컬러", "grade": "common", "base": "black", "bicolor": true, "pattern": "B_D_S_"},
	"chocolate": {"name": "초콜릿", "grade": "rare", "base": "chocolate", "bicolor": false, "pattern": "bbD_ss"},
	"blue": {"name": "블루", "grade": "rare", "base": "blue", "bicolor": false, "pattern": "B_ddss"},
	"chocolate_bicolor": {"name": "초콜릿 바이컬러", "grade": "uncommon", "base": "chocolate", "bicolor": true, "pattern": "bbD_S_"},
	"blue_bicolor": {"name": "블루 바이컬러", "grade": "uncommon", "base": "blue", "bicolor": true, "pattern": "B_ddS_"},
	"lilac": {"name": "라일락", "grade": "epic", "base": "lilac", "bicolor": false, "pattern": "bbddss"},
	"lilac_bicolor": {"name": "라일락 바이컬러", "grade": "rare", "base": "lilac", "bicolor": true, "pattern": "bbddS_"},
}

## 가이드 이미지의 번호 순서(도감 정렬용).
const PHENOTYPE_ORDER: Array[String] = [
	"black", "black_bicolor", "chocolate", "blue",
	"chocolate_bicolor", "blue_bicolor", "lilac", "lilac_bicolor",
]

const GRADE_ORDER: Array[String] = ["common", "uncommon", "rare", "epic"]
const GRADE_NAMES := {"common": "커먼", "uncommon": "언커먼", "rare": "레어", "epic": "에픽"}

## 등급별 스페셜(의상) 등장 확률. 부모 등급이 같을 때만 적용, 등급이 다르면 의상은 나오지 않는다.
const COSTUME_CHANCE := {"common": 0.01, "uncommon": 0.07, "rare": 0.10, "epic": 0.15}

const COSTUMES: Array[String] = ["chef", "wizard", "crown", "captain", "detective", "santa", "explorer"]
const COSTUME_NAMES := {
	"chef": "요리사", "wizard": "마법사", "crown": "왕관", "captain": "선장",
	"detective": "탐정", "santa": "계절(산타)", "explorer": "탐험가",
}


## "BbDdSs" 같은 문자열을 유전자형으로 변환. 순서·대소문자 외 문자는 허용하지 않는다.
static func parse_genotype(text: String) -> Dictionary:
	var compact := text.replace(" ", "")
	assert(compact.length() == LOCI.size() * 2, "유전자형은 6글자여야 합니다: %s" % text)
	var genome := {}
	for i in LOCI.size():
		var locus: String = LOCI[i]
		var pair := [compact[i * 2], compact[i * 2 + 1]]
		for allele in pair:
			assert(allele.to_upper() == locus, "%s 좌위에 잘못된 대립유전자 %s" % [locus, allele])
		genome[locus] = pair
	return genome


## 유전자형을 "BbDdSs" 형식으로. 각 좌위는 우성을 앞에 둔다.
static func genotype_string(genome: Dictionary) -> String:
	var out := ""
	for locus in LOCI:
		var pair: Array = genome[locus].duplicate()
		pair.sort_custom(func(a, b): return a == locus and b != locus)
		out += pair[0] + pair[1]
	return out


static func has_dominant(genome: Dictionary, locus: String) -> bool:
	return locus in genome[locus]


static func phenotype_id(genome: Dictionary) -> String:
	var dense := has_dominant(genome, "D")
	var base: String
	if has_dominant(genome, "B"):
		base = "black" if dense else "blue"
	else:
		base = "chocolate" if dense else "lilac"
	return base + "_bicolor" if has_dominant(genome, "S") else base


static func grade_of(genome: Dictionary) -> String:
	return PHENOTYPES[phenotype_id(genome)]["grade"]


## 부모 등급 조합으로 스페셜 의상 확률을 구한다. 등급이 다르면 0.
static func costume_chance(grade_a: String, grade_b: String) -> float:
	if grade_a != grade_b:
		return 0.0
	return COSTUME_CHANCE[grade_a]


## 각 부모에게서 좌위마다 대립유전자 하나씩 물려받는다.
static func cross(father: Dictionary, mother: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var child := {}
	for locus in LOCI:
		child[locus] = [
			father[locus][rng.randi_range(0, 1)],
			mother[locus][rng.randi_range(0, 1)],
		]
	return child


## 교배 결과 한 마리. 의상은 유전되지 않고 매 탄생마다 확률로 붙는다.
static func breed(father: Dictionary, mother: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var genome := cross(father, mother, rng)
	var chance := costume_chance(grade_of(father), grade_of(mother))
	var costume := ""
	if rng.randf() < chance:
		costume = COSTUMES[rng.randi_range(0, COSTUMES.size() - 1)]
	return describe(genome, "F" if rng.randf() < 0.5 else "M", costume)


## 유전자형 + 성별 + 의상으로 고양이 외형 정보를 만든다.
static func describe(genome: Dictionary, sex: String, costume: String = "") -> Dictionary:
	var id := phenotype_id(genome)
	var info: Dictionary = PHENOTYPES[id]
	return {
		"genome": genome,
		"genotype": genotype_string(genome),
		"sex": sex,
		"phenotype": id,
		"name": info["name"],
		"grade": info["grade"],
		"base": info["base"],
		"bicolor": info["bicolor"],
		"costume": costume,
	}


## 부모 유전자형에서 자손 표현형의 정확한 확률(좌위별 4조합을 모두 곱해서 계산).
static func offspring_distribution(father: Dictionary, mother: Dictionary) -> Dictionary:
	var dist := {}
	for id in PHENOTYPE_ORDER:
		dist[id] = 0.0
	var per_locus := []
	for locus in LOCI:
		var combos := []
		for fa in father[locus]:
			for ma in mother[locus]:
				combos.append([fa, ma])
		per_locus.append(combos)
	for b in per_locus[0]:
		for d in per_locus[1]:
			for s in per_locus[2]:
				var id := phenotype_id({"B": b, "D": d, "S": s})
				dist[id] += 1.0 / 64.0
	return dist
