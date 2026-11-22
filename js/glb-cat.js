// glb-cat.js — 블렌더에서 만든 고양이 GLB를 팀 웹 게임(world.js)에서 움직이게 하는 모듈 (three r160)
// world.js가 매 프레임 부르는 root.userData.tick(t, {activity, moving, dt})를 기존 cat3d.js와 같은 모양으로 제공.
//
// GLB 안의 Action(cat_deploy.glb 기준):
//   반복  idle_loop, walk_loop, bouncy_walk_loop, loaf_loop, loaf_doze_loop, groom_loop  (이름이 _loop로 끝나면 반복)
//   1회   happy, loaf_enter, loaf_to_walk, walk_to_loaf_left, walk_to_loaf_right
// 셰이프 키: body_slim, body_chubby (체형 슬라이더 하나로 연결: 음수 = 홀쭉, 양수 = 뚱냥)
// 재질: coat(털), eye(얼굴 데칼)

import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';

/** 뼈대가 있는 모델 복제 (three의 SkeletonUtils.clone과 같은 동작 — 로컬 vendor에 파일이 없을 수 있어 직접 구현) */
function cloneSkinned(source) {
  const srcOf = new Map();
  const cloneOf = new Map();
  const copy = source.clone();
  (function walk(a, b) {
    srcOf.set(b, a);
    cloneOf.set(a, b);
    for (let i = 0; i < a.children.length; i++) walk(a.children[i], b.children[i]);
  })(source, copy);
  copy.traverse(node => {
    if (!node.isSkinnedMesh) return;
    const src = srcOf.get(node);
    node.skeleton = src.skeleton.clone();
    node.bindMatrix.copy(src.bindMatrix);
    node.skeleton.bones = src.skeleton.bones.map(b => cloneOf.get(b));
    node.bind(node.skeleton, node.bindMatrix);
  });
  return copy;
}

const loader = new GLTFLoader();
const cache = new Map();

/** 같은 GLB는 한 번만 내려받아 모든 고양이가 공유 */
export function loadCatGlb(url) {
  if (!cache.has(url)) cache.set(url, loader.loadAsync(url));
  return cache.get(url);
}

// 웹 게임 행동(behavior.js) → 멈춰 있을 때 재생할 Action과 자세
// posture: 'stand' 서 있는 계열, 'loaf' 식빵자세 계열 / once: 행동이 시작될 때 한 번 재생
const ACTIVITY = {
  idle:    { clip: 'idle_loop',      posture: 'stand' },
  roam:    { clip: 'idle_loop',      posture: 'stand' },
  explore: { clip: 'idle_loop',      posture: 'stand' },
  watch:   { clip: 'idle_loop',      posture: 'stand' },
  alert:   { clip: 'idle_loop',      posture: 'stand' },
  pounce:  { clip: 'idle_loop',      posture: 'stand' },
  groom:   { clip: 'groom_loop',     posture: 'stand' },
  greet:   { clip: 'idle_loop',      posture: 'stand', once: 'happy' },
  rub:     { clip: 'idle_loop',      posture: 'stand', once: 'happy' },
  care:    { clip: 'idle_loop',      posture: 'stand', once: 'happy' },
  nap:     { clip: 'loaf_doze_loop', posture: 'loaf' },
  shelter: { clip: 'loaf_loop',      posture: 'loaf' },
  hide:    { clip: 'loaf_loop',      posture: 'loaf' },
};
// 이동 중: 신난 행동이면 통통 걷기, 아니면 일반 걷기
const BOUNCY = new Set(['pounce', 'rub', 'greet', 'explore']);
// 클릭 반응
const REACT_CLIP = { pet: 'happy', feed: 'happy', yarn: 'happy' };

const isLoop = name => /_loop$/.test(name);

/**
 * @param gltf   loadCatGlb 결과
 * @param cat    게임의 고양이 데이터 (참고용)
 * @param opts   { scale: GLB 크기에 곱할 배율, height: 원하는 높이(scale 대신),
 *                 body: 체형 -1~1 (음수 홀쭉, 양수 뚱냥), walkSpeed: 숫자 또는 () => 숫자,
 *                 convertMaterial: (원래재질, 메시) => 새 재질, eyes: { open, closed: Texture } }
 */
