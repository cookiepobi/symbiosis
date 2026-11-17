class_name ToonMat
extends RefCounted
## three MeshToonMaterial / MeshBasicMaterial 대응 머티리얼 생성.

const SHADERS := {
	"opaque": preload("res://shaders/toon.gdshader"),
	"double": preload("res://shaders/toon_double.gdshader"),
	"alpha": preload("res://shaders/toon_alpha.gdshader"),
	"alpha_double": preload("res://shaders/toon_alpha_double.gdshader"),
}


static func color_of(c) -> Color:
	if c is Color:
		return c
	if c is String:
		return Color(c)
	return Color.hex((int(c) << 8) | 0xFF)


## opts: map(Texture2D), transparent, opacity, double_sided, lit, emissive(Color), emissive_intensity,
##       emissive_from_map, fog, view_bias, map_repeat(Vector2), alpha_test
static func make(color, opts := {}) -> ShaderMaterial:
	var transparent: bool = opts.get("transparent", false)
	var double: bool = opts.get("double_sided", false)
	var key := ("alpha" if transparent else "opaque") if not double else ("alpha_double" if transparent else "double")
	var m := ShaderMaterial.new()
	m.shader = SHADERS[key]
	m.set_shader_parameter("albedo", color_of(color))
	m.set_shader_parameter("lit", opts.get("lit", true))
	if opts.has("map") and opts["map"] != null:
		m.set_shader_parameter("use_map", true)
		m.set_shader_parameter("map", opts["map"])
	if opts.has("map_repeat"):
		m.set_shader_parameter("map_repeat", opts["map_repeat"])
	if opts.has("opacity"):
		m.set_shader_parameter("opacity", opts["opacity"])
	if opts.has("emissive"):
		m.set_shader_parameter("emissive", color_of(opts["emissive"]))
		m.set_shader_parameter("emissive_intensity", opts.get("emissive_intensity", 1.0))
		m.set_shader_parameter("emissive_from_map", opts.get("emissive_from_map", false))
	if opts.has("fog"):
		m.set_shader_parameter("use_fog", opts["fog"])
	if opts.has("view_bias"):
		m.set_shader_parameter("view_bias", opts["view_bias"])
	if opts.has("alpha_test"):
		m.set_shader_parameter("alpha_test", opts["alpha_test"])
	if opts.has("render_priority"):
		m.render_priority = opts["render_priority"]
	return m


static func toon(color, opts := {}) -> ShaderMaterial:
	return make(color, opts)


static func basic(color, opts := {}) -> ShaderMaterial:
	var o: Dictionary = opts.duplicate()
	o["lit"] = false
	return make(color, o)


## three: new Mesh(geometry, material) + position/scale/rotation(Euler XYZ)
static func mesh_node(geo: ThreeGeo, mat: Material, pos := Vector3.ZERO, scale := Vector3.ONE, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = geo.mesh()
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	mi.rotation_order = EULER_ORDER_XYZ
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func group(pos := Vector3.ZERO) -> Node3D:
	var g := Node3D.new()
	g.rotation_order = EULER_ORDER_XYZ
	g.position = pos
	return g
