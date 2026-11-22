# 에셋 워크플로우: Blender → Google Drive → Godot

## ✅ 넘기기 전 체크리스트 (셰이더 · 리깅 · 애니메이션 · 쉐입키)

웹(Three.js)이든 Godot이든 Blender 작업물은 **glTF(.glb) 하나로만** 게임에 들어갑니다(Actions가 Blender 5.3으로 변환). 아래 규칙은 두 엔진에 거의 똑같이 적용됩니다.

### 1. 셰이더·재질
- **넘어감:** Principled BSDF 값(Base Color·Roughness·Metallic·Normal·Emission·Alpha) + 연결된 **이미지 텍스처**, 버텍스 컬러
- **사라짐:** 절차적 노드(Noise·Voronoi), ColorRamp, 수학 노드, Shader to RGB, 툰·림라이트 커스텀 조명, 드라이버 → **Bake**해서 이미지로 굽거나 **게임 셰이더로 재구현**
- **Blender 조명·렌더 설정은 게임에 영향 없음.** 툰 느낌(4단계 음영, 따뜻한 조명)은 엔진 셰이더가 만듭니다. Blender에서는 "색과 무늬"만 정하고, 명암을 텍스처에 그리지 마세요(게임 음영과 이중으로 겹침).
- **유전으로 색이 바뀌는 털은 색을 칠하지 않음.** 흰 반점 마스크(`white_mask`)·명암 디테일 같은 **회색조 마스크**만 만들고, 색은 게임이 유전자로 계산합니다.
- **텍스처:** 색 = sRGB, 노멀·마스크 = **Non-Color**. 크기는 2의 거듭제곱(512·1024·2048…)으로 필요한 만큼만(모바일·웹). 이미지는 **Pack** 또는 상대 경로(절대 경로는 다른 PC에서 깨짐).
- **투명도:** 재질 설정에서 Alpha Clip(잘라내기) / Blend(반투명) 선택. 수염·털끝처럼 경계만 필요하면 Clip이 가볍고 정렬 문제가 없음.
- **재질 이름을 의미 있게** (`coat`, `eye`, `nose`, `costume` …). 게임이 이 이름으로 재질을 찾아 툰 셰이더로 교체합니다.

### 2. 크기·방향·원점
- 1 Blender 단위 = 1m. 애드온 기준 모형(집사·고양이·울타리·문) 옆에서 크기감을 맞춤
- 마무리 전 **Ctrl+A → All Transforms**. 음수 스케일(거울 복사 후 방치)은 면이 뒤집혀 보임
- 원점은 **발밑 바닥 중앙**, 정면 방향은 기준 모형과 같게
- 업로드 전 애드온 **게임 규칙 검사** 실행 (위 항목과 사라지는 노드를 경고)

### 3. 리깅
- 캐릭터 하나에 아마추어 하나
- IK 타깃·폴 같은 **조종용 본은 Deform 끄기** (변형용 본만 내보내야 가벼움)
- **정점당 영향 본 최대 4개** (glTF 기본·웹 한계): Weights → Limit Total(4), Normalize All로 합 1
- 본 개수는 모바일·웹을 생각해 꼭 필요한 만큼만
- 메시·아마추어 모두 트랜스폼 적용 후 바인딩. 나중에 아마추어 크기를 바꾸면 게임에서 어긋남
- **컨스트레인트(IK·Copy Rotation)·드라이버는 넘어가지 않음** → 애니메이션 Bake (4번)

### 4. 애니메이션
- **Action 하나 = 게임 애니메이션 하나.** 이름은 영어로 분명하게 (`idle`, `walk`, `sit`, `sleep`, `happy` …)
- 쓰지 않는 Action은 저장 시 지워질 수 있음 → **Fake User(방패 아이콘)** 켜기 또는 **NLA Stash**
- **컨스트레인트·IK는 Bake:** Object → Animation → Bake Action, Visual Keying 켜고 Clear Constraints
- **제자리 애니메이션.** 걷기도 제자리걸음, 실제 이동은 게임 코드가 함. 아마추어 오브젝트 위치는 애니메이션하지 않음
- **반복 애니메이션:** 첫·마지막 프레임 자세 동일. Godot은 이름이 `loop`/`cycle`로 시작하거나 끝나면 자동 반복(예: `walk_loop`), 웹은 코드에서 설정
- 프레임레이트는 팀 전체 하나로 통일(예: 30fps). 불필요한 키프레임은 정리(파일 크기)

