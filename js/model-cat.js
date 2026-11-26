// Blender 리그 고양이 (assets/models/newcat3.glb, 아기: newcat3_kitten.glb)
// - 털색: 고양이 유전형(검정·블루·초코·라일락·흰색 × 단색/바이컬러)에 맞는 텍스처로 교체
// - 털색·얼굴·명암이 한 장에 구워진(baked) 텍스처라 조명을 다시 받지 않도록 unlit(MeshBasicMaterial)로 표시
//   (팀 규칙: 툰 재질로 바꾸지 않음. glb 안의 텍스처·외곽선·수염 재질 색을 그대로 씀)
// - 동작은 glb 안의 11개 Action을 활동에 맞춰 재생 (walk_loop, idle_loop, groom_loop, loaf_doze_loop, happy …)
// - 예전 고양이(newcat.glb, 리그 없음)는 ?cat=classic 으로 코드 고양이를 쓰거나 git 기록에서 볼 수 있음
import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { clone as cloneSkinned } from 'three/addons/utils/SkeletonUtils.js';

const ADULT_URL = new URL('../assets/models/newcat3.glb', import.meta.url).href;
const KITTEN_URL = new URL('../assets/models/newcat3_kitten.glb', import.meta.url).href;
// 모델 원본(m) → 게임 단위. 성묘 키 0.78m × 2.3 ≈ 1.8 (예전 고양이와 비슷한 크기)
export const MODEL_SCALE = 2.3;
const FADE = 0.25;   // 동작 전환 시간(초)

// 털색: 성묘 261124의 확정 페인팅(4K)을 2K JPG로 줄인 9종. 털색·흰 반점·얼굴이 한 장에 구워져 있음
// (성묘·아기 모델 UV가 같아서 둘 다 같은 텍스처를 씀. 표정은 '뜬 눈 + 웃는 입' 고정)
const COAT_DIR = new URL('../assets/models/coats/', import.meta.url).href;
// 게임 유전 색 → 준비된 털색. 오렌지·크림·시나몬·폰은 아직 그림이 없어 가장 가까운 색으로 대신함
const COAT_OF = {
  black: 'black', blue: 'blue', chocolate: 'chocolate', lilac: 'lilac',
  cinnamon: 'chocolate', fawn: 'lilac', orange: 'chocolate', cream: 'white',
};
const coatCache = new Map();
function coatTexture(name) {
  if (!coatCache.has(name)) {
    const t = new THREE.TextureLoader().load(COAT_DIR + 'coat_' + name + '.jpg', undefined, undefined,
      e => console.warn('털색 텍스처를 불러오지 못했어요', name, e));
    t.flipY = false; t.colorSpace = THREE.SRGBColorSpace; t.anisotropy = 4;
    coatCache.set(name, t);
  }
  return coatCache.get(name);
}
export function coatName(cat) {
  const ph = cat?.ph;
  if (!ph) return null;
  const base = COAT_OF[ph.colors?.[0]] || 'lilac';
  if (base === 'white') return 'white';               // 흰색은 무늬 구분 없음
  return ph.white && ph.white !== 'none' ? base + '_bicolor' : base;
}

let shared = null;   // { adult: gltf, kitten: gltf|null }
let pending = null;

export function modelCatReady() { return !!shared; }

/* 게임 시작 전에 한 번 불러옴. 실패하면 false를 돌려주고 코드 고양이를 계속 사용 */
export function preloadModelCat() {
  if (pending) return pending;
  pending = (async () => {
    try {
      const loader = new GLTFLoader();
      const [adult, kitten] = await Promise.all([
        loader.loadAsync(ADULT_URL),
        loader.loadAsync(KITTEN_URL).catch(error => { console.warn('아기 고양이 모델이 없어 성묘를 줄여서 씁니다.', error); return null; }),
      ]);
      shared = { adult, kitten };
      return true;
    } catch (error) {
      console.warn('모델 고양이를 불러오지 못해 기본 고양이를 사용합니다.', error);
      return false;
    }
  })();
  return pending;
}

/* glb 재질 → unlit. 텍스처·색·양면 여부는 그대로 */
function unlit(src) {
  const m = new THREE.MeshBasicMaterial({
    name: src.name,
    color: src.color ? src.color.clone() : new THREE.Color(0xffffff),
    map: src.map || null,
    side: src.side,
    transparent: src.transparent,
    alphaTest: src.alphaTest,
  });
  return m;
}

