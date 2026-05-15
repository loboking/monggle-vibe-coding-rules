#!/bin/bash
#
# auto-compact.sh - Claude Code 자동 컴팩트 설정 관리
#
# 컨텍스트가 80% 이상 차면 자동으로 compact를 제안합니다.
#
# Usage:
#   /auto-compact on        # auto-compact 활성화
#   /auto-compact off       # auto-compact 비활성화
#   /auto-compact status    # 현재 상태 확인
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
CLAUDE_JSON="$HOME/.claude.json"
AUTO_COMPACT_THRESHOLD=80  # 80% 기준

# OS Detection
detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)   echo "linux" ;;
        msys*|cygwin*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# Portable sed -i
sed_i() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║       Auto-Compact 설정 관리                  ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print success
print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

# Print warning
print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Print error
print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Print info
print_info() {
    echo -e "${BLUE}[→]${NC} $1"
}

# Ensure jq is installed
ensure_jq() {
    if command -v jq &> /dev/null; then
        return 0
    fi
    return 1
}

# Get current auto-compact status
get_status() {
    if [ ! -f "$CLAUDE_JSON" ]; then
        echo "off"
        return
    fi

    if ensure_jq; then
        local status=$(jq -r '.autoCompact // "false"' "$CLAUDE_JSON" 2>/dev/null || echo "false")
        if [ "$status" = "true" ]; then
            echo "on"
        else
            echo "off"
        fi
    else
        # jq 없으면 grep으로 fallback
        if grep -q '"autoCompact"[[:space:]]*:[[:space:]]*true' "$CLAUDE_JSON" 2>/dev/null; then
            echo "on"
        else
            echo "off"
        fi
    fi
}

# Show current status
show_status() {
    print_header

    local status=$(get_status)

    echo -e "${BOLD}현재 Auto-Compact 상태:${NC}"

    if [ "$status" = "on" ]; then
        echo -e "  ${GREEN}활성화 (ON)${NC}"
        echo ""
        echo -e "${BOLD}설정:${NC}"
        echo -e "  - 기준: ${AUTO_COMPACT_THRESHOLD}% 이상 사용 시 자동 compact 제안"
        echo -e "  - 설정 파일: $CLAUDE_JSON"
    else
        echo -e "  ${YELLOW}비활성화 (OFF)${NC}"
        echo ""
        echo -e "${CYAN}활성화하려면: /auto-compact on${NC}"
    fi
    echo ""
}

# Enable auto-compact
enable_auto_compact() {
    print_header
    print_info "Auto-compact 활성화 중..."

    if ensure_jq; then
        # jq가 있으면 안전하게 업데이트
        if [ -f "$CLAUDE_JSON" ]; then
            local tmp_file="$CLAUDE_JSON.tmp"
            jq '.autoCompact = true' "$CLAUDE_JSON" > "$tmp_file" && mv "$tmp_file" "$CLAUDE_JSON"
            print_success "Auto-compact 활성화됨"
        else
            # 파일이 없으면 생성
            cat > "$CLAUDE_JSON" << 'EOF'
{
  "autoCompact": true
}
EOF
            print_success "~/.claude.json 생성 및 auto-compact 활성화됨"
        fi
    else
        # jq가 없으면 수동으로 처리
        print_warning "jq가 설치되지 않아 수동으로 설정합니다"
        print_warning "jq 설치 권장: brew install jq (macOS) 또는 apt install jq (Linux)"

        if [ -f "$CLAUDE_JSON" ]; then
            # 이미 설정되어 있는지 확인
            if grep -q '"autoCompact"[[:space:]]*:[[:space:]]*true' "$CLAUDE_JSON" 2>/dev/null; then
                print_success "이미 활성화되어 있습니다"
            else
                # 간단한 텍스트 추가 (주의: 완전하지 않을 수 있음)
                if ! grep -q 'autoCompact' "$CLAUDE_JSON"; then
                    # 파일 끝에 콤마가 있으면 추가, 없으면 콤마와 함께 추가
                    if tail -c1 "$CLAUDE_JSON" | grep -q '}'; then
                        # 마지막 } 전에 추가
                        sed_i 's/}$/,\n  "autoCompact": true\n}/' "$CLAUDE_JSON"
                        print_success "Auto-compact 활성화됨 (jq 설치 권장)"
                    fi
                fi
            fi
        else
            # 파일 생성
            cat > "$CLAUDE_JSON" << 'EOF'
{
  "autoCompact": true
}
EOF
            print_success "~/.claude.json 생성 및 auto-compact 활성화됨"
        fi
    fi

    echo ""
    echo -e "${CYAN}설정 파일: $CLAUDE_JSON${NC}"
    echo -e "${CYAN}기준: ${AUTO_COMPACT_THRESHOLD}% 이상 사용 시 자동 compact 제안${NC}"
    echo ""
}

# Disable auto-compact
disable_auto_compact() {
    print_header
    print_info "Auto-compact 비활성화 중..."

    if [ ! -f "$CLAUDE_JSON" ]; then
        print_success "이미 비활성화되어 있습니다 (설정 파일 없음)"
        echo ""
        return
    fi

    if ensure_jq; then
        # jq가 있으면 안전하게 제거
        local tmp_file="$CLAUDE_JSON.tmp"
        jq 'del(.autoCompact)' "$CLAUDE_JSON" > "$tmp_file" && mv "$tmp_file" "$CLAUDE_JSON"
        print_success "Auto-compact 비활성화됨"
    else
        # jq가 없으면 수동으로 처리
        if grep -q 'autoCompact' "$CLAUDE_JSON"; then
            # autoCompact 라인 제거 (간단 구현)
            sed_i '/autoCompact/d' "$CLAUDE_JSON"
            print_success "Auto-compact 비활성화됨 (jq 설치 권장)"
        else
            print_success "이미 비활성화되어 있습니다"
        fi
    fi
    echo ""
}

# Show usage
show_usage() {
    print_header
    echo -e "${BOLD}사용법:${NC}"
    echo "  /auto-compact on       # auto-compact 활성화"
    echo "  /auto-compact off      # auto-compact 비활성화"
    echo "  /auto-compact status   # 현재 상태 확인"
    echo ""
    echo -e "${BOLD}설명:${NC}"
    echo "  컨텍스트가 ${AUTO_COMPACT_THRESHOLD}% 이상 차면 자동으로 compact를 제안합니다."
    echo "  Claude Code의 내장 auto-compact 기능을 제어합니다."
    echo ""
    echo -e "${BOLD}설정 파일:${NC} $CLAUDE_JSON"
    echo ""
}

# Main
main() {
    case "${1:-status}" in
        on|enable|true|1)
            enable_auto_compact
            ;;
        off|disable|false|0)
            disable_auto_compact
            ;;
        status|check|"")
            show_status
            ;;
        -h|--help|help)
            show_usage
            ;;
        *)
            echo -e "${RED}알 수 없는 명령: $1${NC}"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
