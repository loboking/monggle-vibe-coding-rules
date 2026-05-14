#!/bin/bash
#
# gate.sh - monggle: PRD Validation Command
#
# Validates PRD file existence, format, and required sections.
# Part of the Vibe Coding Rules enforcement system.
#
# Usage: /gate [prd_file]
# Examples:
#   /gate                    # Auto-detect PRD
#   /gate prd/feature.md     # Validate specific file
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_FILE="${SCRIPT_DIR}/../hooks/pre-tool-use.sh"

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     PRD Gate - Validation Check       ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# Print result
print_result() {
    local exit_code=$1

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ PRD VALIDATION PASSED${NC}"
        echo -e "${GREEN}You may proceed with implementation.${NC}"
    else
        echo -e "${RED}${BOLD}✗ PRD VALIDATION FAILED${NC}"
        echo -e "${YELLOW}Please fix the PRD before proceeding.${NC}"
    fi
    echo ""

    return $exit_code
}

# Main execution
main() {
    print_header

    # Check if hook exists
    if [[ ! -f "$HOOK_FILE" ]]; then
        echo -e "${RED}Error: Hook file not found: $HOOK_FILE${NC}"
        return 1
    fi

    # Make sure hook is executable
    chmod +x "$HOOK_FILE"

    # Run the hook with provided arguments
    if "$HOOK_FILE" "$@"; then
        print_result 0
    else
        print_result 1
    fi
}

# Run main
main "$@"