### 5. 쉐입키 (Shape key)
- glTF **Morph Target**으로 넘어가고 이름도 유지 (Godot Blend Shape / Three.js `morphTargetDictionary`). 이름은 영어로 (`chubby`, `ear_big`, `blink` …)
- **모디파이어 주의:** 쉐입키가 있으면 내보낼 때 모디파이어가 적용되지 않음 → Subdivision·Mirror 등은 **쉐입키 만들기 전에 적용** (Armature 모디파이어는 그대로)
- 쉐입키를 만든 뒤 정점 추가·삭제 금지 (키가 깨짐)
- **드라이버(본 회전 → 쉐입키)는 넘어가지 않음.** 게임 코드가 값을 넣음. 체형 같은 연속값(통통함 0~1)에 적합
- 쉐입키 값 애니메이션(눈 깜빡임 등)은 Action에 키프레임으로 넣으면 넘어감
- 메시당 쉐입키는 꼭 필요한 것만 (개수만큼 모바일·웹 메모리·연산 증가)

### 6. 엔진별 차이
| | 웹 (Three.js) | Godot |
|---|---|---|
| 불러오기 | `GLTFLoader`로 .glb | .glb import (Actions가 변환한 파일) |
| 툰 재질 적용 | 불러온 뒤 메시를 돌며 `MeshToonMaterial`로 교체 | 재질 이름으로 `toon.gdshader`로 교체 |
| 반복 | 코드에서 설정 | 이름에 `loop` → 자동 (import 설정도 가능) |
| 압축 | Draco·KTX2 사용 시 디코더 파일도 함께 배포 | import 시 자체 압축 |
| .blend 직접 열기 | 불가 | 가능하지만 모든 PC에 Blender 경로 필요 → 우리는 GLB로 통일 |

웹은 텍스처·메시 용량이 곧 로딩 시간입니다. Godot도 웹·모바일로 내보내면 같은 제약을 받습니다.

> **한 줄 체크:** 트랜스폼 적용 → 재질은 Principled + 이미지만 → 조종용 본 Deform 끄기·가중치 4개 이하 → Action 이름·Fake User → 컨스트레인트 Bake → 모디파이어는 쉐입키 전에 적용 → 애드온 규칙 검사 통과

자세한 셰이더 배경은 [SHADER_NOTES.md](SHADER_NOTES.md) 참고.

---

팀원은 지금처럼 **Google Drive에 .blend를 올리기만** 하면 됩니다. 나머지(검사, GLB 변환, Godot 반영)는 GitHub Actions가 처리합니다.
크기는 올리기 전에 **Blender 안에서** 게임 기준 모형과 바로 비교할 수 있습니다.

```
[Blender 5.3]  냥냥 에셋 패널: 기준 모형과 크기 비교 → 검사 → 고치기
      │ 저장 (텍스처 Pack)
      ▼
[Google Drive]  공유 폴더/<카테고리>/<이름>.blend        ← 팀원이 하는 일은 여기까지
      │ 30분마다 (또는 Actions에서 바로 실행)
      ▼
[GitHub Actions]  Drive 읽기 → 같은 규칙으로 검사 → .glb 변환 → Godot import·테스트
      │
      ▼
[Pull Request "에셋 동기화"]  크기·폴리곤·리그·문제점 보고서 → 담당자가 확인 후 merge
      │
      ▼
[Godot]  godot/assets/models/<카테고리>/<이름>.glb  (미리보기 씬에서 바로 확인)
```

크기 규칙은 [`godot/assets/asset_rules.json`](../godot/assets/asset_rules.json) **한 파일**에만 있습니다. Blender 애드온, 자동 변환기, Godot 미리보기가 모두 이 파일을 읽습니다.

