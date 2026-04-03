#!/bin/bash
#
# mode.sh - Project Mode Management
#
# Usage: /mode [solo|team]
#
# Manage project mode:
# - solo: PRD optional for quick iterations
# - team: PRD required for quality assurance
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
CONFIG_FILE="$PROJECT_ROOT/monggle.config.yaml"

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

# Show current mode
show_mode() {
    if [[ -f "$CONFIG_FILE" ]]; then
        local mode
        mode=$(grep "^mode:" "$CONFIG_FILE" | awk '{print $2}' | tr -d '"')

        if [[ -n "$mode" ]]; then
            local prd_required
            prd_required=$(grep "^prd_required:" "$CONFIG_FILE" | awk '{print $2}')

            echo ""
            echo -e "${CYAN}Current Mode: ${mode^^}${NC}"
            echo ""

            if [[ "$prd_required" == "true" ]]; then
                echo -e "${GREEN}✓ PRD is REQUIRED for all development work${NC}"
            else
                echo -e "${YELLOW}○ PRD is OPTIONAL (but recommended for complex features)${NC}"
            fi
            echo ""
        else
            echo "solo (default)"
        fi
    else
        echo "solo (default - config file not found)"
    fi
}

# Set mode
set_mode() {
    local new_mode="$1"

    if [[ "$new_mode" != "solo" ]] && [[ "$new_mode" != "team" ]]; then
        log_error "Invalid mode: $new_mode (use: solo | team)"
        exit 1
    fi

    # Create config directory if needed
    mkdir -p "$(dirname "$CONFIG_FILE")"

    # Write config
    cat > "$CONFIG_FILE" <<EOF
# Monggle Vibe Coding Rules - Project Configuration
# This file should be committed to Git for team-wide settings

# Project Mode
# solo: PRD optional for quick iterations (default)
# team: PRD required for quality assurance
mode: $new_mode

# Auto-calculated based on mode
prd_required: $([ "$new_mode" == "team" ] && echo "true" || echo "false")

# Enabled agents (all by default)
agents_enabled:
  - gate
  - scan
  - fold
  - verdict
  - patch
  - trace
EOF

    log_success "Mode set to: $new_mode"

    # Sync rules
    if [[ -f "${PROJECT_ROOT}/scripts/sync_rules.py" ]]; then
        log_info "Syncing rules..."
        python3 "${PROJECT_ROOT}/scripts/sync_rules.py" > /dev/null 2>&1 || true
    fi

    # Show implications
    echo ""
    if [[ "$new_mode" == "team" ]]; then
        echo -e "${GREEN}Team Mode Activated:${NC}"
        echo "  • PRD is REQUIRED for all development work"
        echo "  • Quality assurance through documentation"
        echo "  • Use /quick for urgent hotfixes only"
    else
        echo -e "${YELLOW}Solo Mode Activated:${NC}"
        echo "  • PRD is OPTIONAL (but recommended)"
        echo "  • Quick iterations and experiments allowed"
        echo "  • PRD still recommended for complex features"
    fi
    echo ""
}

# Main entry point
main() {
    case "${1:-}" in
        solo)
            set_mode "solo"
            ;;
        team)
            set_mode "team"
            ;;
        "")
            show_mode
            ;;
        *)
            echo "Usage: /mode [solo|team]"
            echo ""
            echo "Arguments:"
            echo "  (none)  Show current mode"
            echo "  solo    Set solo mode (PRD optional)"
            echo "  team    Set team mode (PRD required)"
            echo ""
            exit 1
            ;;
    esac
}

# Run main
main "$@"
