class_name Thumbnails
extends Node
## 웹 stage.js thumbnail(): 오프스크린에서 고양이를 찍어 카드·도감 이미지로 쓴다.
## 요청 즉시 빈 ImageTexture를 돌려주고, 렌더가 끝나면 같은 텍스처 내용을 채운다.

static var instance: Thumbnails

var _vp: SubViewport
var _cam: Camera3D
var _cache := {}
var _queue: Array = []
var _busy := false


func _ready() -> void:
	instance = self
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(180, 180)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_cam = Camera3D.new()
	_cam.fov = 30
	_cam.near = 0.1
	_cam.far = 50
	_vp.add_child(_cam)
	_cam.look_at_from_position(Vector3(0, 1.6, 5.6), Vector3(0, 0.95, 0))


static func key_of(cat: Dictionary, size: int) -> String:
	return "%s|%s|%s|%s|%d" % [cat["seed"], cat["catalogId"], str(cat.get("costume")), "b" if cat.get("personality") == null else str(cat["personality"]), size]


static func get_texture(cat: Dictionary, size := 180) -> Texture2D:
	return instance._request(cat, size)


func _request(cat: Dictionary, size: int) -> Texture2D:
	var key := key_of(cat, size)
	if _cache.has(key):
		return _cache[key]
	var tex := ImageTexture.create_from_image(Image.create(size, size, false, Image.FORMAT_RGBA8))
	_cache[key] = tex
	_queue.append({"cat": cat.duplicate(true), "size": size, "tex": tex})
	if _cache.size() > 400:
		_cache.erase(_cache.keys()[0])
	if not _busy:
		_pump()
	return tex


func _pump() -> void:
	_busy = true
	while not _queue.is_empty():
		var job: Dictionary = _queue.pop_front()
		var model := CatModel.build(job["cat"])
		model.rotation.y = 0.35
		model.tick(0.2)
		_vp.add_child(model)
		_vp.size = Vector2i(job["size"], job["size"])
		_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		model.queue_free()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGBA8)
			job["tex"].set_image(img)
	_busy = false
