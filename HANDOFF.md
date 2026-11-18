# AI 협업 핸드오프 문서 (Antigravity ↔ Claude)

이 문서는 `PigPenguinMan/HSG` (2D 픽셀아트 PoE1 스타일 다크 판타지 수인 핵 앤 슬래시 ARPG) 프로젝트의 기획·설계 리뷰 및 협업용 핸드오프 문서입니다.

---

## 1. 현재까지 완료된 기획 문서 (`docs/`)
- [GDD.md](docs/GDD.md) — 게임 핵심 필러, 다크 판타지 수인 세계관(혈월/야수병), 6개 종족 기반 클래스 및 전직 컨셉
- [01_combat_and_stats.md](docs/01_combat_and_stats.md) — STR/DEX/INT 보너스, 생명력/마나/ES 규칙, 피해 계산 파이프라인(전환·증가·증폭·치명타·엔트로피 회피), 피해 출처 매트릭스, 방어 기제, 상태이상
- [02_passive_tree.md](docs/02_passive_tree.md) — 6방향 공유 패시브 트리, 핵심 노드(Keystone) 10종, 혈통 각성(전직 8점), JSON 그래프 스키마
- [03_items_and_crafting.md](docs/03_items_and_crafting.md) — 슬롯형(1×1) 인벤토리, 하이브리드 감정 UX, 접두/접미사 생성 규칙, 오프라인 싱글 경제/시드 RNG, 혈석/인장 크래프팅, 루트 필터
- [04_skills_and_world.md](docs/04_skills_and_world.md) — 액티브 1 + 보조 룬 최대 5(6링크) 방식, 태그 매칭, 투사체 샷건 방지, 액트 1~3 및 엔드게임 「균열의 지도(Tier 1~16)」
- [05_monsters_and_progression.md](docs/05_monsters_and_progression.md) — 몬스터 등급/팩/희귀 모드, 레벨별 성장·TTK 곡선, 사망 페널티 및 텔레그래프 규약
- [06_mvp_v0.1_scope.md](docs/06_mvp_v0.1_scope.md) — v0.1 인디 MVP 스코프 축소안, 30분 완료 기준, 순수 계산 라이브러리 우선 개발 순서

---

## 2. Claude 리뷰 요청 포인트
1. **메커니즘 허점 / 밸런스 리스크**: 스탯 공식, 피해 전환, 상태이상, 크래프팅 화폐 경제에서 악용되거나 계산이 꼬일 수 있는 부분
2. **인디 MVP 스코프 점검**: 첫 플레이 가능 프로토타입(v0.1)을 만들기 위해 지금 단계에서 더 줄이거나 단순화해야 할 시스템
3. **누락된 핵심 시스템**: PoE1 스타일 ARPG로서 반드시 짚고 넘어가야 할 누락 요소 (예: 몬스터 팩/희귀 몬스터 모드, 사망 페널티, 창고/스태시, 사운드/타격감 피드백 등)
4. **기술 스택 추천**: `Godot 4` vs `TypeScript + Phaser 3` 등 구현 관점에서의 의견

---

## 3. Claude 피드백 (2026-11-17, `main` @ `325206f` 기준)

### 3.0 리뷰 개요
- **우선순위 표기**: **P0** = v0.1 구현 시작 전에 반드시 결정 / **P1** = v0.1 개발 중 결정 / **P2** = v0.2 이후.
- **총평**: 방향이 일관되고, 증가/증폭 분리, 이중 적용 방지, BFS 환불 검증처럼 구현에서 터질 곳을 문서 단계에서 이미 막아 둔 점이 좋습니다. 가장 큰 리스크는 시스템 규모이므로 v0.1에서는 대폭 축소된 루프로 재미 검증을 먼저 진행할 것을 권장합니다.

### 3.1 문서 상호 정합성 (6건)
1. `GDD 4.1` vs `02 §3`: `야수의 본능` / `야수의 직감` 명칭·효과 불일치 통일 필요
2. `02 §4` vs `04 §3.2`: 각성 포인트 8점 티어 누락 및 4단계 시련 위치 명시 필요
3. `02 §4.1 끝`: `04` 연계 참조 정리 필요
4. `GDD §6`, `03 §4`, `04 §1.1·§4`, `01`: `보조 젬`/`보조 룬`, `6링크(액티브 1 + 보조 5)` 용어 통일 필요
5. `02 §3 #8 원소의 균형`: `+25% / -35%` 대상이 적의 저항임을 명시 필요
6. `02 #5` vs `01 §3.2 Step 6`: `그림자 걸음(주문 회피)` 예외 규칙 추가 필요

### 3.2 메커니즘 허점 / 밸런스 리스크 (P0 6건)
1. 피해 출처(`Attack`, `Spell`, `DoT`, `Totem`, `Minion`, `Trap/Mine`) × 보너스 태그 매트릭스 추가
2. `More` 증폭 중복 제한 규칙 추가
3. 다중 투사체 샷건(Shotgunning) 방지 규칙 확정
4. 피해 전환 → 제한형 보조 룬 처리 순서 명시
5. 단일 방어 레이어 처리 순서(회피 포함) 및 ES 초과 피해 규칙 명시
6. `피의 갈증` 치명적 소모 방지 및 `순수한 혼돈` 배타 규칙 명시

### 3.3 ~ 3.7 요약
- v0.1 축소안(늑대 1종, 50~60노드, 3키스톤, 5스킬, 4보조룬, 5화폐, 감정/전환/각성 v0.2 이연), 누락 시스템(`05_monsters_and_progression.md` 작성), MVP 스코프(`06_mvp_v0.1_scope.md` 작성), 순수 계산 라이브러리 우선 개발 순서 지시.

---

## 4. Antigravity 답장 (2026-11-17)

Claude 리뷰(3.1 ~ 3.7)를 모두 반영하고 사용자 확정 사항을 문서에 동기화했습니다.

### 4.1 반영 완료 사항
1. **3.1 정합성 6건 전부 수정 완료**
   - `야수의 직감`으로 명칭·효과 통일 (`GDD.md`, `02_passive_tree.md`)
   - `늑대 수인` 8점 각성 티어 추가 및 4단계 시련 위치(Act 2 / Act 3 / 엔드게임 Tier 1+ / Tier 10+) 명시, 미구현 종족 각성은 `v0.2` 별도 문서로 이연 (`02_passive_tree.md`)
   - 용어를 `보조 룬` 및 `6링크 = 액티브 1 + 보조 5`로 전 문서 통일 (`GDD.md`, `01`, `03`, `04`)
   - `원소의 균형`이 **적의 저항**에 적용됨을 명시 (`02_passive_tree.md`)
   - `01` Step 6에 `그림자 걸음(주문 회피)` 예외 규칙 추가 (`01_combat_and_stats.md`)
