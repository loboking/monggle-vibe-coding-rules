#!/bin/bash
#
# pipeline.sh - monggle: Agent Pipeline
#
# Executes the full Vibe Coding agent pipeline:
# 1. Gate (PRD validation)
# 2. Scan (codebase analysis)
# 3. Fold (requirements breakdown)
# 4. Verdict (validation)
# 5. Patch (implementation) - if Verdict is PASS
# 6. Trace (logging)
#
# Usage: /pipeline [prd_file] [options]
# Examples:
#   /pipeline                    # Auto-detect PRD, full run
#   /pipeline prd/feature.md     # Specific PRD
#   /pipeline --dry-run          # Show plan only
#   /pipeline --verbose          # Detailed logging
#   /pipeline --retry 3          # Retry failed agents up to 3 times
#

set -euo pipefail

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
RUN_AGENT="${PROJECT_ROOT}/scripts/run_agent.py"
HOOK_FILE="${SCRIPT_DIR}/../hooks/pre-tool-use.sh"
LOOP_DETECTION_LIB="${SCRIPT_DIR}/../lib/loop_detection.sh"

# Source loop detection library
if [[ -f "$LOOP_DETECTION_LIB" ]]; then
    source "$LOOP_DETECTION_LIB"
else
    # Create stub functions if library not found
    loop_detect_init() { :; }
    loop_check_file() { return 0; }
    loop_record_attempt() { :; }
    loop_reset_file() { :; }
    loop_check_prd() { return 0; }
    loop_record_prd_attempt() { :; }
fi

# Source TDD enforcer
TDD_ENFORCER_LIB="${SCRIPT_DIR}/../lib/tdd_enforcer.sh"
if [[ -f "$TDD_ENFORCER_LIB" ]]; then
    source "$TDD_ENFORCER_LIB"
else
    tdd_pre_patch_hook() { return 0; }
fi

# Source git helper for team mode checks
GIT_HELPER_LIB="${SCRIPT_DIR}/../lib/git_helper.sh"
if [[ -f "$GIT_HELPER_LIB" ]]; then
    source "$GIT_HELPER_LIB"
else
    is_behind_origin() { return 1; }
fi

# Flags (v2.4)
DRY_RUN=false
SKIP_VALIDATION=false
USE_PYTHON_AGENT=false
VERBOSE=false
RETRY_COUNT=0
PARALLEL_MODE=false

# Parse arguments (v2.4)
parse_args() {
    local prd_file=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --python)
                USE_PYTHON_AGENT=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --retry)
                if [[ $# -ge 2 && "$2" != -* ]]; then
                    RETRY_COUNT="$2"
                    shift 2
                else
                    RETRY_COUNT=1
                    shift
                fi
                ;;
            --parallel)
                PARALLEL_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}" >&2
                echo "Use --help to see available options" >&2
                return 1
                ;;
            *)
                prd_file="$1"
                shift
                ;;
        esac
    done

    echo "$prd_file"
}

# Show help (v2.4)
show_help() {
    echo ""
    echo -e "${CYAN}${BOLD}/pipeline - Agent Pipeline Executor v3.4${NC}"
    echo ""
    echo "Usage:"
    echo "  /pipeline [prd_file] [options]"
    echo ""
    echo "Options:"
    echo "  --dry-run              Show execution plan without running"
    echo "  --skip-validation      Skip gate validation"
    echo "  --verbose, -v          Enable detailed logging"
    echo "  --retry <n>            Retry failed agents up to n times (default: 1)"
    echo "  --parallel             Run independent agents in parallel (experimental)"
    echo "  --python               Force Python agent execution"
    echo "  -h, --help             Show this help"
    echo ""
    echo "Examples:"
    echo "  /pipeline prd/feature.md"
    echo "  /pipeline --verbose --retry 3"
    echo "  /pipeline --dry-run"
    echo ""
}

