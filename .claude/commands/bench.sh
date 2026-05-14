#!/bin/bash
#
# bench.sh - monggle: Run benchmarks
#
# Usage: /bench [options] [target]
#
# Options:
#   --compare REF    Compare against reference (branch/tag)
#   --format FORMAT  Output format (table|json|markdown)
#   --runs N         Number of benchmark runs
#   --save FILE      Save results to file
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
COMPARE_REF=""
FORMAT="table"
RUNS=3
SAVE_FILE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --compare)
            COMPARE_REF="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --runs)
            RUNS="$2"
            shift 2
            ;;
        --save)
            SAVE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: /bench [options] [target]"
            echo ""
            echo "Options:"
            echo "  --compare REF   Compare against reference"
            echo "  --format FORMAT Output format (table|json|markdown)"
            echo "  --runs N        Number of runs (default: 3)"
            echo "  --save FILE     Save results to file"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "Benchmark Runner - Project: $PROJECT_TYPE"

# Run benchmarks based on project type
run_benchmarks() {
    local project_type="$1"
    local compare_ref="$2"

    case "$project_type" in
        python)
            benchmark_python "$compare_ref"
            ;;
        typescript|nodejs)
            benchmark_nodejs "$compare_ref"
            ;;
        go)
            benchmark_go "$compare_ref"
            ;;
        rust)
            benchmark_rust "$compare_ref"
            ;;
        java)
            benchmark_java "$compare_ref"
            ;;
        *)
            log_warn "No benchmark configured for: $project_type"
            run_generic_benchmark
            ;;
    esac
}

# Python benchmarks
benchmark_python() {
    local compare_ref="$1"
    log_step "Running Python benchmarks..."

    # Check for pytest-benchmark
    if grep -q "pytest-benchmark" requirements.txt pyproject.toml setup.py 2>/dev/null; then
        log_info "Running pytest-benchmark..."
        pytest --benchmark-only \
            --benchmark-autosave \
            --benchmark-save-data \
            --benchmark-columns=min,max,mean,stddev,ops,rounds 2>/dev/null || true

        # Comparison if ref provided
        if [[ -n "$compare_ref" ]]; then
            log_info "Comparing against $compare_ref..."
            pytest-benchmark compare "$compare_ref" 2>/dev/null || true
        fi
    fi

    # Check for benchmark file
    if [[ -f "benchmarks.py" ]] || [[ -f "bench.py" ]]; then
        log_info "Running benchmark script..."
        for i in $(seq 1 "$RUNS"); do
            log_info "Run $i/$RUNS..."
            python benchmarks.py 2>/dev/null || python bench.py 2>/dev/null || true
        done
    fi

    # Try performance test framework
    if command_exists perf; then
        log_info "Running with perf..."
        perf stat -e cycles,instructions,cache-references,cache-misses \
            python -c "import time; time.sleep(0.1)" 2>/dev/null || true
    fi

    format_benchmark_results "python"
}

# Node.js/TypeScript benchmarks
benchmark_nodejs() {
    local compare_ref="$1"
    log_step "Running Node.js/TypeScript benchmarks..."

    # Check for benchmark files
    local bench_files
    bench_files=$(find . -name "*.bench.js" -o -name "*.bench.ts" -o -name "*.test.js" -o -name "*.test.ts" 2>/dev/null | head -5)

    if [[ -n "$bench_files" ]]; then
        log_info "Found benchmark files:"
        echo "$bench_files"
        echo ""

        # Try common benchmark runners
        if grep -q "benchmark" package.json 2>/dev/null; then
            npm run benchmark 2>/dev/null || yarn benchmark 2>/dev/null || pnpm benchmark 2>/dev/null || true
        fi

        # Try ts-mocha with mocha-bench
        if command_exists mocha; then
            for file in $bench_files; do
                log_info "Running $file..."
                mocha "$file" 2>/dev/null || true
            done
        fi
    else
        log_warn "No benchmark files found"
        log_info "Create *.bench.js or *.bench.ts files with your benchmarks"
    fi

    # Check for common benchmark libraries
    if grep -q "benchmark" package.json 2>/dev/null; then
        log_info "Using benchmark.js library detected"
    fi

    # Try timeit
    if [[ -f "package.json" ]]; then
        log_info "Quick timing test..."
        local start
        start=$(node -e "console.log(Date.now())" 2>/dev/null || echo 0)
        # Run npm test if available
        if timeout 5 npm test 2>/dev/null; then
            local end
            end=$(node -e "console.log(Date.now())" 2>/dev/null || echo 0)
            local duration=$((end - start))
            log_info "Tests completed in: ${duration}ms"
        fi
    fi

    format_benchmark_results "nodejs"
}

# Go benchmarks
benchmark_go() {
    local compare_ref="$1"
    log_step "Running Go benchmarks..."

    if command_exists go; then
        log_info "Running go test benchmarks..."

        # Run benchmarks
        local bench_output
        bench_output=$(go test -bench=. -benchmem -run=^$ . 2>/dev/null || true)

        echo "$bench_output"

        # Save results if requested
        if [[ -n "$SAVE_FILE" ]]; then
            echo "$bench_output" > "$SAVE_FILE"
            log_success "Results saved to: $SAVE_FILE"
        fi

        # Comparison if ref provided
        if [[ -n "$compare_ref" ]]; then
            log_info "Comparing against $compare_ref..."
            go test -bench=. -benchmem "$compare_ref" 2>/dev/null | head -20 || true
        fi

        # Try benchstat for comparison
        if command_exists benchstat; then
            if [[ -n "$compare_ref" ]]; then
                log_info "Using benchstat for comparison..."
                # Save current
                go test -bench=. -benchmem -run=^$ . > new.txt 2>/dev/null
                # Save old
                git show "$compare_ref":$(find . -name "*_test.go" | head -1) 2>/dev/null > /dev/null || true
                benchstat old.txt new.txt 2>/dev/null || true
            fi
        else
            log_info "Install benchstat: go install golang.org/x/perf/cmd/benchstat@latest"
        fi
    fi

    format_benchmark_results "go"
}

