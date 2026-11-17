extends Control
## 웹 lab.html/lab.js/simulation.js/expectation.js: 유전 실험실 (유전 가이드 3좌위 버전).
## 게임 진행에는 영향을 주지 않는다.

signal closed

const LABELS := {"B": "갈색 (B)", "D": "희석 (D)", "S": "흰반점 (S)"}
const OPTIONS := {"B": ["B", "b"], "D": ["D", "d"], "S": ["S", "s"]}
const COUNTS := [100, 1000, 10000]

var father: Dictionary
var mother: Dictionary
var running := false
var cancelled := false
var revision := 0
var seed_edit: LineEdit
var count_opt: OptionButton
var father_box: VBoxContainer
var mother_box: VBoxContainer
var expect_box: VBoxContainer
var status: Label
var progress: ProgressBar
var results: VBoxContainer
var run_btn: Button
var cancel_btn: Button
var lockables: Array = []
var width := 800.0


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#fbf8ef")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	width = minf(860.0, get_viewport_rect().size.x - 32)
	var main := UIKit.vbox([], 14)
	main.custom_minimum_size = Vector2(width, 0)
	center.add_child(main)
	var header := HBoxContainer.new()
	var back := LinkButton.new()
	back.text = "🐾 냥냥 유전 하우스로 돌아가기"
	back.add_theme_color_override("font_color", Color("#426d5a"))
	back.pressed.connect(func(): closed.emit())
	header.add_child(back)
	main.add_child(UIKit.spacer(10))
	main.add_child(header)
	main.add_child(UIKit.label("CAT GENETICS LAB", 11, "#7a8f72", true))
	main.add_child(UIKit.label("어떤 아기가 태어날까요?", 30, "#3f4a3a", true))
	main.add_child(UIKit.label("부모의 숨은 유전자를 바꾸고, 같은 seed로 결과를 다시 확인해 보세요.", 14, "#3f4a3a"))
	main.add_child(UIKit.hint("게임 진행에는 영향을 주지 않는 실험 공간이에요. 고양이 유전 가이드(B·D·S 3좌위)를 그대로 사용합니다."))
	seed_edit = LineEdit.new()
	seed_edit.text = "nyang-lab-2026"
	seed_edit.max_length = 120
	seed_edit.custom_minimum_size = Vector2(220, 0)
	seed_edit.text_changed.connect(func(_t): _invalidate())
	count_opt = OptionButton.new()
	for t in ["100회 · 빠르게", "1,000회 · 기본", "10,000회 · 정밀하게"]:
		count_opt.add_item(t)
	count_opt.select(1)
	count_opt.item_selected.connect(func(_i): _invalidate())
	var rnd := UIKit.button("이 seed로 부모 생성", _randomize, "pale")
	run_btn = UIKit.button("🧬 교배 실험 시작", _run, "leaf")
	cancel_btn = UIKit.button("실험 중지", func(): cancelled = true, "gray")
	cancel_btn.visible = false
	lockables = [seed_edit, count_opt, rnd, run_btn]
	main.add_child(UIKit.box([UIKit.row([UIKit.vbox([UIKit.label("실험 seed", 12, UIKit.INK, true), seed_edit], 4), UIKit.vbox([UIKit.label("교배 횟수", 12, UIKit.INK, true), count_opt], 4), rnd, run_btn, cancel_btn], 12)], "#eef0e6", "#eef0e6", 16, 0, 16))
	var presets := [UIKit.label("예제", 13, UIKit.INK2, false, false)]
	for p in [["dilute", "희석 Dd × Dd"], ["white", "흰반점 Ss × Ss"], ["chocolate", "초콜릿 Bb × Bb"], ["all", "모두 이형접합 BbDdSs × BbDdSs"]]:
		var key: String = p[0]
		var b := UIKit.button(p[1], func(): _preset(key), "pale", true)
		lockables.append(b)
		presets.append(b)
	main.add_child(UIKit.row(presets, 6))
	father_box = UIKit.vbox([], 6)
	mother_box = UIKit.vbox([], 6)
	var parents := HBoxContainer.new()
	parents.add_theme_constant_override("separation", 16)
	for b in [father_box, mother_box]:
		var bx := UIKit.box([b], "#ffffff", "#e6e1d2", 16, 1, 16)
		bx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		parents.add_child(bx)
	main.add_child(parents)
	expect_box = UIKit.vbox([], 6)
	main.add_child(UIKit.box([expect_box], "#ffffff", "#e6e1d2", 16, 1, 16))
	var exp := UIKit.button("💾 실험 설정 저장", _export, "pale", true)
	var imp := UIKit.button("📂 설정 불러오기", _import, "pale", true)
	lockables.append_array([exp, imp])
	main.add_child(UIKit.row([exp, imp, UIKit.hint("seed·부모 유전자·횟수를 JSON 파일로 보관합니다.")], 8))
	status = UIKit.label("부모 유전자를 선택하거나 예제를 골라 보세요.", 14, "#426d5a")
	main.add_child(status)
	progress = ProgressBar.new()
	progress.visible = false
	main.add_child(progress)
	results = UIKit.vbox([], 8)
	results.visible = false
	main.add_child(UIKit.box([results], "#ffffff", "#e6e1d2", 16, 1, 16))
	main.add_child(UIKit.hint("성격은 돌봄으로 결정되므로 이 실험에는 포함하지 않습니다. SPECIAL·판타지·의상은 게임 규칙에 따라 별도로 추첨합니다."))
	main.add_child(UIKit.spacer(30))
	_randomize()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


