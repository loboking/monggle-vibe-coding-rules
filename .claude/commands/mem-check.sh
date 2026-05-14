#!/bin/bash
#
# mem-check.sh - monggle: Memory leak detector
#
# Usage: /mem-check [options] [command]
#
# Options:
#   --type TYPE       Check type (leak|usage|heap)
#   --threshold MB    Memory threshold in MB
#   --monitor         Continuous monitoring mode
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
CHECK_TYPE="leak"
THRESHOLD=100
MONITOR_MODE=0
JSON_OUTPUT=0
COMMAND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            CHECK_TYPE="$2"
            shift 2
            ;;
        --threshold)
            THRESHOLD="$2"
            shift 2
            ;;
        --monitor)
            MONITOR_MODE=1
            shift
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -h|--help)
            echo "Usage: /mem-check [options] [command]"
            echo ""
            echo "Options:"
            echo "  --type TYPE     Check type (leak|usage|heap)"
            echo "  --threshold MB  Memory threshold in MB (default: 100)"
            echo "  --monitor       Continuous monitoring mode"
            echo ""
            echo "Examples:"
            echo "  /mem-check python main.py"
            echo "  /mem-check --type usage --threshold 500 node server.js"
            exit 0
            ;;
        *)
            COMMAND="$*"
            break
            ;;
    esac
done

print_header "Memory Leak Checker - Project: $PROJECT_TYPE"

# Run memory check based on project type
run_memory_check() {
    local project_type="$1"
    local check_type="$2"
    local command="$3"

    case "$project_type" in
        python)
            check_python_memory "$check_type" "$command"
            ;;
        typescript|nodejs)
            check_nodejs_memory "$check_type" "$command"
            ;;
        go)
            check_go_memory "$check_type" "$command"
            ;;
        rust)
            check_rust_memory "$check_type" "$command"
            ;;
        java)
            check_java_memory "$check_type" "$command"
            ;;
        *)
            log_warn "No memory checker configured for: $project_type"
            run_generic_check
            ;;
    esac
}

# Python memory check
check_python_memory() {
    local check_type="$1"
    local command="${2:-main.py}"

    log_step "Python memory check: $check_type"

    case "$check_type" in
        leak)
            log_info "Checking for memory leaks..."

            # Try memray
            if command_exists memray; then
                log_info "Using memray..."
                memray run "$command"
                memray flamegraph
                log_success "Flame graph generated"
            else
                log_warn "Install memray: pip install memray"
            fi

            # Try tracemalloc
            log_info "Using tracemalloc..."
            cat > /tmp/check_leaks.py << 'EOF'
import tracemalloc
import sys

tracemalloc.start()

# Run the command
import subprocess
subprocess.run(sys.argv[1:])

# Get snapshot
snapshot = tracemalloc.take_snapshot()
top_stats = snapshot.statistics('lineno')

print("[INFO] Top 10 memory allocations:")
for stat in top_stats[:10]:
    print(stat)
EOF
            python /tmp/check_leaks.py $command 2>/dev/null || true

            # Try memory_profiler
            if command_exists mprof; then
                log_info "Using mprof..."
                mprof run --include-children python "$command"
                mprof plot --output memory-profile.png
                log_success "Memory profile saved to memory-profile.png"
            fi
            ;;
        usage)
            log_info "Checking memory usage..."
            check_process_memory "$command"
            ;;
        heap)
            log_info "Heap analysis..."
            if command_exists objgraph; then
                log_info "Using objgraph..."
                python -c "import objgraph; objgraph.show_most_common_types()" 2>/dev/null || true
            else
                log_warn "Install objgraph: pip install objgraph"
            fi
            ;;
        *)
            log_error "Unknown check type: $check_type"
            ;;
    esac

    # Check for common Python memory issues
    check_python_memory_patterns
}

# Check Python memory patterns
check_python_memory_patterns() {
    log_info "Checking for common memory issues..."

    # Check for unclosed files
    local unclosed
    unclosed=$(find . -name "*.py" -exec grep -l "open(" {} \; 2>/dev/null | \
        while read -r file; do
            if ! grep -q "\.close()" "$file" 2>/dev/null; then
                if ! grep -q "with open" "$file" 2>/dev/null; then
                    echo "$file"
                fi
            fi
        done)

    if [[ -n "$unclosed" ]]; then
        log_warn "Files with possible unclosed file handles:"
        echo "$unclosed" | head -5
    fi

    # Check for global lists/dicts
    local globals
    globals=$(find . -name "*.py" -exec grep -E "^[A-Z_]+ = \[|^[A-Z_]+ = \{" {} \; 2>/dev/null | wc -l)
    if [[ $globals -gt 0 ]]; then
        log_info "Found $globals potential global collections"
    fi
}