---

## 1. 팀원: 처음 한 번만

1. **Blender 5.3** 설치 (자동 변환기도 5.3.0으로 변환합니다. 더 높은 버전에서 저장한 파일은 열리지 않을 수 있습니다.)
2. **애드온 설치**
   - zip 받기: GitHub → Actions → *Godot tests* 최근 실행 → Artifacts의 `nyang_asset_tools-blender-addon` (또는 담당자가 `python tools/blender/build_addon.py`로 만든 `dist/nyang_asset_tools.zip`)
   - Blender → Edit → Preferences → Get Extensions → 오른쪽 위 ∨ → **Install from Disk…** → zip 선택
   - 3D 뷰에서 `N` → 사이드바의 **냥냥 에셋** 탭
3. Drive 공유 폴더에 접근 권한이 있는지 확인

> 크기 규칙이 바뀌면 애드온 zip도 새로 받아 다시 설치하세요.

## 2. 팀원: 에셋 만들 때 지킬 것

| 항목 | 규칙 | 이유 |
|---|---|---|
| 단위 | Metric, Unit Scale 1.0 → **1 = 1 m** | 게임도 1 unit = 1 m |
| 위치 | 에셋 **바닥 중앙이 원점(0,0,0)** | 게임에서 땅에 딱 붙게 |
| 방향 | 앞모습이 **Front 뷰(숫자패드 1)** 에 보이게 (-Y 방향) | 게임 안 정면 방향 통일 |
| 스케일 | 오브젝트 스케일 **적용(Ctrl+A → Scale)** | 리그·물리·크기 계산 오차 방지 |
| 텍스처 | **File → External Data → Pack Resources** | Drive에는 .blend만 올라가서 외부 이미지는 사라짐 |
| 파일명 | 영문 소문자·숫자·`_` (예: `cat_base.blend`, `food_bowl.blend`) | 파일명이 그대로 게임 리소스 이름 |
| 폴리곤 | 카테고리별 권장치 이하 (규칙 파일 `max_tris`) | 모바일·웹 성능 |
| 백업 | `.blend1`은 올리지 않아도 됨 (자동 무시) | |

### 고양이·캐릭터 (리그·애니메이션·Shape key)

- 아마추어 1개, 메시는 Armature 모디파이어로 연결
- **애니메이션 = Action 1개당 동작 1개.** 이름은 영어로: `idle`, `walk`, `run`, `sit`, `sleep`, `eat`, `groom`, `play`, `happy` …
  - Action마다 **Fake User(방패 아이콘)** 를 켜 두세요. 안 켜면 저장할 때 사라질 수 있습니다.
  - IK·컨스트레인트는 게임으로 넘어가지 않습니다. 결과는 키프레임으로 **Bake** 해 두세요 (Pose → Animation → Bake Action).
- **Shape key** 는 게임에서 그대로 쓸 수 있습니다 (Godot Blend Shape). 이름은 영어로: `body_chubby`, `ear_big`, `face_round`, `whisker_long` …
  - 드라이버로 움직이는 Shape key는 넘어가지 않습니다. 게임 코드가 값을 직접 조절합니다.
  - Shape key가 있으면 내보낼 때 모디파이어를 적용하지 않습니다 → Subdivision 등은 미리 적용하고 Armature만 남기세요.
- **털 무늬** (임시 규칙, 셰이더 방식 확정 전 — [SHADER_NOTES.md](SHADER_NOTES.md))
  - 털 머티리얼 이름에 `coat`를 넣어 주세요 (예: `Coat`). 게임이 이 머티리얼을 유전 색으로 바꿉니다.
  - 흰 반점 영역은 흑백 마스크 이미지(흰색 = 흰 털)로 따로 그려 두면 바이컬러에 씁니다.

### 카테고리 = Drive 최상위 폴더

