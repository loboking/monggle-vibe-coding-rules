#!/bin/bash
#
# profile.sh - monggle: Performance profiler
#
# Usage: /profile [options] [command]
#
# Options:
#   --type TYPE       Profiler type (cpu|memory|heap|flame)
#   --output FILE     Output file for results
#   --visual          Visualize results
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
PROFILE_TYPE="cpu"
OUTPUT_FILE=""
VISUALIZE=0
COMMAND=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            PROFILE_TYPE="$2"
            shift 2
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --visual)
            VISUALIZE=1
            shift
            ;;
        -h|--help)
            echo "Usage: /profile [options] [command]"
            echo ""
            echo "Options:"
            echo "  --type TYPE     Profiler type (cpu|memory|heap|flame)"
            echo "  --output FILE   Output file for results"
            echo "  --visual        Visualize results"
            echo ""
            echo "Examples:"
            echo "  /profile --type cpu --output profile.py python main.py"
            echo "  /profile --type flame node server.js"
            exit 0
            ;;
        *)
            COMMAND="$*"
            break
            ;;
    esac
done

print_header "Profiler - Type: $PROFILE_TYPE"

# Run profiler based on project type
run_profiler() {
    local project_type="$1"
    local profile_type="$2"
    local command="$3"

    case "$project_type" in
        python)
            profile_python "$profile_type" "$command"
            ;;
        typescript|nodejs)
            profile_nodejs "$profile_type" "$command"
            ;;
        go)
            profile_go "$profile_type" "$command"
            ;;
        rust)
            profile_rust "$profile_type" "$command"
            ;;
        java)
            profile_java "$profile_type" "$command"
            ;;
        *)
            log_warn "No profiler configured for: $project_type"
            ;;
    esac
}

# Python profiling
profile_python() {
    local profile_type="$1"
    local command="${2:-main.py}"

    log_step "Python profiling: $profile_type"

    case "$profile_type" in
        cpu)
            log_info "Using cProfile..."
            local output="${OUTPUT_FILE:-profile.prof}"
            python -m cProfile -o "$output" $command
            log_success "Profile saved to: $output"
            log_info "View with: python -m pstats $output"
            log_info "Or: snakeviz $output"

            if [[ $VISUALIZE -eq 1 ]]; then
                if command_exists snakeviz; then
                    snakeviz "$output" &
                else
                    log_warn "Install snakeviz: pip install snakeviz"
                fi
            fi
            ;;
        memory)
            log_info "Using memory_profiler..."
            local output="${OUTPUT_FILE:-profile.mem}"
            if command_exists mprof; then
                mprof run $command
                mprof plot --output "$output.png"
                log_success "Memory profile saved to: $output.png"
            else
                log_warn "Install memory_profiler: pip install memory_profiler"
            fi
            ;;
        line)
            log_info "Using line_profiler..."
            if command_exists kernprof; then
                kernprof -l -v $command
            else
                log_warn "Install line_profiler: pip install line_profiler"
            fi
            ;;
        flame)
            log_info "Using flame graph..."
            if command_exists py-spy; then
                local output="${OUTPUT_FILE:-profile.svg}"
                log_warn "py-spy requires a running process"
                log_info "Usage: py-spy record -o $output --pid <PID>"
            else
                log_warn "Install py-spy: pip install py-spy"
            fi
            ;;
        *)
            log_error "Unknown profile type: $profile_type"
            ;;
    esac
}

# Node.js profiling
profile_nodejs() {
    local profile_type="$1"
    local command="${2:-node server.js}"

    log_step "Node.js profiling: $profile_type"

    case "$profile_type" in
        cpu)
            log_info "Using Node.js built-in profiler..."
            local output="${OUTPUT_FILE:-profile.cpuprofile}"
            node --prof $command
            node --prof-process isolate-*.log > "$output"
            log_success "Profile saved to: $output"
            ;;
        heap)
            log_info "Using heap profiler..."
            if command_exists clinic; then
                clinic heapprofiler -- on "$command"
            else
                log_warn "Install clinic: npm install -g clinic"
            fi
            ;;
        flame)
            log_info "Using flame graph..."
            if command_exists clinic; then
                clinic flame -- "$command"
            else
                log_warn "Install clinic: npm install -g clinic"
            fi
            ;;
        0x)
            if command_exists 0x; then
                log_info "Using 0x profiler..."
                0x "$command"
            else
                log_warn "Install 0x: npm install -g 0x"
            fi
            ;;
        *)
            log_error "Unknown profile type: $profile_type"
            ;;
    esac
}

