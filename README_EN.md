# Vibe Coding Skills for Claude

<div align="center">

**"Knowing how to use Claude is different from using it well"**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-3.4.0-blue.svg)](https://github.com/loboking/monggle-vibe-coding-rules)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Compatible-orange.svg)](https://claude.com/claude-code)

**Skills collection to get better results with Claude Code**

[English](README_EN.md) | [한국어](README.md)

</div>

---

## 📖 What is this project?

A **collection of skills that help developers get better results when using Claude Code**.

- **📋 PRD Templates**: Structured requirement definition (Korean/English/Chinese/Japanese)
- **🤖 Agent Pipeline**: Automated code generation workflow based on PRD
- **🔍 Code Quality Tools**: Linting, security scanning, complexity analysis
- **📚 Documentation Automation**: Automatic CHANGELOG and API docs generation
- **🔄 Git Collaboration Skills**: Safe Git synchronization and conflict resolution

> **Honest confession**: This is not a team collaboration tool. It's a methodology for individual developers to use Claude better.
>
> But since v2.5, Git collaboration skills have been added, making team development possible!

---

## 🎯 Why do you need it?

### Common Problems

| Problem | Cause |
|---------|-------|
| "I don't understand the code Claude wrote" | Requirements unclear → different code each time |
| "Code keeps changing" | No conventions → lack of consistency |
| "Reviews take too long" | Lack of basic quality validation |
| "Git conflicts keep happening" | Hard to time synchronization right |

### Provided Tools

| Tool | Role |
|------|------|
| **Structured PRD** | Prevent missing required items |
| **Code Quality Tools** | Auto-detect project and run appropriate tools |
| **AI Pre-review** | Automatic validation before commit |
| **Verdict System** | PRD quality judgment (PASS/FIX/FAIL) |
| **Git Collaboration Skills** | Safe synchronization and conflict resolution |

---

## 🚀 Installation

### Git Clone

```bash
git clone https://github.com/loboking/monggle-vibe-coding-rules.git
cd monggle-vibe-coding-rules
./install.sh
```

### Curl One-liner

```bash
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

---

## 🎬 0. Initial Setup (First Time Only)

Set up the basic environment when you start.

```bash
/init                    # Run initial setup wizard
/init --reset            # Reset configuration and re-setup
```

**Configuration Items**:
- Work mode (Solo / Team)
- PRD language (Korean / English / 中文 / 日本語)
- Default AI model (Haiku / Sonnet / Opus)
- User information (name, email)

Configuration is saved in `.claude/config/user.conf`, and all subsequent skills will use these values.

---

## 🔄 Work Modes

**Solo Mode** (default):
- Freely modify code without PRD
- Suitable for rapid prototyping

**Team Mode**:
- PRD required! Auto-generate PRD prompt if missing
- Ensures systematic collaboration process

Change mode:
```bash
/mode solo              # Switch to Solo mode
/mode team              # Switch to Team mode
```

---

## 📝 Core Features

### 0. 🤖 Intent-Based Skill Execution (v2.6)

Automatically detects the **intent** from natural language input and runs the appropriate skill. Based on semantic understanding, not keyword matching.

**Features:**
- ✅ Multi-language support (Korean, English)
- ✅ Automatic recognition of various expressions
- ✅ Context-aware intent parsing

**Examples:**
```
User: "너무 느려" (Too slow) → Auto: /bottleneck
User: "보안 문제 없나?" (Security?) → Auto: /audit
User: "기획 좀 세워줘" (Plan this) → Auto: /prd
User: "코드 올릴게" (Push code) → Auto: /push-safe
```

**Supported Intents:**
| Intent | Skill |
|--------|-------|
| Planning | `/prd` |
| Architecture review | `/arch-review` |
| Performance issues | `/bottleneck`, `/profile`, `/bench` |
| Security check | `/audit` |
| Code review | `/review` |
| Git sync | `/push-safe`, `/update` |

---

### 1. PRD Generation (Multilingual Support)

Generate structured PRDs through interactive questions.

```bash
/prd                     # Interactive PRD generation
/prd feature             # New feature PRD
/prd bug                 # Bug fix PRD
/prd api                 # API design PRD
/prd --language en       # English PRD
/prd --language ko       # Korean PRD
```

**Supported Types**: `feature`, `bug`, `refactor`, `hotfix`, `experiment`, `api`, `migration`, `ml`, `devops`

**Supported Languages**:
- `--language ko` - Korean (default)
- `--language en` - English
- `--language zh` - Chinese
- `--language ja` - Japanese

---

### 2. Agent Pipeline

Automatically executes the following stages when PRD is written:

```
Gate(Validate) → Scan(Analyze) → Fold(Evaluate) → Verdict(Judge) → Patch(Implement) → Trace(Log)
```

```bash
/pipeline prd/feature-xyz.md     # Run full pipeline
/quick prd/hotfix.md             # Quick run (skip Gate/Fold)
```

**Verdict System**:
- **PASS** (>= 0.9): Proceed with implementation
- **FIX** (>= 0.5): PRD needs improvement
- **FAIL** (< 0.5): Rewrite from scratch

---

### 3. Code Quality Tools

Auto-detect project and run appropriate tools.

```bash
/lint-smart      # Auto-detect project and run linter
/audit           # Security vulnerability scan
/format-check    # Code format check only
/complexity      # Complexity analysis
```

---

### 4. Documentation Automation

Automatically generate documentation from Git logs and code.

```bash
/changelog       # Git log → CHANGELOG.md
/bump            # Bump version + Git tag
/api-docs        # Docstring → API documentation
/readme-sync     # README synchronization
```

---

### 5. Performance Analysis

Analyze code performance and find bottlenecks.

```bash
/bottleneck      # Bottleneck analysis
/profile         # Profiling
/bench           # Benchmark execution/comparison
/mem-check       # Memory leak detection
```

---

### 6. Git Collaboration Skills (v2.5) 🆕

Safe Git synchronization and conflict resolution for team development

```bash
./update                 # or ./.claude/commands/update.sh
./push-safe              # or ./.claude/commands/push-safe.sh
```

**Features**:
- ✅ Auto stash for safe work storage
- ✅ Auto rollback on conflict
- ✅ Auto-create GitHub/GitLab/Bitbucket PR
- ✅ Conflict resolution guide

**Usage Examples**:
```bash
./update                 # Interactive run
./update --auto          # Auto run
./update --dry-run       # Check plan only

./push-safe              # Safe push + PR
./push-safe --no-pr      # Push without PR
```

**Conflict Resolution Guide**:
```
❌ Conflict detected: src/auth.ts

🔍 Root Cause:
- Conflict on same line (line 15)
- Original: return true (modified by teamA)
- Mine: return false (modified by me)

💡 Resolution:
1. git checkout --theirs src/auth.ts  → Keep original
2. git checkout --ours src/auth.ts    → Keep my changes
3. Manually edit src/auth.ts          → Merge both
```

---

### 7. Task Management Skills (v2.6) 🆕

```bash
/save-point              # Save current work state
/save-point list         # List saved states
/save-point resume       # Restore latest state

/arch-review             # Architecture/design review
/arch-review <prd-file>  # Review PRD file

/weekly-recap            # Weekly recap
/weekly-recap --team     # Team member analysis
```

**Saved Information (`/save-point`)**:
- Git state (branch, modified files, commits)
- Completed/in-progress/remaining tasks
- Important decisions
- Related PRD/issue links

**Architecture Review Items (`/arch-review`)**:
- Component separation & dependencies
- Data flow
- Edge cases (network failure, concurrency, etc.)
- Test coverage
- Performance & security

---

### 8. Harness System (v2.4)

Automatically runs after Pipeline execution (in background).

```bash
/pipeline prd/feature.md
# → Auto-shows improvement suggestions after completion (Critical only)
```

| Feature | Description | Auto/Manual |
|---------|-------------|-------------|
| **Loop Detection** | Prevent infinite edits to same file | Auto |
| **Improvement Suggestions** | Analyze stats and suggest improvements | Auto (after Pipeline) |
| **`/harness`** | Status check, manual diagnosis | Manual (for debugging) |

```bash
/harness status      # Check current status (manual)
/harness loops       # Loop detection status (manual)
/harness improve     # View all suggestions (manual)
```

---

## 💻 All Commands

### Workflow
| Command | Description |
|---------|-------------|
| `/init` | Initial setup (first time only) |
| `/prd` | PRD generation (interactive) |
| `/pipeline` | Run full pipeline |
| `/quick` | Quick run (Hotfix) |
| `/gate` | PRD validation |

### Git Collaboration (v2.5)
| Command | Description |
|---------|-------------|
| **`./update`** | Git sync (safe) |
| **`./push-safe`** | Safe push + PR |
| `/git-guardian` | Secrets scan + commit |

### Code Quality
| Command | Description |
|---------|-------------|
| `/lint-smart` | Auto linter |
| `/audit` | Security scan |
| `/format-check` | Format check |
| `/complexity` | Complexity analysis |
| `/review` | AI code review |

### Documentation
| Command | Description |
|---------|-------------|
| `/changelog` | Generate CHANGELOG |
| `/bump` | Bump version + tag |
| `/api-docs` | API documentation |
| `/readme-sync` | README sync |

### Performance Analysis
| Command | Description |
|---------|-------------|
| `/bottleneck` | Find bottleneck |
| `/profile` | Profiling |
| `/bench` | Benchmark |
| `/mem-check` | Memory leak |

### Task Management (v2.6) 🆕
| Command | Description |
|---------|-------------|
| `/save-point` | Save/restore work state |
| `/arch-review` | Architecture review |
| `/weekly-recap` | Weekly recap |

### System
| Command | Description |
|---------|-------------|
| `/stats` | Statistics |
| `/mode` | Change mode |
| `/harness` | Harness system |

---

## 🧪 Testing

```bash
./tests/run_tests.sh           # All tests (Python + bats)
./tests/run_tests.sh --python  # Python tests only
./tests/run_tests.sh --bats    # bats tests only
```

**Test Coverage**:
- Python unittest: 35 tests
- bats-core: 34 tests
- Total: 69 test cases

---

## ❓ FAQ

**Q: Is Claude Code required?**
- A: Limited features available in Bash fallback mode, but performs best with Claude Code.

**Q: What languages are supported?**
- A: PRD generation supports **Korean, English, Chinese, Japanese**. Code analysis supports Python, JavaScript, TypeScript, Go, Java, Ruby, Rust, etc.

**Q: Can I apply this to existing projects?**
- A: Yes, install to existing projects with `./install.sh /path/to/project`.

**Q: Can our team use it together?**
- A: Yes! Since v2.5, Git collaboration skills enable team development:
  - Safe remote repo sync with `/update`
  - Conflict-free push with `/push-safe`
  - Auto-create GitHub/GitLab/Bitbucket PRs
  - Each team member can use Git workflow after installation

**Q: When should I write a PRD?**
- A: Recommended before starting complex development work. For simple fixes or questions, feel free to chat without a PRD.

---

## 🔄 Updates

### 1. Check Current Version

```bash
cat VERSION  # Or check README badge
```

### 2. Check Latest Version

**Check GitHub Release:**
```bash
# In browser
https://github.com/loboking/monggle-vibe-coding-rules/releases
```

**Or Check Git Tags:**
```bash
git fetch origin --tags
git tag -l | tail -5  # Last 5 tags
```

### 3. Update Methods

#### Method A: Git Clone (if installed)

```bash
# Go to project directory
cd monggle-vibe-coding-rules

# Check changes (optional)
git fetch origin
git log HEAD..origin/main --oneline  # Check new commits

# Update
git pull origin main

# Reinstall (if needed)
./install.sh
```

#### Method B: Curl One-liner

```bash
# Full reinstall
curl -fsSL https://raw.githubusercontent.com/loboking/monggle-vibe-coding-rules/main/install.sh | bash
```

> **💡 Tip**: Config files (`.claude/config/user.conf`) are preserved, so update with confidence!

### 4. Post-Update Check

```bash
# Check version
cat VERSION

# Test skills
/stats  # Check statistics
```

### 5. Check Changes

```bash
# Last 5 commits
git log --oneline -5

# Last 10 commits detailed
git log -10 --pretty=format:"%h - %s (%ar)" --author="loboking"

# Check release notes
# https://github.com/loboking/monggle-vibe-coding-rules/blob/main/CHANGELOG.md
```

### ⚠️ Update Notes

- **Config preservation**: `.claude/config/user.conf` is auto-backed up
- **PRD preservation**: `prd/` directory is unaffected
- **Log reset**: `logs/` directory may be reset
- **Conflict prevention**: Commit in-progress files before updating

---

## 📜 License

[MIT License](LICENSE)

---

## 🔗 Links

- [GitHub Repository](https://github.com/loboking/monggle-vibe-coding-rules)
- [Issues](https://github.com/loboking/monggle-vibe-coding-rules/issues)
- [Discussions](https://github.com/loboking/monggle-vibe-coding-rules/discussions)

---

<div align="center">

**Vibe Coding Skills for Claude v3.2.0**

Made with ❤️ by [loboking](https://github.com/loboking)

</div>
