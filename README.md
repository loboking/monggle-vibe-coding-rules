# Vibe Coding Skills for Claude

<div align="center">

**"Claude는 쓰는데, 잘 쓰는 법은 다릅니다"**

[![Version](https://img.shields.io/badge/version-3.4.0-blue.svg)](https://github.com/loboking/monggle-vibe-coding-rules)

**Claude Code를 더 잘 쓰기 위한 스킬 모음**

</div>

---

## 🚀 빠른 시작

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

---

## ⬆️ 업그레이드 방법

툴킷(스킬·라이브러리) 자체를 최신 버전으로 올릴 때는 `/monggle-upgrade` 한 줄이면 됩니다.
GitHub 최신 버전 확인 → `git pull` → `install.sh` 재실행(글로벌 동기화)까지 한 번에 처리합니다.

```bash
/monggle-upgrade               # 최신 버전 확인 후 자동 업그레이드 (하루 1회 스로틀)
/monggle-upgrade --check-only  # 업데이트 여부만 확인 (설치 안 함)
/monggle-upgrade --force       # 하루 1회 제한 무시하고 즉시 재확인
```

> **`/monggle-upgrade` vs `/update`**
> - `/monggle-upgrade` = **툴킷 자체 최신화**(버전 비교 + `git pull` + `install.sh` 재실행). 평소엔 이걸 쓰세요.
> - `/update` = **현재 작업 브랜치를 원격과 동기화**하는 범용 git pull 도우미. 툴킷 업그레이드 목적이면 `/monggle-upgrade`를 사용하세요.

---

## 💡 자주 쓰는 명령어 (Top 10)

| 명령어 | 설명 |
|--------|------|
| `/help` | 전체 명령어 보기 |
| `/init` | 초기 설정 (최초 1회) |
| `/prd` | 기획서 생성 |
| `/debug` | 디버깅 |
| `/qa` | 테스트 |
| `/review` | 코드 리뷰 |
| `/changelog` | 변경 로그 |
| `/push-safe` | 안전한 Git push |
| `/brain` | 뇌 시스템 (기억) |
| `/super` | 간단 요청 → 상세 요구사항 |

---

## 🔗 monggle- 접두사 별칭

`monggle-` 접두사를 사용하여 동일한 스킬 호출 가능:

| 별칭 | 원본 | 호출 방법 |
|-----|------|----------|
| `monggle-super` | `super.md` | 자연어: `Use monggle-super to expand...` |
| `monggle-gemini` | `gemini.md` | 자연어: `Use monggle-gemini to analyze...` |
| `monggle-brain` | `smart-brain.md` | 자연어: `Use monggle-brain to remember...` |
| `monggle-init` | `project-init.md` | 자연어: `Use monggle-init to setup...` |
| `monggle-planner` | `product-manager.md` | 자연어: `Use monggle-planner to plan...` |

**참고:** 이 스킬들은 Agent 형태로 제공되며 자연어로 호출합니다.

---

## 📖 상세 문서

| 문서 | 설명 |
|------|------|
| [GUIDE.md](GUIDE.md) | 전체 사용 가이드 |
| [CHANGELOG.md](CHANGELOG.md) | 변경 로그 |

---

## 🎯 주요 기능

- **📋 PRD 템플릿** - 구조화된 요구사항 정의
- **🤖 Agent Pipeline** - PRD 기반 자동 코드 생성
- **🔍 코드 품질** - 린트, 보안 스캔, 복잡도 분석
- **📚 문서 자동화** - CHANGELOG, API 문서 자동 생성
- **🧠 뇌 시스템** - 맥락 기억, 망각 곡선, 시냅스 연결
- **🔄 Git 협업** - 안전한 동기화, 충돌 해결

---

## ✨ 특징

- ✅ 오타 자동 교정 (`/qaa` → `/qa`)
- ✅ 의도 기반 스킬 실행 ("너무 느려" → `/bottleneck`)
- ✅ 다국어 PRD (한국어/영어/중국어/일본어)

---

## 📜 License

[MIT License](LICENSE)

---

<div align="center">

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
