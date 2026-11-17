extends RefCounted
## 아주 작은 테스트 베이스. 외부 플러그인 없이 headless로 실행한다.

var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func check_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("%s (기대: %s, 실제: %s)" % [message, str(expected), str(actual)])


func check_near(actual: float, expected: float, tolerance: float, message: String = "") -> void:
	if absf(actual - expected) > tolerance:
		failures.append("%s (기대: %.4f ± %.4f, 실제: %.4f)" % [message, expected, tolerance, actual])
