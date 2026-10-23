#!/bin/bash
#
# harness.sh - monggle: 하네스 메트릭 및 관리 도구
#
# Usage: /harness [command] [options]
#
# Commands:
#   status      - 하네스 상태 확인
#   loops       - 둠 루프 탐지 현황
#   improve     - 개선 제안 보기/추가
#   metrics     - 가이드/센서 통계
#   reset       - 메트릭 초기화
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# 통합 하네스 경로: 실행 위치와 무관하게 한 곳에 모은다 (HARNESS_HOME으로 오버라이드).
HARNESS_DIR="${HARNESS_HOME:-${HOME}/.claude/.harness}"
LOOP_DETECTION="${HARNESS_DIR}/loop-detection.json"
IMPROVEMENT_LOG="${HARNESS_DIR}/improvement-log.jsonl"
METRICS_DIR="${HARNESS_DIR}/metrics"
AGENT_METRICS="${METRICS_DIR}/agent-success-rate.json"
GUIDE_SENSOR_STATS="${METRICS_DIR}/guide-sensor-stats.json"

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          Harness Metrics & Management         ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Show help
show_help() {
    print_header
    echo "Usage: /harness [command] [options]"
    echo ""
    echo "Commands:"
    echo "  status              하네스 상태 확인"
    echo "  loops               둠 루프 탐지 현황"
    echo "  improve [add]       개선 제안 보기/추가"
    echo "  metrics             가이드/센서 통계"
    echo "  reset               메트릭 초기화"
    echo ""
    echo "Examples:"
    echo "  /harness status"
    echo "  /harness loops"
    echo "  /harness improve add --type guide_addition --agent scan"
    echo ""
}

# Initialize harness directories/files
init_harness() {
    if [[ ! -d "$HARNESS_DIR" ]]; then
        mkdir -p "$HARNESS_DIR"
        mkdir -p "$METRICS_DIR"
    fi

    if [[ ! -f "$LOOP_DETECTION" ]]; then
        cat > "$LOOP_DETECTION" << 'EOF'
{
  "version": "1.0.0",
  "last_updated": "2025-01-12T00:00:00Z",
  "files": {},
  "thresholds": {
    "max_modifications": 5,
    "max_consecutive_failures": 3,
    "cooldown_minutes": 30
  }
}
EOF
    fi

    if [[ ! -f "$IMPROVEMENT_LOG" ]]; then
        echo '{"timestamp":"2025-01-12T00:00:00Z","type":"harness_init","agent":"system","severity":"info","message":"Harness system initialized"}' > "$IMPROVEMENT_LOG"
    fi

    if [[ ! -f "$AGENT_METRICS" ]]; then
        cat > "$AGENT_METRICS" << 'EOF'
{
  "version": "1.0.0",
  "agents": {
    "gate": {"total": 0, "success": 0, "failure": 0},
    "scan": {"total": 0, "success": 0, "failure": 0},
    "fold": {"total": 0, "success": 0, "failure": 0},
    "verdict": {"total": 0, "success": 0, "failure": 0},
    "patch": {"total": 0, "success": 0, "failure": 0}
  }
}
EOF
    fi

    if [[ ! -f "$GUIDE_SENSOR_STATS" ]]; then
        cat > "$GUIDE_SENSOR_STATS" << 'EOF'
{
  "version": "1.0.0",
  "guides": {
    "computational": {"lint": 0, "type_check": 0, "template": 0},
    "inferential": {"code_review": 0, "design_advice": 0}
  },
  "sensors": {
    "computational": {"tests": 0, "ci": 0, "format": 0},
    "inferential": {"llm_judge": 0, "semantic": 0}
  }
}
EOF
    fi
}

