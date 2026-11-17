class_name VillageMapView
extends Control
## 웹 village-map.js의 SVG 지도(600×370)를 같은 좌표로 그린다.

var pens: Dictionary
var zones: Array
var player: Vector2
var npcs: Array


func setup(p: Dictionary, z: Array, pl: Vector2, n: Array) -> VillageMapView:
	pens = p
	zones = z
	player = pl
	npcs = n
	custom_minimum_size = Vector2(0, 250)
	return self


func _draw() -> void:
	var k := minf(size.x / 600.0, size.y / 370.0)
	var off := Vector2((size.x - 600 * k) / 2, (size.y - 370 * k) / 2)
	var P := func(v: Vector2) -> Vector2: return off + Locations.map_point(v) * k
	draw_style_box(UIKit.sb("#dbeacc", int(18 * k)), Rect2(off, Vector2(600, 370) * k))
	var road := Color("#e9d4aa")
	draw_line(P.call(Vector2(-32, 13)), P.call(Vector2(32, 13)), road, 22 * k)
	draw_line(P.call(Vector2(0, 13)), P.call(Vector2(0, -10.4)), road, 22 * k)
	draw_line(P.call(Vector2(-28, -10.4)), P.call(Vector2(30, -10.4)), road, 22 * k)
	var font := Fonts.body()
	for pen in pens.values():
		var p0: Vector2 = P.call(Vector2(pen["cx"] - pen["w"] / 2, pen["cz"] - pen["d"] / 2))
		var r := Rect2(p0, Vector2(pen["w"] / 76.0 * 600, pen["d"] / 53.0 * 370) * k)
		draw_style_box(UIKit.sb("#f5e3b0" if pen["id"] == "mine" else "#e4ddba", int(6 * k), int(2 * k) + 1, "#b59062"), r)
	var home: Vector2 = P.call(Vector2(pens["mine"]["cx"], pens["mine"]["cz"]))
	draw_string(font, home + Vector2(-60, 6) * k, "🏠 우리집", HORIZONTAL_ALIGNMENT_CENTER, 120 * k, int(20 * k), Color("#4e5944"))
	for zone in zones:
		var p: Vector2 = P.call(Vector2(zone["x"], zone["z"]))
		var npc: bool = str(zone["id"]).begins_with("npc:")
		var idx := -1
		for i in npcs.size():
			if "npc:" + npcs[i]["id"] == zone["id"]:
				idx = i
		var text: String = ("%d %s" % [idx + 1, npcs[idx]["name"]]) if npc and idx >= 0 else Locations.destination_name(zone["id"], npcs)
		var rad := (7.0 if npc else 10.0) * k
		draw_circle(p, rad + 2 * k, Color.WHITE)
		draw_circle(p, rad, Color("#8a987a") if npc else Color("#e5ac99"))
		draw_string(font, p + Vector2(-90 * k, (25 if npc else -18) * k + 6 * k), text, HORIZONTAL_ALIGNMENT_CENTER, 180 * k, int(19 * k), Color("#4e5944"))
	var pp: Vector2 = P.call(player)
	draw_circle(pp, 12 * k, Color.WHITE)
	draw_circle(pp, 9 * k, Color("#3d8dba"))
	var right := Locations.map_point(player).x > 480
	draw_string(font, pp + Vector2(-134 * k if right else 14 * k, -10 * k), "현재 위치", HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT, 120 * k, int(18 * k), Color("#245675"))
