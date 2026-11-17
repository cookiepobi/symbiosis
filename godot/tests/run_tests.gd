extends SceneTree
## 실행: godot --headless --path godot -s res://tests/run_tests.gd

const SUITES := [
	"res://tests/test_genetics.gd",
	"res://tests/test_assets.gd",
	"res://tests/test_game.gd",
	"res://tests/test_rng.gd",
]


func _init() -> void:
	var total := 0
	var failed := 0
	for path in SUITES:
		var script: GDScript = load(path)
		for method in script.get_script_method_list():
			var name: String = method["name"]
			if not name.begins_with("test_"):
				continue
			var suite = script.new()
			suite.call(name)
			total += 1
			if suite.failures.is_empty():
				print("  ok   %s :: %s" % [path.get_file(), name])
			else:
				failed += 1
				print("  FAIL %s :: %s" % [path.get_file(), name])
				for f in suite.failures:
					print("         - " + f)
	print("\n%d개 중 %d개 통과" % [total, total - failed])
	quit(1 if failed > 0 else 0)
