extends "res://tests/test_case.gd"
## 동기화된 에셋이 Godot에서 열리는지, 규칙 파일이 올바른지 검사한다.

const RULES_PATH := "res://assets/asset_rules.json"
const MODELS_DIR := "res://assets/models"


func test_rules_file_is_valid() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(RULES_PATH))
	check(data is Dictionary, "asset_rules.json 파싱 실패")
	if not data is Dictionary:
		return
	for key in ["caretaker", "cat_adult", "kitten", "fence", "door"]:
		check(data["references"].has(key), "기준 모형 누락: " + key)
	for cat_name in data["categories"]:
		var range_: Array = data["categories"][cat_name]["height"]
		check(range_.size() == 2 and range_[0] < range_[1], "높이 범위 오류: " + cat_name)


func test_every_synced_model_loads() -> void:
	for path in _list_models(MODELS_DIR):
		var scene = load(path)
		check(scene is PackedScene, "불러오기 실패: " + path)
		if scene is PackedScene:
			var node: Node = scene.instantiate()
			check(node != null, "인스턴스 생성 실패: " + path)
			if node:
				node.free()


func _list_models(dir_path: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_list_models(dir_path.path_join(sub)))
	for file in dir.get_files():
		var name := file.trim_suffix(".import").trim_suffix(".remap")
		if name.get_extension() == "glb" and not out.has(dir_path.path_join(name)):
			out.append(dir_path.path_join(name))
	return out
