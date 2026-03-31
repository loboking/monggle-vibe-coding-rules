# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.4.1] - 2026-03-31

### Added
- `CONTRIBUTING.md` - 상세한 기여 가이드라인
- Project badges to README (License, Version, Claude Code compatible)

### Changed
- README reorganized for clarity (650 lines → 202 lines)
- Improved visual hierarchy with emojis and tables
- Consolidated command references
- Added pipeline ASCII diagram

### Removed
- Obsolete documentation files (8 files, 1,862 lines)
  - `docs/CODE_REVIEW_REPORT.md`
  - `AI_REVIEWER_IMPLEMENTATION.md`
  - `agents/agent_m_*.md` (6 files) - replaced by Python implementation

### Docs
- Link to CONTRIBUTING.md for collaboration details
- Improve Quick Start with 5-minute guide
- Add Overview section with core features table

---

## [2.4.0] - 2026-03-16

### Added
- 12 code quality/documentation/performance skills
  - `/lint-smart` - Auto-detect project linter
  - `/audit` - Security vulnerability scan
  - `/format-check` - Code format check
  - `/complexity` - Complexity analysis
  - `/changelog` - Auto-generate CHANGELOG from Git commits
  - `/bump` - Version up + tag creation
  - `/api-docs` - API documentation extraction
  - `/readme-sync` - README synchronization
  - `/bottleneck` - Performance bottleneck finder
  - `/profile` - Profiling
  - `/bench` - Benchmark execution/comparison
  - `/mem-check` - Memory leak detection
- PRD templates (5 types)
- Solo/Team modes
- Interactive PRD creation (`/init`)
- AI Reviewer system (Manual/Semi-Auto/Auto modes)

---

## [2.3.0] - 2026-02-24

### Added
- Interactive PRD creation (`/init` command)
- Natural language PRD generation
- Hotfix PRD template with fast-track pipeline

---

## [2.2.0] - 2026-02-19

### Added
- Solo/Team mode flexibility
- Fast track hotfix workflow (`/quick`)
- Auto pipeline based on PRD type
- Pipeline statistics (`/stats`)
- Single source of truth (`rules/core-rules.yaml`)

---

## [2.0.0] - 2025-02-19

### Added
- Full Agent Pipeline (Gate → Scan → Fold → Verdict → Patch → Trace)
- AI Reviewer system
- Verdict System (PASS/FIX/FAIL)
- PRD-based development methodology

---

## Links

- [GitHub Repository](https://github.com/loboking/monggle-vibe-coding-rules)
- [Contributing](CONTRIBUTING.md)

---

[2.4.1]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.4.0...v2.4.1
[2.4.0]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.3.0...v2.4.0
[2.3.0]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/loboking/monggle-vibe-coding-rules/compare/v2.0.0...v2.2.0
[2.0.0]: https://github.com/loboking/monggle-vibe-coding-rules/releases/tag/v2.0.0