static func experiment_parent(seed_value: String, sex: String, genome = null) -> Dictionary:
	if seed_value.strip_edges() == "" or seed_value.length() > 120 or not (sex in ["M", "F"]):
		push_error("seed와 성별을 확인해 주세요")
		return {}
	var p := CatEngine.create_founder("%s:%s" % [seed_value, sex], {"sex": sex, "specialChance": 0.0})
	if genome != null:
		for loc in OPTIONS:
			var pair = genome.get(loc)
			if not (pair is Array) or pair.size() != 2 or not (pair[0] in OPTIONS[loc]) or not (pair[1] in OPTIONS[loc]):
				return {}
		p["genome"] = genome.duplicate(true)
	return CatEngine.finalize_cat(p)


func _invalidate() -> void:
	revision += 1
	results.visible = false
	progress.visible = false
	status.text = "설정이 바뀌었어요. 교배 실험을 시작해 주세요."


func _randomize() -> void:
	var s := seed_edit.text.strip_edges()
	var f := experiment_parent(s, "M")
	var m := experiment_parent(s, "F")
	if f.is_empty() or m.is_empty():
		status.text = "seed와 성별을 확인해 주세요"
		return
	father = f
	mother = m
	_render_parents()
	_invalidate()


func _preset(key: String) -> void:
	var s := seed_edit.text.strip_edges()
	var f := experiment_parent(s, "M")
	var m := experiment_parent(s, "F")
	if f.is_empty():
		return
	var fg: Dictionary = f["genome"]
	var mg: Dictionary = m["genome"]
	match key:
		"dilute":
			fg["D"] = ["D", "d"]; mg["D"] = ["D", "d"]
		"white":
			fg["S"] = ["S", "s"]; mg["S"] = ["S", "s"]
		"chocolate":
			fg["B"] = ["B", "b"]; mg["B"] = ["B", "b"]
		"all":
			fg = Genetics.parse_genotype("BbDdSs"); mg = Genetics.parse_genotype("BbDdSs")
	father = experiment_parent(s, "M", fg)
	mother = experiment_parent(s, "F", mg)
	_render_parents()
	_invalidate()