# Print header (v2.4)
print_header() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║   Vibe Coding Agent Pipeline v3.4            ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check Python availability
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        echo -e "${YELLOW}Warning: Python not found, using fallback mode${NC}"
        return 1
    fi

    # Check version
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
        echo -e "${YELLOW}Warning: Python 3.8+ required, found $PYTHON_VERSION${NC}"
        echo -e "${YELLOW}Using fallback mode${NC}"
        return 1
    fi

    return 0
}

# Find PRD file
find_prd_file() {
    local specified="${1:-}"

    if [[ -n "$specified" ]]; then
        if [[ "$specified" != /* ]]; then
            echo "${PROJECT_ROOT}/${specified}"
        else
            echo "$specified"
        fi
        return 0
    fi

    # Auto-detect: find latest PRD
    local prd_dir="${PROJECT_ROOT}/prd"

    if [[ ! -d "$prd_dir" ]]; then
        echo ""
        return 1
    fi

    # Find latest modified .md file (portable)
    local latest
    local latest_time=0

    # Use find with ls -T for portability (works on most Unix-like systems)
    for f in "$prd_dir"/*.md; do
        if [[ -f "$f" ]]; then
            # Get modification time in seconds (portable)
            local mtime
            if [[ "$OSTYPE" == darwin* ]]; then
                # macOS/BSD stat
                mtime=$(stat -f "%m" "$f" 2>/dev/null || echo "0")
            else
                # GNU stat
                mtime=$(stat -c "%Y" "$f" 2>/dev/null || echo "0")
            fi

            if [[ "$mtime" -gt "$latest_time" ]]; then
                latest_time="$mtime"
                latest="$f"
            fi
        fi
    done

    echo "$latest"
}

# Print pipeline plan (v2.4)
print_plan() {
    local prd_file="$1"

    echo -e "${BOLD}Pipeline Plan:${NC}"
    echo ""

    # Print stages with icons
    echo -e "  ${GREEN}○${NC} gate       - PRD validation"
    echo -e "  ${GREEN}○${NC} scan       - Codebase analysis"
    echo -e "  ${GREEN}○${NC} fold       - Requirements synthesis"
    echo -e "  ${GREEN}○${NC} verdict    - Final decision"
    echo -e "  ${GREEN}○${NC} patch      - Implementation (if PASS)"
    echo -e "  ${GREEN}○${NC} trace      - Logging"

    echo ""
    echo -e "${BOLD}Configuration:${NC}"
    echo "  PRD File: ${prd_file:-Auto-detect}"
    if [[ "$USE_PYTHON_AGENT" == true ]]; then
        echo "  Mode: Python Agent"
    else
        echo "  Mode: Bash Fallback"
    fi
    echo "  Dry Run: ${DRY_RUN}"
    echo "  Skip Validation: ${SKIP_VALIDATION}"
    echo "  Verbose: ${VERBOSE}"
    echo "  Retry Count: ${RETRY_COUNT}"
    echo "  Parallel Mode: ${PARALLEL_MODE}"

    # Show warnings for experimental features
    if [[ "$PARALLEL_MODE" == true ]]; then
        echo ""
        echo -e "${YELLOW}  ⚠ Warning: Parallel mode is experimental${NC}"
    fi

    echo ""
}

# Run Python agent pipeline (v2.4)
run_python_pipeline() {
    local prd_file="$1"

    local args=("$prd_file")

    if [[ "$SKIP_VALIDATION" == true ]]; then
        args+=(--skip-gate)
    fi

    if [[ "$VERBOSE" == true ]]; then
        args+=(--verbose)
    fi

    if [[ "$RETRY_COUNT" -gt 0 ]]; then
        args+=(--retry "$RETRY_COUNT")
    fi

    if [[ "$PARALLEL_MODE" == true ]]; then
        args+=(--parallel)
    fi

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}${BOLD}DRY RUN MODE - No actual execution${NC}"
        echo ""
        return 0
    fi

    # Execute Python runner
    "$PYTHON_CMD" "$RUN_AGENT" "${args[@]}"
    return $?
}

# Run fallback pipeline (bash only)
run_fallback_pipeline() {
    local prd_file="$1"
    local exit_code=0

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}${BOLD}DRY RUN MODE - No actual execution${NC}"
        echo ""
        return 0
    fi

    # 1. Gate
    echo -e "${BLUE}[→]${NC} Running gate..."
    if [[ "$SKIP_VALIDATION" == true ]] || [[ ! -f "$HOOK_FILE" ]]; then
        echo -e "${GREEN}[✓]${NC} gate skipped"
    else
        if "$HOOK_FILE" "$prd_file"; then
            echo -e "${GREEN}[✓]${NC} gate passed"
        else
            echo -e "${RED}[✗]${NC} gate failed"
            return 1
        fi
    fi

    # 2. Scan (placeholder)
    echo -e "${BLUE}[→]${NC} Running scan (Python agent recommended)..."
    echo -e "${YELLOW}[!]${NC} scan skipped (install Python 3.8+ for full functionality)"

    # 3. Fold (placeholder)
    echo -e "${BLUE}[→]${NC} Running fold (Python agent recommended)..."
    echo -e "${YELLOW}[!]${NC} fold skipped (install Python 3.8+ for full functionality)"

    # 4. Verdict (placeholder)
    echo -e "${BLUE}[→]${NC} Running verdict (Python agent recommended)..."
    echo -e "${YELLOW}[!]${NC} verdict skipped (install Python 3.8+ for full functionality)"

    # Summary
    echo ""
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Limited functionality: Install Python 3.8+ for full pipeline${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════${NC}"
    echo ""

    return 0
}

# Print summary
print_summary() {
    local exit_code=$1
    local prd_file="$2"

    echo ""

    # Record result in loop detection
    if [[ $exit_code -eq 0 ]]; then
        loop_record_attempt "$prd_file" "success"
        loop_record_prd_attempt "$prd_file" "success" "complete"
        echo -e "${GREEN}${BOLD}✓ PIPELINE COMPLETED${NC}"
        echo ""
        echo -e "${GREEN}Check the results above.${NC}"
    else
        loop_record_attempt "$prd_file" "failure"
        loop_record_prd_attempt "$prd_file" "failure" "patch"
        echo -e "${RED}${BOLD}✗ PIPELINE FAILED${NC}"
        echo ""
        echo -e "${YELLOW}Please check the errors above and fix before proceeding.${NC}"

        # Show loop status if multiple failures
        local file_status=$(loop_get_status "$prd_file")
        if [[ "$file_status" =~ Consecutive\ Failures:\ [2-9] ]]; then
            echo ""
            echo -e "${YELLOW}⚠ Warning: Multiple consecutive failures detected${NC}"
            echo "$file_status"
        fi

        # Check PRD loop
        if loop_is_prd_in_loop "$prd_file"; then
            echo ""
            echo -e "${RED}⚠ PRD 루프 감지: 3회 연속 실패${NC}"
            echo "   /prd --update 로 PRD를 수정하세요"
        fi
    fi
    echo ""
}

# ═══════════════════════════════════════════════════════════════════════════
# Team Mode: Pre-pipeline Git Sync Check (v3.0)
# ═══════════════════════════════════════════════════════════════════════════

pre_pipeline_git_check() {
    if [[ "$SKIP_VALIDATION" == true ]]; then
        return 0
    fi

    echo -e "${BLUE}[→]${NC} Git 동기화 확인 중..."

    # Git 저장소 확인
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        echo -e "${YELLOW}[!]${NC} Git 저장소가 아닙니다. 건너뜀니다."
        return 0
    fi

    # 원격 저장소 확인
    if ! git remote get-url origin >/dev/null 2>&1; then
        echo -e "${YELLOW}[!]${NC} 원격 저장소가 없습니다. 건너뜀니다."
        return 0
    fi

    # git fetch
    if ! git fetch origin >/dev/null 2>&1; then
        echo -e "${YELLOW}[!]${NC} git fetch 실패. 네트워크를 확인하세요."
        return 0  # 실패해도 진행
    fi

    # 뒤처짐 확인
    local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "HEAD")
    local local_commit=$(git rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null)

    if [[ "$local_commit" != "$remote_commit" ]] && [[ -n "$remote_commit" ]]; then
        echo ""
        echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${YELLOW}║  ⚠️ 원본에 새로운 변경사항이 있습니다                        ║${NC}"
        echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo "  현재 브랜치: ${CYAN}${current_branch}${NC}"
        echo ""
        echo "다음 옵션 중 선택:"
        echo "  1. ${CYAN}/update${NC}    - 동기화 후 재시도 (권장)"
        echo "  2. ${CYAN}/update --auto${NC} - 자동 동기화"
        echo "  3. --skip-validation로 강제 진행"
        echo ""
        return 1
    fi

    echo -e "${GREEN}[✓]${NC} 최신 상태입니다"
    return 0
}

# Main execution
main() {
    # Parse arguments
    local prd_file
    prd_file=$(parse_args "$@")

    # Print header
    print_header

    # Check Python if not explicitly disabled
    if [[ "$USE_PYTHON_AGENT" == false ]] && check_python; then
        USE_PYTHON_AGENT=true
    fi

    # Find PRD if not specified
    if [[ -z "$prd_file" ]]; then
        prd_file=$(find_prd_file)
        if [[ -z "$prd_file" ]]; then
            echo -e "${RED}Error: No PRD file found${NC}"
            echo ""
            echo "Please create a PRD first:"
            echo "  cp prd/feature.md prd/feature-your-feature.md"
            echo ""
            return 1
        fi
    fi

    # Check PRD exists
    if [[ ! -f "$prd_file" ]]; then
        echo -e "${RED}Error: PRD file not found: $prd_file${NC}"
        return 1
    fi

    echo -e "${CYAN}Using PRD: ${prd_file}${NC}"
    echo ""

    # Team Mode: Git sync check (v3.0)
    if ! pre_pipeline_git_check; then
        echo -e "${RED}Pipeline cancelled: 먼저 /update를 실행하세요${NC}"
        echo "또는 --skip-validation으로 강제 진행 (권장하지 않음)"
        return 1
    fi

    # Initialize loop detection
    loop_detect_init

    # Check for PRD-level doom loop (v3.0)
    if ! loop_check_prd "$prd_file"; then
        echo ""
        echo -e "${YELLOW}다음 옵션 중 선택:${NC}"
        echo "  1. ${CYAN}/prd --update${NC} - PRD 수정"
        echo "  2. --force로 강제 진행"
        echo ""
        if [[ "${@}" != *"--force"* ]]; then
            echo -e "${CYAN}Pipeline cancelled${NC}"
            return 1
        fi
        loop_reset_prd "$prd_file"
    fi

    # Check for file-level doom loop (기존)
    if ! loop_check_file "$prd_file"; then
        echo ""
        echo -e "${YELLOW}To proceed anyway:${NC}"
        echo "  1. Fix the root cause and retry"
        echo "  2. Or use --skip-validation to bypass (not recommended)"
        echo ""
        if [[ "${@}" != *"--skip-validation"* ]]; then
            if [[ -t 0 ]]; then
                local reply=""
                read -p "Continue anyway? (y/N): " -n 1 -r reply || reply=""
                echo ""
                if [[ ! $reply =~ ^[Yy]$ ]]; then
                    echo -e "${CYAN}Pipeline cancelled${NC}"
                    return 1
                fi
            else
                echo -e "${CYAN}Pipeline cancelled (non-interactive; use --skip-validation to bypass)${NC}"
                return 1
            fi
        fi
        # Reset loop count to allow retry
        loop_reset_file "$prd_file"
    fi

    # Print plan
    print_plan "$prd_file"

    # Run pipeline
    local exit_code=0

    if [[ "$USE_PYTHON_AGENT" == true ]]; then
        run_python_pipeline "$prd_file"
        exit_code=$?
    else
        run_fallback_pipeline "$prd_file"
        exit_code=$?
    fi

    # Print summary
    print_summary $exit_code "$prd_file"

    return $exit_code
}

# Run main
main "$@"
