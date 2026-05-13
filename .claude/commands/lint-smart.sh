#!/bin/bash
#
# lint-smart.sh - Smart project auto-detection linter
#
# Usage: /lint-smart [options] [files...]
#
# Options:
#   --fix         Auto-fix issues when possible
#   --verbose     Show detailed output
#   --json        Output in JSON format
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# 하네스 래퍼 로드 (자동 추적)
source "${SCRIPT_DIR}/../brain/skill-harness-wrapper.sh" 2>/dev/null || true

# 스킬 종료 시 자동 기록 (trap)
trap 'harness_skill_end $?' EXIT

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
AUTO_FIX=0
VERBOSE=0
JSON_OUTPUT=0

# 하네스 추적 시작
harness_skill_start "$@"


# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --fix)
            AUTO_FIX=1
            shift
            ;;
        --verbose)
            VERBOSE=1
            shift
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -h|--help)
            echo "Usage: /lint-smart [options] [files...]"
            echo ""
            echo "Options:"
            echo "  --fix         Auto-fix issues when possible"
            echo "  --verbose     Show detailed output"
            echo "  --json        Output in JSON format"
            exit 0
            ;;
        *)
            break
            ;;
    esac
done

print_header "Smart Linter - Project Type: $PROJECT_TYPE"

# Run linter based on project type
run_linter() {
    local project_type="$1"
    local exit_code=0

    case "$project_type" in
        python)
            run_python_linter
            exit_code=$?
            ;;
        typescript|nodejs)
            run_nodejs_linter "$project_type"
            exit_code=$?
            ;;
        go)
            run_go_linter
            exit_code=$?
            ;;
        rust)
            run_rust_linter
            exit_code=$?
            ;;
        java)
            run_java_linter
            exit_code=$?
            ;;
        ruby)
            run_ruby_linter
            exit_code=$?
            ;;
        *)
            log_warn "No linter configured for project type: $project_type"
            return 1
            ;;
    esac

    return $exit_code
}

# Python linters
run_python_linter() {
    log_step "Running Python linters..."

    local fix_arg=""
    [[ $AUTO_FIX -eq 1 ]] && fix_arg="--fix"

    # Try pylint
    if command_exists pylint; then
        log_info "Running pylint..."
        if [[ $AUTO_FIX -eq 1 ]] && command_exists autopep8; then
            autopep8 --in-place --aggressive -r . 2>/dev/null || true
        fi
        pylint **/*.py 2>/dev/null || true
    fi

    # Try flake8
    if command_exists flake8; then
        log_info "Running flake8..."
        flake8 . || true
    fi

    # Try ruff (fast)
    if command_exists ruff; then
        log_info "Running ruff..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            ruff check --fix . || true
        else
            ruff check . || true
        fi
    fi

    # Try mypy (type checker)
    if command_exists mypy; then
        log_info "Running mypy..."
        mypy . 2>/dev/null || true
    fi

    return 0
}

# Node.js/TypeScript linters
run_nodejs_linter() {
    local project_type="$1"
    log_step "Running Node.js/TypeScript linters..."

    # ESLint
    if command_exists eslint; then
        log_info "Running eslint..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            eslint . --fix || true
        else
            eslint . || true
        fi
    elif [[ -f "node_modules/.bin/eslint" ]]; then
        log_info "Running local eslint..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            ./node_modules/.bin/eslint . --fix || true
        else
            ./node_modules/.bin/eslint . || true
        fi
    else
        log_warn "ESLint not found. Install with: npm install -D eslint"
    fi

    # TypeScript specific
    if [[ "$project_type" == "typescript" ]]; then
        # TypeScript compiler
        if command_exists tsc || [[ -f "node_modules/.bin/tsc" ]]; then
            log_info "Running TypeScript compiler..."
            npx tsc --noEmit || true
        fi
    fi

    # Prettier
    if command_exists prettier; then
        log_info "Running prettier..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            prettier --write . || true
        else
            prettier --check . || true
        fi
    elif [[ -f "node_modules/.bin/prettier" ]]; then
        log_info "Running local prettier..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            ./node_modules/.bin/prettier --write . || true
        else
            ./node_modules/.bin/prettier --check . || true
        fi
    fi

    return 0
}

# Go linters
run_go_linter() {
    log_step "Running Go linters..."

    # gofmt (always available with Go)
    log_info "Running gofmt..."
    if [[ $AUTO_FIX -eq 1 ]]; then
        gofmt -w . || true
    else
        gofmt -l . || true
    fi

    # go vet
    if command_exists go; then
        log_info "Running go vet..."
        go vet ./... || true
    fi

    # golangci-lint
    if command_exists golangci-lint; then
        log_info "Running golangci-lint..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            golangci-lint run --fix || true
        else
            golangci-lint run || true
        fi
    else
        log_info "Install golangci-lint: https://golangci-lint.run/usage/install/"
    fi

    return 0
}

# Rust linters
run_rust_linter() {
    log_step "Running Rust linters..."

    # cargo fmt
    if command_exists cargo; then
        log_info "Running cargo fmt..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            cargo fmt || true
        else
            cargo fmt --check || true
        fi
    fi

    # cargo clippy
    if command_exists cargo; then
        log_info "Running cargo clippy..."
        cargo clippy || true
    fi

    return 0
}

# Java linters
run_java_linter() {
    log_step "Running Java linters..."

    # Checkstyle (if available)
    if command_exists checkstyle; then
        log_info "Running checkstyle..."
        checkstyle -c google_checks.xml src/ || true
    fi

    # SpotBugs (if available)
    if command_exists spotbugs; then
        log_info "Running spotbugs..."
        spotbugs -textui -effort:max build/classes/ || true
    fi

    # For Android projects
    if [[ -f "gradlew" ]] || [[ -f "gradlew.bat" ]]; then
        log_info "Running Android linter..."
        ./gradlew lint || true
    fi

    return 0
}

# Ruby linters
run_ruby_linter() {
    log_step "Running Ruby linters..."

    # Rubocop
    if command_exists rubocop; then
        log_info "Running rubocop..."
        if [[ $AUTO_FIX -eq 1 ]]; then
            rubocop -a || true
        else
            rubocop || true
        fi
    else
        log_warn "Install Rubocop: gem install rubocop"
    fi

    return 0
}

# Main execution
cd "$PROJECT_ROOT"

if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "{\"project_type\":\"$PROJECT_TYPE\"}"
fi

if run_linter "$PROJECT_TYPE"; then
    log_success "Linting complete!"
else
    log_warn "Linting finished with warnings"
fi

exit 0
