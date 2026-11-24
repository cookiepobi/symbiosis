// glb-coat.js — GLB 고양이에 원래 게임의 털색·무늬(유전 표현형)를 입히는 툰 재질
//
// 원래 게임(js/textures.js)은 도형 고양이의 부위별 UV에 맞춰 캔버스 텍스처를 그린다.
// GLB 고양이는 UV 배치가 달라서 그 텍스처를 그대로 붙일 수 없으므로,
// 같은 표현형 값(resolveAppearance 결과)을 받아 셰이더에서 "모델의 기본 자세 위치 + 뼈 부위"로 무늬를 계산한다.
//   · 기본색 / 토티(오렌지 패치) / 고등어·클래식 태비 / 흰 반점(bicolor·high) / 포인트(point·sepia·mink)
//   · 실버·농도는 resolveAppearance가 이미 색에 반영 / 스핑크스(피부색) / 판타지(그라데이션 + 반짝이)
// 기본 자세 위치를 쓰므로 걷기·식빵자세·체형 셰이프 키로 모양이 바뀌어도 무늬가 털에 붙어서 같이 움직인다.
// 원래 coat 텍스처의 얼굴 그림(검은 눈·입, 분홍 코·볼터치·귀 안쪽)은 그대로 살린다.
import { resolveAppearance, FANTASY_PALETTE } from './appearance.js';

// 뼈 이름 → 부위 (Meshy/블렌더 리그 이름 기준)
const REGION_RULES = [
  [/^ear/i, [1, 1, 0, 0]],              // 머리 + 귀
  [/^(head|neck)/i, [1, 0, 0, 0]],      // 머리(얼굴 포함)
  [/^tail/i, [0, 0, 1, 0]],             // 꼬리
  [/^(front|rear)/i, [0, 0, 0, 1]],     // 다리
];

/** 정점마다 부위 가중치(머리, 귀, 꼬리, 다리)를 vec4 속성 catRegion으로 만든다. geometry당 한 번. */
export function ensureRegionAttribute(THREE, mesh) {
  const g = mesh.geometry;
  if (!g || g.attributes.catRegion) return;
  // 무늬 좌표 기준점: 모델마다 바닥 높이·앞뒤 중앙이 달라도 cat_deploy.glb 기준 좌표로 맞춘다
  // (cat_deploy.glb: 바닥 y≈-0.475, 앞뒤 중앙 z≈-0.0105 / newcat2: 바닥 y≈0, 중앙 z≈0)
  g.computeBoundingBox();
  const bb = g.boundingBox;
  g.userData.catOrigin = new THREE.Vector3(0, bb.min.y + 0.475, (bb.min.z + bb.max.z) / 2 + 0.0105);
  const si = g.attributes.skinIndex, sw = g.attributes.skinWeight;
  const n = g.attributes.position.count;
  const out = new Float32Array(n * 4);
  if (si && sw && mesh.skeleton) {
    const boneRegion = mesh.skeleton.bones.map(b => {
      const rule = REGION_RULES.find(([re]) => re.test(b.name));
      return rule ? rule[1] : [0, 0, 0, 0];
    });
    for (let i = 0; i < n; i++) {
      for (let k = 0; k < 4; k++) {
        const w = sw.getComponent(i, k);
        if (!w) continue;
        const r = boneRegion[si.getComponent(i, k)] || [0, 0, 0, 0];
        for (let c = 0; c < 4; c++) out[i * 4 + c] += w * r[c];
      }
    }
  }
  g.setAttribute('catRegion', new THREE.BufferAttribute(out, 4));
}

function seedOf(s) {
  let h = 2166136261;
  s = String(s ?? 'x');
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  return ((h >>> 0) % 10000) / 100; // 0 ~ 100
}

