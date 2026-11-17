extends "res://tests/test_case.gd"
## 웹 rng.js와 같은 수열인지 확인. 기대값은 JScript(cscript)로 rng.js 공식을 그대로 실행해 얻었다.

const EXPECTED_HASH := {"grass": 1667208945, "decor": 2277433192, "calibration-v1": 1194249879, "start-abc123": 4006125869, "모찌:personality": 838699695}
const EXPECTED_GRASS := [0.38159030908718705, 0.45442519197240470, 0.70018332847394050, 0.54245507461018860, 0.21612542285583913, 0.10222515813075006, 0.91260560508817430, 0.87239746749401090]


func test_hash_seed_matches_web() -> void:
	for key in EXPECTED_HASH:
		check_eq(Rng.hash_seed(key), EXPECTED_HASH[key], key)


func test_sequence_matches_web() -> void:
	var r := Rng.new("grass")
	for v in EXPECTED_GRASS:
		check_near(r.next(), v, 1e-15, "grass 수열")