/* 개체마다 뼈대·지오메트리·재질을 따로 복제 (disposeCat이 개체별로 정리해도 다른 고양이에 영향 없게) */
function instance(gltf) {
  const scene = cloneSkinned(gltf.scene);
  scene.traverse(o => {
    if (!o.isMesh) return;
    o.geometry = o.geometry.clone();
    o.material = Array.isArray(o.material) ? o.material.map(unlit) : unlit(o.material);
    o.castShadow = true;
    o.frustumCulled = false;   // 스키닝으로 움직이는 메시가 화면 끝에서 사라지지 않게
  });
  return scene;
}

// 게임 활동 → glb 동작 이름
const ACTIVITY_CLIP = {
  idle: 'idle_loop', watch: 'idle_loop', explore: 'idle_loop', alert: 'idle_loop',
  rub: 'idle_loop', greet: 'idle_loop', pounce: 'bouncy_walk_loop',
  groom: 'groom_loop', nap: 'loaf_doze_loop', hide: 'loaf_loop', shelter: 'loaf_loop',
};

/* buildCat에서 호출. 반환 구조(root.userData.tick/react/parts)는 코드 고양이와 같게 맞춤 */
export function buildModelCat(cat, app, tex, root, { addCostume, behavior }) {
  const baby = cat.personality === null || cat.personality === undefined;
  const useKitten = baby && !!shared.kitten;
  const gltf = useKitten ? shared.kitten : shared.adult;
  const rig = new THREE.Group(); root.add(rig);
  const body = instance(gltf);
  body.scale.setScalar(MODEL_SCALE);
  // 유전형에 맞는 털색으로 바꿈 (못 불러오면 glb 기본 라일락 바이컬러 그대로)
  const coat = coatName(cat);
  if (coat) body.traverse(o => { if (o.isMesh && o.material.name === 'coat') { o.material.map = coatTexture(coat); o.material.needsUpdate = true; } });
  rig.add(body);

  // 의상 부착용 머리 기준점 (고양이 크기 비율에 맞춰)
  const box = new THREE.Box3().setFromObject(body);
  const h = box.max.y - box.min.y;
  const head = new THREE.Group();
  head.position.set(0, h * 0.64, h * 0.15);
  rig.add(head);
  const bodyDims = { wK: h * 0.31, hK: h * 0.26, dK: h * 0.46, fw: 1 };
  if (cat.costume) addCostume(cat.costume, head, rig, bodyDims);

  root.userData.sizeMul = app.special === 'singapura' ? 0.7 : 1;
  root.userData.baby = baby;
  // 아기 전용 모델이 있으면 원래 크기 그대로, 없으면 성묘를 줄여서
  rig.scale.setScalar((baby && !useKitten ? 0.62 : 1) * root.userData.sizeMul);

  // 동작
  const mixer = new THREE.AnimationMixer(body);
  const actions = {};
  for (const clip of gltf.animations) actions[clip.name] = mixer.clipAction(clip);
  for (const name of ['happy', 'loaf_enter', 'loaf_to_walk', 'walk_to_loaf_left', 'walk_to_loaf_right']) {
    if (actions[name]) { actions[name].setLoop(THREE.LoopOnce, 1); actions[name].clampWhenFinished = true; }
  }
  let current = null;
  const play = (name, speed = 1) => {
    const next = actions[name] || actions.idle_loop;
    if (!next) return;
    next.timeScale = speed;
    if (current === next) return;
    next.reset().setEffectiveWeight(1).fadeIn(FADE).play();
    if (current) current.fadeOut(FADE);
    current = next;
  };
  play('idle_loop');
  // 개체마다 시작 위치를 다르게 (모두 똑같이 움직이지 않게)
  mixer.update(Math.random() * 3);

  let reaction = null;
  root.userData.react = action => {
    reaction = { action, start: performance.now() };
    if (actions.happy) { actions.happy.reset(); current = null; play('happy'); }
  };
  root.userData.tick = (t, { activity = 'idle', moving = false, dt = 1 / 60 } = {}) => {
    const elapsed = reaction ? (performance.now() - reaction.start) / 1000 : 99;
    const reacting = elapsed < (actions.happy ? actions.happy.getClip().duration : 0);
    if (!reacting) {
      if (moving) play('walk_loop', 0.6 + behavior.speed * 0.25);
      else play(ACTIVITY_CLIP[activity] || 'idle_loop');
    }
    // 게임 쪽(world.js)이 걸을 때 root를 흔드는데, 모델 동작에 이미 들어 있으므로 되돌림
    root.position.y = 0; root.rotation.z = 0;
    mixer.update(Math.min(0.1, dt));
  };
  root.userData.parts = { rig, head, body, app, model: true };
  return root;
}
