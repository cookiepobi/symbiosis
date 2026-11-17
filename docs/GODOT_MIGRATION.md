# Godot 전환

웹 프로토타입(JavaScript + Three.js, 저장소 루트)의 기능을 Godot 4.7(`godot/`)로 옮겼습니다. **유전자좌만 고양이 유전 가이드로 바꾸고**, 나머지 규칙·화면·연출은 웹과 같게 구현했습니다. 웹 버전과 GitHub Pages 배포는 그대로 남아 있습니다.

## 실행

- 에디터: `godot/project.godot` 열기 → F5 (메인 씬 `scenes/main.tscn`)
- 개발용 시간 버튼(+1시간/+1일): 실행 인자에 `-- --dev`
- 에셋 미리보기: 에디터에서 `scenes/asset_preview/asset_preview.tscn` 열고 F6
- 테스트: `godot --headless --path godot --import` 후 `godot --headless --path godot -s res://tests/run_tests.gd`
- 저장 위치: `user://catgene-save-v1.json` (Windows: `%APPDATA%\Godot\app_userdata\냥냥 빌리지\`)

## 결정 사항

| 항목 | 결정 |
|---|---|
| 엔진 / 언어 | Godot 4.7.2 / GDScript |
| 렌더러 | Compatibility (PC·웹·모바일 공통) |
| 유전 규칙 | 고양이 유전 가이드: B/D/S 3좌위, 기본 8종 |
| 등급 | **희귀도(멘델 비율 27:9:3:1) 기준 4등급** — 커먼·언커먼·레어·에픽 |
| 스페셜 의상 | 부모 등급이 **같을 때만**. 커먼 1% · 언커먼 7% · 레어 10% · 에픽 15%. 등급이 다르면 의상 없음 |
| 글꼴 | 제목·버튼·주요 표시 Jua, 본문 고운돋움 (둘 다 SIL OFL, `godot/assets/fonts`) |

### 유전 가이드 기준 등급

| 등급 | 외형 | BbDdSs × BbDdSs에서의 비율 |
|---|---|---|
| 커먼 | 블랙 바이컬러 | 27/64 (42.19%) |
| 언커먼 | 블랙, 초콜릿 바이컬러, 블루 바이컬러 | 각 9/64 (14.06%) |
| 레어 | 초콜릿, 블루, 라일락 바이컬러 | 각 3/64 (4.69%) |
| 에픽 | 라일락 | 1/64 (1.56%) |

가이드 이미지의 예시 4 비율 라벨(블랙 42.19% / 블랙 바이컬러 14.06%)은 서로 바뀌어 있어 멘델 법칙대로 구현했습니다.

### 웹 7등급 → 4등급에 맞춘 값

웹에서 등급별 배열이던 값은 앞 4칸을 씁니다 (`scripts/core/params.gd`).
- 시간당 수입 1·2·4·8냥, 판매가 10·25·60·150냥, 도감 보상 5·10·20·40냥
- 판타지(웹: 최고 등급 미시컬에서 10%) → 최고 등급 **에픽**에서 10%
- 창업 개체군 빈도: B 0.7 / b 0.3 (웹의 b·bl 합침), D 0.7 / d 0.3, S 0.28 / s 0.72
- 숨은 열성 보인자 수 = 이형접합 좌위 수 (가격 +15%씩)
- 의상 목록은 가이드의 7종(요리사·마법사·왕관·선장·탐정·산타·탐험가). 탐험가 모자는 새로 만들었고, 웹에만 있던 한복·우주비행사·딸기 모자·노란 우비는 뺐습니다.

웹 저장 파일(12좌위)은 유전자 구조가 달라 Godot에서 불러올 수 없습니다(복구 화면이 원본을 보호).

## 옮긴 기능과 파일

| 웹 | Godot | 내용 |
|---|---|---|
| `rng.js` | `scripts/core/rng.gd` | mulberry32·hashSeed 비트 단위 동일 (웹과 같은 수열, 테스트로 확인) |
| `genes.js`, `engine.js` | `scripts/genetics/genetics.gd`, `scripts/core/cat_engine.gd` | 유전(가이드), 외형 파라미터 유전·변이, SPECIAL 4종, 판타지, 의상, 근친 규칙, 가격·수입 |
| `params.js` | `scripts/core/params.gd` | 쿨다운 24h, 성장 1h, 우리 레벨 8단계, 샵 6h 입고 등 |
| `game.js`, `save-data.js`, `recovery.js` | `scripts/core/game_state.gd`, `save_data.gd`, `scripts/main.gd` | 보유·샵·이웃·도감·수입(소수 이월, 24h 상한)·판매·교환·교배·저장 검사·복구 화면 |
| `personality.js`, `wellbeing.js` | `personality.gd`, `wellbeing.gd` | 1시간 돌봄 → 소프트맥스 성격, 편안함, 화장실 |
| `behavior.js`, `navigation.js`, `locations.js`, `next-step.js`, `village-map.js` | `behavior.gd`, `navigation.gd`, `locations.gd`, `scripts/ui/village_map_view.gd` | 성격별 행동·쉼터·인사, A* 길찾기, 장소 메뉴, 다음 할 일, 마을 지도 |
| `cat3d.js`, `appearance.js`, `textures.js` | `scripts/render/cat_model.gd`, `cat_textures.gd`, `raster.gd`, `three_geo.gd` | 프로시저럴 툰 고양이, 성격별 눈, 걷기·행동 애니메이션, 텍스처 |
| `world.js` | `scripts/render/world_view.gd`, `label_sprite.gd` | 마을·건물·우리·쉼터·화장실·나무·꽃, 집사·이웃 아바타, 카메라, 클릭·키보드 이동 |
| `stage.js` | `breed_stage.gd`, `thumbnails.gd` | 교배 연출, 카드 썸네일 |
| `ui.js`, `style.css`, `index.html`, `focus.js`, `touch-controls.js` | `scripts/ui/game_ui.gd`, `ui_kit.gd`, `click_card.gd` | 상단바, 패널 5종, 모달, 토스트, 효과, 탭, 조이스틱, 좁은 화면 레이아웃 |
| `audio.js`, `preferences.js` | `scripts/audio/game_audio.gd`, `preferences.gd` | 합성 삼각파 배경음악·효과음, 음량 저장 |
| `lab.html`, `lab.js`, `simulation.js`, `expectation.js` | `scripts/ui/genetics_lab.gd` | 유전 실험실 (3좌위, 이론 vs 표본) |
| `tests/*.test.js` | `godot/tests/test_*.gd` | 게임·우리·수입·화장실·길찾기·행동·안내·음량·조이스틱·난수·유전 테스트 61개 |

## 남은 일

- 배포 대상이 정해지면 export 설정(웹은 이모지 글꼴 포함 필요 — 지금은 OS 이모지 글꼴 사용)
- 팀원 고양이 .blend가 들어오면 프로시저럴 모델을 교체 (셰이더 방식 확정 후)
- 웹 브라우저 회귀 테스트(`scripts/browser-test.mjs`, `smoke.html`)에 해당하는 Godot UI 자동 테스트