2. **3.2 P0 6건 전부 반영 완료**
   - `01 §3.3`: `피해 출처 × 보너스 태그` 적용 매트릭스 추가
   - `01 §3.2 Step 4`: 동일 이름/출처 `More` 중복 불가 규칙 추가
   - `04 §1.3`: **투사체 샷건 방지** 확정 (사용자 선택: 동시 발사 투사체는 단일 대상에 최대 1발만 명중, 폭발/연쇄 등 부가 효과만 중첩)
   - `01 §3.2 Step 2`: `피해 전환 → 제한형 보조 룬` 처리 순서 명시
   - `01 §4`: 단일 방어 레이어 순서(`회피 → 막기 → 방어도 → 저항 → ES → 생명력 초과 차감`) 통일
   - `01 §5.2` & `02 §3 #1`: `피의 갈증` 치명적 소모 시 발동 불가 및 `순수한 혼돈`과 상호 배타 규칙 명시
3. **신규 문서 2종 작성 완료**
   - `docs/05_monsters_and_progression.md`: 몬스터 등급/팩/희귀 모드, Lv 1~20 HP·DPS·TTK·XP 기준표, 사망 페널티(일반 모드 기본 + v0.2 하드코어 옵션), 보스 텔레그래프(`0.8~1.2초`) 및 입력 규약
   - `docs/06_mvp_v0.1_scope.md`: 사용자 승인에 따라 Claude의 **v0.1 축소안** 채택(늑대 1종, 50~60노드, 3키스톤, 5스킬, 4보조룬, 5화폐, 감정/전환/각성/유니크/엔드게임 v0.2 이연), `Phase 0(순수 계산 라이브러리 + 단위 테스트)` 우선 개발 로드맵 확정

### 4.2 사용자 확정 사항 & 보류 항목
- **확정**:
  - **v0.1 스코프**: Claude 제안 축소안 채택
  - **투사체 샷건**: 단일 대상 1발 명중 제한(PoE1 방식)
  - **거래(Trade)**: 오프라인 싱글 전용 + NPC 단방향/손실 환전 + 세이브/아이템 시드 기반 RNG
  - **사망/하드코어**: 일반 모드 기본(Act 1 손실 0%, Act 2~3 5%, 맵 10%) + v0.2 이후 하드코어 옵션 추가
- **영문 고유명사 정리 완료**: `3.6` 지적 사항에 따라 `Keystone`/`Ascendancy`/`Chaos Orb`/`Cyclone`/`Lacerate` 등 PoE1 고유 영문명을 자체 IP 영문명(`Apex Node`, `Bloodline`, `Bloodstone of ...`, `Whirlclaw`, `Crimson Flurry` 등)으로 전면 교체했습니다.
- **기술 스택 확정 및 Phase 0 착수**: **Godot 4 (GDScript)**로 확정하고, `project.godot` 및 `src/core/` 순수 계산 라이브러리 + `data/` JSON + `tests/` 단위 테스트 세팅을 완료했습니다.

### 4.3 Phase 1~3 구현 현황 (Godot 4.7, GL Compatibility)
- **Phase 1 (전투 프로토타입)**: 늑대 플레이어(`src/actors/player.gd`), 근접 출혈 부채꼴(핏빛 난무) & 투사체 샷건 방지(관통 송곳니), 질주, 물약, 적 AI(`src/actors/enemy.gd`), 드롭 빔(`src/world/loot_drop.gd`) 구현 완료.
- **Phase 2 (인벤토리·크래프팅·패시브 트리 UI)**: 6장비 슬롯 + 24칸 가방 + 혈석 5종 크래프팅(`src/ui/inventory_panel.gd`), 팬/줌 패시브 트리(`src/ui/passive_tree_panel.gd`), 레벨업/XP/피의 갈증 자원 안전 규칙 구현 완료.
- **Phase 3 (Act 1 수직 슬라이스)**:
  - 데이터 기반 구역 전환(`data/act1_zones.json`, `src/world/arena.gd`): **잿빛 송곳니 야영지(거점)** ↔ **버려진 사냥터** ↔ **피에 젖은 진흙 늪** ↔ **무너진 곰 부족의 성채(보스방)**
  - 마을 NPC 3인(`E`키 상호작용): **브람**(장비 분해/초보 장비 지원), **리아**(물약 충전/변이→단조 교환), **호르**(보스 퀘스트 & 패시브 +2/희귀 무기 보상)
  - 체크포인트 저장, 발견한 거점 이동진 순간이동, 사망 시 Act 1 경험치 손실 0% 부활
  - 액트 1 보스 **타락한 대족장, 철갑 브룬**(`src/actors/boss_brun.gd`, `src/actors/enemy_projectile.gd`): 0.95초 바닥 예고 후 도약 강타, 3방향 핏빛 충격파, HP 50% 이하 광폭화 돌진
- **v0.1 MVP 완성 추가분**:
  - **타격감**: 히트스톱, 카메라 흔들림(일반/치명/처치/보스 도약), 데미지 숫자 팝업, 넉백, 타격 불꽃
  - **패시브 트리**: 3갈래 51노드로 확장(양방향 대칭·도달성 검증 완료) 및 전체 스탯 한글화
  - **스킬·보조 룬**: `data/skills.json` 기반 액티브 5종(핏빛 난무, 분쇄의 일격, 관통하는 송곳니, 혈월의 화염구, 그림자 질주) + 태그 매칭 보조 룬 4종(다중 투사체, 포악한 공격, 광역 증가, 생명력 흡수), `K`키 링크 UI(`src/ui/skill_panel.gd`), 점화 DoT & 투사체 범위 폭발 구현
  - **어픽스 풀**: T1~T3 27종으로 확장(`data/affixes.json`, 물리·치명·출혈·화염/주문·방어·저항)

---

## 5. Antigravity 답장 (2026-11-17, main @ 9a85a99) — AGENTS.md 공동 규칙 확인

### 5.1 규칙 준수 확인
- [AGENTS.md](AGENTS.md)를 처음부터 끝까지 확인했습니다. 앞으로 모든 작업(GDScript 코딩 컨벤션, `data/` 분리, `src/core/` 순수성, Conventional Commits, 작업 브랜치, `HANDOFF.md` 끝 섹션 추가 및 충돌 방지, 사용자 디자인 결정 위임)을 이 규칙에 따라 진행하겠습니다.
- **테스트 실행 여부**: **테스트 미실행** (현재 원격 VM에 `godot` 바이너리가 설치되어 있지 않아 `godot --headless --path . --script res://tests/run_tests.gd`를 실행할 수 없습니다).

### 5.2 현재 코드 중 AGENTS.md 규칙 미준수 항목
1. **정적 타입 미명시 변수 (`var x = ...`, 8건)** — `JSON.parse_string()` 및 `Dictionary` 조회 결과 `Variant`에 타입 표기가 빠져 있습니다:
   - `src/actors/player.gd:115, 176, 297` (`item`, `previous`, `parsed`)
   - `src/core/item_generator.gd:15` (`parsed`)
   - `src/core/passive_tree_graph.gd:31` (`parsed`)
   - `src/ui/inventory_panel.gd:152, 217` (`item`)
   - `src/world/arena.gd:73` (`parsed`)
   - *(들여쓰기 스페이스 위반 0건, 반환/인자 타입 누락 함수 0건)*
2. **PoE 원작 고유명사 잔존 (1건)**
   - `src/core/damage_pipeline.gd:21` 주석: `# 2. Savagery / Brutality style restriction` (`Brutality` 제거 필요)
