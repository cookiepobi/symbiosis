// 사람 캐릭터 (집사: assets/models/characters/main_human.glb, 이웃: neighbor_npc.glb)
// - Blender 리그 + Walk(제자리 걷기, 0.8초 반복) 동작이 들어 있음
// - world.js의 기존 아바타와 같은 userData(inner/legs/arms/head)를 갖춰서 나머지 코드는 그대로 동작
// - 불러오기에 실패하면 null을 돌려주고 world.js가 예전 코드 아바타를 씀
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';

const URLS = {
  main: new URL('../assets/models/characters/main_human.glb', import.meta.url).href,
  npc: new URL('../assets/models/characters/neighbor_npc.glb', import.meta.url).href,
};
// 모델 키 2.0m → 게임 단위 약 2.4 (예전 코드 아바타 키와 비슷)
export const HUMAN_SCALE = 1.2;
// Walk 동작이 원래 앞으로 가는 속도: 모델 기준 초속 0.6m × 크기 → 게임 단위
const GROUND_SPEED = 0.6 * HUMAN_SCALE;
// 실제 이동 속도에 맞춰 재생 속도를 올림 (발 미끄러짐 줄이기). 너무 빨라 보이지 않게 상한을 둠
const MAX_WALK_RATE = 1.8;
// 서 있을 때: Walk의 지나가기(두 발이 모이는) 순간에서 멈춰 자연스러운 서 있는 자세로 씀
const STAND_TIME = 0.2;

const shared = {};
let pending = null;

export function preloadHumans() {
  if (pending) return pending;
  const loader = new GLTFLoader();
  pending = Promise.all(Object.entries(URLS).map(async ([kind, url]) => {
    try { shared[kind] = await loader.loadAsync(url); }
    catch (error) { console.warn(`사람 캐릭터(${kind})를 불러오지 못해 기본 아바타를 씁니다.`, error); }
  }));
  return pending;
}

export function humanReady(kind) { return !!shared[kind]; }

// 앞치마 색 8종 (assets/models/characters/aprons/apron_N.jpg, 1번 = 집사 기본 머스터드)
const APRON_DIR = new URL('../assets/models/characters/aprons/', import.meta.url).href;
const apronCache = new Map();
function apronTexture(n) {
  if (!apronCache.has(n)) {
    const t = new THREE.TextureLoader().load(APRON_DIR + `apron_${n}.jpg`, undefined, undefined,
      e => console.warn('앞치마 텍스처를 불러오지 못했어요', n, e));
    t.flipY = false; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
    apronCache.set(n, t);
  }
  return apronCache.get(n);
}

/* kind: 'main'(집사) | 'npc'(이웃). apron: 1~8 앞치마 색(없으면 모델 기본). 준비 안 됐으면 null */
export function buildHuman(kind, { apron } = {}) {
  const gltf = shared[kind];
  if (!gltf) return null;
  const g = new THREE.Group(), inner = new THREE.Group(); g.add(inner);
  const model = cloneSkinned(gltf.scene);
  model.scale.setScalar(HUMAN_SCALE);
  model.traverse(o => {
    if (!o.isMesh) return;
    o.castShadow = true;
    o.frustumCulled = false;
    // 머티리얼은 개체별로 복제 (나중에 색을 바꿔도 다른 캐릭터에 번지지 않게)
    o.material = Array.isArray(o.material) ? o.material.map(m => m.clone()) : o.material.clone();
    if (apron && o.material.name === 'pinafore_mustard') { o.material.map = apronTexture(apron); o.material.needsUpdate = true; }
  });
  inner.add(model);

  const mixer = new THREE.AnimationMixer(model);
  const clip = THREE.AnimationClip.findByName(gltf.animations, 'Walk') || gltf.animations[0];
  const walk = clip ? mixer.clipAction(clip) : null;
  if (walk) { walk.play(); walk.paused = true; walk.time = STAND_TIME; mixer.update(0); }

  let moving = false;
  const last = new THREE.Vector3(); let hasLast = false, speed = 0;
  const human = {
    mixer,
    /* 매 프레임 호출: 걷는 중이면 Walk 재생(실제 이동 속도에 맞춤), 멈추면 서 있는 자세로 */
    update(dt, isMoving) {
      if (!walk) return;
      // 이번 프레임에 실제로 움직인 거리(벽에 막히면 0)로 속도를 잼
      const moved = hasLast ? Math.hypot(g.position.x - last.x, g.position.z - last.z) : 0;
      last.copy(g.position); hasLast = true;
      speed = THREE.MathUtils.lerp(speed, dt > 0 ? moved / dt : 0, 0.3);
      const going = isMoving && speed > 0.2;
      if (going && !moving) walk.paused = false;
      if (!going && moving) { walk.paused = true; walk.time = STAND_TIME; }
      moving = going;
      walk.timeScale = THREE.MathUtils.clamp(speed / GROUND_SPEED, 1, MAX_WALK_RATE);
      mixer.update(going ? dt : 0);
    },
  };
  // 기존 코드가 만지는 부위들: 모델에서는 실제로 쓰지 않는 빈 객체로 둠
  const dummy = () => new THREE.Object3D();
  g.userData.inner = inner;
  g.userData.legs = [dummy(), dummy()];
  g.userData.arms = [dummy(), dummy()];
  g.userData.head = dummy();
  g.userData.human = human;
  return g;
}
