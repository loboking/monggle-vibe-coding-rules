# Vibe Coding Starter Kit

> **파일 하나로 팀 전체가 동일한 AI 협업 환경을 구축합니다.**

## 🚀 Quick Start

### 방법 1: Git Clone (추천)

```bash
# 프로젝트 루트에서 클론
git clone https://github.com/loboking/monggle-vibe-coding-rules.git temp-rules
cp temp-rules/CLAUDE.md .
cp temp-rules/.cursorrules .
rm -rf temp-rules
```

### 방법 2: 수동 복사

```bash
# 프로젝트 루트에 복사
cp CLAUDE.md /your-project/
cp .cursorrules /your-project/
```

끝! 이제 AI가 자동으로 규칙을 따릅니다.

---

## 📦 파일 구성

| 파일 | 용도 | 위치 |
|------|------|------|
| `CLAUDE.md` | Claude Code/Desktop | 레포 루트 |
| `.cursorrules` | Cursor IDE | 레포 루트 |
| `.github/copilot-instructions.md` | GitHub Copilot | .github 폴더 |
| `VIBE_CODING_INIT.md` | 상세 초기화 문서 | docs 폴더 |
| `SETUP_GUIDE.md` | 적용 가이드 | docs 폴더 |

---

## 📋 핵심 원칙

1. **PRD 먼저** - 코딩 전에 PRD 작성
2. **AI가 검증** - 리뷰/검증/판단은 AI가 담당
3. **개발자는 집중** - 구현과 창의성에만 집중
4. **자유로운 실험** - 개인 브랜치에서 마음껏

---

## 🌿 브랜치 구조

```
main                          ← Production (Protected)
 ├─ dev/{user}/{feature}      ← 개인 개발
 └─ hotfix/{issue-id}         ← 긴급 수정
```

---

## 📊 워크플로우

```
PRD 작성 → 개인 개발 → PR 생성 → AI 리뷰 → 승인 → 머지 → 배포
```

---

## 💡 FAQ

**Q: 매번 규칙을 AI에게 알려줘야 하나요?**
A: 아니요! `CLAUDE.md` 파일이 레포에 있으면 AI가 자동으로 읽습니다.

**Q: 여러 AI 도구를 쓰는데요?**
A: 같은 내용으로 여러 파일 배치:
- Claude → `CLAUDE.md`
- Cursor → `.cursorrules`
- Copilot → `.github/copilot-instructions.md`

---

## 📜 최종 선언

> **"버그 없는 시스템이 아닌, 실패를 통제하고 반복하지 않는 시스템을 만든다."**

---

**Created with Vibe Coding Methodology v1.0**
