class_name CatAppearance
extends RefCounted
## 유전 결과(Genetics.describe)를 고양이 모델의 머티리얼에 적용한다. (임시안 — 셰이더 방식 확정 전)
##
## 고양이 .glb 규칙(초안):
##   - 털 머티리얼 이름에 "coat"가 들어가면 털로 인식해 cat_coat 셰이더로 교체
##   - 같은 폴더의 <모델이름>_white_mask.png / <모델이름>_detail.png 를 마스크로 사용

const COAT_SHADER := preload("res://shaders/cat_coat.gdshader")

## 가이드 이미지 색감에 맞춘 기본색. 아트 확정 시 이 표만 바꾸면 된다.
const BASE_COLORS := {
	"black": Color("2b2b30"),
	"chocolate": Color("7a4a2f"),
	"blue": Color("8d939c"),
	"lilac": Color("c8aeb0"),
}
const WHITE_COLOR := Color("f7f4ec")


static func make_coat_material(cat: Dictionary, white_mask: Texture2D = null, detail: Texture2D = null) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = COAT_SHADER
	mat.set_shader_parameter("base_color", BASE_COLORS[cat["base"]])
	mat.set_shader_parameter("white_color", WHITE_COLOR)
	mat.set_shader_parameter("bicolor", cat["bicolor"])
	if white_mask:
		mat.set_shader_parameter("white_mask", white_mask)
	if detail:
		mat.set_shader_parameter("detail_map", detail)
	return mat


## 모델 안의 모든 메시에서 "coat" 머티리얼을 찾아 교체한다. 바뀐 표면 수를 돌려준다.
static func apply(model: Node, cat: Dictionary, white_mask: Texture2D = null, detail: Texture2D = null) -> int:
	var coat := make_coat_material(cat, white_mask, detail)
	var replaced := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if src and "coat" in src.resource_name.to_lower():
				mi.set_surface_override_material(i, coat)
				replaced += 1
	return replaced