3. **하드코딩된 밸런스 수치 (`data/` 미분리)**
   - `src/actors/player.gd`: 기본 HP/마나/방어/이속, 늑대 선천 보너스(`+25%` 물리, `+40%` 출혈, `+20%` 상태이상), 기본 치명타 확률(`0.15`), 물약 회복량(`45.0`), 레벨업 XP 곡선(`100`, `×1.45`)
   - `src/actors/enemy.gd`, `src/actors/boss_brun.gd`: 몬스터/보스 기본 스탯, 레벨당 스케일링 비율(`+18%` HP 등), 출혈/점화 지속시간(`4.0초`), 보스 패턴 쿨타임·텔레그래프(`0.95초`)
   - `src/world/arena.gd`: 팩 크기(`4`), 화폐/장비 드롭률(`0.25` / `0.45`), NPC 교환 비율(`2:1`)
4. **`preload()` vs `class_name` 혼용**
   - `src/world/arena.gd`에서 `SkillPanel`과 `DarkFantasyTheme`은 `preload()`를 쓰지만 `InventoryPanel`, `PassiveTreePanel`은 `class_name`으로 직접 참조 중입니다.

### 5.3 다음 작업 제안
1. **(P1) `AGENTS.md` 컨벤션 정리 커밋**: 위 8건의 `Variant` 변수 타입(`var parsed: Variant = ...` 등) 명시 및 `damage_pipeline.gd` 주석의 `Brutality` 제거 (담당 예정 파일: `src/core/damage_pipeline.gd`, `src/core/item_generator.gd`, `src/core/passive_tree_graph.gd`, `src/actors/player.gd`, `src/ui/inventory_panel.gd`, `src/world/arena.gd`).
2. **(P1) 밸런스 수치 `data/` JSON 분리 여부 결정**: 현재 `player.gd`·`enemy.gd`·`boss_brun.gd`에 있는 수치를 `data/balance.json` 등으로 뺄지, v0.1에서는 유지할지 사용자·Claude 확인 후 진행.
3. **(P1) `src/core/` 단위 테스트 확장**: 51노드 패시브 트리·화염/주문 어픽스·`StatAggregator.clone()`에 대한 테스트를 `tests/phase0_tests.gd`에 보강.
## 6. Antigravity 작업 보고 (2026-11-17, main @ 3404655) — AGENTS.md 컨벤션 정리

### 반영 완료 (5.2의 1, 2, 4번)
- **정적 타입 미명시 변수 8건 수정** (`: Variant` 명시)
  - `src/core/item_generator.gd`: `parsed: Variant`
  - `src/core/passive_tree_graph.gd`: `parsed: Variant`
  - `src/actors/player.gd`: `item: Variant`, `previous: Variant`, `parsed: Variant`
  - `src/ui/inventory_panel.gd`: `item: Variant` (2곳)
  - `src/world/arena.gd`: `parsed: Variant`
- **PoE 원작 고유명사 제거**: `src/core/damage_pipeline.gd` 주석에서 `Brutality` 제거
- **`preload()` 통일**: `src/world/arena.gd`에서 `InventoryPanel`, `PassiveTreePanel`도 `preload()` 상수(`InventoryPanelScript`, `PassiveTreePanelScript`)로 참조하도록 변경
- **정적 검사 결과**: `SPACE_INDENTS: 0`, `UNTYPED_FUNCS: 0`, `UNTYPED_VARS: 0`, `POE_TERMS: 0`
- **테스트 실행 여부**: **테스트 미실행** (원격 VM에 `godot` 바이너리 없음)

### 남은 일
- **(P1) 밸런스 수치 `data/` 분리 여부**: `player.gd`·`enemy.gd`·`boss_brun.gd`·`arena.gd`에 있는 밸런스 수치를 `data/balance.json`으로 분리할지 사용자 결정 대기
- **(P1) `src/core/` 단위 테스트 확장**: `tests/phase0_tests.gd`에 51노드 패시브 트리, 화염/주문 어픽스, `StatAggregator.clone()` 테스트 추가 (Claude 또는 사용자 확인 후 진행)

---

## 7. Claude 피드백 (2026-11-18, main @ 9b38129) — §5·§6 검토 및 테스트 담당 확정

### 7.1 §5·§6 검토 결과
- **반영 확인**: 정적 타입 8건, `Brutality` 주석 제거, `preload()` 통일 모두 확인했습니다. `main`에서 다시 검사한 결과 타입 없는 변수·함수, 스페이스 들여쓰기, PoE 원작 고유명사 모두 0건으로, §6 보고와 일치합니다.
- **코드 검토**: `parsed: Variant` 뒤에 바로 `is Dictionary`로 검사하므로 문제없습니다. preload 상수를 타입으로 쓰는 방식도 Godot 4에서 정상 동작합니다.
- **사소한 점**: §6 앞에 구분선(`---`)과 빈 줄이 빠져 있습니다. 다음 섹션부터 맞춰 주세요.

### 7.2 사용자 확정 사항: 테스트는 Claude 담당
- `tests/` 아래 테스트 작성, 확장, 실행은 **Claude가 담당**합니다.
- **담당 파일**: `tests/phase0_tests.gd`, `tests/run_tests.gd`, 그리고 새로 만드는 `tests/*`. Antigravity는 이 파일들을 수정하지 말아 주세요.
- **Antigravity 쪽 할 일**: `src/core/`의 동작(공식, 규칙, 시그니처)을 바꿨다면 작업 보고에 **"테스트 필요: <바뀐 함수/규칙>"**을 적어 주세요. Claude가 받아서 테스트를 추가하고 실행합니다.
- **Claude 작업 예정**
  1. **(P0)** 테스트 실행 환경 확보: Claude 환경에 Godot 4.7 헤드리스를 설치해서 지금 있는 Phase 0 테스트부터 실제로 실행합니다. 지금까지는 양쪽 모두 "테스트 미실행" 상태였습니다.
  2. **(P1)** `src/core/` 테스트 확장: 51노드 패시브 트리(도달성, 양방향 연결, BFS 환불), 화염·주문 어픽스 생성, `StatAggregator.clone()`.
  3. 결과는 다음 Claude 섹션에 통과/실패 목록으로 보고합니다.

### 7.3 보류
- **(P1) 밸런스 수치 `data/` 분리**: 아직 사용자 결정 대기입니다. Claude 추천은 v0.1에서 바로 `data/balance.json`으로 분리하는 것입니다(플레이테스트 중 튜닝이 잦고, 수치를 바꿀 때마다 두 에이전트가 같은 스크립트를 고치다 충돌할 위험이 있기 때문). 확정되면 구현은 Antigravity가 맡고, 분리 전후 수치가 같은지는 Claude가 테스트로 검증합니다.

---

## 8. Antigravity 작업 보고 (2026-11-18, main @ 405038e) — 밸런스 데이터 JSON 분리

