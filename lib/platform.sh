#!/bin/bash
#
# platform.sh - Platform-specific compatibility layer
#
# Provides cross-platform functions for macOS and Linux
#

# Detect OS
get_os() {
    local uname_s
    uname_s=$(uname -s)
    case "$uname_s" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
        *)      echo "unknown" ;;
    esac
}

# Portable sed -i (macOS requires empty string after -i)
sed_inplace() {
    local expr="$1"
    local file="$2"

    if [[ "$(get_os)" == "macos" ]]; then
        sed -i '' "$expr" "$file"
    else
        sed -i "$expr" "$file"
    fi
}

# Portable stat (macOS uses different flags)
get_file_mtime() {
    local file="$1"

    if [[ "$(get_os)" == "macos" ]]; then
        stat -f "%m" "$file" 2>/dev/null || echo "0"
    else
        stat -c "%Y" "$file" 2>/dev/null || echo "0"
    fi
}

get_file_size() {
    local file="$1"

    if [[ "$(get_os)" == "macos" ]]; then
        stat -f "%z" "$file" 2>/dev/null || echo "0"
    else
        stat -c "%s" "$file" 2>/dev/null || echo "0"
    fi
}

# Portable timeout (macOS needs gtimeout from coreutils)
run_timeout() {
    local timeout_sec="$1"
    shift

    if command -v gtimeout &>/dev/null; then
        gtimeout "$timeout_sec" "$@"
    elif command -v timeout &>/dev/null; then
        timeout "$timeout_sec" "$@"
    else
        # Fallback: no timeout
        "$@"
    fi
}

# Check if running on macOS
is_macos() {
    [[ "$(get_os)" == "macos" ]]
}

# Check if running on Linux
is_linux() {
    [[ "$(get_os)" == "linux" ]]
}
