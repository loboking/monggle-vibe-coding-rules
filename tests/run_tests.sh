#!/bin/bash
#
# run_tests.sh - 통합 TDD 테스트 실행기
#
# Option 3 통합 접근법:
#   - Python unittest로 Bash 라이브러리 테스트
#   - bats-core로 스크립트 기능 테스트
#
# Usage:
#   ./run_tests.sh              # 전체 테스트 실행
#   ./run_tests.sh --python     # Python 테스트만
#   ./run_tests.sh --bats       # bats 테스트만
#   ./run_tests.sh --verbose    # 상세 출력
#

set -euo pipefail

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 옵션 파싱
RUN_PYTHON=true
RUN_BATS=true
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --python)
            RUN_BATS=false
            shift
            ;;
        --bats)
            RUN_PYTHON=false
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --python       Python 테스트만 실행"
            echo "  --bats         bats-core 테스트만 실행"
            echo "  --verbose, -v  상세 출력"
            echo "  --help, -h     도움말"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# 헤더 출력
print_header() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
}

# Python 테스트 실행
run_python_tests() {
    print_header "Python Tests (unittest)"

    local python_tests=(
        "tests/test_init_core.py"
        "tests/test_agents.py"
        "tests/test_lib_sh.py"
    )

    local total=0
    local passed=0
    local failed=0

    for test_file in "${python_tests[@]}"; do
        if [[ -f "$PROJECT_ROOT/$test_file" ]]; then
            echo -e "${BLUE}Running:${NC} $test_file"

            if [[ "$VERBOSE" == true ]]; then
                if python3 "$PROJECT_ROOT/$test_file"; then
                    ((passed++))
                else
                    ((failed++))
                fi
            else
                if python3 "$PROJECT_ROOT/$test_file" 2>&1 | tail -20; then
                    ((passed++))
                else
                    ((failed++))
                fi
            fi
            ((total++))
            echo ""
        else
            echo -e "${YELLOW}Skip:${NC} $test_file (not found)"
        fi
    done

    # 요약
    echo -e "${CYAN}Python Tests Summary:${NC}"
    echo "  Total:   $total"
    echo -e "  ${GREEN}Passed:  $passed${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "  ${RED}Failed:  $failed${NC}"
    fi
    echo ""

    return $failed
}

# bats-core 테스트 실행
run_bats_tests() {
    print_header "Bash Tests (bats-core)"

    # bats 설치 확인
    if ! command -v bats &> /dev/null; then
        echo -e "${YELLOW}bats-core not found. Installing...${NC}"

        if [[ "$(uname)" == "Darwin" ]]; then
            brew install bats-core
        else
            # Linux
            if command -v apt-get &> /dev/null; then
                git clone https://github.com/bats-core/bats-core.git /tmp/bats
                sudo /tmp/bats/install.sh /usr/local
                rm -rf /tmp/bats
            else
                echo -e "${RED}Cannot install bats-core automatically. Please install manually.${NC}"
                echo "  macOS: brew install bats-core"
                echo "  Linux: See https://github.com/bats-core/bats-core#installing-bats-from-source"
                return 1
            fi
        fi
    fi

    echo -e "${BLUE}bats version:${NC} $(bats --version)"
    echo ""

    local bats_files=(
        "tests/bash/skills.bats"
        "tests/bash/git_helper.bats"
        "tests/bash/update.bats"
        "tests/bash/push-safe.bats"
        "tests/bash/conflict_helper.bats"
        "tests/bash/e2e_git_collaboration.bats"
    )

    local total=0
    local passed=0
    local failed=0

    for bats_file in "${bats_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$bats_file" ]]; then
            echo -e "${BLUE}Running:${NC} $bats_file"

            # bats 실행 및 결과 파싱 (macOS grep 호환)
            local output
            local bats_exit=0

            # set -u 일시 해제 (empty array 문제 회피)
            set +u
            if [[ "$VERBOSE" == true ]]; then
                output=$(bats --verbose --trace "$PROJECT_ROOT/$bats_file" 2>&1) || bats_exit=$?
            else
                output=$(bats "$PROJECT_ROOT/$bats_file" 2>&1) || bats_exit=$?
            fi
            set -u

            echo "$output"

            # 결과 파싱 (TAP 형식: 1..N)
            local first_line=$(echo "$output" | head -1)
            if [[ "$first_line" =~ ([0-9]+)\.\.([0-9]+) ]]; then
                local num_tests="${BASH_REMATCH[2]}"
            else
                local num_tests="0"
            fi

            # 실패 카운트
            local num_fail=$(echo "$output" | grep -c "^not ok" || true)
            local num_pass=$((num_tests - num_fail))

            total=$((total + num_tests))
            passed=$((passed + num_pass))
            failed=$((failed + num_fail))

            echo ""
        else
            echo -e "${YELLOW}Skip:${NC} $bats_file (not found)"
        fi
    done

    # 요약
    echo -e "${CYAN}Bats Tests Summary:${NC}"
    echo "  Total:   $total"
    echo -e "  ${GREEN}Passed:  $passed${NC}"
    if [[ $failed -gt 0 ]]; then
        echo -e "  ${RED}Failed:  $failed${NC}"
    fi
    echo ""

    return $failed
}

# 메인 실행
main() {
    print_header "TDD Test Runner - Option 3 Combined"
    echo -e "Project Root: ${BLUE}$PROJECT_ROOT${NC}"
    echo ""

    local overall_result=0

    # Python 테스트
    if [[ "$RUN_PYTHON" == true ]]; then
        if ! run_python_tests; then
            overall_result=1
        fi
    fi

    # bats 테스트
    if [[ "$RUN_BATS" == true ]]; then
        if ! run_bats_tests; then
            overall_result=1
        fi
    fi

    # 전체 결과
    print_header "Test Complete"
    if [[ $overall_result -eq 0 ]]; then
        echo -e "${GREEN}✓ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        return 1
    fi
}

# 실행
main "$@"