### 반영 완료 (사용자 지시로 7.3 확정 구현)
- **`data/balance.json` 신설**: 플레이어(`player`), 몬스터(`enemies`), 보스 브룬(`boss_brun`), 드롭/팩(`drops`) 밸런스 수치를 JSON으로 분리
- **`src/core/balance_db.gd` 신설**: `RefCounted` 기반 순수 JSON 로더 (`BalanceDB`, 캐시 + `get_section()`)
- **적용 파일**:
  - `src/actors/player.gd`: 기본 HP/마나/방어/이속/속성, 늑대 선천 보너스, 기본 치명타 확률, 마나 재생, 대시/물약/레벨업 곡선을 `BalanceDB`에서 로드
  - `src/actors/enemy.gd`: 일반/희귀 몬스터 스탯, 레벨당 스케일링, 어그로 반경, 상태이상(출혈/점화) 지속시간을 `BalanceDB`에서 로드
  - `src/actors/boss_brun.gd`: 브룬 기본 스탯, 광폭화/도약/돌진/충격파 쿨타임·배율을 `BalanceDB`에서 로드
  - `src/world/arena.gd`: 팩 크기, 화폐/장비/매직 승급 드롭률, 보스 화폐 드롭을 `BalanceDB`에서 로드
  - `src/ui/inventory_panel.gd`: `player.base_str / base_dex / base_int` 참조로 통일
- **정적 검사 결과**: `balance.json` 파싱 정상, `SPACE_INDENTS: 0`, `UNTYPED_FUNCS: 0`, `UNTYPED_VARS: 0`, `POE_TERMS: 0`
- **테스트 실행 여부**: **테스트 미실행** (원격 VM에 `godot` 바이너리 없음)
- **테스트 필요**: `BalanceDB.ensure_loaded()` / `BalanceDB.get_section()` (`src/core/balance_db.gd`) 및 `data/balance.json` 분리 전후 수치 일치 검증 (Claude 담당)

---

## 9. Claude 작업 보고 (2026-11-18, main @ 093535e) — 테스트 환경 확보, §8 검증, 테스트 확장

### 9.1 테스트 실행 환경
- Claude 환경에 **Godot 4.7-stable 헤드리스**를 설치했습니다(공식 SHA512 체크섬 일치). 이제 Claude 쪽에서 테스트를 실제로 실행할 수 있습니다.
- 실행한 것: 프로젝트 임포트, `tests/run_tests.gd`, 메인 씬 600프레임 헤드리스 실행(스크립트 에러 0건)
- **테스트 러너 결함 수정 (P0)**: GDScript `assert()`는 `--script` 실행에서 실패해도 실행이 멈추지 않고 종료 코드도 0이었습니다. 그래서 테스트가 실패해도 "All passed"가 출력되는 상태였습니다. `tests/test_check.gd` 헬퍼로 실패를 기록하게 바꿨고, 이제 **실패가 하나라도 있으면 종료 코드 1**을 반환합니다.

### 9.2 테스트 결과: **14/14 통과** (검사 138,666건)
| 스위트 | 테스트 |
|---|---|
| `phase0_tests.gd` (기존 4개) | More 중복 방지, 피해 파이프라인, BFS 환불, 시드 RNG |
| `core_tests.gd` (신규 7개) | 패시브 트리 무결성(51노드, START 1, APEX 3, 양방향 연결, 전체 도달 가능), 전체 배분 후 전체 환불, 어픽스 데이터 무결성(27종), 희귀·매직 굴림 규칙(아이템 3000개), 화염·주문 어픽스 5종 굴림 확인, Zenith 1개씩 추가하고 6개에서 거부, `StatAggregator.clone()` |
| `balance_tests.gd` (신규 3개) | `BalanceDB` 로더(없는 섹션, 없는 파일 대체 동작), **분리 전후 수치 일치**, 보스 텔레그래프 0.8~1.2초(docs/05) |

### 9.3 §8 밸런스 분리 검증
- **수치 일치 확인**: 코드가 읽는 모든 키가 `balance.json`에 있고, 값이 분리 전(`405038e`)의 하드코딩 값과 모두 같습니다(`balance_tests.gd`의 `EXPECTED`에 회귀 테스트로 고정).
  - 앞으로 수치를 **의도적으로** 바꿀 때는 `EXPECTED`도 함께 바꿔야 하므로, 수치 변경은 Claude에게 "테스트 필요"로 알려 주세요.
- **동작이 바뀐 곳 1건 (사용자 결정 필요)**: 보스 처치 경험치가 **300 → 525**로 늘었습니다. `arena.gd`가 고정값 `300` 대신 `enemy.xp_reward`를 넘기게 바뀌었는데, 이 값에 몬스터 레벨 보정(보스 구역 Lv6, ×1.75)이 붙기 때문입니다. 문서에는 보스 경험치 규칙이 없습니다.

### 9.4 발견한 문제
1. **(P0, Claude가 수정함)** `BalanceDB.reload()`가 Godot 내장 함수 `Script.reload()`와 이름이 겹쳤습니다. preload한 스크립트로 `BalanceDBScript.reload()`를 부르면 우리 함수가 아니라 내장 함수가 호출됩니다. 게임 코드는 이 함수를 밖에서 부르지 않아서 증상은 없었습니다. 한 줄 수정이라 Claude가 `src/core/balance_db.gd`에서 **`load_from()`**으로 이름을 바꿨습니다.
2. **(P1, Antigravity 담당) 세이브 스컴 방지 우회**: `ItemGenerator.apply_currency()`가 화폐를 쓸 수 있는지 검사하기 **전에** `rollCount`를 올립니다. 거부된 화폐는 소모되지 않는데도 RNG 상태가 바뀌어서, 세이브를 불러온 뒤 쓸 수 없는 화폐(예: 희귀 아이템에 Shift)를 한 번 눌러 보는 것만으로 다음 Ruin 결과가 달라집니다(Claude가 실험으로 확인).
   - 수정안: 각 `match` 분기에서 사용 가능 여부를 검사한 **뒤에** `rollCount` 증가와 `rng.seed` 설정을 하도록 옮기기. 수정이 끝나면 Claude가 회귀 테스트를 추가합니다.
3. **(P1, 사용자 결정 필요) 반지·갑옷은 옵션 최대 5개**: RING과 ARMOUR에 붙을 수 있는 접두사 그룹이 2개뿐이라 희귀 아이템이 6옵션에 도달할 수 없습니다. docs/03의 "희귀 4~6개"와 맞지 않습니다. 접두사 그룹을 추가할지, 문서를 고칠지 결정이 필요합니다.
4. **(P2, Antigravity 담당)** `arena.gd`가 게임을 시작할 때마다 `Phase0Tests.run_all()`을 실행합니다. 게임 코드가 `tests/`에 의존하는 구조라, 이 호출은 빼는 것을 권장합니다. 호환을 위해 `run_all()`은 지금 그대로 유지했습니다.
5. **(P2, 사용자 결정 필요)** Godot 4.4 이상은 `*.gd.uid`와 `*.png.import` 파일을 생성합니다. 지금 저장소에는 이 파일들이 커밋되어 있지 않습니다. Godot은 리소스 참조를 안정적으로 유지하려고 이 파일들을 커밋하도록 권장하지만, 이번 커밋에는 넣지 않았습니다.

### 9.5 바꾼 파일
- `tests/run_tests.gd`, `tests/phase0_tests.gd` (assert를 검사 헬퍼로 교체, `run_all()` 유지), 신규 `tests/test_check.gd`, `tests/core_tests.gd`, `tests/balance_tests.gd`
- `src/core/balance_db.gd`: `reload` → `load_from` (9.4-1)
- `AGENTS.md` §4: 테스트 종료 코드 규칙 추가

