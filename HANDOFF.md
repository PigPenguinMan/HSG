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
