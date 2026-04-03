#!/bin/bash
#
# bottleneck.sh - Find performance bottlenecks
#
# Usage: /bottleneck [options]
#
# Options:
#   --type TYPE       Analysis type (cpu|memory|io|network)
#   --depth N         Analysis depth (default: 10)
#   --json            Output in JSON format
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
ANALYSIS_TYPE="all"
DEPTH=10
JSON_OUTPUT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            ANALYSIS_TYPE="$2"
            shift 2
            ;;
        --depth)
            DEPTH="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -h|--help)
            echo "Usage: /bottleneck [options]"
            echo ""
            echo "Options:"
            echo "  --type TYPE     Analysis type (cpu|memory|io|network|all)"
            echo "  --depth N       Analysis depth (default: 10)"
            echo "  --json          Output in JSON format"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "Bottleneck Finder - Project: $PROJECT_TYPE"

# Run bottleneck analysis based on project type
run_analysis() {
    local project_type="$1"
    local analysis_type="$2"

    case "$project_type" in
        python)
            analyze_python_bottlenecks "$analysis_type"
            ;;
        typescript|nodejs)
            analyze_nodejs_bottlenecks "$analysis_type"
            ;;
        go)
            analyze_go_bottlenecks "$analysis_type"
            ;;
        rust)
            analyze_rust_bottlenecks "$analysis_type"
            ;;
        java)
            analyze_java_bottlenecks "$analysis_type"
            ;;
        *)
            log_warn "No bottleneck analyzer configured for: $project_type"
            run_generic_analysis
            ;;
    esac
}

# Python bottleneck analysis
analyze_python_bottlenecks() {
    local analysis_type="$1"
    log_step "Analyzing Python bottlenecks..."

    # Check for common performance issues
    check_python_patterns

    # Try py-spy
    if command_exists py-spy; then
        log_info "Running py-spy..."
        # Note: requires a running Python process
        log_warn "py-spy requires a running Python process to profile"
    fi

    # Try line_profiler
    if command_exists line_profiler; then
        log_info "To use line_profiler, add @profile decorator to functions"
    fi

    # Try memory_profiler
    if command_exists mprof; then
        log_info "To use memory_profiler, run: mprof run <script>"
    fi

    # Check for common anti-patterns
    check_python_antipatterns
}

# Check Python performance patterns
check_python_patterns() {
    log_info "Checking for common performance patterns..."

    local issues=0

    # Check for nested loops
    log_info "Checking for nested loops..."
    local nested_loops
    nested_loops=$(find . -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
        -exec grep -l "for .* in .*:.*for .* in .*:" {} \; 2>/dev/null | wc -l)

    if [[ $nested_loops -gt 0 ]]; then
        log_warn "Found $nested_loops files with nested loops (potential O(n²) complexity)"
        issues=1
    fi

    # Check for string concatenation in loops
    log_info "Checking for string concatenation in loops..."
    local concat_issues
    concat_issues=$(find . -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
        -exec awk '/for.*:/{flag=1} flag && /\+.*=/{print FILENAME; flag=0}' {} \; 2>/dev/null | wc -l)

    if [[ $concat_issues -gt 0 ]]; then
        log_warn "Found string concatenation in loops (use list + join() instead)"
        issues=1
    fi

    # Check for global imports
    log_info "Checking for global imports inside functions..."
    local function_imports
    function_imports=$(find . -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
        -exec awk '/def /{flag=1} flag && /^import /{print FILENAME; flag=0}' {} \; 2>/dev/null | wc -l)

    if [[ $function_imports -gt 0 ]]; then
        log_warn "Found $function_imports imports inside functions (move to module level)"
        issues=1
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "No obvious performance anti-patterns found"
    fi
}

# Check Python anti-patterns
check_python_antipatterns() {
    log_info "Checking for Python anti-patterns..."

    # Check for mutable default arguments
    local mutable_defaults
    mutable_defaults=$(find . -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
        -exec grep -E "def.*\(.*=\[\]|.*=\{\}|.*=\(\)" {} \; 2>/dev/null | wc -l)

    if [[ $mutable_defaults -gt 0 ]]; then
        log_warn "Found $mutable_defaults mutable default arguments (use None and check inside function)"
    fi

    # Check for unnecessary list comprehensions
    log_info "Checking for list comprehensions that could be generators..."
    find . -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" \
        -exec grep -nE "\[.*for .* in .*\]" {} \; 2>/dev/null | head -5 || true
}

# Node.js/TypeScript bottleneck analysis
analyze_nodejs_bottlenecks() {
    local analysis_type="$1"
    log_step "Analyzing Node.js/TypeScript bottlenecks..."

    # Check for common performance issues
    check_nodejs_patterns

    # Try clinic.js
    if command_exists clinic; then
        log_info "clinic.js available. To profile:"
        echo "  clinic doctor -- node server.js"
        echo "  clinic heapprofiler -- node server.js"
        echo "  clinic flame -- node server.js"
    fi

    # Try 0x profiler
    if command_exists 0x; then
        log_info "0x profiler available. To profile:"
        echo "  0x -- node server.js"
    fi
}