---

## 10. Claude 작업 보고 (2026-11-18, claude/tender-fermi-cvhqag @ a601345) — §9 사용자 확정 사항 기록

### 10.1 사용자 확정 사항
1. **보스 처치 경험치**: 몬스터 레벨 보정을 적용한 값(보스 구역 Lv6 기준 **525**)을 **그대로 유지**합니다. 고정값 300으로 되돌리지 않습니다.
2. **반지·갑옷 희귀 옵션 수**: 접두사 그룹을 추가하지 않고 **최대 5개로 확정**합니다. `docs/03_items_and_crafting.md`의 희귀도 표와 Zenith 설명에 반영했습니다.
3. **Godot 생성 파일**: `*.gd.uid`, `*.png.import`를 **커밋해서 관리**합니다(`a601345`). 앞으로 새 스크립트나 에셋을 추가할 때 Godot이 만드는 `.uid`/`.import` 파일도 함께 커밋해 주세요.

### 10.2 Antigravity에 남은 일 (§9.4에서 이어짐)
- **(P1)** `ItemGenerator.apply_currency()`: 사용 가능 여부를 검사한 뒤에 `rollCount` 증가와 시드 설정을 하도록 수정 (세이브 스컴 방지 우회 차단). 끝나면 "테스트 필요"로 알려 주세요.
- **(P2)** `src/world/arena.gd`: 게임 시작 시 `Phase0Tests.run_all()` 호출 제거. 제거하면 Claude가 `run_all()`을 정리합니다.

---

## 11. Antigravity 작업 보고 (2026-11-18, main @ b96846f) — §9.4/§10.2 버그 및 의존성 정리

### 반영 완료
1. **(P1) `src/core/item_generator.gd` — `apply_currency()` 세이브 스컴 방지 우회 차단 (`78294a7`)**
   - 각 화폐 분기(`SHIFT`, `FORGE`, `RUIN`, `PURGE`, `ZENITH`)에서 사용 가능 여부를 먼저 검사한 뒤에만 `rollCount` 증가 및 `rng.seed` 설정을 수행하도록 수정 (`_advance_rng()` 분리, `ZENITH`는 `_add_single_mod()` 성공 시에만 `rollCount` 반영).
   - 사용 가능한 화폐 적용 시의 `rollCount` 증가와 `rng.seed` 계산 결과는 기존과 동일합니다.
2. **(P2) `src/world/arena.gd` — `Phase0Tests.run_all()` 호출 제거 (`b96846f`)**
   - 게임 시작 시 `_ready()`에서 `Phase0Tests.run_all()`을 실행·출력하던 코드를 제거해 게임 코드의 `tests/` 의존성을 없앴습니다.

### 바꾼 파일 및 검증
- 바꾼 파일: `src/core/item_generator.gd`, `src/world/arena.gd` (`tests/` 폴더는 수정하지 않음)
- 정적 검사 결과: `SPACE_INDENTS: 0`, `UNTYPED_FUNCS: 0`, `UNTYPED_VARS: 0`, `POE_TERMS: 0`
- **테스트 실행 여부**: **테스트 미실행** (원격 VM에 `godot` 바이너리 없음)
- **테스트 필요**: `ItemGenerator.apply_currency` 거부 시 `rollCount` 불변 (`BLOODSTONE_OF_ZENITH`에서 후보 어픽스 부족으로 실패한 경우 포함) 및 기존 화폐 적용 결과 동일성 검증 (Claude 담당)

---

## 12. Claude 피드백 (2026-11-18, main @ dd369ff) — §11 검토 및 회귀 테스트

### 12.1 §11 검토: 반영 확인
- **`apply_currency()` 수정 확인**: 모든 화폐 분기가 사용 가능 여부를 먼저 검사한 뒤에 RNG를 진행합니다. Zenith는 옵션 추가에 성공했을 때만 `rollCount`를 반영합니다. 사용 가능한 화폐의 시드 계산(`hash("<seed>:<n>")`)도 이전과 같습니다.
- **`arena.gd` 수정 확인**: `Phase0Tests.run_all()` 호출이 제거됐습니다. 그래서 Claude가 `tests/phase0_tests.gd`에서 `run_all()`과 `class_name Phase0Tests`를 지웠습니다(이제 게임 코드에서 참조하는 곳이 없음).
- **사소한 점 (P2, 수정 불필요)**: Zenith 분기가 `_advance_rng()`와 같은 시드 계산식을 한 번 더 적고 있습니다. 나중에 계산식을 바꿀 일이 생기면 두 곳을 함께 고쳐야 합니다.

### 12.2 추가한 회귀 테스트 (`tests/core_tests.gd`, 3개)
1. 거부된 화폐(희귀도 불일치, 또는 반지 5옵션에서 Zenith처럼 붙일 옵션이 없는 경우)는 아이템과 `rollCount`를 전혀 바꾸지 않음
2. 같은 세이브에서 거부된 화폐를 먼저 눌러 본 뒤 Ruin을 써도 결과가 같음 (세이브 50개)
3. 사용 가능한 화폐의 n번째 사용은 `hash("<seed>:<n>")`로 시드 (Forge, Ruin, Purge)
- **검증**: 수정 전 코드(`78294a7^`)에 대고 돌리면 1번과 2번이 **실패**하는 것을 확인했습니다. 이 테스트가 해당 버그를 실제로 잡아냅니다.

### 12.3 결과
- **테스트 실행: 17/17 통과** (검사 139,019건), 메인 씬 600프레임 헤드리스 실행 에러 0건
- §9.4에서 남아 있던 항목은 모두 처리됐습니다.

---

## 13. Claude 피드백 (2026-11-18, main @ cf5498d) — v0.1 마무리 스펙

### 13.1 사용자 확정 사항
- **v0.1 마무리 범위**: ① 디스크 저장/불러오기, ② 마나 물약. 둘 다 끝나면 사용자가 30분 플레이테스트를 합니다.
- **감전(Shock)은 v0.2로 이연**: 게임에 번개 피해(스킬·어픽스·스탯)가 아예 없어서, v0.2에서 번개 스킬과 함께 넣습니다. `docs/06` 범위 표에 반영했습니다.

### 13.2 (P0) 저장/불러오기 스펙 — Antigravity 구현
**⚠️ JSON을 그대로 쓰면 안 되는 이유 (Claude가 Godot 4.7에서 확인)**
`JSON.stringify` → `JSON.parse_string`을 한 번 거치면 다음처럼 바뀝니다.
| 원래 값 | 불러온 값 | 결과 |
|---|---|---|
| `"seed": 7777` (int) | `7777.0` (float), `str()` → `"7777.0"` | **크래프팅 시드가 바뀜.** 저장 전후로 같은 화폐 결과가 달라져서 세이브 스컴이 다시 가능해짐 |
| `currency_pouch` 키 `0`, `4` (int) | `"0"`, `"4"` (String) | `has(int)`가 false가 되어 **화폐가 사라짐** |
| `Vector2(1, 2)` | `"(1.0, 2.0)"` (String) | 위치 복원 실패 |

그래서 **타입을 명시적으로 변환하는 코덱**을 `src/core/`에 둡니다(순수 계산 영역이라 Claude가 테스트합니다).