| 폴더 | 내용 | 허용 높이 |
|---|---|---|
| `cat/` | 고양이 본체 | 0.45–0.8 m |
| `costume/` | 스페셜 의상 (요리사·마법사·왕관·선장·탐정·산타·탐험가) | 0.03–0.6 m |
| `prop/` | 밥그릇·장난감·방석 | 0.03–1.5 m |
| `furniture/` | 쉼터·캣타워·가구 | 0.2–2.5 m |
| `building/` | 건물 | 2–8 m |
| `nature/` | 나무·풀·바위 | 0.05–9 m |
| `character/` | 집사·이웃 NPC | 1.4–2.0 m |

(정확한 값은 `asset_rules.json`. 하위 폴더는 자유: `prop/toys/yarn.blend` → `prop/yarn.glb`)

## 3. 팀원: 크기 확인하고 올리기

1. **냥냥 에셋** 패널에서 **카테고리** 선택
2. **기준 모형 추가** → 에셋 왼쪽에 반투명 모형이 생깁니다
   - Kitten 0.37 m · Cat adult 0.60 m · Caretaker(집사) 1.70 m · Door 1.54 m · Fence 0.77 m
   - Front 뷰(숫자패드 1)에서 비교하면 게임 안 사이즈감과 같습니다
   - 이 모형은 `NYANG_REFERENCE` 컬렉션에 있고, 렌더·변환에서 자동으로 빠지니 지우지 않고 저장해도 됩니다
3. 크기를 고칠 때는 Edit 모드에서 줄이거나, 오브젝트 모드에서 줄인 뒤 **스케일 적용** 버튼
4. **게임 규칙 검사** → 결과가 패널에 표시됩니다
   - ⛔ 오류: 이 상태로 올리면 변환되지 않습니다 (높이 범위 밖, 텍스처 없음 등)
   - ⚠️ 경고: 변환은 되지만 게임에서 이상하게 보일 수 있습니다 (바닥 위치, 스케일, 셰이더 노드 등)
   - **바닥 중앙에 맞추기** 버튼이 위치 문제를 한 번에 고칩니다
5. 저장(텍스처 Pack 확인) → Drive의 **해당 카테고리 폴더**에 업로드 (수정본은 **같은 이름으로 덮어쓰기**)
6. 30분 안에 GitHub에 **"에셋 동기화" PR**이 생기고, 보고서에 크기·결과가 표시됩니다. 급하면 Actions → *Drive asset sync* → **Run workflow**

## 3-1. 바닥 텍스처 작업 매뉴얼

마을 잔디처럼 **넓은 바닥에 반복해서 깔리는 이미지**를 만드는 방법입니다. 모델(.blend)이 아니라 **PNG 이미지 한 장**이 결과물입니다.

### 지금 게임의 바닥은 어떻게 되어 있나
| 부분 | 지금 모습 | 처리 방식 |
|---|---|---|
| 잔디 (마을 전체 170 × 130 m) | 바탕 `#79c277` + 밝은 `#86cd80` / 어두운 `#6dba6c` 작은 삼각형 풀잎 | 이미지 한 장을 가로 26 × 세로 20번 **반복** |
| 흙길 | 단색 `#e8d3a2`, 폭 3 m | 색만 있는 판 (조명 받음) |
| 우리 마당 | 단색 `#f2e2b6` | 색만 있는 판 (조명 안 받음) |

- **잔디 이미지 한 장 = 땅 약 6.5 m × 6.5 m.** 고양이(0.6 m) 10마리가 한 줄로 서는 정도의 넓이입니다.
- 지금 잔디 풀잎 하나는 0.2~0.4 m 크기(이미지 폭의 3~6%)입니다.
- 바닥은 **조명을 받지 않는 재질**이라 칠한 색이 그대로 화면에 나옵니다. 그림자나 명암이 따로 더해지지 않습니다.
- 멀리 있는 바닥(45~95 m)은 하늘색 `#d8f0f0` 안개로 서서히 흐려집니다.
- 카메라는 비스듬히 위에서 내려다보고, 평소에는 화면 가로에 땅이 약 18 m 보입니다(이미지가 약 3번 반복되어 보임). 고양이를 따라갈 때는 약 9 m가 보입니다(이미지 1.5장 정도).

