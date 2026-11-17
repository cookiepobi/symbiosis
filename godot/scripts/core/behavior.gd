class_name Behavior
extends RefCounted
## 웹 behavior.js: 성격은 움직임에만 영향. 같은 우리 안 친구만 사교 대상.

const BEHAVIORS := [
	{"speed": 1.7, "chance": .82, "rest": 1.4, "bounce": .17, "sway": .08, "tail": .42},
	{"speed": .75, "chance": .28, "rest": 5.0, "bounce": .04, "sway": .02, "tail": .08},
	{"speed": 1.15, "chance": .6, "rest": 2.6, "bounce": .08, "sway": .1, "tail": .35},
	{"speed": .85, "chance": .35, "rest": 4.0, "bounce": .04, "sway": .025, "tail": .14},
	{"speed": 1.25, "chance": .75, "rest": 2.0, "bounce": .09, "sway": .07, "tail": .3},
	{"speed": .6, "chance": .2, "rest": 8.0, "bounce": .025, "sway": .02, "tail": .06},
	{"speed": 1.5, "chance": .85, "rest": 1.8, "bounce": .2, "sway": .12, "tail": .48},
	{"speed": 1.3, "chance": .45, "rest": 3.0, "bounce": .06, "sway": .035, "tail": .22},
]
const BABY := {"speed": .8, "chance": .5, "rest": 3.0, "bounce": .1, "sway": .06, "tail": .2}

const ACTIVITY_NAMES := {"idle": "주변을 둘러봐요", "roam": "산책해요", "explore": "새로운 곳을 살펴봐요", "nap": "낮잠을 자요",
	"groom": "앞발을 핥고 단장해요", "hide": "조용한 구석에서 쉬어요", "shelter": "포근한 쉼터에서 쉬어요", "watch": "혼자 느긋하게 구경해요", "rub": "친구와 얼굴을 비벼요",
	"pounce": "친구 곁에서 장난쳐요", "greet": "친구의 인사를 받아 줘요", "alert": "주변 움직임에 귀를 기울여요", "care": "집사와 함께 놀아요"}


static func of(personality) -> Dictionary:
	if personality == null or int(personality) < 0 or int(personality) >= BEHAVIORS.size():
		return BABY
	return BEHAVIORS[int(personality)]


static func clamp_target(point: Vector2, pen: Dictionary) -> Vector2:
	return Vector2(clampf(point.x, pen["minX"], pen["maxX"]), clampf(point.y, pen["minZ"], pen["maxZ"]))


## 위치는 Vector2(x, z)
static func social_target(position: Vector2, friend: Vector2, pen: Dictionary) -> Vector2:
	var d := position - friend
	var length := d.length()
	var dir := d / length if length > 1e-6 else Vector2(1, 0)
	return clamp_target(friend + dir * 0.8, pen)


static func can_receive_greeting(activity: String) -> bool:
	return activity in ["idle", "roam", "explore", "watch", "groom"]


## peers: [{id, pos: Vector2}], shelters: [{id, pos: Vector2}], random: Callable → float
static func choose_activity(personality, position: Vector2, peers: Array, pen: Dictionary, random: Callable, shelters: Array = []) -> Dictionary:
	var behavior := of(personality)
	var p: int = -1 if personality == null else int(personality)
	var target := func(x: float, z: float) -> Vector2: return Vector2(clampf(x, pen["minX"], pen["maxX"]), clampf(z, pen["minZ"], pen["maxZ"]))
	var nearest = null
	var distance := INF
	for peer in peers:
		var d: float = peer["pos"].distance_to(position)
		if d < distance:
			nearest = peer
			distance = d
	var duration: float = behavior["rest"] * (1.0 + random.call())
	var should_move: bool = random.call() < behavior["chance"]
	if p == 1 and not shelters.is_empty():
		var other: Vector2 = nearest["pos"] if nearest != null else position
		var sorted := shelters.duplicate()
		sorted.sort_custom(func(a, b): return a["pos"].distance_to(other) > b["pos"].distance_to(other))
		var quietest: Dictionary = sorted[0]
		return {"kind": "shelter", "duration": 8.0 + random.call() * 8.0, "target": target.call(quietest["pos"].x, quietest["pos"].y), "shelterId": quietest["id"]}
	if p == 5 and not should_move:
		return {"kind": "nap", "duration": 9.0 + random.call() * 9.0}
	if p == 7 and nearest != null and distance < 1.5:
		return {"kind": "alert", "duration": 3.0}
	if not should_move:
		return {"kind": "watch" if p == 3 else ("hide" if p == 1 else "groom"), "duration": duration}
	if p == 1 or p == 3:
		var other2: Vector2 = nearest["pos"] if nearest != null else position
		var corners := [target.call(pen["minX"], pen["minZ"]), target.call(pen["maxX"], pen["minZ"]), target.call(pen["minX"], pen["maxZ"]), target.call(pen["maxX"], pen["maxZ"])]
		corners.sort_custom(func(a, b): return a.distance_to(other2) > b.distance_to(other2))
		return {"kind": "hide" if p == 1 else "watch", "duration": duration, "target": corners[0]}
	if (p == 2 or p == 6) and nearest != null:
		return {"kind": "rub" if p == 2 else "pounce", "duration": 4.0 if p == 2 else 2.0,
			"target": social_target(position, nearest["pos"], pen), "partnerId": nearest["id"]}
	var roam: Vector2 = target.call(pen["minX"] + random.call() * (pen["maxX"] - pen["minX"]), pen["minZ"] + random.call() * (pen["maxZ"] - pen["minZ"]))
	return {"kind": "explore" if p == 4 else "roam", "duration": duration, "target": roam}
