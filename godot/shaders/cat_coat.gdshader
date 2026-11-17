shader_type spatial;
// 고양이 털색 셰이더 (임시안 — 확정 아님).
// 팀원이 만든 마스크 텍스처 + 유전자에서 계산한 색으로 털을 칠한다.
//   white_mask : 흰 반점(바이컬러) 영역. 흰색=흰 털. S_일 때만 사용.
//   detail_map : 명암·털결 등 색과 무관한 디테일(회색조). 없으면 흰색.
// 색 자체는 텍스처에 굽지 않으므로 8종 × 의상 조합을 텍스처 하나로 처리한다.

uniform vec3 base_color : source_color = vec3(0.17, 0.17, 0.18);
uniform vec3 white_color : source_color = vec3(0.97, 0.96, 0.93);
uniform bool bicolor = false;
uniform sampler2D white_mask : hint_default_black, filter_linear_mipmap;
uniform sampler2D detail_map : hint_default_white, filter_linear_mipmap;
uniform float toon_steps : hint_range(1.0, 6.0) = 3.0;
uniform float toon_softness : hint_range(0.0, 0.5) = 0.06;

void fragment() {
	float white = bicolor ? texture(white_mask, UV).r : 0.0;
	vec3 coat = mix(base_color, white_color, white);
	ALBEDO = coat * texture(detail_map, UV).rgb;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}

void light() {
	// 웹 버전의 MeshToonMaterial과 비슷한 계단식 음영
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float stepped = floor(ndl * toon_steps) / toon_steps;
	float band = mix(stepped, ndl, toon_softness);
	DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * max(band, 0.35) / PI;
}
