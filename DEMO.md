# MacSense — 발표/데모 가이드

> 10~15분 progress report 용. 1) 주제 → 2) 마주친 문제 → 3) Solution design + 라이브 데모.

## 0. 발표 전 사전 세팅 (필수)

### 빌드
```bash
cd ~/Desktop/MacSense
./build.sh
```
출력: `✅ Built: build/MacSense.app`

### 권한 부여 (한 번만, 발표 전에)
1. **시스템 설정 → 개인정보 보호 및 보안 → 접근성**
   - `+` 눌러서 `build/MacSense.app` 추가, 토글 ON
2. **시스템 설정 → 개인정보 보호 및 보안 → 입력 모니터링**
   - 동일하게 `build/MacSense.app` 추가, 토글 ON

### LLM 키 (선택, AI 데모 시) — Groq, 카드 불필요, 2분 소요
1. https://console.groq.com 접속 → Google/GitHub 로그인
2. 좌측 메뉴 **API Keys** → `Create API Key` → `gsk_...` 복사
3. 터미널에 `export GROQ_API_KEY="gsk_..."`
4. 무료 한도: 30 RPM / 6K TPM / **1,000 req/일** (우리는 30분 쿨다운 + DB miss만 호출이라 거의 안 씀)
```bash
export GROQ_API_KEY="gsk_..."   # https://console.groq.com/keys 에서 발급
```

### 첫 알림 권한 트리거 (macOS가 처음 한 번 묻습니다)
```bash
osascript -e 'display notification "테스트" with title "MacSense"'
```
→ 알림 센터에 “osascript에서 알림 보내기 허용” 묻는 거 *허용*.

### 깨끗한 상태로 시작하고 싶다면
```bash
rm -f ~/Library/Application\ Support/MacSense/events.db
```

## 1. 발표 슬라이드 흐름 (10–15분)

### Slide 1–2: 주제 (1–2분)
- 한 줄: "macOS 사용자가 모르는 비효율을 AI가 먼저 발견해서 알려준다."
- 배경 통계:
  - 하루 평균 클릭 5,000회 (WhatPulse)
  - 단축키 학습 시 연간 64시간 절약 (Brainscape)
- 기존 단축키 앱과의 차이:
  > "기존: 사용자가 단축키를 알아야 한다. MacSense: AI가 먼저 발견한다."

### Slide 3–4: 마주친 문제 (3–5분)
중요한 건 *해결한 문제*를 보여주는 거. 각각 한두 줄 + 해결책.

1. **"클릭한 UI 요소가 뭔지 어떻게 아느냐"**
   - 해결: Accessibility API + CGEventTap 조합. `AXUIElementCopyElementAtPosition`로 좌표 → 요소 매핑.
