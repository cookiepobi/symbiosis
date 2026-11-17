class_name Rng
extends RefCounted
## 웹 버전 rng.js(mulberry32 + hashSeed)를 비트 단위까지 같게 옮긴 시드 난수.
## 같은 seed 문자열이면 웹과 같은 수열이 나온다(장식 배치·패치 등 재현용).

const M32 := 0xFFFFFFFF

var s: int = 0


func _init(seed_value: Variant = 0) -> void:
	if seed_value is String:
		s = hash_seed(seed_value)
	else:
		s = int(seed_value) & M32


## Math.imul과 같은 32비트 곱 (결과는 부호 없는 32비트)
static func imul(a: int, b: int) -> int:
	a &= M32
	b &= M32
	var lo := (a * (b & 0xFFFF)) & M32
	var hi := ((a * (b >> 16)) & 0xFFFF) << 16
	return (lo + hi) & M32


static func hash_seed(text: String) -> int:
	var h := (1779033703 ^ text.length()) & M32
	for i in text.length():
		h = imul(h ^ text.unicode_at(i), 3432918353)
		h = ((h << 13) & M32) | (h >> 19)
	h = imul(h ^ (h >> 16), 2246822507)
	h = imul(h ^ (h >> 13), 3266489909)
	return (h ^ (h >> 16)) & M32


func next() -> float:
	s = (s + 0x6D2B79F5) & M32
	var t := s
	t = imul(t ^ (t >> 15), t | 1)
	t = (t ^ ((t + imul(t ^ (t >> 7), t | 61)) & M32)) & M32
	return float((t ^ (t >> 14)) & M32) / 4294967296.0


func int_below(n: int) -> int:
	return int(floor(next() * n))


func range_f(a: float, b: float) -> float:
	return a + (b - a) * next()


func chance(p: float) -> bool:
	return next() < p


func pick(arr: Array) -> Variant:
	return arr[int_below(arr.size())]


func gauss() -> float:
	var u := 0.0
	var v := 0.0
	while u == 0.0:
		u = next()
	while v == 0.0:
		v = next()
	return sqrt(-2.0 * log(u)) * cos(TAU * v)


func weighted(weights: Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	var r := next() * total
	for i in weights.size():
		r -= weights[i]
		if r < 0:
			return i
	return weights.size() - 1


static func random_seed_string() -> String:
	const CH := "0123456789abcdefghijklmnopqrstuvwxyz"
	var out := ""
	for i in 8:
		out += CH[randi() % 36]
	return out + String.num_int64(int(Time.get_unix_time_from_system() * 1000), 36)
