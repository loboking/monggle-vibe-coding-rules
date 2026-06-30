#!/bin/bash
#
# stats.sh - monggle: Pipeline Statistics
#
# Usage: /stats [options]
#
# Shows agent pipeline execution statistics:
# - Total runs, success rate
# - Verdict distribution (PASS/FIX/FAIL)
# - Agent performance (duration, success rate)
# - Recent runs
#
# New in v2.4:
# - ASCII visualization (bar charts, sparklines, timelines)
# - Log filtering (by verdict, PRD type, agent, date)
# - Web dashboard (HTML with CSS-only charts)
# - Agent execution time analysis
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

STATS_SCRIPT="${PROJECT_ROOT}/scripts/stats.py"

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    printf "${CYAN}║   %-45s║${NC}\n" "Monggle Vibe Coding - Pipeline Stats v${TOOLKIT_VERSION}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show help
show_help() {
    print_header
    echo "Usage: /stats [options]"
    echo ""
    echo "Options:"
    echo "  --verbose, -v          Show detailed statistics"
    echo "  --json                 Output as JSON"
    echo "  --web                  Generate HTML web dashboard"
    echo "  --clear                Clear all logs (use with caution)"
    echo ""
    echo "Filters:"
    echo "  --filter-verdict PASS  Filter by verdict (PASS/FIX/FAIL)"
    echo "  --filter-type feature  Filter by PRD type"
    echo "  --filter-agent scan    Filter by agent name"
    echo "  --since YYYY-MM-DD     Filter logs since date"
    echo "  --until YYYY-MM-DD     Filter logs until date"
    echo ""
    echo "Examples:"
    echo "  /stats                           # Basic statistics"
    echo "  /stats --verbose                 # Detailed with charts"
    echo "  /stats --web                     # Generate dashboard"
    echo "  /stats --filter-verdict PASS     # Only PASS verdicts"
    echo "  /stats --since 2024-01-01        # Since specific date"
    echo ""
}

# Check Python
check_python() {
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found"
        return 1
    fi
    return 0
}

# Main execution
main() {
    print_header

    # Check prerequisites
    if ! check_python; then
        exit 1
    fi

    # Check if stats script exists
    if [[ ! -f "$STATS_SCRIPT" ]]; then
        log_error "Stats script not found: $STATS_SCRIPT"
        exit 1
    fi

    # Show help for -h or --help
    if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
        show_help
        exit 0
    fi

    # Parse arguments
    local args=""

    # Pass all arguments to Python script
    while [[ $# -gt 0 ]]; do
        args="$args $1"
        shift
    done

    # Execute stats script
    if python3 "$STATS_SCRIPT" $args; then
        exit 0
    else
        log_error "Failed to retrieve statistics"
        exit 1
    fi
}

# Run main
main "$@"