# Node.js/TypeScript memory check
check_nodejs_memory() {
    local check_type="$1"
    local command="${2:-node server.js}"

    log_step "Node.js/TypeScript memory check: $check_type"

    case "$check_type" in
        leak)
            log_info "Checking for memory leaks..."

            # Use Node.js built-in flags
            log_info "Running with --inspect flag..."
            node --inspect --expose-gc "$command" &
            local pid=$!
            sleep 2

            log_info "PID: $pid"
            log_info "Take heap snapshots with Chrome DevTools"
            log_info "Connect to: chrome://inspect"

            # Wait for user
            if [[ $MONITOR_MODE -eq 1 ]]; then
                log_info "Monitoring memory. Press Ctrl+C to stop..."
                while kill -0 $pid 2>/dev/null; do
                    local mem
                    mem=$(ps -o rss= -p $pid 2>/dev/null || echo 0)
                    echo "$(date +%T) Memory: $((mem / 1024)) MB"
                    sleep 5
                done
            else
                wait $pid 2>/dev/null || true
            fi
            ;;
        usage)
            log_info "Checking memory usage..."
            check_process_memory "$command"
            ;;
        heap)
            log_info "Heap snapshot..."
            log_info "Run with: node --heap-prof $command"
            ;;
        clinic)
            if command_exists clinic; then
                log_info "Using clinic heapprofiler..."
                clinic heapprofiler -- on $command
            fi
            ;;
        *)
            log_error "Unknown check type: $check_type"
            ;;
    esac

    check_nodejs_memory_patterns
}

# Check Node.js memory patterns
check_nodejs_memory_patterns() {
    log_info "Checking for common memory issues..."

    # Check for event listener leaks
    log_info "Checking for potential event listener leaks..."
    find . -name "*.js" -o -name "*.ts" 2>/dev/null | \
        while read -r file; do
            local add_listeners
            add_listeners=$(grep -c "addEventListener\|on(" "$file" 2>/dev/null || echo 0)
            local remove_listeners
            remove_listeners=$(grep -c "removeEventListener\|off(" "$file" 2>/dev/null || echo 0)

            if [[ $add_listeners -gt 0 && $remove_listeners -eq 0 ]]; then
                log_warn "Possible event listener leak in: $file"
            fi
        done

    # Check for setInterval without clearInterval
    log_info "Checking for timers without cleanup..."
    find . -name "*.js" -o -name "*.ts" 2>/dev/null | \
        while read -r file; do
            if grep -q "setInterval\|setTimeout" "$file" 2>/dev/null; then
                if ! grep -q "clearInterval\|clearTimeout" "$file" 2>/dev/null; then
                    log_info "Possible timer leak in: $file"
                fi
            fi
        done
}

# Go memory check
check_go_memory() {
    local check_type="$1"
    local command="${2:-go test}"

    log_step "Go memory check: $check_type"

    case "$check_type" in
        leak)
            log_info "Checking for memory leaks..."
            log_info "Run: go test -memprofile=mem.prof"
            go test -memprofile=mem.prof . 2>/dev/null || true

            if [[ -f "mem.prof" ]]; then
                log_info "Analyze with: go tool pprof mem.prof"
            fi
            ;;
        usage)
            log_info "Checking memory usage..."
            check_process_memory "$command"
            ;;
        heap)
            log_info "Heap profile..."
            go test -memprofile=heap.prof . 2>/dev/null || true
            if [[ -f "heap.prof" ]]; then
                go tool pprof -text heap.prof | head -20
            fi
            ;;
        *)
            log_error "Unknown check type: $check_type"
            ;;
    esac

    check_go_memory_patterns
}

# Check Go memory patterns
check_go_memory_patterns() {
    log_info "Checking for common memory issues..."

    # Check for goroutine leaks
    log_info "Checking for potential goroutine leaks..."
    find . -name "*.go" -exec grep -l "go func" {} \; 2>/dev/null | \
        while read -r file; do
            if ! grep -q "WaitGroup\|context\|Done()" "$file" 2>/dev/null; then
                log_info "Possible untracked goroutine in: $file"
            fi
        done

    # Check for missing defer close()
    find . -name "*.go" -exec grep -l "os.Open\|net.Dial" {} \; 2>/dev/null | \
        while read -r file; do
            if ! grep -A5 "os.Open\|net.Dial" "$file" | grep -q "defer.*Close"; then
                log_warn "Possible unclosed resource in: $file"
            fi
        done
}