# Rust benchmarks
benchmark_rust() {
    local compare_ref="$1"
    log_step "Running Rust benchmarks..."

    if command_exists cargo; then
        # Check for Criterion (default)
        if grep -q "criterion" Cargo.toml 2>/dev/null; then
            log_info "Running Criterion benchmarks..."
            cargo bench 2>/dev/null || true
        fi

        # Try libtest bench
        log_info "Running libtest benchmarks..."
        cargo test --benches 2>/dev/null || true

        # Try with --release for accurate timing
        log_info "Running release benchmarks..."
        cargo bench --release 2>/dev/null || true

        # Try cargo-criterion if available
        if command_exists cargo-criterion; then
            log_info "Using cargo-criterion..."
            cargo criterion 2>/dev/null || true
        fi

        # Comparison if ref provided
        if [[ -n "$compare_ref" ]]; then
            log_info "Comparing against $compare_ref..."
            cargo bench --bench ** -- --baseline "$compare_ref" 2>/dev/null || true
        fi
    fi

    format_benchmark_results "rust"
}

# Java benchmarks
benchmark_java() {
    local compare_ref="$1"
    log_step "Running Java benchmarks..."

    # Check for JMH (Java Microbenchmark Harness)
    if [[ -f "pom.xml" ]]; then
        if grep -q "jmh" pom.xml 2>/dev/null; then
            log_info "Running JMH benchmarks..."
            mvn clean install 2>/dev/null || true
            java -jar target/benchmarks.jar 2>/dev/null || true
        fi
    fi

    # For Android projects
    if [[ -f "gradlew" ]]; then
        log_info "Running Android benchmarks..."
        ./gradlew benchmark 2>/dev/null || true
    fi

    # Try JUnit benchmarks
    local test_files
    test_files=$(find . -name "*Benchmark*.java" 2>/dev/null || true)

    if [[ -n "$test_files" ]]; then
        log_info "Found benchmark files:"
        echo "$test_files"
    fi

    format_benchmark_results "java"
}

# Generic benchmark
run_generic_benchmark() {
    log_step "Running generic benchmark..."

    # Try hyperfine if available
    if command_exists hyperfine; then
        log_info "Using hyperfine..."

        # Detect common commands to benchmark
        if [[ -f "package.json" ]]; then
            hyperfine "npm test" 2>/dev/null || true
        elif [[ -f "pyproject.toml" ]]; then
            hyperfine "pytest" 2>/dev/null || true
        elif [[ -f "Makefile" ]]; then
            hyperfine "make test" 2>/dev/null || true
        fi
    else
        log_warn "hyperfine not found. Install: cargo install hyperfine"
    fi

    # Try time command
    log_info "Basic timing with time command..."
    time echo "Benchmark placeholder"
}

# Format benchmark results
format_benchmark_results() {
    local project_type="$1"

    case "$FORMAT" in
        json)
            output_json "$project_type"
            ;;
        markdown)
            output_markdown "$project_type"
            ;;
        table|*)
            # Already output above
            ;;
    esac
}

output_json() {
    echo "{"
    echo "  \"project_type\": \"$1\","
    echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\","
    echo "  \"runs\": $RUNS"
    echo "}"
}

output_markdown() {
    echo ""
    echo "## Benchmark Results"
    echo ""
    echo "- **Project Type:** $1"
    echo "- **Runs:** $RUNS"
    echo "- **Timestamp:** $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
}

# Show benchmark tips
show_benchmark_tips() {
    log_section "Benchmark Tips"
    log_info "1. Run benchmarks multiple times for consistency"
    log_info "2. Use stable hardware/environment"
    log_info "3. Close other applications to reduce noise"
    log_info "4. Compare against a baseline (use --compare)"
    log_info "5. Profile slow benchmarks to find bottlenecks"
    echo ""
    log_info "Setting up benchmarks:"
    case "$PROJECT_TYPE" in
        python)
            echo "  pip install pytest pytest-benchmark"
            echo "  # Create test_bench.py with @pytest.mark.benchmark"
            ;;
        typescript|nodejs)
            echo "  npm install --save-dev benchmark"
            echo "  # Create *.bench.js files"
            ;;
        go)
            echo "  # Add _test.go files with BenchmarkXxx functions"
            echo "  go test -bench=. -benchmem"
            ;;
        rust)
            echo "  # AddCargo.toml: [dev-dependencies] criterion = \"0.5\""
            echo "  # Add benches/ directory with benchmark functions"
            ;;
        java)
            echo "  # Add JMH dependency to pom.xml"
            echo "  # Create @Benchmark methods"
            ;;
    esac
}

# Main execution
cd "$PROJECT_ROOT"

if ! is_git_repo; then
    log_warn "Not a git repository. --compare not available."
fi

show_benchmark_tips
echo ""

run_benchmarks "$PROJECT_TYPE" "$COMPARE_REF"

log_success "Benchmarks complete!"

exit 0