func _render_parent(box: VBoxContainer, parent: Dictionary, title: String, key: String) -> void:
	for ch in box.get_children():
		ch.queue_free()
	box.add_child(UIKit.label(title, 20, UIKit.INK, true))
	var prev := HBoxContainer.new()
	prev.add_theme_constant_override("separation", 12)
	prev.add_child(UIKit.thumb_bg(parent, 130, 90, 14))
	var info := UIKit.vbox([UIKit.label(CatEngine.grade_label(parent), 15, UIKit.INK, true), UIKit.label("%s · %s" % [CatEngine.phenotype_name(parent), parent["ph"]["genotype"]], 13)], 4)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	prev.add_child(info)
	box.add_child(prev)
	var table := GridContainer.new()
	table.columns = 2
	table.add_theme_constant_override("h_separation", 20)
	table.add_child(UIKit.label("유전자좌", 12, UIKit.INK2, true, false))
	table.add_child(UIKit.label("대립유전자", 12, UIKit.INK2, true, false))
	for loc in OPTIONS:
		table.add_child(UIKit.label(LABELS[loc], 13, UIKit.INK, false, false))
		var r := HBoxContainer.new()
		for i in 2:
			var opt := OptionButton.new()
			for a in OPTIONS[loc]:
				opt.add_item(a)
			opt.select(OPTIONS[loc].find(parent["genome"][loc][i]))
			var index := i
			var locus: String = loc
			opt.item_selected.connect(func(sel):
				var genome: Dictionary = (father if key == "father" else mother)["genome"].duplicate(true)
				genome[locus][index] = OPTIONS[locus][sel]
				var updated := experiment_parent(seed_edit.text.strip_edges(), "M" if key == "father" else "F", genome)
				if updated.is_empty():
					status.text = "%s 유전자형을 확인해 주세요" % locus
					return
				if key == "father":
					father = updated
				else:
					mother = updated
				_render_parents()
				_invalidate())
			lockables.append(opt)
			r.add_child(opt)
		table.add_child(r)
	box.add_child(table)


func _render_parents() -> void:
	lockables = lockables.filter(func(c): return is_instance_valid(c) and not (c is OptionButton and c != count_opt))
	_render_parent(father_box, father, "♂ 아빠", "father")
	_render_parent(mother_box, mother, "♀ 엄마", "mother")
	_render_expectation()


static func _pct(p: float) -> String:
	return "%.1f%%" % (p * 100)


func _render_expectation() -> void:
	for ch in expect_box.get_children():
		ch.queue_free()
	expect_box.add_child(UIKit.label("🧮 실험 전, 이론으로 예상하기", 20, UIKit.INK, true))
	expect_box.add_child(UIKit.hint("부모의 대립유전자를 하나씩 고르는 모든 경우를 합산합니다(멘델 법칙). 표본의 비율은 이론과 다를 수 있어요."))
	var dist := Genetics.offspring_distribution(father["genome"], mother["genome"])
	var metrics := []
	for id in Genetics.PHENOTYPE_ORDER:
		if dist[id] > 0:
			metrics.append(UIKit.box([UIKit.label(Genetics.PHENOTYPES[id]["name"], 12, UIKit.INK2, false, false), UIKit.label(_pct(dist[id]), 18, UIKit.INK, true, false)], "#f3f4ec", "#f3f4ec", 12, 0, 10))
	expect_box.add_child(UIKit.row(metrics, 8))
	expect_box.add_child(UIKit.hint("성별은 암컷·수컷 각각 50%. SPECIAL·판타지·의상·외형 파라미터는 이 표에 포함하지 않습니다."))
	var table := GridContainer.new()
	table.columns = 3
	table.add_theme_constant_override("h_separation", 24)
	for h in ["좌위", "자손 유전자형", "이론 비율"]:
		table.add_child(UIKit.label(h, 12, UIKit.INK2, true, false))
	for loc in OPTIONS:
		var counts := {}
		for a in father["genome"][loc]:
			for b in mother["genome"][loc]:
				var pair := [a, b]
				pair.sort()
				var k := "/".join(pair)
				counts[k] = counts.get(k, 0.0) + 0.25
		for k in counts:
			table.add_child(UIKit.label(loc, 13, UIKit.INK, false, false))
			table.add_child(UIKit.label(k, 13, UIKit.INK, false, false))
			table.add_child(UIKit.label(_pct(counts[k]), 13, UIKit.INK, false, false))
	expect_box.add_child(UIKit.label("좌위별 이론 비율", 14, UIKit.INK, true))
	expect_box.add_child(table)


func _set_running(v: bool) -> void:
	running = v
	for c in lockables:
		if is_instance_valid(c):
			if c is BaseButton:
				c.disabled = v
			elif c is LineEdit:
				c.editable = not v
	cancel_btn.visible = v