# Show harness status
show_status() {
    print_header

    init_harness

    log_info "Harness Directory: ${HARNESS_DIR}"
    echo ""

    # Loop detection status
    echo -e "${MAGENTA}🔄 Loop Detection Status:${NC}"
    if [[ -f "$LOOP_DETECTION" ]]; then
        local file_count=$(jq '.files | length' "$LOOP_DETECTION" 2>/dev/null || echo "0")
        if [[ "$file_count" -eq 0 ]]; then
            log_success "No doom loops detected"
        else
            log_warning "Tracking $file_count files"
            jq -r '.files | to_entries[] | "  - \(.key): \(.value.count) modifications (last: \(.value.last_modified))"' "$LOOP_DETECTION" 2>/dev/null
        fi
    else
        log_warning "Loop detection not initialized"
    fi
    echo ""

    # Improvement log summary
    echo -e "${MAGENTA}💡 Improvement Log Summary:${NC}"
    if [[ -f "$IMPROVEMENT_LOG" ]]; then
        local total_logs=$(wc -l < "$IMPROVEMENT_LOG" 2>/dev/null || echo "0")
        local critical=$(jq -s '[.[] | select(.severity=="critical")] | length' "$IMPROVEMENT_LOG" 2>/dev/null || echo "0")
        local major=$(jq -s '[.[] | select(.severity=="major")] | length' "$IMPROVEMENT_LOG" 2>/dev/null || echo "0")

        echo "  Total entries: $total_logs"
        echo "  - Critical: $critical"
        echo "  - Major: $major"
        echo "  - Minor/Info: $((total_logs - critical - major))"
    else
        log_warning "Improvement log not found"
    fi
    echo ""

    # Agent success rates
    echo -e "${MAGENTA}📊 Agent Success Rates:${NC}"
    if [[ -f "$AGENT_METRICS" ]]; then
        jq -r '.agents | to_entries[] |
            "  \(.key | ascii_upcase): \(.value.success)/\(.value.total) (\(
                if .value.total > 0 then
                    (.value.success / .value.total * 100 | floor)
                else
                    0
                end
            )%)"' "$AGENT_METRICS" 2>/dev/null || log_warning "Metrics not available"
    fi
    echo ""
}

# Show doom loops
show_loops() {
    print_header
    log_info "Doom Loop Detection Report"
    echo ""

    if [[ ! -f "$LOOP_DETECTION" ]]; then
        log_error "Loop detection file not found"
        return 1
    fi

    local threshold=$(jq -r '.thresholds.max_modifications' "$LOOP_DETECTION")

    jq -r ".files | to_entries[] |
        select(.value.count >= $threshold) |
        \"\(.key): \(.value.count) modifications (threshold: $threshold)\"" "$LOOP_DETECTION" 2>/dev/null | while read -r line; do
        log_warning "$line"
    done

    local count=$(jq -r "[.files | to_entries[] | select(.value.count >= $threshold)] | length" "$LOOP_DETECTION" 2>/dev/null || echo "0")

    if [[ "$count" -eq 0 ]]; then
        log_success "No doom loops detected (threshold: $threshold)"
    else
        echo ""
        log_warning "$count file(s) exceed modification threshold"
        echo "Review .harness/on-the-loop.md for remediation steps"
    fi
}

# Show improvement suggestions
show_improvements() {
    print_header
    log_info "Improvement Suggestions"
    echo ""

    local suggestion_file="${HARNESS_DIR}/improvement-suggestions.json"

    # 자동 생성된 제안이 있으면 우선 표시
    if [[ -f "$suggestion_file" ]]; then
        local count=$(jq '.count // 0' "$suggestion_file" 2>/dev/null || echo "0")
        if [[ $count -gt 0 ]]; then
            echo -e "${CYAN}Auto-generated suggestions (${count} items):${NC}"
            jq -r '.suggestions[] |
                "  \(.severity | ascii_upcase): \(.recommendation)"' "$suggestion_file" 2>/dev/null | head -20 || true
            echo ""
            echo -e "${BLUE}Full report: /harness improve show${NC}"
            echo ""
        fi
    fi

    # 로그에서도 읽기
    if [[ ! -f "$IMPROVEMENT_LOG" ]]; then
        log_error "No improvement data found"
        return 1
    fi

    # Group by severity
    echo -e "${RED}🔴 Critical:${NC}"
    jq -r 'select(.severity=="critical") | "  [\(.timestamp)] \(.recommendation)"' "$IMPROVEMENT_LOG" 2>/dev/null || echo "  None"
    echo ""

    echo -e "${YELLOW}🟡 Major:${NC}"
    jq -r 'select(.severity=="major") | "  [\(.timestamp)] \(.recommendation)"' "$IMPROVEMENT_LOG" 2>/dev/null || echo "  None"
    echo ""

    echo -e "${GREEN}🟢 Minor/Info:${NC}"
    local count=$(jq -s '[.[] | select(.severity=="minor" or .severity=="info")] | length' "$IMPROVEMENT_LOG" 2>/dev/null || echo "0")
    echo "  $count entries (use --verbose to see all)"
}

