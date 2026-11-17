class_name SaveData
extends RefCounted
## 웹 save-data.js: 전체 스냅샷을 검사한 뒤에만 현재 게임을 교체한다. 실패하면 오류(문자열)를 돌려준다.

const ERR := "올바른 냥냥 유전 하우스 저장 파일이 아니에요"
const ALLELES := {"B": ["B", "b"], "D": ["D", "d"], "S": ["S", "s"]}
static var _id_re: RegEx
static var _unsafe_re: RegEx


static func _num(v) -> bool:
	return (v is float or v is int) and is_finite(float(v))


static func _int(v) -> bool:
	return _num(v) and float(v) == floor(float(v))


## 성공하면 "" , 실패하면 오류 메시지
static func validate(data) -> String:
	if _id_re == null:
		_id_re = RegEx.create_from_string("^[\\w-]+$")
		_unsafe_re = RegEx.create_from_string("[<>&\"']")
	if not (data is Dictionary):
		return ERR
	if data.get("version") != null and float(data["version"]) != 1.0:
		return ERR
	if not _num(data.get("coins")) or float(data["coins"]) < 0 or not _num(data.get("offset")) or not _num(data.get("lastCollect")):
		return ERR
	var rem = data.get("incomeRemainder")
	if rem != null and (not _num(rem) or float(rem) < 0 or float(rem) >= 1):
		return ERR
	var pl = data.get("penLevel")
	if pl != null and (not _int(pl) or float(pl) < 1 or float(pl) > Params.PEN_LEVELS.size()):
		return ERR
	if not (data.get("cats") is Dictionary) or not (data.get("mine") is Array) or not (data.get("shop") is Array) or not (data.get("npcs") is Array) or not (data.get("dex") is Dictionary):
		return ERR
	var cats: Dictionary = data["cats"]
	var has := func(id) -> bool: return id is String and cats.has(id)
	for id in cats:
		var c = cats[id]
		if not (c is Dictionary) or c.get("id") != id or not (c.get("name") is String) or c["name"].length() > 80 or _unsafe_re.search(c["name"]) != null:
			return ERR
		if _id_re.search(id) == null or id in ["__proto__", "constructor", "prototype"] or not (c.get("seed") is String) or not (c.get("sex") in ["M", "F"]):
			return ERR
		if c.get("special") != null and not CatEngine.SPECIALS.has(c["special"]):
			return ERR
		if c.get("fantasy") != null and not CatEngine.FANTASY.has(c["fantasy"]):
			return ERR
		if c.get("costume") != null and not (c["costume"] in Genetics.COSTUMES):
			return ERR
		if not _num(c.get("birthTime")) or not (c.get("lastBreedAt") == null or _num(c.get("lastBreedAt"))):
			return ERR
		if c.get("incomeSince") != null and not _num(c["incomeSince"]):
			return ERR
		if (c.get("fatherId") != null and not has.call(c["fatherId"])) or (c.get("motherId") != null and not has.call(c["motherId"])):
			return ERR
		var p = c.get("personality")
		if not (p == null or (_int(p) and float(p) >= 0 and float(p) < 8)):
			return ERR
		var genome = c.get("genome")
		if not (genome is Dictionary):
			return ERR
		for locus in ALLELES:
			var pair = genome.get(locus)
			if not (pair is Array) or pair.size() != 2:
				return ERR
			for a in pair:
				if not (a in ALLELES[locus]):
					return ERR
		var body = c.get("body")
		if not (body is Dictionary):
			return ERR
		for k in CatEngine.BODY_KEYS:
			if not _num(body.get(k)) or float(body[k]) < 0 or float(body[k]) > 1:
				return ERR
		var care = c.get("care")
		if care != null:
			if not (care is Dictionary) or not (care.get("scores") is Array) or care["scores"].size() != 8 or not (care.get("last") is Dictionary):
				return ERR
			for s in care["scores"]:
				if not _num(s):
					return ERR
			for t in care["last"].values():
				if not _num(t):
					return ERR
			if care.get("log") != null:
				if not (care["log"] is Array):
					return ERR
				for t in care["log"]:
					if not _num(t):
						return ERR
		var wb = c.get("wellbeing")
		if wb != null:
			if not (wb is Dictionary):
				return ERR
			for t in wb.values():
				if not _num(t):
					return ERR
	var assigned: Array = data["mine"] + data["shop"]
	if data["npcs"].size() != 5:
		return ERR
	for i in data["npcs"].size():
		var n = data["npcs"][i]
		if not (n is Dictionary) or n.get("id") != "n%d" % (i + 1) or not (n.get("name") is String) or _unsafe_re.search(n["name"]) != null:
			return ERR
		if not (n.get("icon") is String) or _unsafe_re.search(n["icon"]) != null or not (n.get("cats") is Array):
			return ERR
		assigned += n["cats"]
	var seen := {}
	for id in assigned:
		if not has.call(id) or seen.has(id):
			return ERR
		seen[id] = true
	for e in data["dex"].values():
		if not (e is Dictionary) or not has.call(e.get("catId")) or not _num(e.get("first")):
			return ERR
	return ""