func _run() -> void:
	if running:
		return
	var s := seed_edit.text.strip_edges()
	var count: int = COUNTS[count_opt.selected]
	var f := experiment_parent(s, "M", father["genome"])
	var m := experiment_parent(s, "F", mother["genome"])
	if f.is_empty() or m.is_empty():
		status.text = "실험 오류: seed와 유전자형을 확인해 주세요"
		return
	father = f
	mother = m
	_render_parents()
	var report := {"total": 0, "sexes": {"M": 0, "F": 0}, "grades": [0, 0, 0, 0], "special": 0, "fantasy": 0, "costume": 0,
		"catalog": {}, "phen": {}, "samples": [], "loci": {}}
	var expected_rev := revision
	cancelled = false
	_set_running(true)
	progress.visible = true
	progress.value = 0
	results.visible = false
	var start := 0
	while start < count and not cancelled:
		for i in range(start, mini(start + 100, count)):
			var child := CatEngine.breed(father, mother, "%s:offspring:%d" % [s, i], 0)
			report["total"] += 1
			report["sexes"][child["sex"]] += 1
			if child.get("special") != null:
				report["special"] += 1
			else:
				report["grades"][child["baseGrade"]] += 1
			if child.get("fantasy") != null:
				report["fantasy"] += 1
			if child.get("costume") != null:
				report["costume"] += 1
			report["catalog"][child["catalogId"]] = report["catalog"].get(child["catalogId"], 0) + 1
			report["phen"][child["ph"]["id"]] = report["phen"].get(child["ph"]["id"], 0) + 1
			for loc in OPTIONS:
				var pair: Array = child["genome"][loc].duplicate()
				pair.sort()
				var key := "/".join(pair)
				if not report["loci"].has(loc):
					report["loci"][loc] = {}
				report["loci"][loc][key] = report["loci"][loc].get(key, 0) + 1
			if report["samples"].size() < 8:
				report["samples"].append(child)
		start += 100
		progress.value = 100.0 * report["total"] / count
		status.text = "교배 중… %s / %s" % [GameUI._comma(report["total"]), GameUI._comma(count)]
		await get_tree().process_frame
	if revision == expected_rev and report["total"] > 0:
		_show_results(report, s, not cancelled)
	status.text = ("%s회에서 중지했어요. 부분 결과를 표시합니다." % GameUI._comma(report["total"])) if cancelled else ("%s회 실험 완료. 같은 설정과 seed는 같은 유전 결과를 만듭니다." % GameUI._comma(report["total"]))
	_set_running(false)


func _hist(label: String, n: int, total: int) -> Control:
	var r := HBoxContainer.new()
	var l := UIKit.label(label, 13, UIKit.INK, false, false)
	l.custom_minimum_size = Vector2(110, 0)
	r.add_child(l)
	r.add_child(UIKit.bar(float(n) / total, 12))
	var v := UIKit.label("%s · %.1f%%" % [GameUI._comma(n), 100.0 * n / total], 13, UIKit.INK2, false, false)
	v.custom_minimum_size = Vector2(110, 0)
	r.add_child(v)
	return r