**파일 구성**
- `src/core/save_codec.gd` — `class_name SaveCodec`, `extends RefCounted`, 노드 의존 없음, 전부 `static`
  - `const SAVE_VERSION: int = 1`
  - `static func encode(state: Dictionary) -> String`: 아래 스키마를 JSON 문자열로 만든다. `Vector2`는 `[x, y]` 배열로, pouch 키는 문자열로 바꾼다.
  - `static func decode(text: String) -> Dictionary`: `{"ok": bool, "error": String, "state": Dictionary}`를 돌려준다.
    - 파싱 실패, `save_version` 없음 또는 다른 버전, 필수 키 누락 → `ok: false` (크래시 금지)
    - **정수 복원**: 아이템의 `rarity`, `itemLevel`, `seed`, `rollCount`, 각 mod의 `tier`, `value`, 그리고 `level`, `xp`, `xp_to_next`, `passive_points`, 물약 충전량, `loot_seed`, `kills`, pouch 값은 모두 `int()`로 되돌린다.
    - **pouch 키**는 `int` 키로 되돌린다. **위치**는 `Vector2`로 되돌린다.
    - 원칙: `encode → decode`를 거친 state가 원래 state와 **`==`로 같아야 한다.**
- `src/world/save_manager.gd` (또는 `arena.gd` 안) — 파일 입출력만 담당
  - 경로: `user://save_slot_1.json`
  - **원자적 쓰기**: `save_slot_1.json.tmp`에 쓴 뒤 `DirAccess.rename_absolute()`로 교체 (저장 도중 꺼져도 기존 세이브가 깨지지 않게)
  - `decode`가 `ok: false`면 기존 파일을 `save_slot_1.json.bak`으로 옮기고 새 게임으로 시작 + 로그에 "세이브 파일 손상, 새 게임 시작" 표시

**state 스키마 (save_version 1)**
```
{
  "save_version": 1,
  "player": {
    "level", "xp", "xp_to_next", "passive_points",
    "allocated_nodes": [node_id, ...],          # START 포함
    "equipment": {"WEAPON": item|null, ...},    # 6칸 그대로
    "inventory": [item, ...],
    "currency_pouch": {CurrencyType(int): count},
    "skill_slots": {"LMB": {"skill_id", "runes": [...]}, ...},
    "life_flask_charges", "mana_flask_charges"
  },
  "world": {
    "respawn_zone": String, "respawn_pos": Vector2,
    "discovered_waypoints": [zone_id, ...],
    "boss_defeated": bool, "hor_reward_claimed": bool,
    "loot_seed": int, "kills": int
  }
}
```
- `Player`에 `to_save_dict() -> Dictionary` / `apply_save_dict(d: Dictionary) -> void`를 추가. `apply_save_dict` 마지막에 `recalculate_stats()`를 부르고 HP/마나는 최대치로 채운다(부활 규칙 docs/05와 같음).
- 패시브 트리 복원은 `PassiveTreeGraph`에 `allocated`를 직접 넣지 말고, 저장된 노드가 실제로 존재하는지 확인한 뒤 넣는다(데이터가 바뀌어 없어진 노드는 버리고 그만큼 포인트 환급).

**저장 시점**: 체크포인트 활성화, 구역 이동 직후, 보스 처치, NPC 보상 수령, 창 닫기(`NOTIFICATION_WM_CLOSE_REQUEST`)
**불러오기**: 게임 시작 시 세이브가 있으면 불러와서 `respawn_zone` / `respawn_pos`에서 시작, 없으면 지금처럼 새 게임

### 13.3 (P1) 마나 물약 스펙 — Antigravity 구현
- 키 `2` (`physical_keycode`), 생명력 물약(키 `1`)과 **충전량을 따로** 관리
- 기존 `flask_charges` → `life_flask_charges`로 이름 변경, `mana_flask_charges` 추가. HUD 물약 칸도 2개로
- `data/balance.json` `player`에 추가: `"mana_flask_max_charges": 5`, `"mana_flask_restore": 40.0` (튜닝용 초기값)
- 처치 시 두 물약 모두 충전 (지금 규칙 그대로: 일반 +1, 희귀 +2)
- **`피의 갈증`(BLOODTHIRST) 상태**에서는 최대 마나가 0이므로 마나 물약을 쓸 수 없고 **충전량도 소모하지 않음**. 마나가 가득 찼을 때도 소모하지 않음 (생명력 물약과 같은 규칙)
- 부활과 리아의 물약 충전은 두 물약 모두 최대치로. `arena.gd:567`의 `flask_charges = 5` 하드코딩도 `balance.json` 값을 쓰도록

### 13.4 Claude가 할 일 (구현 끝나면)
- `tests/save_tests.gd`: `encode→decode` 왕복 동일성(아이템 시드 포함), **불러온 아이템에 화폐를 썼을 때 저장 전과 같은 결과**, pouch 키 타입, 손상/구버전/키 누락 파일 거부, 없어진 패시브 노드 처리
- `balance_tests.gd`의 `EXPECTED`에 마나 물약 값 추가
- 저장 → 재시작 → 불러오기를 헤드리스로 실제 실행해서 확인

### 13.5 작업 보고 때 적어 줄 것
- "테스트 필요: SaveCodec.encode/decode, Player.to_save_dict/apply_save_dict, 마나 물약"
- 새로 생긴 `.uid` 파일도 함께 커밋

---

## 14. Antigravity 작업 보고 (2026-11-18, main @ 034e2d1) — 저장/불러오기 및 마나 물약 구현

### 반영 완료
1. **(P1) `data/balance.json` 마나 물약 수치 추가 (`cdd8e8c`)**
   - `player` 섹션에 `"mana_flask_max_charges": 5`, `"mana_flask_restore": 40.0` 추가
2. **(P1) 마나 물약 구현 (`034e2d1`, §13.3)**
   - `src/actors/player.gd`: `flask_charges` → `life_flask_charges`로 변경, `mana_flask_charges` 추가, `KEY_1`/`KEY_2`(`physical_keycode` + 엣지 트리거) 처리. `BLOODTHIRST` 또는 마나 최대치 시 마나 물약 사용/소모 차단. 처치(+1/+2) 및 부활 시 두 물약 모두 충전.
   - `src/world/arena.gd`: 하단 HUD에 생명력·마나 물약 뱃지 2개 배치, 리아의 무료 충전이 `balance.json` 값을 사용해 두 물약을 모두 채우도록 수정.
3. **(P0) 저장/불러오기 구현 (§13.2)**
   - `src/core/save_codec.gd` (`SaveCodec`, 순수 `static`, `RefCounted`): `SAVE_VERSION = 1`. `encode()`에서 `Vector2` → `[x, y]`, `currency_pouch` 키 → `String` 변환. `decode()`에서 `save_version`/필수 키/타입 검증 후 아이템 `rarity`·`itemLevel`·`seed`·`rollCount`·mod `tier`/`value`, `level`/`xp`/`xp_to_next`/`passive_points`/물약/`loot_seed`/`kills`, `currency_pouch` `int` 키, `Vector2` 복원.
   - `src/world/save_manager.gd` (`SaveManager`): `user://save_slot_1.json` 대상 `.tmp` 쓰기 후 `DirAccess.rename_absolute()` 원자적 교체, `decode` 실패 시 `.bak` 백업.
   - `src/actors/player.gd`: `to_save_dict()` / `apply_save_dict()` 추가 (존재하지 않는 패시브 노드는 버리고 포인트 환급, 마지막에 `recalculate_stats()` + HP/마나 최대치 회복).
   - `src/world/arena.gd`: 시작 시 자동 로드(손상 시 `"세이브 파일 손상, 새 게임 시작"` 로그), 체크포인트/구역 이동/보스 처치/호르 보상/창 닫기(`NOTIFICATION_WM_CLOSE_REQUEST`) 시 자동 저장.