/** 표현형 → 셰이더 uniform 값 */
export function coatUniforms(THREE, cat) {
  let app = null;
  try { app = cat?.ph ? resolveAppearance(cat) : null; } catch { app = null; }
  const col = hex => new THREE.Color(hex);
  const u = {
    uBase: { value: col('#fcfaf6') }, uOrange: { value: col('#fcfaf6') },
    uPointBase: { value: col('#fcfaf6') }, uPointOrange: { value: col('#fcfaf6') },
    uTortie: { value: 0 }, uTabby: { value: 0 }, uTabbyDark: { value: 1 },
    uWhite: { value: 0 }, uPoint: { value: 0 }, uHairless: { value: 0 },
    uFantasy: { value: 0 }, uPal0: { value: col('#ffffff') }, uPal1: { value: col('#ffffff') }, uPal2: { value: col('#ffffff') },
    uSeed: { value: seedOf(cat?.seed ?? cat?.id) },
    uCream: { value: col('#f6ebe0') },
  };
  if (!app) return { uniforms: u, app: null };
  u.uBase.value = col(app.bodyColors[0]);
  u.uOrange.value = col(app.bodyColors[1] || app.bodyColors[0]);
  u.uPointBase.value = col(app.pointColors[0]);
  u.uPointOrange.value = col(app.pointColors[1] || app.pointColors[0]);
  u.uTortie.value = app.tortie ? 1 : 0;
  u.uTabby.value = !app.tabby ? 0 : app.tabbyType === 'classic' ? 2 : 1;
  u.uTabbyDark.value = app.tabbyDark ? 1 : 0;
  u.uWhite.value = app.white === 'none' ? 0 : app.white === 'bicolor' ? 1 : 2;
  u.uPoint.value = app.tyr === 'full' ? 0 : 1;
  u.uHairless.value = app.hairless ? 1 : 0;
  if (app.fantasy && FANTASY_PALETTE[app.fantasy]) {
    const p = FANTASY_PALETTE[app.fantasy];
    u.uFantasy.value = 1;
    u.uPal0.value = col(p[0]); u.uPal1.value = col(p[1]); u.uPal2.value = col(p[2]);
  }
  return { uniforms: u, app };
}

const VERT_HEAD = /* glsl */`
attribute vec4 catRegion;
uniform vec3 uOrigin;
varying vec3 vCatRest;
varying vec3 vCatRestN;
varying vec4 vCatReg;
`;
const VERT_BODY = /* glsl */`
#include <begin_vertex>
vCatRest = position - uOrigin;
vCatRestN = normal;
vCatReg = catRegion;
`;

