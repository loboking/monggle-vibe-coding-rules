#!/bin/bash
#
# review.sh - monggle: AI Code Review
#
# Usage:
#   /review                    # Review current changes
#   /review <file>             # Review specific file
#   /review --staged           # Review staged changes
#

set -euo pipefail

# 하네스 래퍼 로드 (자동 추적)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../brain/skill-harness-wrapper.sh" 2>/dev/null || true

# 스킬 종료 시 자동 기록 (trap)
trap 'harness_skill_end $?' EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Get diff based on arguments
get_diff() {
    local target="${1:-}"
    local file="${2:-}"

    if [ "$target" == "--file" ] && [ -n "$file" ]; then
        # Show specific file content
        cat "$file"
    elif [ "$target" == "--staged" ]; then
        # Show staged changes
        git diff --staged
    elif [ -n "$target" ] && [ -f "$target" ]; then
        # Show specific file
        cat "$target"
    else
        # Show unstaged changes
        git diff HEAD 2>/dev/null || git diff
    fi
}

# Main function
main() {
    # 하네스 추적 시작
    harness_skill_start "$@"

    local target=""
    local file=""

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --file)
                target="--file"
                file="$2"
                shift 2
                ;;
            --staged)
                target="--staged"
                shift
                ;;
            *)
                if [ -z "$target" ]; then
                    target="$1"
                fi
                shift
                ;;
        esac
    done

    # Get diff
    local diff
    diff=$(get_diff "$target" "$file")

    if [ -z "$diff" ] || [ "$(echo "$diff" | wc -l)" -lt 2 ]; then
        echo -e "${YELLOW}⚠️ No changes to review${NC}"
        echo ""
        echo "Tips:"
        echo "  - Make some changes first"
        echo "  - Use /review --staged for staged changes"
        echo "  - Use /review <file> to review a specific file"
        return 0
    fi

    # Output review request for Claude Code
    cat <<'EOF'

## 🔍 Code Review Request

Please review the following code changes for:

### Check Areas
- **Security**: Injection vulnerabilities, hardcoded secrets, authentication issues
- **Performance**: Inefficient algorithms, N+1 queries, memory leaks
- **Best Practices**: Code style, naming, structure
- **Error Handling**: Edge cases, null checks, exception handling
- **Test Coverage**: Missing tests, test quality

### Code Changes
```diff
EOF

    echo "$diff"

    cat <<'EOF'
```

### Review Format
Please provide:
1. **Overall Assessment** ✅ APPROVED / ⚠️ NEEDS CHANGES / ❌ REJECTED
2. **Issues Found** (if any) - list with severity [HIGH/MEDIUM/LOW]
3. **Suggestions** - specific improvements
4. **Positive Notes** - what was done well

EOF

    # Show diff stats
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Diff Stats:${NC}"
    echo "$diff" | diffstat 2>/dev/null || echo "  (diffstat not available, showing line count)"
    echo "  Total lines changed: $(echo "$diff" | wc -l | tr -d ' ')"
    echo ""
}

# Run main
main "$@"