# Rust memory check
check_rust_memory() {
    local check_type="$1"
    local command="${2:-cargo test}"

    log_step "Rust memory check: $check_type"

    log_info "Rust has memory safety built-in, but we can check for:"
    echo "  - Memory leaks (rare, usually Rc/RefCell cycles)"
    echo "  - Excessive allocations"
    echo "  - Stack overflows"

    case "$check_type" in
        leak)
            log_info "Running with Miri for undefined behavior..."
            if command_exists cargo-miri; then
                cargo miri test 2>/dev/null || true
            else
                log_warn "Install Miri: rustup component add miri"
            fi

            # Try valgrind
            if command_exists valgrind; then
                log_info "Running with valgrind..."
                cargo build --release 2>/dev/null || true
                valgrind --leak-check=full --show-leak-kinds=all \
                    ./target/release/$(basename "$PROJECT_ROOT") 2>/dev/null || true
            fi
            ;;
        usage)
            log_info "Checking memory usage..."
            check_process_memory "$command"
            ;;
        heap)
            log_info "Use heaptrack or DHAT for detailed heap analysis"
            ;;
        *)
            log_error "Unknown check type: $check_type"
            ;;
    esac
}

# Java memory check
check_java_memory() {
    local check_type="$1"
    local command="${2}"

    log_step "Java memory check: $check_type"

    case "$check_type" in
        leak)
            log_info "Checking for memory leaks..."

            # Run with heap dump on OOM
            log_info "Run with: -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/tmp"

            # Try VisualVM
            if command_exists jvisualvm; then
                log_info "Launch jvisualvm to monitor memory"
            fi
            ;;
        usage)
            log_info "Checking memory usage..."
            if [[ -f "gradlew" ]]; then
                ./gradlew --profile 2>/dev/null || true
            fi
            check_process_memory "$command"
            ;;
        heap)
            log_info "Heap dump analysis..."
            log_info "Get heap dump with: jmap -dump:format=b,file=heap.bin <pid>"
            log_info "Analyze with: VisualVM, Eclipse MAT, or jhat"
            ;;
        *)
            log_error "Unknown check type: $check_type"
            ;;
    esac
}

# Generic memory check
run_generic_check() {
    log_step "Running generic memory check..."

    if command_exists valgrind; then
        log_info "Using valgrind..."
        log_warn "Valgrind available but no command specified"
    fi

    if command_exists massif; then
        log_info "Using massif (heap profiler)..."
        log_warn "Run: valgrind --tool=massif <command>"
    fi
}

# Check process memory
check_process_memory() {
    local command="$1"

    if [[ -z "$command" ]]; then
        log_info "No command specified. Showing current memory usage..."

        # Show system memory
        if [[ "$(get_os)" == "macos" ]]; then
            vm_stat | head -5
        else
            free -h 2>/dev/null || cat /proc/meminfo | head -10
        fi
        return
    fi

    log_info "Running command and monitoring memory..."

    # Run command in background and monitor
    $command &
    local pid=$!
    sleep 1

    local max_mem=0
    local iterations=0
    local max_iterations=60

    while kill -0 $pid 2>/dev/null && [[ $iterations -lt $max_iterations ]]; do
        local mem
        mem=$(ps -o rss= -p $pid 2>/dev/null || echo 0)
        local mem_mb=$((mem / 1024))

        if [[ $mem_mb -gt $max_mem ]]; then
            max_mem=$mem_mb
        fi

        echo "$(date +%T) Memory: ${mem_mb} MB (max: ${max_mem} MB)"

        if [[ $mem_mb -gt $THRESHOLD ]]; then
            log_warn "Memory threshold exceeded: ${mem_mb} MB > ${THRESHOLD} MB"
        fi

        sleep 2
        iterations=$((iterations + 1))
    done

    wait $pid 2>/dev/null || true

    echo ""
    log_info "Peak memory: ${max_mem} MB"
}

# Show memory check tips
show_memory_tips() {
    log_section "Memory Check Tips"
    log_info "1. Monitor memory over time, not just snapshots"
    log_info "2. Look for steady memory growth (leak indicator)"
    log_info "3. Check for unclosed resources (files, connections)"
    log_info "4. Beware of global variables and caches"
    log_info "5. Use memory profiling tools for detailed analysis"
    echo ""
    log_info "Common leak sources:"
    echo "  - Event listeners not removed"
    echo "  - Timers not cleared"
    echo "  - Global collections growing"
    echo "  - Caches without size limits"
    echo "  - Circular references (in some languages)"
}

# Main execution
cd "$PROJECT_ROOT"

show_memory_tips
echo ""

if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "{\"project_type\":\"$PROJECT_TYPE\",\"check_type\":\"$CHECK_TYPE\"}"
fi

run_memory_check "$PROJECT_TYPE" "$CHECK_TYPE" "$COMMAND"

log_success "Memory check complete!"

exit 0