export function buildGlbCat(gltf, cat = {}, opts = {}) {
  const root = new THREE.Group();
  const model = cloneSkinned(gltf.scene);
  root.add(model);
  const ownMaterials = new Set(); // 이 고양이만 쓰는 재질 (지울 때 정리)

  if (opts.scale) model.scale.multiplyScalar(opts.scale);
  if (opts.height) {
    model.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(model, true);
    const h = box.max.y - box.min.y;
    if (h > 0) model.scale.multiplyScalar(opts.height / h);
  }
  // 발이 바닥(y=0)에 닿고 몸 중심이 원점에 오게 (GLB 바닥이 -0.475 m여도 보정)
  model.updateMatrixWorld(true);
  const ground = new THREE.Box3().setFromObject(model, true);
  model.position.y -= ground.min.y;
  model.position.x -= (ground.min.x + ground.max.x) / 2;
  model.position.z -= (ground.min.z + ground.max.z) / 2;

  // ── 재질 변환 (팀 웹처럼 PBR → 툰). 고양이마다 따로 만들어 털색을 마리별로 바꿀 수 있게 ──
  if (opts.convertMaterial) {
    model.traverse(o => {
      if (!o.isMesh) return;
      const conv = m => {
        if (!m) return m;
        const n = opts.convertMaterial(m, o);
        n.name = m.name;
        ownMaterials.add(n);
        return n;
      };
      o.material = Array.isArray(o.material) ? o.material.map(conv) : conv(o.material);
    });
  }

  // ── 얼굴(eye) 재질: 고양이마다 복제 + 깊이 살짝 앞으로 (털에서 0.75 mm 떠 있어 멀리서 깜빡이지 않게) ──
  const eyeMats = [];
  model.traverse(o => {
    if (!o.isMesh) return;
    const list = Array.isArray(o.material) ? o.material : [o.material];
    const cloned = list.map(m => {
      if (!m || !/eye/i.test(m.name)) return m;
      const c = ownMaterials.has(m) ? m : m.clone();
      c.polygonOffset = true;
      c.polygonOffsetFactor = -2;
      c.polygonOffsetUnits = -2;
      ownMaterials.add(c);
      eyeMats.push(c);
      return c;
    });
    o.material = Array.isArray(o.material) ? cloned : cloned[0];
  });

  // ── 애니메이션 상태 기계 ──
  const mixer = new THREE.AnimationMixer(model);
  const clips = Object.fromEntries(gltf.animations.map(c => [c.name, c]));
  const actions = {};
  const action = name => {
    if (!clips[name]) return null;
    if (!actions[name]) {
      const a = mixer.clipAction(clips[name]);
      if (isLoop(name)) a.setLoop(THREE.LoopRepeat, Infinity);
      else { a.setLoop(THREE.LoopOnce, 1); a.clampWhenFinished = true; }
      actions[name] = a;
    }
    return actions[name];
  };
  let current = null;      // 지금 재생 중인 Action
  let currentName = '';
  let busy = false;        // 1회 동작(전환·반응) 재생 중
  let posture = 'stand';   // 지금 자세
  let lastActivity = null;
  let lastMoving = false;

  function fadeTo(name, fade = 0.25) {
    const a = action(name);
    if (!a) return false;
    if (a === current) return true;
    a.reset().fadeIn(fade).play();
    if (current) current.fadeOut(fade);
    current = a;
    currentName = name;
    return true;
  }
  function playOnce(name, fade = 0.2) {
    if (!clips[name]) return false;
    if (current === actions[name]) current = null; // 같은 1회 동작을 다시 재생할 때
    busy = fadeTo(name, fade);
    return busy;
  }
  mixer.addEventListener('finished', e => {
    if (e.action === current) busy = false; // 다음 tick에서 목표 동작으로 이어짐
  });

  function walkClip(activity) {
    return BOUNCY.has(activity) && clips.bouncy_walk_loop ? 'bouncy_walk_loop' : 'walk_loop';
  }
  function walkingFootSide() {
    // 걷기 주기 앞쪽 절반이면 왼발, 뒤쪽 절반이면 오른발 디딤으로 보고 앉는 전환을 고름
    if (!current || !/walk/.test(currentName)) return 'left';
    return (current.time / current.getClip().duration) % 1 < 0.5 ? 'left' : 'right';
  }

  function update(activity, moving) {
    const spec = ACTIVITY[activity] || ACTIVITY.idle;
    const enteredActivity = activity !== lastActivity;
    lastActivity = activity;
    lastMoving = moving;
    if (busy) return;

    if (moving) {
      if (posture === 'loaf') {           // 식빵자세에서 일어나 걷기
        posture = 'stand';
        if (playOnce('loaf_to_walk')) return;
      }
      fadeTo(walkClip(activity));
      return;
    }
    if (spec.posture === 'loaf' && posture !== 'loaf') {   // 앉기 전환
      const fromWalk = /walk/.test(currentName);
      posture = 'loaf';
      const tr = fromWalk ? `walk_to_loaf_${walkingFootSide()}` : 'loaf_enter';
      if (playOnce(tr) || playOnce('loaf_enter')) return;
    }
    if (spec.posture === 'stand' && posture === 'loaf') {  // 앉아 있다가 서기
      posture = 'stand';
      if (playOnce('loaf_to_walk')) return;
    }
    if (spec.once && enteredActivity && playOnce(spec.once)) return;
    if (!fadeTo(spec.clip)) fadeTo('idle_loop');
  }

  // ── 셰이프 키: 체형 ──
  const morphMeshes = [];
  model.traverse(o => { if (o.isMesh && o.morphTargetDictionary) morphMeshes.push(o); });
  const setMorph = (name, v) => {
    for (const m of morphMeshes) {
      const i = m.morphTargetDictionary[name];
      if (i !== undefined) m.morphTargetInfluences[i] = v;
    }
  };
  const hasMorph = name => morphMeshes.some(m => m.morphTargetDictionary[name] !== undefined);
  function setBody(v) {
    setMorph('body_slim', Math.max(0, -v));
    setMorph('body_chubby', Math.max(0, v));
  }
  setBody(opts.body ?? 0);

  // ── 눈 깜빡임 (blink 셰이프 키나 감은 눈 텍스처를 넘겼을 때만 보임) ──
  const eyes = opts.eyes || {};
  let eyeState = 'open';
  function setEyes(name) {
    const tex = eyes[name];
    if (!tex || eyeState === name) return;
    for (const m of eyeMats) { m.map = tex; m.needsUpdate = true; }
    eyeState = name;
  }
  let nextBlink = 1 + Math.random() * 4;
  let blinkEnd = 0;

  root.userData.tick = (t, { activity = 'idle', moving = false, dt = 1 / 60 } = {}) => {
    // world.js가 도형 고양이용으로 넣는 통통 튀기·좌우 흔들림은 GLB 걷기 동작과 겹치므로 끔
    root.position.y = 0;
    root.rotation.z = 0;

    update(activity, moving);
    const ws = typeof opts.walkSpeed === 'function' ? opts.walkSpeed() : (opts.walkSpeed ?? 1);
    if (current) current.timeScale = moving && /walk_loop$/.test(currentName) ? ws : 1;
    mixer.update(Math.min(0.05, dt));

    if (activity === 'nap') { setEyes('closed'); setMorph('blink', 1); return; }
    if (!blinkEnd && t > nextBlink) {
      blinkEnd = t + 0.12;
      if (hasMorph('blink')) setMorph('blink', 1); else setEyes('closed');
    }
    if (blinkEnd && t > blinkEnd) {
      blinkEnd = 0;
      nextBlink = t + 2 + Math.random() * 4;
      setMorph('blink', 0);
      setEyes('open');
    }
  };

  root.userData.react = act => {
    const name = REACT_CLIP[act];
    if (name && posture === 'stand') playOnce(name);
  };
  root.userData.setBody = setBody;
  root.userData.setChubby = v => setBody(v); // 예전 이름 호환
  root.userData.clips = Object.keys(clips);
  root.userData.mixer = mixer;
  root.userData.ownMaterials = ownMaterials;
  root.userData.state = () => ({ posture, clip: currentName, busy });
  root.userData.glb = true;
  return root;
}

/**
 * 고양이를 지울 때 사용. cat3d.js의 disposeCat은 지오메트리를 dispose하는데,
 * GLB 고양이는 모든 마리가 같은 지오메트리·텍스처를 공유하므로 그걸 쓰면 다른 고양이까지 깨진다.
 */
export function disposeGlbCat(root) {
  root.userData.mixer?.stopAllAction();
  root.userData.mixer?.uncacheRoot(root.children[0]);
  for (const m of root.userData.ownMaterials || []) m.dispose();
  root.removeFromParent();
}
