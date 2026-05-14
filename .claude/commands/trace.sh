#!/bin/bash
#
# trace.sh - monggle: Pipeline Trace
#
# View and analyze Vibe Coding pipeline logs.
# Shows validation results, agent outputs, and execution traces.
#
# Usage: /trace [options]
# Examples:
#   /trace                    # Show latest logs
#   /trace --list             # List all log files
#   /trace --tail             # Tail latest log
#   /trace --errors           # Show only errors
#   /trace 20250210-120000    # Show specific log
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

# Configuration
LOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/logs"

# Flags
SHOW_LIST=false
SHOW_TAIL=false
SHOW_ERRORS=false
SPECIFIC_LOG=""

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list|-l)
                SHOW_LIST=true
                shift
                ;;
            --tail|-t)
                SHOW_TAIL=true
                shift
                ;;
            --errors|-e)
                SHOW_ERRORS=true
                shift
                ;;
            -*)
                echo -e "${RED}Unknown option: $1${NC}"
                echo "Usage: /trace [--list] [--tail] [--errors] [log_id]"
                return 1
                ;;
            *)
                SPECIFIC_LOG="$1"
                shift
                ;;
        esac
    done
}

# Print header
print_header() {
    clear
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║     Vibe Coding Log Tracer           ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════╝${NC}"
    echo ""
}

# List all log files
list_logs() {
    echo -e "${BOLD}Available Log Files:${NC}"
    echo ""

    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${YELLOW}No logs directory found${NC}"
        return 0
    fi

    local log_files=()
    while IFS= read -r -d '' file; do
        log_files+=("$file")
    done < <(find "$LOG_DIR" -type f -name "*.log" -print0 2>/dev/null | sort -z -r)

    if [[ ${#log_files[@]} -eq 0 ]]; then
        echo -e "${YELLOW}No log files found${NC}"
        return 0
    fi

    local count=0
    for file in "${log_files[@]}"; do
        count=$((count + 1))
        local filename
        filename=$(basename "$file")
        local timestamp
        timestamp=$(date -r "$file" +"%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")
        local size
        size=$(du -h "$file" 2>/dev/null | cut -f1 || echo "Unknown")

        # Extract log ID from filename
        local log_id
        log_id=$(echo "$filename" | sed 's/.*-\([0-9]*-[0-9]*\).*/\1/')

        printf "  ${CYAN}%2d${NC}. ${BOLD}%s${NC} (${YELLOW}%s${NC}, ${BLUE}%s${NC})\n" \
            "$count" "$filename" "$timestamp" "$size"
    done

    echo ""
    echo -e "Use ${BOLD}/trace <log_id>${NC} to view specific log"
    echo ""
}

# Show latest log
show_latest() {
    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${RED}No logs directory found${NC}"
        return 1
    fi

    local latest_log
    latest_log=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | sort -r | head -1)

    if [[ -z "$latest_log" ]]; then
        echo -e "${YELLOW}No log files found${NC}"
        return 0
    fi

    echo -e "${BOLD}Latest Log:${NC} ${CYAN}$(basename "$latest_log")${NC}"
    echo ""
    cat "$latest_log"
}

# Tail latest log
tail_log() {
    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${RED}No logs directory found${NC}"
        return 1
    fi

    local latest_log
    latest_log=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | sort -r | head -1)

    if [[ -z "$latest_log" ]]; then
        echo -e "${YELLOW}No log files found${NC}"
        return 0
    fi

    echo -e "${BOLD}Tailing Log:${NC} ${CYAN}$(basename "$latest_log")${NC}"
    echo -e "${YELLOW}Press Ctrl+C to exit${NC}"
    echo ""
    tail -f "$latest_log"
}

# Show errors only
show_errors() {
    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${RED}No logs directory found${NC}"
        return 1
    fi

    local latest_log
    latest_log=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | sort -r | head -1)

    if [[ -z "$latest_log" ]]; then
        echo -e "${YELLOW}No log files found${NC}"
        return 0
    fi

    echo -e "${BOLD}Errors from:${NC} ${CYAN}$(basename "$latest_log")${NC}"
    echo ""

    local errors
    errors=$(grep -i "\[fail\]\|\[error\]" "$latest_log" 2>/dev/null || true)

    if [[ -z "$errors" ]]; then
        echo -e "${GREEN}No errors found${NC}"
    else
        echo "$errors" | while IFS= read -r line; do
            echo -e "${RED}$line${NC}"
        done
    fi
    echo ""
}

# Show specific log
show_specific_log() {
    local log_id="$1"

    if [[ ! -d "$LOG_DIR" ]]; then
        echo -e "${RED}No logs directory found${NC}"
        return 1
    fi

    # Find log by ID
    local log_file
    log_file=$(find "$LOG_DIR" -type f -name "*-${log_id}.log" 2>/dev/null | head -1)

    if [[ -z "$log_file" ]]; then
        echo -e "${RED}Log not found: $log_id${NC}"
        echo ""
        echo "Use ${BOLD}/trace --list${NC} to see available logs"
        return 1
    fi

    echo -e "${BOLD}Log File:${NC} ${CYAN}$(basename "$log_file")${NC}"
    echo ""
    cat "$log_file"
}

# Print stats
print_stats() {
    if [[ ! -d "$LOG_DIR" ]]; then
        return 0
    fi

    local total_logs
    total_logs=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | wc -l | tr -d ' ')

    local total_size
    total_size=$(du -sh "$LOG_DIR" 2>/dev/null | cut -f1 || echo "Unknown")

    echo ""
    echo -e "${BOLD}Statistics:${NC}"
    echo "  Total Logs: ${CYAN}${total_logs}${NC}"
    echo "  Total Size: ${CYAN}${total_size}${NC}"
}

# Main execution
main() {
    # Parse arguments
    parse_args "$@" || return $?

    # Print header
    print_header

    # Execute based on flags
    if [[ "$SHOW_LIST" == true ]]; then
        list_logs
    elif [[ "$SHOW_TAIL" == true ]]; then
        tail_log
    elif [[ "$SHOW_ERRORS" == true ]]; then
        show_errors
        print_stats
    elif [[ -n "$SPECIFIC_LOG" ]]; then
        show_specific_log "$SPECIFIC_LOG"
        print_stats
    else
        show_latest
        print_stats
    fi

    return 0
}

# Run main
main "$@"
