#!/bin/bash
#
# complexity.sh - monggle: Code complexity analysis
#
# Usage: /complexity [options]
#
# Options:
#   --threshold   Set complexity threshold (default: 10)
#   --html        Generate HTML report
#   --json        Output in JSON format
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
THRESHOLD=10
HTML_REPORT=0
JSON_OUTPUT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --html)
            HTML_REPORT=1
            shift
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -h|--help)
            echo "Usage: /complexity [options]"
            echo ""
            echo "Options:"
            echo "  --threshold N  Set complexity threshold (default: 10)"
            echo "  --html         Generate HTML report"
            echo "  --json         Output in JSON format"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "Complexity Analysis - Project Type: $PROJECT_TYPE"

# Run complexity analysis based on project type
run_complexity_analysis() {
    local project_type="$1"

    case "$project_type" in
        python)
            analyze_python_complexity
            ;;
        typescript|nodejs)
            analyze_nodejs_complexity
            ;;
        go)
            analyze_go_complexity
            ;;
        rust)
            analyze_rust_complexity
            ;;
        java)
            analyze_java_complexity
            ;;
        *)
            log_warn "No complexity analyzer configured for: $project_type"
            run_generic_complexity
            ;;
    esac
}

# Python complexity analysis
analyze_python_complexity() {
    log_step "Analyzing Python code complexity..."

    # radon - complexity metrics
    if command_exists radon; then
        log_info "Running radon cc (Cyclomatic Complexity)..."
        radon cc . -a -s --min "C" || true

        echo ""
        log_info "Running radon mi (Maintainability Index)..."
        radon mi . || true

        if [[ $HTML_REPORT -eq 1 ]]; then
            log_info "Generating HTML report..."
            radon cc . -a -s --min "C" -o html || true
        fi
    else
        log_warn "radon not found. Install: pip install radon"
    fi

    # lizard - complexity analyzer
    if command_exists lizard; then
        log_info "Running lizard..."
        lizard . -C $THRESHOLD || true
    else
        log_warn "lizard not found. Install: pip install lizard"
    fi

    # xenon - complexity monitoring
    if command_exists xenon; then
        log_info "Running xenon..."
        xenon --max-average $THRESHOLD --max-modules $THRESHOLD --max-absolute $((THRESHOLD * 3)) . || true
    else
        log_warn "xenon not found. Install: pip install xenon"
    fi
}

# Node.js/TypeScript complexity analysis
analyze_nodejs_complexity() {
    log_step "Analyzing Node.js/TypeScript code complexity..."

    # eslint-plugin-complexity
    if [[ -f "node_modules/.bin/eslint" ]]; then
        log_info "Running ESLint complexity rules..."
        ./node_modules/.bin/eslint . --format json \
            --rule 'complexity: ["error", $THRESHOLD]' \
            --rule 'max-lines-per-function: ["warn", 50]' \
            2>/dev/null || true
    fi

    # TypeScript complexity
    if command_exists tsc; then
        log_info "Analyzing TypeScript complexity..."
        # Use complexity-report if available
        if command_exists complexity-report; then
            complexity-report -o . || true
        fi
    fi

    # lizard (language-agnostic)
    if command_exists lizard; then
        log_info "Running lizard..."
        lizard . -l javascript,typescript -C $THRESHOLD || true
    else
        log_warn "lizard not found. Install: pip install lizard"
    fi
}

# Go complexity analysis
analyze_go_complexity() {
    log_step "Analyzing Go code complexity..."

    # gocyclo - cyclomatic complexity
    if command_exists gocyclo; then
        log_info "Running gocyclo..."
        gocyclo -over $THRESHOLD . || log_success "No functions exceed complexity threshold"
    else
        log_warn "gocyclo not found. Install: go install github.com/fzipp/gocyclo/cmd/gocyclo@latest"
    fi

    # gocomplex - complexity analyzer
    if command_exists gocomplex; then
        log_info "Running gocomplex..."
        gocomplex . || true
    fi

    # lizard (language-agnostic)
    if command_exists lizard; then
        log_info "Running lizard..."
        lizard . -l go -C $THRESHOLD || true
    fi
}

# Rust complexity analysis
analyze_rust_complexity() {
    log_step "Analyzing Rust code complexity..."

    # cargo-complexity
    if command_exists cargo; then
        if cargo installable complexus; then
            log_info "Running cargo complexus..."
            cargo complexus || true
        fi
    fi

    # lizard (language-agnostic)
    if command_exists lizard; then
        log_info "Running lizard..."
        lizard . -l rust -C $THRESHOLD || true
    else
        log_warn "lizard not found. Install: pip install lizard"
    fi
}

# Java complexity analysis
analyze_java_complexity() {
    log_step "Analyzing Java code complexity..."

    # Java Parser
    if command_exists jsm; then
        log_info "Running Java complexity analysis..."
        jsm . || true
    fi

    # lizard (language-agnostic)
    if command_exists lizard; then
        log_info "Running lizard..."
        lizard . -l java -C $THRESHOLD || true
    else
        log_warn "lizard not found. Install: pip install lizard"
    fi

    # For Android projects
    if [[ -f "gradlew" ]]; then
        log_info "Running Android complexity analysis..."
        ./gradlew detekt || true
    fi
}

# Generic complexity analysis (language-agnostic)
run_generic_complexity() {
    log_step "Running generic complexity analysis..."

    if command_exists lizard; then
        log_info "Running lizard..."
        lizard . -C $THRESHOLD || true
    else
        log_warn "lizard not found. Install: pip install lizard"
        log_info "lizard supports: C/C++, Java, C#, JavaScript, Python, Ruby, PHP, Swift, TypeScript, Go, OCaml, Rust, Lua, etc."
    fi

    # tokei - code statistics (not complexity but useful)
    if command_exists tokei; then
        log_info "Running tokei (code statistics)..."
        tokei . || true
    fi
}

# Show complexity summary
show_complexity_summary() {
    log_section "Complexity Summary"
    log_info "Threshold: $THRESHOLD"
    log_info "Functions exceeding threshold will be flagged"
    echo ""
    log_info "Cyclomatic Complexity Categories:"
    echo "  1-10    : Simple, low risk"
    echo "  11-20   : Moderate, medium risk"
    echo "  21-50   : High, high risk"
    echo "  50+     : Very high, very high risk"
}

# Main execution
cd "$PROJECT_ROOT"

if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "{\"project_type\":\"$PROJECT_TYPE\",\"threshold\":$THRESHOLD}"
fi

show_complexity_summary
echo ""

run_complexity_analysis "$PROJECT_TYPE"

echo ""
log_success "Complexity analysis complete!"
log_info "Consider refactoring functions that exceed the threshold"

exit 0