# Check Node.js performance patterns
check_nodejs_patterns() {
    log_info "Checking for common performance patterns..."

    # Check for synchronous operations in async handlers
    log_info "Checking for sync operations in async handlers..."
    find . -name "*.js" -o -name "*.ts" 2>/dev/null | \
        while read -r file; do
            if grep -qE "\.(fs|readFileSync|writeFileSync|execSync)" "$file" 2>/dev/null; then
                if grep -qE "async |await " "$file" 2>/dev/null; then
                    log_warn "Potential sync operations in async file: $file"
                fi
            fi
        done

    # Check for missing await
    log_info "Checking for missing await..."
    find . -name "*.js" -o -name "*.ts" 2>/dev/null | \
        while read -r file; do
            if grep -E "Promise\.<|\.then\(" "$file" > /dev/null 2>&1; then
                log_info "Promise chaining without await in: $file"
            fi
        done

    # Check for large node_modules
    if [[ -d "node_modules" ]]; then
        local size
        size=$(du -sh node_modules 2>/dev/null | cut -f1)
        log_info "node_modules size: $size"
    fi
}

# Go bottleneck analysis
analyze_go_bottlenecks() {
    local analysis_type="$1"
    log_step "Analyzing Go bottlenecks..."

    # Check for common performance issues
    check_go_patterns

    # Try go tool pprof
    if command_exists go; then
        log_info "Go profiling tools available:"
        echo "  CPU:     go test -cpuprofile=cpu.prof"
        echo "  Memory:  go test -memprofile=mem.prof"
        echo "  View:    go tool pprof cpu.prof"
    fi

    # Try go-torch
    if command_exists go-torch; then
        log_info "go-torch available for flame graphs"
    fi
}

# Check Go performance patterns
check_go_patterns() {
    log_info "Checking for common performance patterns..."

    # Check for inefficient string concatenation
    log_info "Checking for string concatenation in loops..."
    find . -name "*.go" -exec grep -l "for.*{.*str.*\+=.*}" {} \; 2>/dev/null | while read -r file; do
        log_warn "Possible string concatenation in loop: $file"
    done

    # Check for defer in loops
    log_info "Checking for defer in loops..."
    find . -name "*.go" -exec awk '/for.*{/{flag=1} flag && /defer/{print FILENAME":"NR":"$0; flag=0}' {} \; 2>/dev/null | while read -r line; do
        log_warn "Defer in loop (may cause memory issues): $line"
    done
}

# Rust bottleneck analysis
analyze_rust_bottlenecks() {
    local analysis_type="$1"
    log_step "Analyzing Rust bottlenecks..."

    if command_exists cargo; then
        log_info "Rust profiling tools available:"
        echo "  Flamegraph:  cargo install flamegraph && cargo flamegraph"
        echo "  Profiler:    cargo profiler"
        echo "  Valgrind:   valgrind --tool=callgrind ./target/release/binary"
    fi

    # Check for common performance issues
    check_rust_patterns
}

# Check Rust performance patterns
check_rust_patterns() {
    log_info "Checking for common performance patterns..."

    # Check for unnecessary clones
    log_info "Checking for .clone() calls..."
    find . -name "*.rs" -exec grep -n "\.clone()" {} + 2>/dev/null | head -10 || true

    # Check for allocations in hot paths
    log_info "Checking for Vec allocations..."
    find . -name "*.rs" -exec grep -nE "Vec::new|vec!\[" {} + 2>/dev/null | head -5 || true
}

# Java bottleneck analysis
analyze_java_bottlenecks() {
    local analysis_type="$1"
    log_step "Analyzing Java bottlenecks..."

    if [[ -f "gradlew" ]]; then
        log_info "Android/Gradle profiling:"
        echo "  ./gradlew assembleDebug --profile"
    fi

    # Try VisualVM
    if command_exists jvisualvm; then
        log_info "VisualVM available for profiling"
    fi

    check_java_patterns
}

# Check Java performance patterns
check_java_patterns() {
    log_info "Checking for common performance patterns..."

    # Check for string concatenation in loops
    log_info "Checking for string concatenation in loops..."
    find . -name "*.java" -exec grep -l "for.*String.*+=" {} \; 2>/dev/null | while read -r file; do
        log_warn "Possible string concatenation in loop: $file"
    done

    # Check for missing @Override
    log_info "Checking for missing @Override annotations..."
    find . -name "*.java" -exec grep -l "public String toString()" {} \; 2>/dev/null | while read -r file; do
        if ! grep -B5 "public String toString()" "$file" | grep -q "@Override"; then
            log_info "Missing @Override on toString() in: $file"
        fi
    done
}

# Generic analysis
run_generic_analysis() {
    log_step "Running generic bottleneck analysis..."

    # Check file sizes
    log_info "Checking for large files..."
    find . -type f -not -path "*/node_modules/*" -not -path "*/venv/*" \
        -not -path "*/target/*" -not -path "*/.git/*" \
        -size +1M -exec ls -lh {} \; 2>/dev/null | head -10 || true

    # Check for duplicate code
    if command_exists jscpd; then
        log_info "Checking for duplicate code..."
        jscpd . 2>/dev/null || true
    fi
}

# Show analysis summary
show_analysis_summary() {
    log_section "Analysis Summary"
    log_info "Project Type: $PROJECT_TYPE"
    log_info "Analysis Type: $ANALYSIS_TYPE"
    echo ""
    log_info "Recommendations:"
    echo "  1. Use profiling tools for accurate measurements"
    echo "  2. Focus on hot paths (frequently executed code)"
    echo "  3. Measure before and after optimization"
    echo "  4. Consider algorithmic complexity improvements"
}

# Main execution
cd "$PROJECT_ROOT"

if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "{\"project_type\":\"$PROJECT_TYPE\",\"analysis_type\":\"$ANALYSIS_TYPE\"}"
fi

show_analysis_summary
echo ""

run_analysis "$PROJECT_TYPE" "$ANALYSIS_TYPE"

echo ""
log_success "Bottleneck analysis complete!"
log_info "Use /profile for detailed profiling"

exit 0
