class_name Locations
extends RefCounted
## 웹 locations.js + village-map.js의 이름 규칙 + next-step.js 안내.

const PLACE_NAMES := {"home": "🏠 우리집", "breed": "💞 교배집", "shop": "🛍️ 동물샵", "dex": "📖 유전 도서관", "npc": "🏘️ 이웃 마을"}


static func tab_of_zone(id) -> String:
	if id == null:
		return ""
	return "npc" if str(id).begins_with("npc:") else str(id)


## zones: [{id, x, z, r}]
static func nearby_zones(position: Vector2, zones: Array) -> Array:
	return zones.filter(func(z): return position.distance_to(Vector2(z["x"], z["z"])) <= z["r"] + 0.35)


static func can_open_at(tab: String, position: Vector2, zones: Array) -> bool:
	if tab == "home":
		return true
	for z in nearby_zones(position, zones):
		if tab_of_zone(z["id"]) == tab:
			return true
	return false


static func destination_name(id, npcs: Array) -> String:
	if id != null and str(id).begins_with("npc:"):
		for n in npcs:
			if n["id"] == str(id).substr(4):
				return "%s %s의 집" % [n["icon"], n["name"]]
	return PLACE_NAMES.get(tab_of_zone(id), "마을")


## 웹 village-map.js 좌표 변환 (600×370 지도)
static func map_point(p: Vector2) -> Vector2:
	return Vector2((p.x + 38.0) / 76.0 * 600.0, (p.y + 28.0) / 53.0 * 370.0)


## 진행 상황만 반영하는 안내. 보상·규칙은 바꾸지 않는다.
static func next_step(pen: Dictionary, coins: int, pending: int, baby_id, ready_to_breed: bool) -> Dictionary:
	if pen["count"] == 0:
		return {"title": "우리집이 비었어요", "text": "도감 기록은 남아 있어요. 진행을 백업해 보관하거나 아래 설정에서 새 게임을 선택할 수 있어요.", "act": "backup", "label": "진행 백업"}
	var nxt = pen["next"]
	if pen["over"] > 0:
		if nxt != null and coins >= nxt["cost"]:
			return {"title": "정원을 넓혀 새 가족을 지켜 주세요", "text": "%d마리를 초과했어요. 확장하면 추가 교배를 이어갈 수 있어요." % pen["over"], "act": "upgradepen", "label": "우리 확장"}
		return {"title": "우리 정원을 먼저 정리해 주세요", "text": "%d마리를 초과했어요. 자동으로 팔지 않으니 직접 남길 가족을 골라 주세요." % pen["over"], "act": "navigate", "zone": "shop", "label": "동물샵 가기"}
	if nxt != null and coins >= nxt["cost"]:
		return {"title": "다음 우리로 확장할 수 있어요", "text": "%d냥로 정원을 %d마리까지 늘릴 수 있어요." % [nxt["cost"], nxt["capacity"]], "act": "upgradepen", "label": "확장 살펴보기"}
	if nxt != null and pending > 0 and coins + pending >= nxt["cost"]:
		return {"title": "모인 수입을 받으면 확장할 수 있어요", "text": "아직 받지 않은 수입 %d냥를 먼저 받아 주세요." % pending, "act": "income", "label": "수입 받기"}
	if nxt == null and pen["count"] >= pen["capacity"]:
		return {"title": "가장 넓은 우리도 정원이 가득 찼어요", "text": "새 가족을 더 만나기 전에 동물샵에서 남길 고양이를 골라 공간을 준비해 주세요.", "act": "navigate", "zone": "shop", "label": "동물샵 가기"}
	if baby_id != null:
		return {"title": "아기와 함께 성격을 만들어 보세요", "text": "태어난 뒤 1시간 동안의 놀이·먹이·쓰다듬기가 성격에 영향을 줘요.", "act": "selectcare", "id": baby_id, "label": "아기 돌보기"}
	if ready_to_breed:
		return {"title": "새 가족의 모습을 만나 볼까요?", "text": "교배집에 가서 부모를 고르면 유전 조합을 확인하고 아기를 만날 수 있어요.", "act": "navigate", "zone": "breed", "label": "교배집 가기"}
	if pending > 0:
		return {"title": "고양이들이 모아 준 수입이 있어요", "text": "%d냥를 받아 다음 우리 확장에 보태 보세요." % pending, "act": "income", "label": "수입 받기"}
	return {"title": "이웃을 만나 새로운 짝을 찾아보세요", "text": "고양이들이 쉬는 동안 이웃 고양이를 구경하거나 교환을 생각해 볼 수 있어요.", "act": "navigate", "zone": "npc:n1", "label": "이웃 만나기"}