### 이미지 규격
| 항목 | 규격 |
|---|---|
| 크기 | **1024 × 1024 px** 권장 (최소 512, 최대 2048). 정사각형, 2의 거듭제곱 |
| 형식 | **PNG** (RGB, 투명 없음) |
| 색 공간 | sRGB (일반 그림 그대로) |
| 이음새 | **상하좌우가 끊김 없이 이어지는 타일(Seamless)** 이어야 함 |
| 파일 이름 | 영어 소문자·숫자·`_` (예: `grass_spring.png`, `dirt_path.png`) |

### 그릴 때 지킬 것
1. **이음새 없이 이어지게.** 가장자리에 걸친 풀잎은 반대쪽 가장자리에서 이어져야 합니다.
   - Photoshop: 필터 → 기타 → **오프셋**(가로·세로 절반, "둘러싸기")으로 이음새를 가운데로 옮겨 지운 뒤 되돌림
   - Krita: **Wrap Around Mode**(W 키)를 켜고 그리기
   - Blender: Texture Paint에서 이미지 텍스처의 Extension을 **Repeat**로 두고 칠하기
2. **눈에 띄는 무늬 하나를 넣지 않기.** 큰 꽃, 돌, 진한 얼룩 하나가 있으면 6.5 m마다 똑같이 반복되어 바둑판처럼 보입니다. 작은 무늬를 고르게 흩뿌리세요. 꽃·돌은 따로 모델로 만들어 배치합니다(`nature/` 폴더).
3. **명암·그림자를 그리지 않기.** 햇빛 방향 그림자나 입체감을 그리면 카메라를 돌렸을 때 어색합니다. 지금처럼 **평평한 일러스트 색**으로 칠합니다.
4. **대비를 낮게.** 바닥은 고양이와 건물의 배경입니다. 바탕색과 무늬색의 밝기 차이를 지금 정도(±5~8%)로 작게 두어야 고양이가 잘 보입니다. 채도가 너무 높으면 털색이 묻힙니다.
5. **톤은 파스텔·따뜻한 쪽으로.** 게임 전체가 크림·파스텔 톤입니다. 지금 색(`#79c277` 계열)을 기준으로 맞추면 다른 에셋과 어울립니다.
6. **무늬 크기는 실제 크기로 생각하기.** 1024 px 이미지라면 1 m ≈ 157 px입니다. 풀잎 0.3 m ≈ 47 px. 너무 작으면(10 px 이하) 멀리서 뭉개지고, 너무 크면 장난감처럼 보입니다.
7. **외곽선이 필요하면 굵고 부드럽게.** 1~2 px 가는 선은 멀리서 깜빡이며 사라집니다.

### 미리 확인하는 방법
- **반복 확인:** 그림 프로그램에서 이미지를 3 × 3으로 붙여 놓고 이음새와 반복 무늬가 튀지 않는지 봅니다.
- **크기 확인(Blender):** 6.5 m × 6.5 m Plane(애드온의 기준 모형 옆)에 이미지를 붙이고 Front·위쪽 비스듬한 시점에서 고양이 기준 모형과 비교합니다. Material은 Principled BSDF 대신 **Emission**(또는 Viewport Shading의 Flat 조명)으로 보면 게임처럼 조명 없는 색이 보입니다.
- **멀리서 확인:** 이미지를 25% 크기로 줄여 보았을 때도 지저분하지 않아야 합니다(평소 카메라 거리).

### 올리는 곳
- Drive 최상위 폴더 아래 **`texture/ground/`** 폴더에 PNG를 올립니다(폴더가 없으면 만들기). 수정본은 같은 이름으로 덮어씁니다.
- 원본 작업 파일(.psd, .kra, .blend)은 `texture/ground/source/`에 함께 두면 나중에 고치기 쉽습니다.
- 무엇의 바닥인지(마을 잔디 / 흙길 / 우리 마당 / 새 구역) 담당자에게 알려 주세요.

