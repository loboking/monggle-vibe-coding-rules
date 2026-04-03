#!/bin/bash
#
# /pipeline - Agent Pipeline Executor v2.4
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
                RETRY_COUNT="${2:-1}"
                shift 2
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
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Use --help to see available options"
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
    echo -e "${CYAN}${BOLD}/pipeline - Agent Pipeline Executor v2.4${NC}"
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
    echo -e "${CYAN}${BOLD}║   Vibe Coding Agent Pipeline v2.4            ║${NC}"
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
    local specified="$1"

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

    # Find latest modified .md file
    local latest
    latest=$(find "$prd_dir" -maxdepth 1 -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)

    if [[ -z "$latest" ]]; then
        # Try macOS/BSD find
        latest=$(find "$prd_dir" -maxdepth 1 -name "*.md" -type f 2>/dev/null | while read -r f; do stat -f "%m %N" "$f"; done | sort -n | tail -1 | cut -d' ' -f2-)
    fi

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
    echo "  Mode: ${USE_PYTHON_AGENT:+Python Agent}${USE_PYTHON_AGENT:-Bash Fallback}"
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

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ PIPELINE COMPLETED${NC}"
        echo ""
        echo -e "${GREEN}Check the results above.${NC}"
    else
        echo -e "${RED}${BOLD}✗ PIPELINE FAILED${NC}"
        echo ""
        echo -e "${YELLOW}Please check the errors above and fix before proceeding.${NC}"
    fi
    echo ""
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
    print_summary $exit_code

    return $exit_code
}

# Run main
main "$@"
