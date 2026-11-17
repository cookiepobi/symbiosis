# 에셋 워크플로우: Blender → Google Drive → Godot

팀원은 지금처럼 **Google Drive에 .blend를 올리기만** 하면 됩니다. 나머지(검사, GLB 변환, Godot 반영)는 GitHub Actions가 처리합니다.
크기는 올리기 전에 **Blender 안에서** 게임 기준 모형과 바로 비교할 수 있습니다.

```
[Blender 5.2]  냥냥 에셋 패널: 기준 모형과 크기 비교 → 검사 → 고치기
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

1. **Blender 5.2** 설치 (자동 변환기도 5.2.1로 변환합니다. 더 높은 버전에서 저장한 파일은 열리지 않을 수 있습니다.)
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
"C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup -P tools/blender/convert_assets.py -- --src <Drive 폴더를 받은 경로> --out godot/assets/models --rules godot/assets/asset_rules.json --report asset-report.md
```

Google Drive for Desktop을 쓰면 `--src`에 `G:/내 드라이브/...` 같은 로컬 경로를 그대로 넣을 수 있습니다.
