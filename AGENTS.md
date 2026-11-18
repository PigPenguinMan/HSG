# HSG 공동 작업 규칙 (Antigravity · Claude 공용)

이 파일은 이 저장소에서 작업하는 모든 AI 에이전트(Antigravity, Claude Code 등)가 따르는 공용 규칙입니다.
Claude Code는 `CLAUDE.md`를 통해 이 파일을 읽습니다. 규칙을 바꿀 때는 **이 파일만** 수정하세요.

---

## 1. 프로젝트 개요
- **게임**: Bloodmoon Wilds (HSG). 2D 픽셀아트 다크 판타지 수인 핵 앤 슬래시 ARPG (PoE1 스타일 시스템, 자체 IP)
- **엔진**: Godot 4.7, GDScript, GL Compatibility 렌더러
- **메인 씬**: `res://scenes/Arena.tscn`
- **현재 단계**: v0.1 MVP (범위는 `docs/06_mvp_v0.1_scope.md`가 기준)

## 2. 폴더 구조
| 경로 | 용도 | 규칙 |
|---|---|---|
| `docs/` | 기획 문서 (GDD, 01~06) | 게임 규칙의 **단일 기준**. 코드와 문서가 다르면 문서를 먼저 고치거나 사용자에게 확인 |
| `data/` | JSON 데이터 (스킬, 어픽스, 패시브 트리, 구역) | 밸런스 수치는 코드에 하드코딩하지 말고 여기에 둔다 |
| `src/core/` | 순수 계산 라이브러리 (스탯, 피해, 패시브 그래프, 아이템 생성) | **노드/씬 의존 금지** (`RefCounted` 기반). 반드시 단위 테스트 동반 |
| `src/actors/` | 플레이어, 적, 보스, 투사체 | 계산은 `src/core/`에 위임 |
| `src/world/` | 구역, 드롭, 이펙트 | |
| `src/ui/` | UI 패널, 테마 | UI 텍스트는 한국어 |
| `scenes/` | `.tscn` 씬 | |
| `assets/sprites/` | 픽셀아트 (32×32 / 48×48) | 텍스처 필터는 Nearest 유지 |
| `tests/` | 헤드리스 단위 테스트 | |

## 3. 코딩 컨벤션 (GDScript)
- **들여쓰기는 탭**. 스페이스 들여쓰기 금지
- **정적 타입 필수**: 변수, 인자, 반환값에 타입 명시 (`var hp: float = 0.0`, `func f(x: int) -> void`)
  - Dictionary/Array에서 꺼낸 Variant 값은 명시 타입으로 받는다 (`var arr: Array = d["key"]`). 타입 추론 실패로 파서 에러가 난 이력이 있음
- 이름 규칙: 파일 `snake_case.gd`, `class_name`은 `PascalCase`, 함수/변수 `snake_case`, 상수 `UPPER_SNAKE_CASE`, 비공개 함수는 `_` 접두
- `class_name` 캐시 누락이 생기는 곳(예: `arena.gd`에서 UI 패널)은 `preload()`로 참조
- 입력은 `physical_keycode` 기준 (Mac 한글 IME 대응). 새 입력 액션은 `project.godot`의 `[input]`에 추가
- 고유명사는 **자체 IP 이름**만 사용. PoE 원작 영문명(Keystone, Ascendancy, Chaos Orb, Cyclone 등) 금지 → `Apex Node`, `Bloodline`, `Bloodstone of ...` 등 사용
- 용어 통일: `보조 룬`, `6링크 = 액티브 1 + 보조 5`, `증가(Increased)`와 `증폭(More)` 구분

## 4. 테스트
- 실행 (Godot 4.7이 PATH에 있을 때):
  ```bash
  godot --headless --path . --script res://tests/run_tests.gd
  ```
- `src/core/` 변경 시 `tests/phase0_tests.gd`에 테스트를 추가/수정하고 통과를 확인한 뒤 커밋
- 테스트를 끄거나 건너뛰어서 통과시키지 않는다
- Godot을 실행할 수 없는 환경이면, 커밋/핸드오프에 **"테스트 미실행"**이라고 명시

## 5. Git 규칙
- **커밋 메시지**: Conventional Commits, 영어, 명령형
  - 형식: `type(scope): summary` — type은 `feat` / `fix` / `chore` / `docs` / `refactor` / `test`
  - 예: `feat(skills): add 4 tag-matched support runes`, `fix(arena): explicit type for kc in _unhandled_input`
- 커밋은 작은 단위로. 한 커밋에 서로 무관한 변경을 섞지 않는다
- `.godot/`, 빌드 산출물, 비밀값은 커밋 금지
- **브랜치**
  - `main`: 사용자가 합치는 기준 브랜치
  - 각 에이전트는 자기 작업 브랜치에서 작업 (Claude: `claude/...`). 상대 에이전트의 브랜치에 강제 푸시/히스토리 재작성 금지
  - 작업 시작 전 `main` 최신 상태를 받아서 시작

## 6. 역할 분담과 핸드오프
- **기본 분담** (사용자가 바꿀 수 있음)
  - Antigravity: 구현, Godot 에디터 작업, 씬/에셋 연결
  - Claude: 설계·코드 리뷰, 밸런스 검증, 단위 테스트, 버그 진단
- **소통 창구는 `HANDOFF.md`**
  - 새 섹션을 끝에 추가: `## N. <에이전트> <피드백|답장|작업 보고> (YYYY-MM-DD, <브랜치> @ <커밋>)`
  - 기존 섹션은 수정하지 않는다 (오타 수정 제외). 반영 결과는 새 섹션에 "반영 완료 / 보류 / 반대 의견"으로 답한다
  - 우선순위 표기: **P0** = 다음 작업 전에 필수, **P1** = 이번 단계 중, **P2** = 다음 버전 이후
  - 작업 보고에는 바꾼 파일, 테스트 실행 여부, 남은 일을 적는다
- **충돌 방지**: 같은 파일을 두 에이전트가 동시에 수정하지 않는다. 큰 작업 전에는 `HANDOFF.md`에 담당 파일을 적어 둔다
- **결정 권한**: 게임 디자인 결정(스코프, 밸런스 방향, 규칙 선택)은 사용자가 한다. 에이전트는 선택지와 추천안을 제시하고, 확정되면 `HANDOFF.md`의 "사용자 확정 사항"에 기록

## 7. 소통 언어
- 사용자와의 대화, 문서, `HANDOFF.md`, UI 텍스트: **한국어**
- 코드 식별자, 커밋 메시지: 영어
- 코드 주석: 영어 또는 한국어 (한 파일 안에서는 통일)