func _show_results(report: Dictionary, s: String, complete: bool) -> void:
	for ch in results.get_children():
		ch.queue_free()
	var n: int = report["total"]
	var largest := 0
	for v in report["catalog"].values():
		largest = maxi(largest, v)
	results.add_child(UIKit.label("실험 결과" if complete else "중지한 실험 결과", 20, UIKit.INK, true))
	results.add_child(UIKit.hint("seed: %s · 고정된 부모 쌍의 독립 교배 %s회 · 표본 비율이며 확정 확률은 아닙니다." % [s, GameUI._comma(n)]))
	var metrics := []
	for kv in [["교배 표본", GameUI._comma(n)], ["발견 외형", str(report["catalog"].size())], ["암컷 / 수컷", "%d / %d" % [report["sexes"]["F"], report["sexes"]["M"]]], ["최다 외형 비율", "%.1f%%" % (100.0 * largest / n)]]:
		metrics.append(UIKit.box([UIKit.label(kv[0], 12, UIKit.INK2, false, false), UIKit.label(kv[1], 20, "#2f4a35", true, false)], "#f3f4ec", "#f3f4ec", 12, 0, 12))
	results.add_child(UIKit.row(metrics, 8))
	results.add_child(UIKit.label("외형 (기본 8종)", 15, UIKit.INK, true))
	for id in Genetics.PHENOTYPE_ORDER:
		results.add_child(_hist(Genetics.PHENOTYPES[id]["name"], report["phen"].get(id, 0), n))
	results.add_child(UIKit.label("등급과 별도 추첨", 15, UIKit.INK, true))
	for i in Params.GRADES.size():
		results.add_child(_hist(Params.GRADES[i], report["grades"][i], n))
	for kv in [["SPECIAL", report["special"]], ["판타지", report["fantasy"]], ["의상", report["costume"]]]:
		results.add_child(_hist(kv[0], kv[1], n))
	results.add_child(UIKit.hint("등급 + SPECIAL은 전체 표본입니다. 판타지·의상은 해당 표본과 중복 집계합니다. 의상은 부모 등급이 같을 때만 나옵니다."))
	results.add_child(UIKit.label("처음 태어난 아기 8마리", 15, UIKit.INK, true))
	var cards := []
	for c in report["samples"]:
		cards.append(UIKit.box([UIKit.thumb_bg(c, 130, 110), UIKit.rich("%s %s" % [UIKit.sex_text(c), CatEngine.grade_label(c)], 13), UIKit.hint(CatEngine.phenotype_name(c))], "#ffffff", "#e6e1d2", 14, 1, 8))
	results.add_child(UIKit.grid(cards, width - 40, 160))
	results.add_child(UIKit.label("이론과 표본 비교", 15, UIKit.INK, true))
	var dist := Genetics.offspring_distribution(father["genome"], mother["genome"])
	var table := GridContainer.new()
	table.columns = 4
	table.add_theme_constant_override("h_separation", 24)
	for h in ["외형", "이론", "실험", "차이 (%p)"]:
		table.add_child(UIKit.label(h, 12, UIKit.INK2, true, false))
	for id in Genetics.PHENOTYPE_ORDER:
		var sample := float(report["phen"].get(id, 0)) / n
		var diff: float = 100.0 * (sample - dist[id])
		table.add_child(UIKit.label(Genetics.PHENOTYPES[id]["name"], 13, UIKit.INK, false, false))
		table.add_child(UIKit.label(_pct(dist[id]), 13, UIKit.INK, false, false))
		table.add_child(UIKit.label(_pct(sample), 13, UIKit.INK, false, false))
		table.add_child(UIKit.label("%s%.1f" % ["+" if diff > 0 else "", diff], 13, UIKit.INK, false, false))
	results.add_child(table)
	results.add_child(UIKit.hint("표본 오차가 있으므로 실험 비율이 이론과 정확히 일치할 필요는 없어요. 더 많은 표본으로 차이를 비교해 보세요."))
	results.add_child(UIKit.label("좌위별 자손 유전자형 분포", 15, UIKit.INK, true))
	for loc in report["loci"]:
		for k in report["loci"][loc]:
			results.add_child(_hist("%s · %s" % [loc, k], report["loci"][loc][k], n))
	results.visible = true


func _config() -> Dictionary:
	return {"version": 1, "seed": seed_edit.text.strip_edges(), "count": COUNTS[count_opt.selected], "father": father["genome"], "mother": mother["genome"]}


func _export() -> void:
	var data := JSON.stringify(_config(), "  ")
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(data.to_utf8_buffer(), "냥냥-유전실험.json", "application/json")
		return
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json"])
	dlg.current_file = "냥냥-유전실험.json"
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(data))
	add_child(dlg)
	dlg.popup_centered()


func _import() -> void:
	var dlg := FileDialog.new()
	dlg.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dlg.access = FileDialog.ACCESS_FILESYSTEM
	dlg.filters = PackedStringArray(["*.json"])
	dlg.use_native_dialog = true
	dlg.file_selected.connect(func(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null or f.get_length() > 100000:
			status.text = "100KB 이하의 실험 설정을 골라 주세요"
			return
		var cfg = JSON.parse_string(f.get_as_text())
		if not (cfg is Dictionary) or cfg.get("version") != 1.0 or not (int(cfg.get("count", 0)) in COUNTS):
			status.text = "지원하지 않는 실험 파일이에요"
			return
		var fa := experiment_parent(str(cfg["seed"]), "M", cfg.get("father"))
		var ma := experiment_parent(str(cfg["seed"]), "F", cfg.get("mother"))
		if fa.is_empty() or ma.is_empty():
			status.text = "유전자형을 확인해 주세요"
			return
		father = fa
		mother = ma
		seed_edit.text = str(cfg["seed"])
		count_opt.select(COUNTS.find(int(cfg["count"])))
		_render_parents()
		_invalidate()
		status.text = "실험 설정을 불러왔어요.")
	add_child(dlg)
	dlg.popup_centered()
