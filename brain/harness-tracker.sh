#!/bin/bash
#
# harness-tracker.sh - 하네스 자동 추적 라이브러리
#
# 스킬 실행 시 자동으로 메트릭 기록
#
# 하네스 기본 원칙:
#   - Computational Guides (결정론적, 행동 전): lint, type_check, template
#   - Inferential Guides (AI 기반, 행동 전): code_review, design_advice
#   - Computational Sensors (결정론적, 행동 후): tests, ci, format
#   - Inferential Sensors (AI 기반, 행동 후): llm_judge, semantic
#
# 수정 최소화 원칙 (Minimal Change Principle):
#   - 변경은 최소한으로: diff-only, 불필요한 재작업 금지
#   - 확장이 꼭 필요하면 전체 수정 허용 (예: 리팩토링, 아키텍처 변경)
#   - 과도한 수정 자동 감지 및 경고
#
# Usage:
#   source harness-tracker.sh
#   harness_track_start <skill_name> <args>
#   ... 스킬 실행 ...
#   harness_track_end <skill_name> <exit_code>
#

set -euo pipefail

# Configuration
# 하네스 데이터는 실행 위치(CWD)와 무관하게 한 곳에 통합한다.
# HARNESS_HOME 환경변수로 오버라이드 가능, 기본값은 설치 영역(~/.claude/.harness, 영속적).
HARNESS_DIR="${HARNESS_HOME:-${HOME}/.claude/.harness}"
LOOP_DETECTION="${HARNESS_DIR}/loop-detection.json"
IMPROVEMENT_LOG="${HARNESS_DIR}/improvement-log.jsonl"
AGENT_METRICS="${HARNESS_DIR}/metrics/agent-success-rate.json"
GUIDE_SENSOR_STATS="${HARNESS_DIR}/metrics/guide-sensor-stats.json"

# Guide/Sensor 분류 (스킬별 설정 - 함수로 구현하여 bash 3.x 호환)
# format-check, lint-smart → Computational Sensor
# code-reviewer, review → Inferential Guide
# qa, test, smart-qa → Computational Sensor
# prd → Inferential Guide

harness_get_classification() {
    local skill="$1"
    case "$skill" in
        format-check|lint-smart)
            echo "sensor:computational:format" ;;
        code-reviewer|review)
            echo "guide:inferential:code_review" ;;
        qa|test|smart-qa)
            echo "sensor:computational:tests" ;;
        prd)
            echo "guide:inferential:design_advice" ;;
        *)
            echo "sensor:computational:generic" ;;
    esac
}

# ============================================================================
# Time helpers (millisecond resolution)
# ============================================================================

# 현재 시각을 밀리초(epoch ms)로 반환.
# BSD date(macOS)는 %3N(나노초)을 지원하지 않으므로 호환 방법 사용:
#   1) GNU date(%s%3N) 시도  2) python3  3) perl  4) 초*1000 fallback
harness_now_ms() {
    local ms
    ms=$(date +%s%3N 2>/dev/null)
    # GNU date 가 아니면 "...N" 같은 리터럴이 남으므로 숫자만인지 검증
    if [[ "$ms" =~ ^[0-9]+$ ]]; then
        echo "$ms"
        return 0
    fi
    if command -v python3 &>/dev/null; then
        python3 -c 'import time; print(int(time.time()*1000))'
        return 0
    fi
    if command -v perl &>/dev/null; then
        perl -MTime::HiRes=time -e 'printf("%d\n", time()*1000)'
        return 0
    fi
    # 최후 fallback: 초 해상도
    echo "$(($(date +%s) * 1000))"
}

# ============================================================================
# Initialization
# ============================================================================

harness_init() {
    mkdir -p "$HARNESS_DIR/metrics"
    mkdir -p "$(dirname "$LOOP_DETECTION")"
    mkdir -p "$(dirname "$IMPROVEMENT_LOG")"

    # 루프 탐지 초기화
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

    # 에이전트 메트릭 초기화
    if [[ ! -f "$AGENT_METRICS" ]]; then
        cat > "$AGENT_METRICS" << 'EOF'
{
  "version": "1.0.0",
  "agents": {}
}
EOF
    fi

    # 개선 로그 초기화
    if [[ ! -f "$IMPROVEMENT_LOG" ]]; then
        echo '{"timestamp":"2025-01-12T00:00:00Z","type":"harness_init","agent":"system","severity":"info","message":"Harness initialized"}' > "$IMPROVEMENT_LOG"
    fi
}

