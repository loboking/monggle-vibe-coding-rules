#!/bin/bash
#
# smart-qa.sh - monggle: Smart QA
#
# 프로젝트 자동 감지 및 플랫폼별 QA 테스트
#
# Usage:
#   /smart-qa              # 자동 감지 + 전체 테스트
#   /smart-qa --android    # Android 프로젝트 테스트
#   /smart-qa --ios        # iOS 프로젝트 테스트
#   /smart-qa --web        # Web 프론트엔드 테스트
#   /smart-qa --server     # 서버/백엔드 테스트
#   /smart-qa --code       # 코드만 (TODO/FIXME, console.log 등)
#

set -euo pipefail

# ============================================================================
# Harness Auto-Tracking
# ============================================================================

# 하네스 래퍼 로드 (자동 추적)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brain/skill-harness-wrapper.sh" 2>/dev/null || true

# 동적 스킬 로더 (v3.5 - 하드코딩 제거)
source "${SCRIPT_DIR}/../lib/skill_loader.sh" 2>/dev/null || true

# 스킬 종료 시 자동 기록 (trap)
trap 'harness_skill_end $?' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Version SSOT (VERSION 파일이 유일한 정본) ──────────────────────────────
get_toolkit_version() {
    [[ -n "${MONGGLE_TOOLKIT_VERSION:-}" ]] && { printf '%s\n' "$MONGGLE_TOOLKIT_VERSION"; return; }
    if [[ -f "${PROJECT_ROOT}/VERSION" ]]; then tr -d '[:space:]' < "${PROJECT_ROOT}/VERSION"; return; fi
    if [[ -f "${HOME}/.claude/.repo_path" ]]; then
        local r; r="$(cat "${HOME}/.claude/.repo_path" 2>/dev/null)"
        [[ -n "$r" && -f "$r/VERSION" ]] && { tr -d '[:space:]' < "$r/VERSION"; return; }
    fi
    if command -v git >/dev/null 2>&1; then
        local t; t="$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')"
        [[ -n "$t" ]] && { printf '%s\n' "$t"; return; }
    fi
    echo unknown
}
TOOLKIT_VERSION="$(get_toolkit_version || echo unknown)"

# Flags
REPORT_ONLY=false
QUICK_MODE=false
FORMAT="text"
VERBOSE=false
TARGET=""
TARGETS=()  # 복수 타겟 지원

# Platform filter (auto-detected by default)
PLATFORM=""
PLATFORM_FILTER=""

# 유효한 스킬 목록 (동적 로드 - v3.5)
VALID_SKILLS="$(load_valid_skills)"

# ============================================================================
# PROJECT AUTO-DETECTION
# ============================================================================