// 좌표는 cat_deploy.glb 기본 자세 기준 (Y 위, +Z 앞, 바닥 y≈-0.475, 머리 앞 z≈0.39, 꼬리 끝 y≈0.3)
const FRAG_HEAD = /* glsl */`
varying vec3 vCatRest;
varying vec3 vCatRestN;
varying vec4 vCatReg;
uniform vec3 uBase, uOrange, uPointBase, uPointOrange, uCream, uPal0, uPal1, uPal2;
uniform float uTortie, uTabby, uTabbyDark, uWhite, uPoint, uHairless, uFantasy, uSeed;

float cHash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
float cNoise(vec3 x) {
  vec3 i = floor(x), f = fract(x); f = f * f * (3.0 - 2.0 * f);
  return mix(mix(mix(cHash(i), cHash(i + vec3(1,0,0)), f.x), mix(cHash(i + vec3(0,1,0)), cHash(i + vec3(1,1,0)), f.x), f.y),
             mix(mix(cHash(i + vec3(0,0,1)), cHash(i + vec3(1,0,1)), f.x), mix(cHash(i + vec3(0,1,1)), cHash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float cFbm(vec3 x) { return 0.6 * cNoise(x) + 0.3 * cNoise(x * 2.1) + 0.1 * cNoise(x * 4.3); }
// 부드러운 줄: s = sin 값, w = 굵기(0~1)
float cBand(float s, float w) { return smoothstep(1.0 - w - 0.12, 1.0 - w + 0.12, s); }

vec3 catCoat() {
  vec3 p = vCatRest, n = normalize(vCatRestN);
  float head = clamp(vCatReg.x, 0.0, 1.0), ear = clamp(vCatReg.y, 0.0, 1.0);
  float tail = clamp(vCatReg.z, 0.0, 1.0), leg = clamp(vCatReg.w, 0.0, 1.0);
  float body = clamp(1.0 - head - tail - leg, 0.0, 1.0);
  vec3 sp = p + vec3(uSeed * 1.37, uSeed * 0.71, uSeed * 2.13);

  // ── 판타지: 3색 그라데이션 + 반짝이 ──
  if (uFantasy > 0.5) {
    float t = fract(p.z * 1.6 + p.y * 0.6 + uSeed * 0.01) * 3.0;
    vec3 c = t < 1.0 ? mix(uPal0, uPal1, t) : t < 2.0 ? mix(uPal1, uPal2, t - 1.0) : mix(uPal2, uPal0, t - 2.0);
    float star = step(0.93, cHash(floor(sp * 55.0)));
    return mix(c, vec3(1.0), star * 0.9);
  }

  // ── 토티: 오렌지 패치 ──
  float orange = uTortie > 0.5 ? smoothstep(0.47, 0.53, cFbm(sp * 6.0)) : 0.0;
  orange *= 1.0 - ear;

  // ── 포인트(샴 등): 얼굴 가운데·귀·꼬리·다리 아래 ──
  float pm = 0.0;
  if (uPoint > 0.5) {
    float face = head * clamp(1.4 - length((p - vec3(0.0, -0.03, 0.40)) / vec3(0.16, 0.14, 0.2)), 0.0, 1.0);
    float lower = leg * smoothstep(-0.22, -0.34, p.y);
    pm = max(max(face, ear), max(tail, lower));
  }
  vec3 c = mix(mix(uBase, uPointBase, pm), mix(uOrange, uPointOrange, pm), orange);

  // ── 태비 줄무늬 ──
  if (uTabby > 0.5) {
    float wob = (cNoise(sp * 9.0) - 0.5) * 1.2;
    float s = 0.0;
    // 몸통: 등 척추선 + 옆구리로 내려오다 배 전에 가늘어지는 줄 (어깨 앞쪽·배는 비움)
    float dorsal = smoothstep(-0.34, -0.12, p.y) * smoothstep(-0.5, 0.2, n.y);
    float spine = (1.0 - smoothstep(0.018, 0.04, abs(p.x))) * smoothstep(0.3, 0.7, n.y);
    float bodyS;
    if (uTabby < 1.5) {
      float taper = mix(0.15, 0.55, smoothstep(-0.34, -0.08, p.y));
      bodyS = cBand(sin(p.z * 70.0 + wob), taper) * dorsal;
    } else {
      vec2 q = vec2(p.y + 0.2, p.z + 0.15) / vec2(0.75, 1.0);
      float ring = cBand(sin(length(q) * 95.0 + wob), 0.45) * smoothstep(0.08, 0.13, abs(p.x));
      bodyS = max(ring, cBand(sin(p.z * 45.0 + wob), 0.35) * smoothstep(0.55, 0.9, n.y)) * dorsal;
    }
    bodyS = max(bodyS, spine * (uTabby < 1.5 ? 0.9 : 1.0));
    bodyS *= smoothstep(0.08, -0.02, p.z); // 어깨 앞쪽은 비움
    s = max(s, body * bodyS);
    // 머리: 이마 M(세로줄) + 볼 줄
    float fore = cBand(sin(p.x * 80.0 + wob * 0.5), 0.4) * (1.0 - smoothstep(0.06, 0.11, abs(p.x)))
               * smoothstep(0.03, 0.1, p.y) * smoothstep(0.0, 0.5, n.y + n.z * 0.6);
    float cheek = cBand(sin(p.y * 90.0 + wob), 0.4) * smoothstep(0.13, 0.18, abs(p.x)) * smoothstep(0.1, 0.25, p.z)
                * (1.0 - smoothstep(-0.02, 0.05, p.y)) * smoothstep(-0.16, -0.1, p.y);
    s = max(s, head * (1.0 - ear) * max(fore, cheek));
    // 다리·꼬리: 고리 줄
    s = max(s, leg * cBand(sin(p.y * 75.0 + wob), 0.42) * smoothstep(-0.46, -0.4, p.y));
    s = max(s, tail * cBand(sin((p.y * 0.8 - p.z * 0.6) * 70.0 + wob), 0.45));
    // 토티일 때 어두운 패치의 줄무늬는 A_(darkTabby)일 때만
    float allowed = uTortie > 0.5 ? max(orange, uTabbyDark) : 1.0;
    s *= allowed;
    float dark = step(c.r + c.g + c.b, 0.3); // 원래 텍스처의 r+g+b < 260 (선형 색 기준 근사)
    vec3 striped = dark > 0.5 ? min(c + vec3(0.03, 0.03, 0.035), vec3(1.0)) : c * vec3(0.55, 0.55, 0.52);
    c = mix(c, striped, s * 0.9);
  }

  // ── 흰 반점 ──
  if (uWhite > 0.5) {
    float edge = (cFbm(sp * 8.0) - 0.5) * 0.35;
    float w = 0.0;
    if (uWhite < 1.5) {
      float belly = body * smoothstep(-0.1, -0.6, n.y + edge);
      float chest = (1.0 - ear) * smoothstep(0.02, 0.12, p.z + edge * 0.2) * (1.0 - smoothstep(0.09, 0.14, abs(p.x) + edge * 0.1))
                  * smoothstep(-0.02, -0.08, p.y + edge * 0.1) * (1.0 - head * smoothstep(0.3, 0.2, p.z)) * step(-0.2, n.z);
      float muzzle = head * smoothstep(0.27, 0.33, p.z + edge * 0.1) * smoothstep(-0.0, -0.06, p.y + edge * 0.08);
      float paws = leg * smoothstep(-0.36, -0.4, p.y + edge * 0.06);
      float tip = tail * smoothstep(0.2, 0.26, p.y);
      w = max(max(belly, chest), max(muzzle, max(paws, tip)));
    } else {
      // 거의 흰 고양이: 정수리·등에 색 반점, 꼬리 시작 부분만 색
      float cap = (head * smoothstep(0.05, 0.12, p.y + edge * 0.1) + ear) * step(0.48, cNoise(sp * 3.0) + 0.15);
      float back = body * smoothstep(-0.2, -0.05, p.y) * smoothstep(0.55, 0.62, cFbm(sp * 4.5));
      float tailBase = tail * smoothstep(0.12, 0.0, p.y + edge * 0.1);
      w = 1.0 - clamp(max(max(cap, back), tailBase), 0.0, 1.0);
    }
    c = mix(c, vec3(0.97, 0.955, 0.92), clamp(w, 0.0, 1.0));
  }

  // ── 스핑크스: 피부색 섞기 ──
  if (uHairless > 0.5) c = mix(c, vec3(0.85, 0.53, 0.43), 0.6);
  return c;
}
`;