# ============================================================================
# Loop Detection
# ============================================================================

# 루프 탐지 체크 (스킬 실행 전)
harness_check_loops() {
    local skill_name="$1"
    shift
    local files=("$@")

    harness_init

    local warnings=0
    local threshold=$(jq -r '.thresholds.max_modifications' "$LOOP_DETECTION")

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            local count=$(jq -r ".files[\"$file\"].count // 0" "$LOOP_DETECTION")
            local last_mod=$(jq -r ".files[\"$file\"].last_modified // \"never\"" "$LOOP_DETECTION")

            if [[ "$count" -ge "$threshold" ]]; then
                echo "⚠️ Loop Warning: $file modified $count times (last: $last_mod)" >&2
                warnings=$((warnings + 1))
            fi
        fi
    done

    # exit code 는 경고 카운트가 아니라 boolean(0=정상, 1=경고 발생)로 반환.
    # 경고 개수를 카운트로 돌려주면 호출부의 `|| true`에 모두 묻혀 의미가 없고,
    # exit code 의미(0=성공)도 위반됨.
    [[ "$warnings" -eq 0 ]]
}

# 파일 수정 기록 (스킬 실행 후)
harness_record_modification() {
    local skill_name="$1"
    local files=("$@")

    local tmp_file="${LOOP_DETECTION}.tmp"
    local now=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    for file in "${files[@]}"; do
        if [[ -f "$file" ]]; then
            jq --arg file "$file" \
               --arg now "$now" \
               --arg skill "$skill_name" \
               '
               if .files[$file] then
                 .files[$file].count += 1 |
                 .files[$file].last_modified = $now |
                 .files[$file].last_skill = $skill
               else
                 .files[$file] = {
                   count: 1,
                   last_modified: $now,
                   last_skill: $skill,
                   created: $now
                 }
               end |
               .last_updated = $now
               ' "$LOOP_DETECTION" > "$tmp_file"
            mv "$tmp_file" "$LOOP_DETECTION"
        fi
    done
}

# ============================================================================
# Agent Metrics
# ============================================================================

# 스킬 실행 시작 기록
harness_track_start() {
    local skill_name="$1"
    shift
    local args="$*"

    harness_init

    # 밀리초 단위로 측정 (초 단위는 1초 미만 스킬이 항상 0)
    local start_time=$(harness_now_ms)
    export HARNESS_SKILL_START="$start_time"
    export HARNESS_SKILL_NAME="$skill_name"

    # DEBUG: echo "[HARNESS] Started: $skill_name at ${start_time}ms" >&2
}