# Go profiling
profile_go() {
    local profile_type="$1"
    local command="${2:-go test}"

    log_step "Go profiling: $profile_type"

    case "$profile_type" in
        cpu)
            log_info "Using CPU profiler..."
            local output="${OUTPUT_FILE:-cpu.prof}"
            go test -cpuprofile="$output" . || true
            go tool pprof -text "$output" | head -20
            log_success "Profile saved to: $output"
            log_info "Interactive: go tool pprof $output"

            if [[ $VISUALIZE -eq 1 ]]; then
                if command_exists go-tool-pprof; then
                    go tool pprof -http=:8080 "$output"
                fi
            fi
            ;;
        memory)
            log_info "Using memory profiler..."
            local output="${OUTPUT_FILE:-mem.prof}"
            go test -memprofile="$output" . || true
            go tool pprof -text "$output" | head -20
            log_success "Profile saved to: $output"
            ;;
        flame)
            log_info "Using flame graph..."
            if command_exists go-torch; then
                go-torch "$command"
            else
                log_warn "Install go-torch: go install github.com/uber/go-torch/cmd/go-torch@latest"
            fi
            ;;
        *)
            log_error "Unknown profile type: $profile_type"
            ;;
    esac
}

# Rust profiling
profile_rust() {
    local profile_type="$1"
    local command="${2:-cargo test}"

    log_step "Rust profiling: $profile_type"

    case "$profile_type" in
        flame)
            log_info "Using flame graph..."
            if command_exists cargo-flamegraph; then
                cargo flamegraph
            elif command_exists flamegraph; then
                flamegraph "$command"
            else
                log_warn "Install flamegraph: cargo install flamegraph"
            fi
            ;;
        perf)
            log_info "Using perf..."
            if command_exists perf; then
                perf record -g "$command"
                perf script | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg
                log_success "Flame graph saved to: flamegraph.svg"
            else
                log_warn "perf not available (Linux only)"
            fi
            ;;
        time)
            log_info "Using timing..."
            time "$command"
            ;;
        *)
            log_error "Unknown profile type: $profile_type"
            ;;
    esac
}

# Java profiling
profile_java() {
    local profile_type="$1"
    local command="${2}"

    log_step "Java profiling: $profile_type"

    case "$profile_type" in
        cpu)
            log_info "Using Java profiler..."
            if command_exists jvisualvm; then
                log_info "Launch jvisualvm and attach to process"
            elif command_exists yourkit; then
                log_info "Launch YourKit profiler"
            else
                log_info "Use JMX: java -Dcom.sun.management.jmxremote ..."
            fi
            ;;
        yourkit)
            if command_exists yourkit; then
                log_info "Launching YourKit..."
                yourkit "$command"
            fi
            ;;
        async)
            log_info "Using async-profiler..."
            if [[ -f "async-profiler" ]]; then
                ./async-profiler -d 60 -f profile.svg $command
                log_success "Profile saved to: profile.svg"
            else
                log_warn "async-profiler not found"
            fi
            ;;
        *)
            log_error "Unknown profile type: $profile_type"
            ;;
    esac
}

# Show profiling tips
show_profiling_tips() {
    log_section "Profiling Tips"
    log_info "1. Profile in a representative environment"
    log_info "2. Use realistic workload/data"
    log_info "3. Profile multiple times for consistency"
    log_info "4. Focus on hot paths (90/10 rule)"
    log_info "5. Measure before and after optimization"
    echo ""
    log_info "Profile types:"
    echo "  cpu     - CPU usage and call graph"
    echo "  memory  - Memory allocation and usage"
    echo "  heap    - Heap snapshot"
    echo "  flame   - Flame graph visualization"
}

# Main execution
cd "$PROJECT_ROOT"

if [[ -z "$COMMAND" ]]; then
    log_warn "No command specified. Showing profiling tips..."
    show_profiling_tips

    echo ""
    log_info "Examples:"
    case "$PROJECT_TYPE" in
        python)
            echo "  /profile python main.py"
            echo "  /profile --type cpu --output profile.prof python main.py"
            ;;
        typescript|nodejs)
            echo "  /profile node server.js"
            echo "  /profile --type flame npm start"
            ;;
        go)
            echo "  /profile go test"
            echo "  /profile --type cpu go test -bench=."
            ;;
        rust)
            echo "  /profile cargo test"
            echo "  /profile --type flame cargo test"
            ;;
        *)
            echo "  /profile <your-command>"
            ;;
    esac
else
    run_profiler "$PROJECT_TYPE" "$PROFILE_TYPE" "$COMMAND"
fi

exit 0