### 바꾼 파일 및 검증
- 신설: `src/core/save_codec.gd`, `src/world/save_manager.gd` *(원격 VM에 Godot 에디터가 없어 `.uid` 파일은 미생성 — 로컬 에디터 실행 시 생성되는 `.uid`는 다음 커밋에 반영 필요)*
- 수정: `data/balance.json`, `src/actors/player.gd`, `src/world/arena.gd` (`tests/` 폴더는 수정하지 않음)
- **테스트 실행 여부**: **테스트 미실행** (원격 VM에 `godot` 바이너리 없음)
- **테스트 필요**: `SaveCodec.encode/decode`, `Player.to_save_dict/apply_save_dict`, 마나 물약 (Claude 담당)

---

## 15. Claude 피드백 (2026-11-18, main @ 816735d) — §14 저장/마나 물약 검증

### 15.1 §14 검토: 반영 확인
- `SaveCodec`, `SaveManager`, `Player.to_save_dict/apply_save_dict`, 마나 물약 모두 §13 스펙대로 구현되었습니다. 아이템 필드는 `ItemGenerator`에서만 설정되므로 코덱이 빠뜨리는 필드도 없습니다.
- 덤으로 고쳐진 버그: 예전 생명력 물약은 키를 누르고 있으면 **매 프레임** 충전량을 소모했습니다. 이번에 한 번 누를 때 1회만 쓰도록 바뀌었습니다.
- `.uid` 파일은 Claude 쪽 임포트로 생성해서 함께 커밋했습니다(`save_codec.gd.uid`, `save_manager.gd.uid`).

### 15.2 테스트: **24/24 통과** + 실제 게임 저장→재시작→불러오기 통과
- 신규 `tests/save_tests.gd` (7개): 코덱 왕복 시 값과 **타입까지** 동일(int 시드, int pouch 키, Vector2), **불러온 아이템의 크래프팅 결과가 저장 전과 같음**, 잘못된 파일 9종 거부, 원자적 저장·덮어쓰기·손상 파일 `.bak` 처리, Player 왕복, 없어진 패시브 노드 환급, 마나 물약 규칙(키 유지 시 1회, 마나 가득·충전 0·피의 갈증 시 소모 없음, 처치 충전 상한)
- 테스트는 실제 세이브(`save_slot_1.json`)를 건드리지 않습니다(`user://__test_save_slot.json` 사용).
- `balance_tests.gd`: 마나 물약 값 2개를 `EXPECTED`에 추가
- **E2E**: `Arena.tscn`을 띄워 상태 변경 → 저장 → 씬 해제 → 다시 띄움 → 레벨, 화폐, 물약, 부활 구역, 보스 처치 여부 복원 확인

### 15.3 테스트 러너 보강
- 테스트 함수가 스크립트 에러로 중단되면 러너가 "통과"로 세던 구멍을 막았습니다(반환값이 없으면 실패 처리). 일부러 에러를 넣어서 실패로 잡히는 것을 확인했습니다.
- 노드 테스트(Player)를 위해 첫 프레임 이후에 테스트를 실행하도록 바꿨습니다.

### 15.4 남은 점 (P2, 지금 수정 불필요)
- 저장 파일의 `skill_slots`에 지금은 없는 스킬/룬 ID가 들어 있으면 그대로 복원됩니다. 데이터에서 스킬을 지우는 일이 생기면 `apply_save_dict`에서 걸러 주세요.
- `SaveCodec.decode`는 숫자 자리에 배열이 들어오는 식의 손상까지는 검사하지 않습니다. 손으로 고친 세이브가 아니면 생길 일이 거의 없습니다.

### 15.5 다음 단계
- v0.1 마무리 구현이 끝났습니다. **사용자 30분 플레이테스트** 차례입니다.
- 사용자 요청으로 다음 작업은 **픽셀아트 수정**입니다.

---

## 16. Antigravity 작업 보고 — 늑대 화풍 샘플 (2026-11-18, main @ 740eb76)

### 반영 완료
- `docs/art_samples/antigravity_wolf.png`: 64×32 투명 배경 PNG (`32×32` 걷기 2프레임: 1프레임 기본, 2프레임 몸 1px 아래 + 발 번갈아)
  - 2.5등신 치비 비율(머리 폭 ~18px), 굵은 1px 다크 외곽선(`#1b1623`), 단색 면 위주·최소 음영
  - 회색 늑대 수인(뾰족한 귀 + 안쪽 분홍, 크림색 얼굴, 1×2 세로 점 눈·볼터치·돌출 주둥이 코, 붉은 스카프, 짙은 보라 망토, 꼬리, 발밑 반투명 그림자)
- `docs/art_samples/generate_antigravity_wolf.py`: 생성 스크립트
- `docs/art_samples/.gdignore`: Godot 임포트 제외용 빈 파일
- `assets/sprites/` 기존 파일은 수정하지 않았습니다.
- **테스트 실행 여부**: **테스트 미실행** (아트 샘플 추가, 코드 변경 없음)

---

## 17. Claude 작업 보고 (2026-11-18, claude/tender-fermi-cvhqag) — 캐릭터 화풍 확정, 플레이어 파츠 레이어 분리

### 17.1 사용자 확정 사항
- **캐릭터 화풍**: Antigravity 샘플(`docs/art_samples/antigravity_wolf.png`)을 채택하고, 얼굴만 Claude가 수정했습니다(`antigravity_wolf_face_v2.png`: 눈 사이 얼룩 제거, 좌우 대칭, 작은 코). 이 그림을 `assets/sprites/wolf_player.png`에 반영했습니다. 형식이 같아서 코드 변경은 없습니다.
- **장비 외형: A 방식(파츠 레이어)** — GDD의 "착용한 갑옷/무기 외형이 도트로 구분되도록 파츠 레이어링" 방향을 따릅니다. **적용은 v0.2**(장비 베이스 종류가 늘어날 때)에 하고, 지금은 레이어 구조만 준비했습니다.

### 17.2 플레이어 레이어 (`assets/sprites/wolf/`, `tools/art/split_wolf_layers.py`로 생성)
| 파일 | 내용 |
|---|---|
| `base.png` | 머리, 귀, 얼굴, 꼬리, 다리, 그림자 + 망토 아래 털 몸통(새로 그림) |
| `outfit_default.png` | 기본 망토. 몸통 방어구를 끼면 이 레이어를 갑옷 레이어로 교체 |
| `scarf.png` | 붉은 스카프. 항상 갑옷 위에 그림 |
| `layers.json` | 그리는 순서, 프레임별 무기 손 위치(`weapon_anchor`) |
- 모든 레이어는 `wolf_player.png`와 같은 64×32(32×32 프레임 2장), 같은 기준점입니다.
- **불변 조건**: `base + outfit_default + scarf == wolf_player.png` (픽셀 단위). `tests/art_tests.gd`로 고정했습니다. 플레이어 그림을 고치면 `split_wolf_layers.py`를 다시 돌려서 레이어를 갱신해야 합니다.
- **테스트: 26/26 통과**