# 스킬 실행 종료 기록
harness_track_end() {
    local skill_name="$1"
    local exit_code="${2:-0}"
    shift 2
    local output="$*"

    # 밀리초 단위 측정 (avg_duration_ms 로 기록 → 1초 미만도 0이 아님)
    local end_time=$(harness_now_ms)
    local duration_ms=$((end_time - ${HARNESS_SKILL_START:-$end_time}))

    # 에이전트 메트릭 업데이트
    local tmp_file="${AGENT_METRICS}.tmp"

    jq --arg agent "$skill_name" \
       --argjson code "$exit_code" \
       --argjson duration "$duration_ms" \
       '
       if .agents[$agent] then
         .agents[$agent].total += 1 |
         if $code == 0 then
           .agents[$agent].success += 1
         else
           .agents[$agent].failure += 1
         end |
         .agents[$agent].last_run = (now | todate) |
         .agents[$agent].avg_duration_ms = (((.agents[$agent].avg_duration_ms // 0) * (.agents[$agent].total - 1) + $duration) / .agents[$agent].total)
       else
         .agents[$agent] = {
           total: 1,
           success: (if $code == 0 then 1 else 0 end),
           failure: (if $code != 0 then 1 else 0 end),
           last_run: (now | todate),
           avg_duration_ms: $duration
         }
       end
       ' "$AGENT_METRICS" > "$tmp_file"
    mv "$tmp_file" "$AGENT_METRICS"

    # Guide/Sensor 분류 통계 갱신 (분류 함수가 정의만 되고 호출 안 되던 문제 해결)
    harness_update_classification "$skill_name"

    # 실패 시 개선 로그 기록
    if [[ "$exit_code" != "0" ]]; then
        harness_log_failure "$skill_name" "$exit_code" "$output"
    fi

    # DEBUG: echo "[HARNESS] Ended: $skill_name (exit: $exit_code, duration: ${duration_ms}ms)" >&2
}

# 스킬의 guide/sensor 분류를 조회해 guide-sensor-stats.json 카운트 증가
harness_update_classification() {
    local skill_name="$1"

    local classification
    classification=$(harness_get_classification "$skill_name")

    # "category:kind:metric" 형식 파싱 (예: sensor:computational:tests)
    local category="${classification%%:*}"          # guide | sensor
    local rest="${classification#*:}"
    local kind="${rest%%:*}"                          # computational | inferential
    local metric="${rest##*:}"                        # tests, code_review, ...

    [[ -n "$category" && -n "$kind" && -n "$metric" ]] || return 0

    local stats_file="$GUIDE_SENSOR_STATS"
    # 파일/스키마 초기화
    if [[ ! -f "$stats_file" ]]; then
        mkdir -p "$(dirname "$stats_file")"
        cat > "$stats_file" << 'EOF'
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

    # category 단수형(guide/sensor) → JSON 키 복수형(guides/sensors)
    local top_key="${category}s"

    local tmp_file="${stats_file}.tmp"
    jq --arg top "$top_key" \
       --arg kind "$kind" \
       --arg metric "$metric" \
       '
       .[$top] = (.[$top] // {}) |
       .[$top][$kind] = (.[$top][$kind] // {}) |
       .[$top][$kind][$metric] = ((.[$top][$kind][$metric] // 0) + 1)
       ' "$stats_file" > "$tmp_file" && mv "$tmp_file" "$stats_file"
}

# ============================================================================
# Improvement Logging
# ============================================================================

harness_log_failure() {
    local skill_name="$1"
    local exit_code="$2"
    local output="${3:-}"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # -c (compact): 한 줄 = 한 객체 (JSONL 무결성 유지)
    jq -nc \
        --arg ts "$timestamp" \
        --arg agent "$skill_name" \
        --argjson code "$exit_code" \
        --arg out "${output:0:500}" \
        '{
            timestamp: $ts,
            type: "skill_failure",
            agent: $agent,
            severity: (if $code >= 2 then "critical" else "major" end),
            exit_code: $code,
            output: $out
        }' >> "$IMPROVEMENT_LOG"
}

harness_log_improvement() {
    local severity="$1"  # critical, major, minor
    local agent="$2"
    local observation="$3"
    local recommendation="$4"

    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # -c (compact): 한 줄 = 한 객체 (JSONL 무결성 유지)
    jq -nc \
        --arg ts "$timestamp" \
        --arg sev "$severity" \
        --arg agent "$agent" \
        --arg obs "$observation" \
        --arg rec "$recommendation" \
        '{
            timestamp: $ts,
            type: "improvement",
            agent: $agent,
            severity: $sev,
            observation: $obs,
            recommendation: $rec
        }' >> "$IMPROVEMENT_LOG"
}

# ============================================================================
# Minimal Change Guide
# ============================================================================

# 수정 최소화 원칙:
#   - 변경은 최소한으로 (diff-only)
#   - 확장이 꼭 필요하면 전체 수정 허용
#   - 불필요한 재작업 금지

# 수정 크기 측정 (스킬 실행 후)
harness_measure_changes() {
    local skill_name="$1"

    if ! command -v git &>/dev/null || ! git rev-parse --git-dir &>/dev/null; then
        return 0
    fi

    # 현재 변경 통계
    local stats=$(git diff --numstat HEAD 2>/dev/null || echo "")
    local files_changed=$(echo "$stats" | wc -l | tr -d ' ')
    local lines_added=$(echo "$stats" | awk '{sum+=$1} END {print sum+0}')
    local lines_deleted=$(echo "$stats" | awk '{sum+=$2} END {print sum+0}')
    local total_changes=$((lines_added + lines_deleted))

    # 메트릭 기록
    local change_metrics="${HARNESS_DIR}/metrics/change-size.jsonl"
    echo "{\"skill\":\"$skill_name\",\"files\":$files_changed,\"added\":$lines_added,\"deleted\":$lines_deleted,\"total\":$total_changes,\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" >> "$change_metrics"

    echo "$files_changed:$lines_added:$lines_deleted:$total_changes"
}

# 최소 수정 검증 (스킬 실행 전 가이드)
harness_verify_minimal_change() {
    local skill_name="$1"
    local max_files=${2:-5}      # 기본 최대 파일 수
    local max_lines=${3:-100}     # 기본 최대 라인 수

    # 기존 변경 확인
    if command -v git &>/dev/null && git rev-parse --git-dir &>/dev/null; then
        local existing_changes=$(git diff --numstat HEAD 2>/dev/null | wc -l | tr -d ' ')

        if [[ "$existing_changes" -gt "$max_files" ]]; then
            echo "⚠️ Minimal Change Warning: $existing_changes files already staged/modified" >&2
            echo "   Consider committing before running $skill_name" >&2
            return 1
        fi
    fi

    return 0
}

# 과도한 수정 경고 (스킬 실행 후)
harness_warn_excessive_changes() {
    local skill_name="$1"
    local max_files=${2:-10}
    local max_lines=${3:-200}

    local changes=$(harness_measure_changes "$skill_name")
    local files_changed=$(echo "$changes" | cut -d: -f1)
    local lines_added=$(echo "$changes" | cut -d: -f2)
    local lines_deleted=$(echo "$changes" | cut -d: -f3)
    local total_changes=$(echo "$changes" | cut -d: -f4)

    if [[ "$files_changed" -gt "$max_files" ]] || [[ "$total_changes" -gt "$max_lines" ]]; then
        echo "⚠️ Excessive Changes Warning" >&2
        echo "   Skill: $skill_name" >&2
        echo "   Files: $files_changed (max: $max_files)" >&2
        echo "   Lines: +$lines_added -$lines_deleted (total: $total_changes, max: $max_lines)" >&2
        echo "" >&2
        echo "   Minimal Change Principle:" >&2
        echo "   • 변경은 최소한으로 (필요한 부분만)" >&2
        echo "   • diff-only 출력 (전체 파일 재출력 금지)" >&2
        echo "   • 확장이 꼭 필요하면 전체 수정 OK" >&2

        # Dedup: git diff HEAD 는 누적이라 동일 change observation 이 매번 반복 로깅된다.
        # 직전 improvement 로그와 (agent, observation)이 같으면 skip.
        local observation="Excessive changes: $files_changed files, $total_changes lines"
        if ! harness_is_duplicate_change "$skill_name" "$observation"; then
            harness_log_improvement "major" "$skill_name" "$observation" "Review changes. Split into smaller commits or reduce scope."
        fi
        return 1
    fi

    return 0
}

# 직전 change observation 과 동일한지 확인 (중복 로깅 방지)
# 반환: 0 = 중복(skip), 1 = 신규(로깅 진행)
harness_is_duplicate_change() {
    local skill_name="$1"
    local observation="$2"

    [[ -f "$IMPROVEMENT_LOG" ]] || return 1

    # 마지막 improvement 엔트리(같은 type/agent)의 observation 추출
    local last_obs
    last_obs=$(jq -rc 'select(.type=="improvement" and .agent==$a) | .observation' \
        --arg a "$skill_name" "$IMPROVEMENT_LOG" 2>/dev/null | tail -1)

    [[ "$last_obs" == "$observation" ]]
}

# ============================================================================
# Analysis
# ============================================================================

# 자동 개선 분석
harness_analyze() {
    harness_init

    local critical_count=$(jq -r 'select(.severity=="critical")' "$IMPROVEMENT_LOG" 2>/dev/null | wc -l || echo "0")
    local failure_rate=$(jq -r '
        .agents |
        to_entries[] |
        select(.value.total > 0) |
        (.value.failure / .value.total)
        ' "$AGENT_METRICS" 2>/dev/null | awk '{s+=$1; n++} END {print (n>0?s/n:0)}')

    # 실패율이 30% 이상이면 경고
    if (( $(echo "$failure_rate > 0.3" | bc -l 2>/dev/null || echo "0") )); then
        echo "⚠️ High failure rate detected: $(printf "%.1f%%" $(echo "$failure_rate * 100" | bc))" >&2
    fi

    # 크리티컬 이슈가 있으면 경고
    if [[ "$critical_count" -gt 0 ]]; then
        echo "🔴 $critical_count critical issues found. Run: /harness improve" >&2
    fi
}

# ============================================================================
# Export
# ============================================================================

export -f harness_now_ms
export -f harness_get_classification
export -f harness_update_classification
export -f harness_is_duplicate_change
export -f harness_init
export -f harness_check_loops
export -f harness_record_modification
export -f harness_track_start
export -f harness_track_end
export -f harness_log_failure
export -f harness_log_improvement
export -f harness_analyze
export -f harness_measure_changes
export -f harness_verify_minimal_change
export -f harness_warn_excessive_changes