const FRAG_MAP = /* glsl */`
#ifdef USE_MAP
  vec4 catTexel = texture2D( map, vMapUv );
#else
  vec4 catTexel = vec4( uCream, 1.0 );
#endif
  // 얼굴 그림(검은 눈·입, 분홍 코·볼터치·귀 안쪽)만 원래 텍스처를 살리고 나머지 털은 유전 색으로
  float catLum = dot( catTexel.rgb, vec3( 0.2126, 0.7152, 0.0722 ) );
  float catKeep = max( smoothstep( 0.16, 0.06, catLum ), smoothstep( 0.08, 0.16, catTexel.r - catTexel.g ) );
  diffuseColor.rgb *= mix( catCoat(), catTexel.rgb, catKeep );
`;

/** 툰 재질(MeshToonMaterial)에 털 무늬 셰이더를 붙인다. */
export function applyCoat(THREE, material, mesh, cat) {
  ensureRegionAttribute(THREE, mesh);
  const { uniforms, app } = coatUniforms(THREE, cat);
  uniforms.uOrigin = { value: (mesh.geometry.userData.catOrigin || new THREE.Vector3()).clone() };
  material.userData.coat = { uniforms, app };
  material.onBeforeCompile = shader => {
    Object.assign(shader.uniforms, uniforms);
    shader.vertexShader = VERT_HEAD + shader.vertexShader.replace('#include <begin_vertex>', VERT_BODY);
    shader.fragmentShader = FRAG_HEAD + shader.fragmentShader.replace('#include <map_fragment>', FRAG_MAP);
  };
  material.customProgramCacheKey = () => 'cat-coat-v2';
  material.needsUpdate = true;
  return material;
}