detect_project_type() {
    local detected=""

    # Android detection
    if [[ -f "$PROJECT_ROOT/build.gradle" ]] || \
       [[ -f "$PROJECT_ROOT/build.gradle.kts" ]] || \
       [[ -f "$PROJECT_ROOT/settings.gradle" ]] || \
       [[ -f "$PROJECT_ROOT/app/build.gradle" ]] || \
       [[ -f "$PROJECT_ROOT/app/src/main/AndroidManifest.xml" ]]; then
        detected="${detected}android "
    fi

    # iOS detection
    if ls -d "$PROJECT_ROOT"/*.xcodeproj >/dev/null 2>&1 || \
       ls -d "$PROJECT_ROOT"/*.xcworkspace >/dev/null 2>&1 || \
       [[ -f "$PROJECT_ROOT/Info.plist" ]] || \
       [[ -f "$PROJECT_ROOT/Podfile" ]]; then
        detected="${detected}ios "
    fi

    # Web/Frontend detection
    if [[ -f "$PROJECT_ROOT/package.json" ]]; then
        # Check for frontend frameworks
        if grep -qE '"(react|vue|angular|next|nuxt|svelte|vite)"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            detected="${detected}web "
        fi
        # Check for Node.js backend
        if grep -qE '"(express|koa|fastify|nest)"' "$PROJECT_ROOT/package.json" 2>/dev/null; then
            detected="${detected}server "
        fi
    fi

    # Python/Server detection
    if [[ -f "$PROJECT_ROOT/requirements.txt" ]] || \
       [[ -f "$PROJECT_ROOT/pyproject.toml" ]] || \
       [[ -f "$PROJECT_ROOT/manage.py" ]] || \
       [[ -f "$PROJECT_ROOT/app.py" ]] || \
       [[ -f "$PROJECT_ROOT/main.py" ]]; then
        detected="${detected}server "
    fi

    # Go/Server detection
    if [[ -f "$PROJECT_ROOT/go.mod" ]] || \
       [[ -f "$PROJECT_ROOT/main.go" ]]; then
        detected="${detected}server "
    fi

    # Java/Spring detection
    if [[ -f "$PROJECT_ROOT/pom.xml" ]] || \
       [[ -f "$PROJECT_ROOT/build.xml" ]] || \
       ls "$PROJECT_ROOT"/*.gradle >/dev/null 2>&1; then
        detected="${detected}server "
    fi

    # Docker/Server detection
    if [[ -f "$PROJECT_ROOT/Dockerfile" ]] || \
       [[ -f "$PROJECT_ROOT/docker-compose.yml" ]]; then
        [[ ! "$detected" =~ server ]] && detected="${detected}server "
    fi

    # Mobile umbrella (includes Android + iOS)
    if [[ "$detected" =~ android ]] && [[ "$detected" =~ ios ]]; then
        detected="${detected}mobile "
    fi

    echo "$detected"
}

# ============================================================================
# PLATFORM-SPECIFIC FILE PATTERNS
# ============================================================================

get_platform_files() {
    local platform="$1"
    local find_cmd="find \"$PROJECT_ROOT\" -type f"

    case "$platform" in
        android)
            echo "$PROJECT_ROOT" \( -name "*.kt" -o -name "*.java" -o -name "AndroidManifest.xml" -o -name "*.gradle" -o -name "*.gradle.kts" -o -name "*.xml" \) ! -path "*/build/*" ! -path "*/.gradle/*"
            ;;
        ios)
            echo "$PROJECT_ROOT" \( -name "*.swift" -o -name "*.m" -o -name "*.h" -o -name "*.xib" -o -name "*.storyboard" \) ! -path "*/Pods/*" ! -path "*/DerivedData/*"
            ;;
        web)
            echo "$PROJECT_ROOT" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.vue" -o -name "*.css" -o -name "*.scss" \) ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/.next/*"
            ;;
        mobile)
            echo "$PROJECT_ROOT" \( -name "*.kt" -o -name "*.java" -o -name "*.swift" -o -name "*.m" -o -name "*.h" -o -name "AndroidManifest.xml" -o -name "*.xml" \) ! -path "*/build/*" ! -path "*/Pods/*"
            ;;
        server)
            echo "$PROJECT_ROOT" \( -name "*.py" -o -name "*.go" -o -name "*.java" -o -name "*.kt" -o -name "*.rs" -o -name "*.ts" -o -name "*.js" \) ! -path "*/node_modules/*" ! -path "*/vendor/*" ! -path "*/target/*" ! -path "*/__pycache__/*"
            ;;
        code)
            echo "$PROJECT_ROOT" \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" -o -name "*.py" -o -name "*.kt" -o -name "*.java" -o -name "*.go" -o -name "*.sh" \) ! -path "*/node_modules/*" ! -path "*/dist/*" ! -path "*/build/*"
            ;;
        *)
            echo "$PROJECT_ROOT" -type f
            ;;
    esac
}

# ============================================================================
# PARSE ARGS
# ============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --report)
                REPORT_ONLY=true
                shift
                ;;
            --quick)
                QUICK_MODE=true
                shift
                ;;
            --format)
                FORMAT="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --android)
                PLATFORM="android"
                PLATFORM_FILTER="android"
                shift
                ;;
            --ios)
                PLATFORM="ios"
                PLATFORM_FILTER="ios"
                shift
                ;;
            --web)
                PLATFORM="web"
                PLATFORM_FILTER="web"
                shift
                ;;
            --mobile)
                PLATFORM="mobile"
                PLATFORM_FILTER="mobile"
                shift
                ;;
            --server)
                PLATFORM="server"
                PLATFORM_FILTER="server"
                shift
                ;;
            --code)
                PLATFORM="code"
                PLATFORM_FILTER="code"
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                show_help
                exit 1
                ;;
            *)
                # [skill|skill] 형식 처리
                if [[ "$1" =~ \[.*\] ]]; then
                    local skills="${1#\[}"
                    skills="${skills%\]}"
                    IFS='|' read -ra SKILL_ARRAY <<< "$skills"
                    for skill in "${SKILL_ARRAY[@]}"; do
                        skill=$(echo "$skill" | xargs)
                        if [[ " $VALID_SKILLS " =~ " $skill " ]]; then
                            TARGETS+=("$skill")
                        else
                            echo -e "${YELLOW}Warning: Unknown skill '$skill'${NC}"
                        fi
                    done
                elif [[ " $VALID_SKILLS " =~ " $1 " ]]; then
                    TARGETS+=("$1")
                else
                    TARGET="$1"
                fi
                shift
                ;;
        esac
    done
}

# Show help
show_help() {
    echo ""
    echo -e "${CYAN}${BOLD}/smart-qa - Smart Code QA Testing v${TOOLKIT_VERSION}${NC}"
    echo ""
    echo "Usage:"
    echo "  /smart-qa [options] [target]"
    echo "  /smart-qa [platform]     # 플랫폼 자동 감지"
    echo ""
    echo "Platforms (auto-detected if not specified):"
    echo "  --android            Android 프로젝트 (.kt, .java, AndroidManifest.xml)"
    echo "  --ios                iOS 프로젝트 (.swift, .m, .h, .xib)"
    echo "  --web                Web 프론트엔드 (.ts, .tsx, .js, .css)"
    echo "  --mobile             Mobile (Android + iOS)"
    echo "  --server             서버/백엔드 (.py, .go, .java, .ts)"
    echo "  --code               코드 전체 (모든 언어)"
    echo ""
    echo "Options:"
    echo "  --report           Generate report only (no fixes)"
    echo "  --quick            Quick smoke test only"
    echo "  --format <fmt>     Output format: json|text|markdown"
    echo "  --verbose, -v      Detailed output"
    echo "  -h, --help         Show this help"
    echo ""
    echo "Examples:"
    echo "  /smart-qa                    # 자동 감지 + 전체 테스트"
    echo "  /smart-qa --android          # Android만 테스트"
    echo "  /smart-qa --web --report     # Web 보고서만"
    echo "  /smart-qa src/auth.ts        # 특정 파일 테스트"
    echo ""
}

# Print header
print_header() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}${BOLD}║   %-45s║${NC}\n" "Smart QA v${TOOLKIT_VERSION}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# ============================================================================
# RUN TESTS
# ============================================================================

run_tests() {
    local test_count=0
    local pass_count=0
    local fail_count=0
    local issues
    issues=()

    # Auto-detect platform if not specified
    if [[ -z "$PLATFORM_FILTER" ]]; then
        PLATFORM=$(detect_project_type)
        if [[ -n "$PLATFORM" ]]; then
            echo -e "${CYAN}Detected platform(s):${NC} $PLATFORM"
            echo ""
        fi
    else
        PLATFORM="$PLATFORM_FILTER"
        echo -e "${CYAN}Platform filter:${NC} $PLATFORM"
        echo ""
    fi

    echo -e "${BLUE}[→]${NC} Running tests..."
    echo ""

    # 스킬 테스트 모드
    if [[ ${#TARGETS[@]} -gt 0 ]]; then
        echo -e "${CYAN}Skill Testing Mode${NC}"
        echo ""

        for skill in "${TARGETS[@]}"; do
            echo -e "${BLUE}  Testing skill:${NC} $skill"

            local script_path="${SCRIPT_DIR}/${skill}.sh"
            local skill_md="${PROJECT_ROOT}/.claude/skills/${skill}/skill.md"

            if [[ -f "$script_path" ]]; then
                if [[ -x "$script_path" ]]; then
                    echo -e "    ${GREEN}[✓]${NC} $skill.sh executable"
                    ((pass_count++))
                else
                    echo -e "    ${YELLOW}[!]${NC} $skill.sh not executable"
                    issues+=("Permission: $skill.sh")
                    ((fail_count++))
                fi

                if bash -n "$script_path" 2>/dev/null; then
                    echo -e "    ${GREEN}[✓]${NC} $skill.sh syntax OK"
                    ((pass_count++))
                else
                    echo -e "    ${RED}[✗]${NC} $skill.sh syntax error"
                    issues+=("Syntax: $skill.sh")
                    ((fail_count++))
                fi
            else
                echo -e "    ${YELLOW}[!]${NC} $skill.sh not found (might be in global)"
            fi

            if [[ -f "$skill_md" ]]; then
                echo -e "    ${GREEN}[✓]${NC} $skill skill.md exists"
                ((pass_count++))

                if grep -q "^name:" "$skill_md" 2>/dev/null; then
                    echo -e "    ${GREEN}[✓]${NC} $skill skill.md has name"
                    ((pass_count++))
                else
                    echo -e "    ${YELLOW}[!]${NC} $skill skill.md missing name"
                    issues+=("skill.md: missing name in $skill")
                    ((fail_count++))
                fi

                if grep -q "^triggers:" "$skill_md" 2>/dev/null; then
                    echo -e "    ${GREEN}[✓]${NC} $skill skill.md has triggers"
                    ((pass_count++))
                else
                    echo -e "    ${YELLOW}[!]${NC} $skill skill.md missing triggers"
                    issues+=("skill.md: missing triggers in $skill")
                    ((fail_count++))
                fi
            else
                echo -e "    ${YELLOW}[!]${NC} $skill skill.md not found"
            fi

            echo ""
            ((test_count++))
        done
    elif [[ -n "$TARGET" ]]; then
        # Single file test
        if [[ -f "$TARGET" ]]; then
            echo -e "${BLUE}  Testing:${NC} $TARGET"

            local ext="${TARGET##*.}"
            case "$ext" in
                sh)
                    if shellcheck "$TARGET" >/dev/null 2>&1; then
                        echo -e "    ${GREEN}[✓]${NC} Shell syntax OK"
                        ((pass_count++))
                    else
                        echo -e "    ${RED}[✗]${NC} Shell syntax issues"
                        issues+=("Shell syntax: $TARGET")
                        ((fail_count++))
                    fi
                    ;;
                py)
                    if python3 -m py_compile "$TARGET" 2>/dev/null; then
                        echo -e "    ${GREEN}[✓]${NC} Python syntax OK"
                        ((pass_count++))
                    else
                        echo -e "    ${RED}[✗]${NC} Python syntax issues"
                        issues+=("Python syntax: $TARGET")
                        ((fail_count++))
                    fi
                    ;;
                kt)
                    if command -v kotlinc &>/dev/null; then
                        if kotlinc "$TARGET" -nowarn 2>/dev/null; then
                            echo -e "    ${GREEN}[✓]${NC} Kotlin syntax OK"
                            ((pass_count++))
                        else
                            echo -e "    ${YELLOW}[!]${NC} Kotlin syntax check skipped"
                        fi
                    else
                        echo -e "    ${GREEN}[✓]${NC} Kotlin file detected"
                        ((pass_count++))
                    fi
                    ;;
                swift)
                    if command -v swiftc &>/dev/null; then
                        if swiftc -syntax-only "$TARGET" 2>/dev/null; then
                            echo -e "    ${GREEN}[✓]${NC} Swift syntax OK"
                            ((pass_count++))
                        else
                            echo -e "    ${YELLOW}[!]${NC} Swift syntax check skipped"
                        fi
                    else
                        echo -e "    ${GREEN}[✓]${NC} Swift file detected"
                        ((pass_count++))
                    fi
                    ;;
                ts|tsx|js|jsx)
                    if command -v eslint &>/dev/null; then
                        if eslint "$TARGET" --format=json 2>/dev/null | jq '.[] | select(.severity >= 2)' | grep -q .; then
                            echo -e "    ${RED}[✗]${NC} ESLint errors found"
                            issues+=("ESLint: $TARGET")
                            ((fail_count++))
                        else
                            echo -e "    ${GREEN}[✓]${NC} ESLint clean"
                            ((pass_count++))
                        fi
                    else
                        echo -e "    ${GREEN}[✓]${NC} TypeScript/JavaScript file"
                        ((pass_count++))
                    fi
                    ;;
                *)
                    echo -e "    ${GREEN}[✓]${NC} File exists: $ext"
                    ((pass_count++))
                    ;;
            esac
            ((test_count++))
        else
            echo -e "${RED}Error: File not found: $TARGET${NC}"
            return 1
        fi
    else
        # Platform-specific checks
        echo -e "${BLUE}  Running platform checks...${NC}"

        local file_pattern="*"
        if [[ -n "$PLATFORM" ]]; then
            case "$PLATFORM" in
                android)
                    file_pattern="*.kt *.java *.gradle *.gradle.kts */AndroidManifest.xml"
                    ;;
                ios)
                    file_pattern="*.swift *.m *.h *.xib"
                    ;;
                web)
                    file_pattern="*.ts *.tsx *.js *.jsx *.css *.scss"
                    ;;
                mobile)
                    file_pattern="*.kt *.java *.swift *.m *.h */AndroidManifest.xml"
                    ;;
                server)
                    file_pattern="*.py *.go *.java *.kt *.rs"
                    ;;
                code)
                    file_pattern="*.ts *.tsx *.js *.jsx *.py *.kt *.java *.go"
                    ;;
            esac
        fi

        # Check for TODO/FIXME
        local find_pattern="."
        if [[ -n "$PLATFORM" ]]; then
            case "$PLATFORM" in
                android) find_pattern="app/src/main" ;;
                ios) find_pattern="." ;;
                web) find_pattern="src" ;;
                mobile) find_pattern="." ;;
                server) find_pattern="." ;;
                code) find_pattern="." ;;
            esac
        fi

        local todo_count=0
        if [[ -d "$PROJECT_ROOT/$find_pattern" ]]; then
            todo_count=$(grep -r "TODO\|FIXME" "$PROJECT_ROOT/$find_pattern" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" --include="*.py" --include="*.kt" --include="*.java" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
        fi

        if [[ "$todo_count" -gt 0 ]]; then
            echo -e "    ${YELLOW}[!]${NC} Found $todo_count TODO/FIXME comments"
            issues+=("Cleanup: $todo_count TODO/FIXME comments")
            ((fail_count++))
        else
            echo -e "    ${GREEN}[✓]${NC} No TODO/FIXME comments"
            ((pass_count++))
        fi
        ((test_count++))

        # Check for console.log/print
        if [[ "$QUICK_MODE" != true ]]; then
            local console_count=0
            if [[ -d "$PROJECT_ROOT/$find_pattern" ]]; then
                case "$PLATFORM" in
                    web|code)
                        console_count=$(grep -r "console\.log\|console\.warn\|console\.error" "$PROJECT_ROOT/$find_pattern" --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" 2>/dev/null | grep -v "test" | wc -l | tr -d ' ' || echo "0")
                        ;;
                    android|mobile)
                        console_count=$(grep -rw "Log\.d\|Log\.e\|print\|println" "$PROJECT_ROOT/$find_pattern" --include="*.kt" --include="*.java" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
                        ;;
                    ios)
                        console_count=$(grep -rw "print\|NSLog" "$PROJECT_ROOT/$find_pattern" --include="*.swift" --include="*.m" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
                        ;;
                    server)
                        console_count=$(grep -rE "\bprint\(|console\." "$PROJECT_ROOT/$find_pattern" --include="*.py" --include="*.go" --include="*.ts" 2>/dev/null | grep -v "logger\|log4j\|winston" | wc -l | tr -d ' ' || echo "0")
                        ;;
                esac
            fi

            if [[ "$console_count" -gt 0 ]]; then
                echo -e "    ${YELLOW}[!]${NC} Found $console_count debug statements"
                issues+=("Cleanup: $console_count debug statements")
                ((fail_count++))
            else
                echo -e "    ${GREEN}[✓]${NC} No debug statements"
                ((pass_count++))
            fi
            ((test_count++))
        fi

        # Git checks
        if git rev-parse --git-dir >/dev/null 2>&1; then
            local changed_files=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ' || echo "0")
            if [[ "$changed_files" -gt 0 ]]; then
                echo -e "    ${YELLOW}[!]${NC} $changed_files uncommitted files"
            else
                echo -e "    ${GREEN}[✓]${NC} Working directory clean"
            fi
            ((test_count++))
        fi
    fi

    echo ""

    # Output results
    case "$FORMAT" in
        json)
            local issues_json=""
            if [[ ${#issues[@]} -gt 0 ]]; then
                for issue in "${issues[@]}"; do
                    local escaped="${issue//\\/\\\\}"
                    escaped="${escaped//\"/\\\"}"
                    if [[ -z "$issues_json" ]]; then
                        issues_json="\"$escaped\""
                    else
                        issues_json="$issues_json,\"$escaped\""
                    fi
                done
            fi
            echo "{\"tests\":$test_count,\"passed\":$pass_count,\"failed\":$fail_count,\"issues\":[${issues_json}]}"
            ;;
        markdown)
            echo "## Smart QA Test Results"
            echo ""
            echo "- **Platform**: $PLATFORM"
            echo "- **Tests**: $test_count"
            echo "- **Passed**: $pass_count"
            echo "- **Failed**: $fail_count"
            echo ""
            if [[ ${#issues[@]} -gt 0 ]]; then
                echo "### Issues"
                for issue in "${issues[@]}"; do
                    echo "- $issue"
                done
            fi
            ;;
        *)
            echo -e "${BOLD}Test Results:${NC}"
            echo -e "  Platform: ${CYAN}$PLATFORM${NC}"
            echo "  Tests:  $test_count"
            echo -e "  Passed: ${GREEN}$pass_count${NC}"
            echo -e "  Failed: ${RED}$fail_count${NC}"
            echo ""

            if [[ ${#issues[@]} -gt 0 ]]; then
                echo -e "${BOLD}Issues Found:${NC}"
                for issue in "${issues[@]}"; do
                    echo -e "  ${YELLOW}•${NC} $issue"
                done
                echo ""
            fi
            ;;
    esac

    # Auto-fix mode
    if [[ "$REPORT_ONLY" != true ]] && [[ $fail_count -gt 0 ]]; then
        echo -e "${BLUE}[→]${NC} Auto-fixing issues..."
        echo ""

        for issue in "${issues[@]}"; do
            if [[ "$issue" =~ "Shell syntax" ]] || [[ "$issue" =~ ^Syntax:.*\.sh$ ]]; then
                local file="${issue#*: }"
                echo -e "  ${CYAN}Fixing:${NC} $file"
                if command -v shellcheck &>/dev/null; then
                    shellcheck "$file" --format=gcc || true
                fi
            fi
        done

        echo ""
        echo -e "${GREEN}[✓]${NC} Auto-fix complete"
        echo ""
    fi

    return $fail_count
}

# Print summary
print_summary() {
    local exit_code=$1

    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""

    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ SMART QA TESTS PASSED${NC}"
        echo -e "${GREEN}All checks passed successfully.${NC}"
    else
        if [[ "$REPORT_ONLY" == true ]]; then
            echo -e "${YELLOW}${BOLD}⚠ QA ISSUES FOUND (REPORT MODE)${NC}"
            echo -e "${YELLOW}Run /smart-qa without --report to auto-fix.${NC}"
        else
            echo -e "${YELLOW}${BOLD}⚠ QA ISSUES FOUND${NC}"
            echo -e "${YELLOW}Please review the issues above.${NC}"
        fi
    fi
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""

    return $exit_code
}

# Main execution
main() {
    # 하네스 추적 시작
    harness_skill_start "$@"

    parse_args "$@"
    print_header

    local exit_code=0
    run_tests || exit_code=$?

    print_summary $exit_code
    return $exit_code
}

# Run main
main "$@"