# Add improvement entry
add_improvement() {
    local type=""
    local agent=""
    local severity=""
    local observation=""
    local recommendation=""
    local expected_impact=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --type) type="$2"; shift 2 ;;
            --agent) agent="$2"; shift 2 ;;
            --severity) severity="$2"; shift 2 ;;
            --observation) observation="$2"; shift 2 ;;
            --recommendation) recommendation="$2"; shift 2 ;;
            --impact) expected_impact="$2"; shift 2 ;;
            *) shift ;;
        esac
    done

    if [[ -z "$type" ]] || [[ -z "$recommendation" ]]; then
        log_error "Required: --type and --recommendation"
        echo "Usage: /harness improve add --type <type> --recommendation <text>"
        return 1
    fi

    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local severity="${severity:-minor}"
    local agent="${agent:-unknown}"

    local entry=$(jq -n \
        --arg ts "$timestamp" \
        --arg type "$type" \
        --arg agent "$agent" \
        --arg sev "$severity" \
        --arg obs "$observation" \
        --arg rec "$recommendation" \
        --arg imp "${expected_impact:-TBD}" \
        '{
            timestamp: $ts,
            type: $type,
            agent: $agent,
            severity: $sev,
            observation: $obs,
            recommendation: $rec,
            expected_impact: $imp
        }')

    echo "$entry" >> "$IMPROVEMENT_LOG"
    log_success "Improvement entry added"
}

# Show guide/sensor metrics
show_metrics() {
    print_header
    log_info "Guide/Sensor Utilization"
    echo ""

    if [[ ! -f "$GUIDE_SENSOR_STATS" ]]; then
        log_error "Metrics file not found"
        return 1
    fi

    echo -e "${CYAN}Computational Guides (결정론적, 행동 전):${NC}"
    jq -r '.guides.computational | to_entries[] | "  \(.key): \(.value) uses"' "$GUIDE_SENSOR_STATS" 2>/dev/null
    echo ""

    echo -e "${CYAN}Inferential Guides (AI 기반, 행동 전):${NC}"
    jq -r '.guides.inferential | to_entries[] | "  \(.key): \(.value) uses"' "$GUIDE_SENSOR_STATS" 2>/dev/null
    echo ""

    echo -e "${CYAN}Computational Sensors (결정론적, 행동 후):${NC}"
    jq -r '.sensors.computational | to_entries[] | "  \(.key): \(.value) uses"' "$GUIDE_SENSOR_STATS" 2>/dev/null
    echo ""

    echo -e "${CYAN}Inferential Sensors (AI 기반, 행동 후):${NC}"
    jq -r '.sensors.inferential | to_entries[] | "  \(.key): \(.value) uses"' "$GUIDE_SENSOR_STATS" 2>/dev/null
}

# Reset metrics
reset_metrics() {
    log_warning "This will reset all harness metrics"
    read -p "Are you sure? (y/N): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        init_harness
        log_success "Metrics reset to defaults"
    else
        log_info "Reset cancelled"
    fi
}

# Main
main() {
    local command="${1:-status}"
    shift || true

    case "$command" in
        -h|--help|help)
            show_help
            ;;
        status)
            show_status
            ;;
        loops)
            show_loops
            ;;
        improve)
            local subcmd="${1:-show}"
            shift || true
            case "$subcmd" in
                show) show_improvements ;;
                add) add_improvement "$@" ;;
                analyze)
                    # 자동 개선 분석 실행
                    log_info "Running automatic improvement analysis..."
                    if command -v python3 &> /dev/null; then
                        python3 "${PROJECT_ROOT}/scripts/auto_improvement.py" analyze
                    else
                        log_warning "Python 3 not found. Skipping analysis."
                    fi
                    ;;
                *) log_error "Unknown subcommand: $subcmd" ;;
            esac
            ;;
        metrics)
            show_metrics
            ;;
        reset)
            reset_metrics
            ;;
        *)
            log_error "Unknown command: $command"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