2. **"AX 요소의 title이 자주 빈다 (특히 툴바 SF Symbol 버튼)"**
   - 해결: `title → description → help → 자식 요소` 폴백 체인. ([src/AX.swift:35-49](src/AX.swift#L35-L49))
3. **"네이티브가 아닌 앱 (Electron, 카카오톡)은?"**
   - PoC 결과: 네이티브 + 카카오톡 ✅ / Electron 부분 / 게임 ❌
   - 한국 시장 타겟에서는 카카오톡 추적이 강점.
4. **"AI가 도대체 어디서 쓰이느냐"**
   - 단순 빈도 카운팅 → DB 매칭은 알고리즘. AI는 *DB에 없는 행동의 대안 제시* 역할.
   - 또는 매칭된 단축키를 자연어 코칭으로 다듬는 역할.

### Slide 5: Solution Design (아키텍처) (2–3분)
```
[CGEventTap] → [AX 요소 추출] → [SQLite 로그]
                                      ↓
                             [N-gram 빈도 감지]
                                ↓             ↓
                       [단축키 DB 매칭]   [LLM 폴백]
                                ↓             ↓
                          [macOS 알림 + 메뉴바 UI]
```

구현 매핑:
- 이벤트 캡처: [src/EventTap.swift](src/EventTap.swift)
- UI 요소 추출: [src/AX.swift](src/AX.swift)
- 저장: [src/Storage.swift](src/Storage.swift) (SQLite C API 직접 사용)
- 패턴 감지: [src/Detector.swift](src/Detector.swift) (threshold=3, 5분 윈도우)
- 단축키 DB: [resources/shortcuts.json](resources/shortcuts.json) (20개 엔트리, Finder/Chrome/Notes)
- LLM: [src/LLMClient.swift](src/LLMClient.swift) (Groq · GPT-OSS 120B, Free Plan 사용 가능)
- 알림: [src/Notifier.swift](src/Notifier.swift) (osascript)
- 메뉴바 UI: [src/AppDelegate.swift](src/AppDelegate.swift)

### Slide 6: 라이브 데모 (3–5분) → 아래 시나리오

### Slide 7: 남은 작업 / 확장 가능성 (1–2분)
- 주간 리포트 (LLM이 하루치 로그를 분석해서 인사이트 생성) — 미구현
- 추천을 사용자가 *수용/거부* 추적해서 학습 통계 → 습득한 단축키 카운트
- Electron 앱 지원 확대
- Windows 포팅 (UI Automation API)

---

## 2. 라이브 데모 시나리오

데모 시작 전 한 번:
```bash
export GROQ_API_KEY="gsk_..."   # https://console.groq.com/keys 에서 발급
./run.sh
```
메뉴바 상단에 💡 떴는지 확인.

### 시나리오 A — DB 매칭 (안정적, 메인 데모)
1. **Finder** 열기, "File" 메뉴 펼치기
2. "New Folder" 클릭 → 새 폴더 1
3. ⌘W로 폴더 닫기 (또는 그냥 두기), 다시 "File" → "New Folder" → 새 폴더 2
4. 한 번 더: "File" → "New Folder" → 새 폴더 3
5. **🔔 알림이 떠야 함**: "오늘 3번 반복하셨어요 — ⌘⇧N — Finder에서 새 폴더 만들기"
6. 메뉴바 💡 클릭 → "감지된 패턴", "추천 단축키" 항목 보여주기

### 시나리오 B — 자동화 레시피 제안 (AI 활용 어필)
DB에 없는 행동을 3번 반복:
1. Chrome 또는 Notes에서 DB에 없는 특정 버튼/폴더를 3번 클릭
2. 알림: "Shortcuts 자동화 방법을 찾는 중…"
3. 5초 내 두 번째 알림: 자동화 레시피 도착
4. 메뉴바 💡 클릭 → "자동화 제안", "Shortcuts에서 만들기" 항목 보여주기
5. "Shortcuts에서 만들기" 클릭 → macOS Shortcuts 앱이 열리는 것 확인

### 시나리오 C — DB 시각화 (백업)
라이브 알림이 안 나오면 SQLite로 결과 보여줌:
```bash
sqlite3 ~/Library/Application\ Support/MacSense/events.db \
  "SELECT app, leaf_label, COUNT(*) as n FROM events
   GROUP BY app, leaf_label ORDER BY n DESC LIMIT 10;"
```
→ "이렇게 실제로 로그가 쌓이고 있고, 이 위에 빈도 분석이 돈다"

### 데모 실패 시 폴백
- 알림이 안 뜸: 메뉴바 💡 클릭 → 모든 상태값 화면에 보여주면서 "여기 보세요, 감지는 됐는데 macOS가 알림 권한을 안 받아서…" 자연스럽게 트러블슈팅 보여주기
- 진짜 막히면: `test.swift` 컴파일된 `mactest` 바이너리(PoC)는 콘솔에 즉시 출력 → 백업 데모로 사용

---

## 3. 발표 시 어필 포인트

1. **단순 ChatGPT 래퍼가 아님** — AX API로 추출한 *고유 행동 데이터*를 LLM에 입력. 차별점 강조.
2. **로컬 우선** — 서버 X, 데이터 외부 전송 X. 사용자 신뢰.
3. **PoC가 진짜로 동작함** — 카카오톡까지 추적되는 라이브 시연.
4. **MVP가 명확함** — Finder 하나로도 데모 가능 + 한국 사용자용으로 카카오톡 포함.

---

## 4. 빠른 문제 해결

| 증상 | 원인 / 조치 |
|---|---|
| "접근성 권한 필요" 뜨고 종료 | 위 0번 권한 부여 다시. **빌드할 때마다 권한 재부여 필요할 수 있음** |
| EventTap 생성 실패 | 입력 모니터링 권한 누락 |
| 알림이 안 뜸 | 첫 osascript 호출 시 macOS가 묻는 권한 *허용* 해야 함 |
| LLM 응답 X | `echo $GROQ_API_KEY` 확인. 네트워크 확인. 30 RPM / 1000 RPD 한도 체크 |
| 알림이 너무 자주/적게 | [src/AppDelegate.swift:7](src/AppDelegate.swift#L7) 의 `threshold` / `windowSeconds` / `cooldownSeconds` 조정 후 재빌드 |
| 데모 다시 하려는데 패턴이 안 떠 | 쿨다운 30분. `kill %1`로 종료 후 재실행하면 in-memory 쿨다운 클리어 |