> ⚠️ **지금은 바닥 이미지가 자동으로 게임에 들어가지 않습니다.** 자동 변환기는 모델 파일(.blend·.fbx·.obj·.glb)만 처리합니다. 바닥 PNG는 담당자가 `godot/assets/textures/ground/`에 넣고 게임 코드(`world_view.gd`의 잔디 텍스처)를 교체해 반영합니다.

## 4. (선택) Godot에서 직접 보기

Godot 4.7을 설치하고 저장소를 받은 사람은 `godot/project.godot`을 열고 실행(F5)하면 **에셋 미리보기** 씬이 뜹니다.
- 동기화된 모든 .glb 목록, 기준 모형과 나란히 표시, 마우스 드래그 회전 / 휠 확대
- 크기·허용 범위·Shape key·애니메이션 목록, 애니메이션 재생
- 고양이는 털색 드롭다운으로 8종 유전 색을 입혀 볼 수 있음 (임시 셰이더)

## 5. 담당자: PR 확인

- PR 본문 보고서에서 ✅/⛔ 확인, 필요하면 브랜치를 받아 미리보기 씬으로 확인 후 merge
- ⛔는 변환되지 않았으므로 올린 사람에게 보고서 내용을 전달
- Drive에서 지운 파일은 자동으로 지워지지 않습니다. `godot/assets/models`에서 해당 .glb와 `manifest.json` 항목을 직접 지우세요.
- 같은 카테고리에 이름이 같은 파일(`chair.blend`, `chair.fbx`)이 있으면 나중 것이 덮어씁니다.

---

## 6. 관리자: 처음 한 번 설정 (GitHub ↔ Google Drive)

GitHub Actions가 Drive를 **읽기 전용**으로 볼 수 있도록 Google Cloud 서비스 계정을 만듭니다. 개인 Google 비밀번호는 쓰지 않습니다.

1. https://console.cloud.google.com 에서 프로젝트 생성 (예: `nyang-asset-sync`)
2. **APIs & Services → Library → Google Drive API → Enable**
3. **IAM & Admin → Service Accounts → Create service account** (역할 부여 없이 생성)
4. 만든 계정 → **Keys → Add key → JSON** → 파일 다운로드 (이 파일은 비밀번호와 같으니 Drive·채팅에 올리지 마세요)
5. Google Drive에서 에셋 공유 폴더 → **공유** → 서비스 계정 이메일(`…@….iam.gserviceaccount.com`)을 **뷰어**로 추가
6. 폴더 URL `https://drive.google.com/drive/folders/<이 부분>` 이 폴더 ID
7. GitHub 저장소 → Settings → Secrets and variables → Actions → **New repository secret**
   - `GDRIVE_SERVICE_ACCOUNT_JSON`: 4번 JSON 파일 내용 전체
   - `GDRIVE_FOLDER_ID`: 6번 폴더 ID
8. Settings → Actions → General → Workflow permissions → **Read and write** + **Allow GitHub Actions to create and approve pull requests** 체크
9. 이 워크플로 파일이 **기본 브랜치(main)** 에 있어야 30분 주기 실행이 동작합니다. 첫 실행은 Actions → *Drive asset sync* → Run workflow

### 용량 참고

- Drive 원본(.blend)은 저장소에 넣지 않고, 변환된 .glb만 **Git LFS**로 저장합니다 (`.gitattributes`).
- GitHub LFS 무료 저장 용량·전송량에는 한도가 있으니, 에셋이 많아지면 Settings → Billing에서 사용량을 확인하세요.
- 로컬에서 저장소를 받는 팀원은 `git lfs install`을 한 번 실행해 두세요.

## 7. 로컬에서 직접 변환해 보기 (담당자용)

```bash
"C:/Program Files/Blender Foundation/Blender 5.3/blender.exe" -b --factory-startup -P tools/blender/convert_assets.py -- --src <Drive 폴더를 받은 경로> --out godot/assets/models --rules godot/assets/asset_rules.json --report asset-report.md
```

Google Drive for Desktop을 쓰면 `--src`에 `G:/내 드라이브/...` 같은 로컬 경로를 그대로 넣을 수 있습니다.
