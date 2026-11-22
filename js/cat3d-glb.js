// cat3d-glb.js — 테스트 페이지(cat-game-glb.html)에서 js/cat3d.js 자리에 끼워 넣는 대체 모듈
// world.js·stage.js가 부르는 buildCat / disposeCat을 GLB 고양이로 바꾸고, 나머지(toon 등)는 원래 cat3d.js 그대로 쓴다.
// 원래 게임(index.html)에는 영향 없음 — 이 파일은 cat-game-glb.html의 importmap에서만 연결됨.
//
// 주소 옵션: cat-game-glb.html?glb=./다른파일.glb&body=0.5&walk=1.2&mat=pbr&bodyrand=0
//   glb       불러올 GLB (기본 ./cat_deploy.glb)
//   body      체형 시작값 -0.70(홀쭉) ~ 0 ~ 0.75(뚱냥)
//   bodyrand  1이면 고양이마다 체형을 다르게 (기본 1, 0이면 모두 같은 체형)
//   walk      걷기 애니메이션 재생 속도 배율
//   mat       pbr이면 GLB 원래 재질로 봄 (비교용, 기본은 팀 웹과 같은 툰 재질)

export * from './cat3d.js?orig';
import * as THREE from 'three';
import { buildCat as buildProcedural, disposeCat as disposeProcedural, toon } from './cat3d.js?orig';
import { loadCatGlb, buildGlbCat, disposeGlbCat } from './glb-cat.js';

const params = new URLSearchParams(location.search);
const GLB_URL = params.get('glb') || './cat_deploy.glb';
// 웹 게임 단위: 1 world unit = 0.7 m (cat-scale-preview.js), 고양이 holder는 CAT_SCALE 0.7 (world.js)
const METRES_PER_UNIT = 0.7;
const CAT_SCALE = 0.7;
// 체형 범위 (블렌더 작업 권장값: -0.70에서 body_slim 0.70, +0.75에서 body_chubby 0.75)
export const BODY_MIN = -0.70;
export const BODY_MAX = 0.75;

const MATERIAL_MODE = params.get('mat') || 'toon';

/** 팀 웹 고양이와 같은 룩: 털 = toon()(4단계 툰), 얼굴(eye) = 조명 없는 MeshBasicMaterial */
function toTeamMaterial(m) {
  const common = {
    map: m.map || null,
    transparent: m.transparent,
    alphaTest: m.alphaTest,
    side: m.side,
  };
  if (/eye/i.test(m.name)) return new THREE.MeshBasicMaterial({ ...common, color: 0xffffff });
  return toon(m.map ? 0xffffff : m.color.getHex(), common);
}

const clampBody = v => Math.min(BODY_MAX, Math.max(BODY_MIN, Number(v) || 0));

export const glbSettings = {
  url: GLB_URL,
  material: MATERIAL_MODE,
  body: clampBody(params.get('body') ?? 0),
  bodyRandom: params.get('bodyrand') !== '0',
  walkSpeed: Number(params.get('walk') ?? 1),
  loaded: false,
  clips: [],
  morphs: [],
  error: null,
};

let gltf = null;
try {
  gltf = await loadCatGlb(GLB_URL);
  glbSettings.loaded = true;
  glbSettings.clips = gltf.animations.map(a => a.name);
  const morphs = new Set();
  gltf.scene.traverse(o => { if (o.morphTargetDictionary) Object.keys(o.morphTargetDictionary).forEach(k => morphs.add(k)); });
  glbSettings.morphs = [...morphs];
} catch (error) {
  glbSettings.error = String(error?.message || error);
  console.warn('[cat3d-glb] GLB를 불러오지 못해 기존 도형 고양이를 씁니다:', error);
}

/** 고양이 id로 정해지는 체형 (같은 고양이는 항상 같은 체형) */
function bodyOf(cat) {
  const s = String(cat?.id ?? Math.random());
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619);
  const u = ((h >>> 0) % 1000) / 999;
  return BODY_MIN + (BODY_MAX - BODY_MIN) * u;
}

const live = new Set();

export function buildCat(cat, opts = {}) {
  if (!gltf) return buildProcedural(cat, opts);
  const body = glbSettings.bodyRandom ? bodyOf(cat) : glbSettings.body;
  const root = buildGlbCat(gltf, cat, {
    scale: 1 / (METRES_PER_UNIT * CAT_SCALE),
    body,
    walkSpeed: () => glbSettings.walkSpeed,
    convertMaterial: MATERIAL_MODE === 'pbr' ? null : toTeamMaterial,
  });
  root.userData.body = body;
  live.add(root);
  return root;
}

export function disposeCat(root) {
  if (root?.userData?.glb) {
    live.delete(root);
    return disposeGlbCat(root);
  }
  return disposeProcedural(root);
}

/** 슬라이더로 모든 고양이 체형을 한 번에 (고양이별 랜덤 체형은 꺼짐) */
export function setAllBody(v) {
  glbSettings.body = clampBody(v);
  glbSettings.bodyRandom = false;
  for (const r of live) { r.userData.setBody?.(glbSettings.body); r.userData.body = glbSettings.body; }
}
/** 고양이별 랜덤 체형으로 되돌리기 */
export function resetRandomBody() {
  glbSettings.bodyRandom = true;
  for (const r of live) {
    const b = bodyOf({ id: r.parent?.userData?.catId });
    r.userData.setBody?.(b);
    r.userData.body = b;
  }
}
export const setAllChubby = setAllBody; // 예전 이름 호환

export function setWalkSpeed(v) {
  glbSettings.walkSpeed = v;
}

export const liveGlbCats = live;
