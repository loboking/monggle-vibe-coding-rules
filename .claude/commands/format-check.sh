#!/bin/bash
#
# format-check.sh - Code format checker (no auto-fix)
#
# Usage: /format-check [options]
#
# Options:
#   --diff        Show diff instead of just checking
#   --json        Output in JSON format
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
SHOW_DIFF=0
JSON_OUTPUT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --diff)
            SHOW_DIFF=1
            shift
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -h|--help)
            echo "Usage: /format-check [options]"
            echo ""
            echo "Options:"
            echo "  --diff        Show diff of formatting issues"
            echo "  --json        Output in JSON format"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "Format Checker - Project Type: $PROJECT_TYPE"

# Run format checker based on project type
run_format_check() {
    local project_type="$1"
    local exit_code=0

    case "$project_type" in
        python)
            check_python_format
            exit_code=$?
            ;;
        typescript|nodejs)
            check_nodejs_format
            exit_code=$?
            ;;
        go)
            check_go_format
            exit_code=$?
            ;;
        rust)
            check_rust_format
            exit_code=$?
            ;;
        java)
            check_java_format
            exit_code=$?
            ;;
        ruby)
            check_ruby_format
            exit_code=$?
            ;;
        *)
            log_warn "No format checker configured for: $project_type"
            return 1
            ;;
    esac

    return $exit_code
}

# Python format check
check_python_format() {
    log_step "Checking Python code formatting..."

    local has_issues=0

    # black - code formatter
    if command_exists black; then
        log_info "Checking with black..."
        if [[ $SHOW_DIFF -eq 1 ]]; then
            if black --diff . 2>/dev/null | grep -q "^---"; then
                has_issues=1
            fi
        else
            if ! black --check . 2>/dev/null; then
                has_issues=1
                log_warn "Black found formatting issues"
            fi
        fi
    else
        log_warn "black not found. Install: pip install black"
    fi

    # isort - import sorting
    if command_exists isort; then
        log_info "Checking import sorting with isort..."
        if [[ $SHOW_DIFF -eq 1 ]]; then
            isort --diff . 2>/dev/null || true
        else
            if ! isort --check-only . 2>/dev/null; then
                has_issues=1
                log_warn "isort found import ordering issues"
            fi
        fi
    else
        log_warn "isort not found. Install: pip install isort"
    fi

    return $has_issues
}

# Node.js/TypeScript format check
check_nodejs_format() {
    log_step "Checking Node.js/TypeScript code formatting..."

    local has_issues=0

    # Prettier
    if command_exists prettier; then
        log_info "Checking with prettier..."
        if [[ $SHOW_DIFF -eq 1 ]]; then
            prettier --list-different . || has_issues=1
        else
            if ! prettier --check . 2>/dev/null; then
                has_issues=1
                log_warn "Prettier found formatting issues"
            fi
        fi
    elif [[ -f "node_modules/.bin/prettier" ]]; then
        log_info "Checking with local prettier..."
        if [[ $SHOW_DIFF -eq 1 ]]; then
            ./node_modules/.bin/prettier --list-different . || has_issues=1
        else
            if ! ./node_modules/.bin/prettier --check . 2>/dev/null; then
                has_issues=1
                log_warn "Prettier found formatting issues"
            fi
        fi
    else
        log_warn "Prettier not found. Install: npm install -D prettier"
    fi

    return $has_issues
}

# Go format check
check_go_format() {
    log_step "Checking Go code formatting..."

    local has_issues=0

    if command_exists gofmt; then
        log_info "Checking with gofmt..."
        local unformatted
        unformatted=$(gofmt -l . 2>/dev/null || true)

        if [[ -n "$unformatted" ]]; then
            has_issues=1
            log_warn "Go files need formatting:"
            echo "$unformatted"

            if [[ $SHOW_DIFF -eq 1 ]]; then
                echo "$unformatted" | while read -r file; do
                    echo ""
                    echo "--- $file ---"
                    gofmt -d "$file"
                done
            fi
        else
            log_success "All Go files are properly formatted"
        fi
    fi

    return $has_issues
}

# Rust format check
check_rust_format() {
    log_step "Checking Rust code formatting..."

    local has_issues=0

    if command_exists cargo; then
        log_info "Checking with cargo fmt..."
        if ! cargo fmt --check 2>/dev/null; then
            has_issues=1
            log_warn "Rust files need formatting"
        else
            log_success "All Rust files are properly formatted"
        fi
    fi

    return $has_issues
}

# Java format check
check_java_format() {
    log_step "Checking Java code formatting..."

    local has_issues=0

    # spotless - code formatter
    if [[ -f "gradlew" ]]; then
        log_info "Checking with spotless..."
        if ./gradlew spotlessCheck 2>/dev/null; then
            log_success "All Java files are properly formatted"
        else
            has_issues=1
            log_warn "Java files need formatting"
        fi
    fi

    # google-java-format
    if command_exists google-java-format; then
        log_info "Checking with google-java-format..."
        local unformatted
        unformatted=$(find . -name "*.java" -exec google-java-format --set-exit-if-changed {} \; 2>/dev/null || true)

        if [[ -n "$unformatted" ]]; then
            has_issues=1
            log_warn "Java files need formatting"
        fi
    fi

    return $has_issues
}

# Ruby format check
check_ruby_format() {
    log_step "Checking Ruby code formatting..."

    local has_issues=0

    if command_exists rubocop; then
        log_info "Checking with rubocop..."
        if ! rubocop --format simple 2>/dev/null; then
            has_issues=1
            log_warn "Ruby files need formatting"
        else
            log_success "All Ruby files are properly formatted"
        fi
    else
        log_warn "Rubocop not found. Install: gem install rubocop"
    fi

    return $has_issues
}

# Main execution
cd "$PROJECT_ROOT"

if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "{\"project_type\":\"$PROJECT_TYPE\"}"
fi

if run_format_check "$PROJECT_TYPE"; then
    log_success "All code is properly formatted!"
    exit 0
else
    log_warn "Formatting issues found. Run with --diff to see changes"
    exit 1
fi
