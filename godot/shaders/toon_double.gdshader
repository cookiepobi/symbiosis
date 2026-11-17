shader_type spatial;
render_mode unshaded, cull_disabled, specular_disabled, shadows_disabled;
// three.js r160 MeshToonMaterial / MeshBasicMaterial을 그대로 계산하는 공용 코드.
//  - 색은 선형 공간에서 계산하고, 안개(Fog)는 three처럼 sRGB 변환 후에 섞는다.
//  - 조명은 웹 stage.js addLights와 같은 반구광 1 + 방향광 2 (전역 셰이더 uniform)
//  - toon 계단: gradientMap [150, 200, 235, 255] / 255, NearestFilter

global uniform vec3 hemi_sky;      // 선형, intensity 곱함
global uniform vec3 hemi_ground;
global uniform vec3 dir1_dir;      // 빛을 향하는 월드 방향(정규화)
global uniform vec3 dir1_color;    // 선형, intensity 곱함
global uniform vec3 dir2_dir;
global uniform vec3 dir2_color;
global uniform vec3 fog_color;     // three Fog.color(선형 값)를 sRGB 출력에 그대로 섞음
global uniform float fog_near;
global uniform float fog_far;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform bool lit = true;           // false = MeshBasicMaterial
uniform bool use_map = false;
uniform sampler2D map : source_color, filter_linear_mipmap, repeat_enable;
uniform vec2 map_repeat = vec2(1.0);
uniform vec3 emissive : source_color = vec3(0.0);
uniform float emissive_intensity = 0.0;
uniform bool emissive_from_map = false;
uniform bool use_fog = true;
uniform float alpha_test = 0.0;
uniform float view_bias = 0.0;   // three polygonOffset 대신 카메라 쪽으로 살짝 당김

varying float fog_depth;

float toon_grad(float x) {
	float i = clamp(floor(x * 4.0), 0.0, 3.0);
	return i < 0.5 ? 150.0 / 255.0 : (i < 1.5 ? 200.0 / 255.0 : (i < 2.5 ? 235.0 / 255.0 : 1.0));
}

vec3 lin_to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 srgb_to_lin(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), c));
}

void vertex() {
	vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	fog_depth = -mv.z;
	mv.z += view_bias;
	POSITION = PROJECTION_MATRIX * mv;
}

void fragment() {
	// Compatibility 렌더러(OUTPUT_IS_SRGB)는 색을 sRGB 그대로 다루므로 직접 선형으로 바꿔 계산한다
	vec4 tex = use_map ? texture(map, UV * map_repeat) : vec4(1.0);
	vec3 tex_rgb = OUTPUT_IS_SRGB ? srgb_to_lin(tex.rgb) : tex.rgb;
	vec3 base_rgb = OUTPUT_IS_SRGB ? srgb_to_lin(albedo.rgb) : albedo.rgb;
	vec3 diffuse = base_rgb * tex_rgb;
	float alpha = albedo.a * opacity * tex.a;
	if (alpha_test > 0.0 && alpha < alpha_test) discard;
	vec3 color = diffuse;
	if (lit) {
		vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
		vec3 irradiance = mix(hemi_ground, hemi_sky, 0.5 * n.y + 0.5);
		vec3 direct = toon_grad(dot(n, dir1_dir) * 0.5 + 0.5) * dir1_color
			+ toon_grad(dot(n, dir2_dir) * 0.5 + 0.5) * dir2_color;
		color = (irradiance + direct) * diffuse / PI;
		vec3 em = OUTPUT_IS_SRGB ? srgb_to_lin(emissive) : emissive;
		color += em * emissive_intensity * (emissive_from_map ? tex_rgb : vec3(1.0));
	}
	vec3 srgb = lin_to_srgb(clamp(color, vec3(0.0), vec3(1.0)));
	if (use_fog && fog_far > 0.0) {
		srgb = mix(srgb, fog_color, smoothstep(fog_near, fog_far, fog_depth));
	}
	ALBEDO = OUTPUT_IS_SRGB ? srgb : srgb_to_lin(srgb);
	
}
