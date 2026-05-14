#!/bin/bash
#
# quick.sh - monggle: Quick hotfix
#
# Usage: /quick [prd_file]
#
# Executes a streamlined pipeline for hotfix PRDs:
# - Skips Fold agent (saves time)
# - Reduced max iterations for Patch
# - Focused on speed while maintaining quality
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
AGENT_RUNNER="${PROJECT_ROOT}/scripts/run_agent.py"
PIPELINE_CONFIG="${PROJECT_ROOT}/agents/pipeline_config.py"

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

log_step() {
    echo -e "${CYAN}[→]${NC} $1"
}

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║     Monggle Vibe Coding - Fast Track          ║${NC}"
    echo -e "${CYAN}║     Hotfix Pipeline (Skip Fold)               ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Check Python
check_python() {
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found"
        return 1
    fi

    local python_version
    python_version=$(python3 --version 2>&1 | awk '{print $2}')
    log_info "Python version: $python_version"
    return 0
}

# Find or validate PRD file
find_prd() {
    local prd_file="$1"

    if [[ -n "$prd_file" ]]; then
        # Use provided file
        if [[ ! -f "$prd_file" ]]; then
            log_error "PRD file not found: $prd_file"
            return 1
        fi
    else
        # Auto-detect most recent hotfix PRD
        local prd_dir="${PROJECT_ROOT}/prd"

        if [[ ! -d "$prd_dir" ]]; then
            log_error "prd/ directory not found"
            return 1
        fi

        # Find hotfix PRDs
        prd_file=$(find "$prd_dir" -maxdepth 1 -name "*hotfix*.md" 2>/dev/null | sort -r | head -1)

        if [[ -z "$prd_file" ]]; then
            log_warning "No hotfix PRD found. Looking for any PRD..."
            prd_file=$(find "$prd_dir" -maxdepth 1 -name "*.md" 2>/dev/null | sort -r | head -1)
        fi

        if [[ -z "$prd_file" ]]; then
            log_error "No PRD files found in prd/"
            log_info "Create a PRD first: cp prd/hotfix.md prd/hotfix-my-fix.md"
            return 1
        fi
    fi

    echo "$prd_file"
}

# Validate PRD is hotfix type
validate_hotfix() {
    local prd_file="$1"

    # Check filename
    local filename
    filename=$(basename "$prd_file" | tr '[:upper:]' '[:lower:]')

    if [[ "$filename" != *"hotfix"* ]]; then
        log_warning "This doesn't appear to be a hotfix PRD"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi

    return 0
}

# Execute fast-track pipeline
execute_pipeline() {
    local prd_file="$1"

    log_step "Starting fast-track pipeline..."
    log_info "PRD: $prd_file"

    # Execute with auto-detected agents
    if [[ -f "$AGENT_RUNNER" ]]; then
        python3 "$AGENT_RUNNER" "$prd_file" \
            --type hotfix \
            --skip-fold
    else
        log_error "Agent runner not found: $AGENT_RUNNER"
        return 1
    fi
}

# Main execution
main() {
    print_header

    # Check prerequisites
    if ! check_python; then
        exit 1
    fi

    # Find PRD
    local prd_file
    prd_file=$(find_prd "$1")

    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    log_success "Using PRD: $prd_file"

    # Validate hotfix
    if ! validate_hotfix "$prd_file"; then
        log_info "Cancelled"
        exit 0
    fi

    # Show pipeline info
    echo ""
    log_info "Fast-track pipeline:"
    echo "  ✓ Gate  - PRD validation (minimal)"
    echo "  ✓ Scan  - Impact analysis (focused)"
    echo "  ✗ Fold  - SKIPPED (time savings)"
    echo "  ✓ Verdict - Decision (PASS/FIX/FAIL)"
    echo "  ✓ Patch - Implementation (max 2 iterations)"
    echo "  ✓ Trace - Execution log"
    echo ""

    # Confirm
    read -p "Proceed? (Y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi

    # Execute
    echo ""
    if execute_pipeline "$prd_file"; then
        log_success "Fast-track pipeline completed!"
        exit 0
    else
        log_error "Pipeline failed"
        exit 1
    fi
}

# Run main
main "$@"