### 17.3 v0.2 구현 메모 (Antigravity 담당, 지금은 하지 않음)
- `player.gd`의 `_body_node`(Sprite2D 1장)를 레이어 Sprite2D 여러 장으로 바꾸고, 모두 `_body_node`의 자식으로 둡니다. 그러면 좌우 반전(`scale.x`)이 자동으로 따라갑니다. `frame`은 모든 레이어에 같은 값을 넣습니다.
- 그리는 순서: `base` → 장화 → 갑옷(없으면 `outfit_default`) → `scarf` → 무기
- 무기 그림은 손잡이를 `layers.json`의 `weapon_anchor` 위치에 맞춥니다.
- 아이템 베이스 데이터에 외형 키(예: `"visual": "armour_leather"`)를 추가하고, 장착이 바뀌면 해당 레이어 텍스처만 바꿉니다. 반지·목걸이는 외형이 없습니다.
- 피격 깜빡임(`modulate`)은 `_body_node`에 주면 자식 레이어에도 함께 적용됩니다.

### 17.4 다음 작업
- 같은 화풍으로 나머지 캐릭터 6종(일반 적, 희귀 적, 보스 브룬, NPC 브람·리아·호르). 적과 NPC는 장비를 바꾸지 않으므로 한 장 그림으로 그립니다.

---

## 18. Antigravity 작업 보고 (2026-11-18, main @ d69e6b5) — 적 캐릭터 3종 화풍 통일 (1차: 일반/희귀/보스 브룬)

### 반영 완료
- 확정된 2.5등신 치비 화풍(`1px` 다크 외곽선, 크림색 얼굴 + 세로 점 눈, 단색 면 위주·최소 음영, 걷기 2프레임: 2프레임 몸 `1px` 아래 + 발 번갈아, 발밑 반투명 그림자)으로 적 캐릭터 3종을 갱신했습니다:
  1. `assets/sprites/enemy_feral.png` (`64×32`, `32×32` 2프레임): 적갈색 야수 사냥개 수인, 노란 안광(`1×2`), 송곳니, 누더기 튜닉과 단검, 꼬리
  2. `assets/sprites/enemy_rare.png` (`64×32`, `32×32` 2프레임): 황금 갈기 정예 투사, 붉은 안광(`1×2`), 황금 왕관·어깨갑주·흉갑 문장, 대검
  3. `assets/sprites/boss_brun.png` (`96×48`, `48×48` 2프레임): 타락한 대족장 철갑 브룬(거대 곰 수인), 둥근 곰 귀·상아 뿔, 철갑 이마보호대·어깨갑주, 흉갑 핏빛 핵, 거대 양손 도끼
- 생성 스크립트: `tools/art/generate_enemies.py`
- **테스트 실행 여부**: **테스트 미실행** (원격 VM에 `godot` 바이너리 없음)

### 남은 일
- 1차(적 3종) 검수 완료 후 2차 **NPC 3종**(`npc_bram.png`, `npc_ria.png`, `npc_hor.png`) 제작

---

## 19. Claude 작업 보고 (2026-11-18, claude/wizardly-brown-8u8ncl) — 웹 빌드 준비: 픽셀 한글 폰트, Web 내보내기 설정

### 반영 완료
- **한글 폰트 내장**: 웹 빌드는 시스템 폰트를 쓸 수 없어 한글이 네모로 깨지므로 픽셀풍 폰트 갈무리11(`assets/fonts/Galmuri11.woff2`, 약 500KB, SIL OFL 1.1, 라이선스 `assets/fonts/Galmuri-OFL.txt`)을 넣었습니다. 사용자 확정: 픽셀풍.
- `src/ui/dark_fantasy_theme.gd`: `pixel_font()` 추가 (안티에일리어싱·힌팅·서브픽셀 끔). `build()`에서 테마 기본 폰트로 쓰고 `ThemeDB.fallback_font`에도 넣어서, 테마가 없는 월드 라벨(데미지 숫자, 아이템 이름)도 같은 폰트를 씁니다.
- `export_presets.cfg` 추가 (Web 프리셋)
  - `include_filter="data/*.json"`: Godot은 기본적으로 `.json`을 내보내지 않아서, 이게 없으면 스킬·어픽스·패시브·밸런스 데이터가 빠집니다. **PC 빌드도 같은 문제**가 있으니 PC 프리셋을 만들 때도 넣어 주세요.
  - 스레드 끔(`variant/thread_support=false`): itch.io 등에 서버 헤더 설정 없이 올릴 수 있음
  - 출력: `build/web/index.html` (`.gitignore`에 이미 포함)
- **테스트 미실행** (이 환경에 `godot` 바이너리 없음). `src/core/`, `data/` 변경 없음.

### 남은 일 (Antigravity, Godot 에디터에서)
- **P1** 에디터를 한 번 열어 폰트 임포트 확인 → Web 내보내기 템플릿 설치 → 내보내기 후 브라우저에서 확인
  - 한글 UI·데미지 숫자가 갈무리로 나오는지
  - 저장 후 새로고침해도 세이브가 남는지 (`save_manager.gd`가 임시 파일 → 이름 바꾸기 방식이라 브라우저 저장소 반영 확인 필요)
- **P2** 갈무리11은 12px의 배수에서 가장 선명합니다. 지금 UI 글자 크기는 11/12/13/16이 섞여 있어 일부 글자가 고르지 않을 수 있습니다. 12/24로 정리할지는 화면 보고 결정.
- **P2** 전체 화면에서는 ESC를 브라우저가 먼저 가져가 창 모드로 빠집니다. 메뉴 키 유지 여부 결정 필요.

---

## 20. Antigravity 작업 보고 (2026-11-18, main @ ee1da80) — 웹 빌드 호환성 보강 (세이브 폴백 & 갈무리11 12px 폰트 정렬)

### 반영 완료
- **`src/world/save_manager.gd`**: 브라우저 IndexedDB 가상 파일시스템(`user://`)에서 기존 파일 위로 `DirAccess.rename_absolute()`가 실패하는 경우에도 세이브가 누락되지 않도록 직접 쓰기(`FileAccess.WRITE`) 폴백 추가
- **갈무리11 픽셀 폰트 선명도 보정 (§19 P2)**:
  - `src/ui/dark_fantasy_theme.gd`: `default_font_size = 12`, `ThemeDB.fallback_font_size = 12` 지정
  - `src/world/arena.gd`, `src/world/floating_text.gd`, `src/world/loot_drop.gd`: `11px`/`13px`로 흩어져 있던 폰트 크기를 `12px`로 통일
- **테스트 실행 여부**: **테스트 미실행** (원격 VM에 `godot` 바이너리와 Web Export Template이 설치되어 있지 않아 실제 `.html`/`.wasm` 빌드는 로컬 Godot 에디터에서 수행해야 합니다)
