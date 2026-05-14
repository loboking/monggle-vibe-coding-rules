# Vibe Coding Rules - 빠른 시작 가이드

> **5분 핵심 스킬** - 설치 후 즉시 사용 가능

---

## 🚀 설치 후 바로 시작

```bash
# 1. 설치 (이미 완료되었다면 건너뛰기)
./install.sh

# 2. 바로 사용 (재시작 불필요!)
/help           # 모든 명령어 확인
/qa             # QA 테스트
/prd            # PRD 생성
```

---

## 📋 자주 쓰는 명령어 TOP 10

| 명령어 | 용도 | 사용 예시 |
|--------|------|----------|
| `/help` | 도움말 | `/help debug` |
| `/qa` | QA 테스트 | `/qa` |
| `/prd` | PRD 생성 | `/prd feature` |
| `/review` | 코드 리뷰 | `/review` |
| `/debug` | 디버깅 | `/debug` |
| `/quick` | 빠른 핫픽스 | `/quick` |
| `/bump` | 버전 업 | `/bump` |
| `/monggle` | monggle 전체 | `/monggle` |
| `/monggle-upgrade` | 업그레이드 | `/monggle-upgrade` |
| `/save-point` | 상태 저장 | `/save-point` |

---

## 🔍 카테고리별 명령어

### Debug & QA (문제 해결)
```bash
/qa              # QA 테스트 (자동 수정)
/qa --report     # 보고서만
/debug           # 버그 분석
/bottleneck      # 성능 병목 찾기
/mem-check       # 메모리 누수 탐지
```

### Review (코드 검토)
```bash
/review          # 코드 리뷰
/arch-review     # 아키텍처 리뷰
/audit           # 보안 감사
```

### Planning (기획)
```bash
/prd             # PRD 생성
/gate            # PRD 검증
/pipeline        # 에이전트 파이프라인
/idea            # 아이디어 수집
```

### Project (프로젝트)
```bash
/init            # 프로젝트 초기화
/mode            # solo/team 모드
/stats           # 파이프라인 통계
/save-point     # 작업 상태 저장
```

### Release (배포)
```bash
/bump            # 버전 업 + 태그
/push-safe       # 안전한 푸시
/profile         # 성능 프로파일링
```

### System (시스템)
```bash
/brain           # 뇌 시스템 (메모리 & 시각화)
/brain timeline  # 활동 타임라인
/brain heatmap   # 활동 히트맵
/brain when      # 특정 날짜 활동 조회
```

---

## 💡 팁 & 트릭

### 오타 자동 교정
```bash
/qaa             # → /qa
/debugg          # → /debug
```

### 도움말 검색
```bash
/help            # 전체 목록
/help debug     # 디버그 관련만
/help --search test  # 검색
```

### monggle 접두사
```bash
# 모두 동일한 기능
/qa
/monggle-qa     # 설명에만 monggle 표시
```

---

## 🔄 업그레이드

```bash
# 자동 체크 (스킬 실행 시 24시간마다)
/qa

# 수동 업그레이드
/monggle-upgrade
/monggle-upgrade --force
```

---

## ❓ 문제 해결

| 문제 | 해결책 |
|------|--------|
| 스킬이 안 먹힘 | `./install.sh` 재실행 |
| 오타 나옴 | 오타 자동 교정 작동 중 |
| 명령어 찾기 | `/help --search <keyword>` |
| 업그레이드 | `/monggle-upgrade` |

---

## 📚 더 알아보기

- **전체 문서**: [CLAUDE.md](./CLAUDE.md)
- **기여하기**: [CONTRIBUTING.md](./CONTRIBUTING.md)
- **변경 이력**: [CHANGELOG.md](./CHANGELOG.md)

---

**Vibe Coding Rules v3.2** - 즉시 사용, 번거로움 제로
