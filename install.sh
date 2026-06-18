#!/bin/bash
#
# install.sh - Monggle Vibe Coding Rules Installer
#
# 원클릭 설치 스크립트
# - settings.json 동적 생성
# - 실행 권한 설정
# - 필수 디렉토리 생성
#
# Usage:
#   ./install.sh              # 현재 디렉토리에 설치
#   ./install.sh /path/to/project  # 특정 프로젝트에 설치
#   ./install.sh --sync       # 저장소에 없는 전역 스킬 잔재 정리(백업 후 제거)
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# OS Detection for cross-platform compatibility
detect_os() {
    case "$OSTYPE" in
        darwin*)  echo "macos" ;;
        linux*)   echo "linux" ;;
        msys*|cygwin*) echo "windows" ;;
        *)        echo "unknown" ;;
    esac
}

OS_TYPE=$(detect_os)

# Print header
print_header() {
    echo ""
    echo -e "${CYAN}${BOLD}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}${BOLD}║   Monggle Vibe Coding Rules - Installer     ║${NC}"
    echo -e "${CYAN}${BOLD}╚════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Print step
print_step() {
    echo -e "${BLUE}[→]${NC} $1"
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

# Portable sed -i for macOS/Linux compatibility
sed_i() {
    if [[ "$OS_TYPE" == "macos" ]]; then
        sed -i "" "$@"
    else
        sed -i "$@"
    fi
}

# Ensure jq is installed
ensure_jq() {
    if command -v jq &> /dev/null; then
        return 0
    fi

    print_warning "jq not found, attempting to install..."

    case "$OS_TYPE" in
        macos)
            if command -v brew &> /dev/null; then
                brew install jq
            else
                print_error "Homebrew not found. Install jq manually: brew install jq"
                return 1
            fi
            ;;
        linux)
            if command -v apt-get &> /dev/null; then
                if command -v sudo &> /dev/null; then
                    sudo apt-get update && sudo apt-get install -y jq
                else
                    apt-get update && apt-get install -y jq
                fi
            elif command -v yum &> /dev/null; then
                if command -v sudo &> /dev/null; then
                    sudo yum install -y jq
                else
                    yum install -y jq
                fi
            elif command -v dnf &> /dev/null; then
                if command -v sudo &> /dev/null; then
                    sudo dnf install -y jq
                else
                    dnf install -y jq
                fi
            elif command -v pacman &> /dev/null; then
                if command -v sudo &> /dev/null; then
                    sudo pacman -S jq
                else
                    pacman -S jq
                fi
            else
                print_error "Package manager not found. Install jq manually"
                return 1
            fi
            ;;
        windows)
            if command -v choco &> /dev/null; then
                choco install jq
            elif command -v winget &> /dev/null; then
                winget install jqlang.jq
            else
                print_error "Package manager not found. Install jq manually: choco install jq"
                return 1
            fi
            ;;
        *)
            print_error "Unknown OS. Install jq manually"
            return 1
            ;;
    esac

    # Verify installation
    if command -v jq &> /dev/null; then
        print_success "jq installed successfully"
        return 0
    else
        print_error "Failed to install jq"
        return 1
    fi
}

# Check Python version
check_python() {
    print_step "Checking Python version..."

    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
    else
        print_error "Python not found"
        return 1
    fi

    # Get version
    PYTHON_VERSION=$($PYTHON_CMD --version 2>&1 | awk '{print $2}')
    PYTHON_MAJOR=$(echo $PYTHON_VERSION | cut -d. -f1)
    PYTHON_MINOR=$(echo $PYTHON_VERSION | cut -d. -f2)

    print_success "Python $PYTHON_VERSION found"

    # Check version (3.8+)
    if [ "$PYTHON_MAJOR" -lt 3 ] || ([ "$PYTHON_MAJOR" -eq 3 ] && [ "$PYTHON_MINOR" -lt 8 ]); then
        print_error "Python 3.8+ required, found $PYTHON_VERSION"
        return 1
    fi

    print_success "Python version compatible (3.8+)"
    return 0
}

# Create directories
create_directories() {
    print_step "Creating directories..."

    mkdir -p "$PROJECT_ROOT/.claude/commands"
    mkdir -p "$PROJECT_ROOT/.claude/hooks"
    mkdir -p "$PROJECT_ROOT/prd"
    mkdir -p "$PROJECT_ROOT/agents"
    mkdir -p "$PROJECT_ROOT/logs"
    mkdir -p "$PROJECT_ROOT/rules"

    # 전역 디렉토리도 생성
    mkdir -p "$HOME/.claude/commands"
    mkdir -p "$HOME/.claude/skills"

    print_success "Directories created"
}

# 스킬 메타데이터 생성 (Claude Code v1.7+ 호환)
create_skill_metadata() {
    local global_dir="$HOME/.claude/commands"
    local skills_dir="$HOME/.claude/skills"

    # 스킬 정의 배열
    local skills=(
        "debug|체계적 버그 분석"
        "debug-perf|성능 병목 찾기"
        "debug-web|프론트엔드 디버깅"
        "debug-css|CSS 디버깅"
        "debug-m|메모리 누수 탐지"
        "qa|Smart QA testing"
        "qa-only|QA 보고서만"
        "investigate|시스템적 디버깅"
        "bottleneck|성능 병목 탐지"
        "front-bugfix|프론트엔드 버그 수정"
        "css-bugfix|CSS 버그 수정"
        "mem-check|메모리 체크"
        "review|코드 리뷰"
        "review-code|코드 품질 리뷰"
        "review-arch|아키텍처 리뷰"
        "code-reviewer|코드 리뷰어"
        "arch-review|아키텍처 리뷰어"
        "prd|PRD 작성기"
        "brainstorm|브레인스토밍"
        "idea|아이디어 수집기"
        "gate|PRD 게이트"
        "pipeline|에이전트 파이프라인"
        "stats|통계"
        "trace|파이프라인 추적"
        "mode|작업 모드"
        "changelog|Changelog 생성"
        "bump|버전 업"
        "push-safe|안전한 푸시"
        "format-check|포맷 체크"
        "lint-smart|스마트 린터"
        "complexity|복잡도 분석"
        "bench|벤치마크"
        "api-docs|API 문서"
        "profile|프로파일링"
        "audit|보안 감사"
        "security|보안성 검증"
        "save-point|저장 포인트"
        "quick|빠른 핫픽스"
        "init|초기화"
        "weekly-recap|주간 회고"
        "verify|AI 응답 검증"
        "pattern|패턴 계약"
        "monggle|Monggle 툴킷"
    )

    local created_count=0

    for skill_info in "${skills[@]}"; do
        IFS='|' read -r skill_name description <<< "$skill_info"
        local skill_dir="$skills_dir/$skill_name"

        mkdir -p "$skill_dir"

        # skill.json 생성
        cat > "$skill_dir/skill.json" << SKILL_EOF
{
  "name": "$skill_name",
  "description": "$description",
  "version": "1.0.0"
}
SKILL_EOF

        # skill.md도 생성 (하위 호환성)
        cat > "$skill_dir/skill.md" << SKILL_MD_EOF
# $skill_name

$description
SKILL_MD_EOF

        ((created_count++))
    done

    # .sh 파일이 있는데 메타데이터가 없는 스킬도 처리
    for script in "$global_dir"/*.sh; do
        if [ -f "$script" ]; then
            local skill_name=$(basename "$script" .sh)
            # 이미 처리됐으면 건너뜀
            if [ ! -f "$skills_dir/$skill_name/skill.json" ]; then
                # monggle- 접두사 제거
                local clean_name="${skill_name#monggle-}"
                local skill_dir="$skills_dir/$clean_name"
                mkdir -p "$skill_dir"

                cat > "$skill_dir/skill.json" << SKILL_EOF2
{
  "name": "$clean_name",
  "description": "Monggle $clean_name skill",
  "version": "1.0.0"
}
SKILL_EOF2

                cat > "$skill_dir/skill.md" << SKILL_MD_EOF2
# $clean_name

Monggle $clean_name skill
SKILL_MD_EOF2

                ((created_count++))
            fi
        fi
    done

    print_success "Created/updated $created_count skill metadata files"
}

# 전역 설치 (스킬 복사)
install_global() {
    print_step "Installing skills to global ~/.claude/commands/..."

    local global_dir="$HOME/.claude/commands"
    local local_commands="$SCRIPT_DIR/.claude/commands"
    local count=0

    # 전역 디렉토리 생성
    mkdir -p "$global_dir"

    # monggle- 접두사 스킬들도 복사 (심볼릭 링크로)
    for script in "$local_commands"/monggle-*.sh; do
        if [ -f "$script" ]; then
            local basename=$(basename "$script")
            cp "$script" "$global_dir/$basename"
            chmod +x "$global_dir/$basename"
            ((count++))
        fi
    done

    # monggle- 접두사 없는 스킬들도 복사
    for script in "$local_commands"/*.sh; do
        local basename=$(basename "$script")
        # monggle- 스킬은 이미 처리됨 (경로가 아닌 파일명 기준으로 판별)
        if [[ "$basename" == monggle-* ]]; then
            continue
        fi
        if [ -f "$script" ]; then
            cp "$script" "$global_dir/$basename"
            chmod +x "$global_dir/$basename"
            ((count++))
        fi
    done

    # .md 파일도 복사 (스킬 메타데이터용)
    local md_count=0
    for md_file in "$local_commands"/*.md; do
        if [ -f "$md_file" ]; then
            local basename=$(basename "$md_file")
            # 이미 존재하고 내용이 같으면 건너뜀
            if [ -f "$global_dir/$basename" ]; then
                if ! cmp -s "$md_file" "$global_dir/$basename" 2>/dev/null; then
                    cp "$md_file" "$global_dir/$basename"
                    ((md_count++))
                fi
            else
                cp "$md_file" "$global_dir/$basename"
                ((md_count++))
            fi
        fi
    done

    # 동기화 모드(--sync): 저장소에 없는 전역 스킬 잔재 정리 (백업 후 제거)
    if [ "${SYNC_MODE:-false}" = true ]; then
        local pruned=0
        local backup_dir="$HOME/.claude/_skill_backup_$(date +%Y%m%d_%H%M%S)"
        for installed in "$global_dir"/*.sh "$global_dir"/*.md; do
            [ -f "$installed" ] || continue
            local ib=$(basename "$installed")
            local stem="${ib%.*}"
            # 보조 파일은 보존
            case "$ib" in
                completions-v2.bash|wrapper.sh) continue ;;
            esac
            # 저장소(local_commands)에 동일 stem의 .sh 또는 .md가 있으면 공식 → 보존
            if [ -f "$local_commands/$stem.sh" ] || [ -f "$local_commands/$stem.md" ]; then
                continue
            fi
            # 잔재 → 백업 후 제거
            mkdir -p "$backup_dir"
            mv "$installed" "$backup_dir/" 2>/dev/null && ((pruned++)) || true
        done
        if [ "$pruned" -gt 0 ]; then
            print_success "Pruned $pruned stale global skill files (backup: $backup_dir)"
        fi
    fi

    # completions-v2.bash 자동 생성
    print_step "Creating completions-v2.bash..."
    cat > "$global_dir/completions-v2.bash" << 'COMPLETION_EOF'
#!/bin/bash
#
# completions-v2.bash - Vibe Coding Rules 자동 완성
#

_vibe_skills_complete() {
    local cur prev words cword
    _init_completion || return

    local cmd="${words[0]#/}"
    cmd="${cmd#monggle-}"

    case "$cmd" in
        stats) COMPREPLY=($(compgen -W "--verbose --web --json --filter-verdict --filter-type --filter-agent --since --help" -- "$cur")) ;;
        qa) COMPREPLY=($(compgen -W "--report --quick --format --android --ios --web --mobile --server --code --help" -- "$cur")) ;;
        prd) COMPREPLY=($(compgen -W "--non-interactive --output --language --type --help feature bug refactor hotfix experiment api migration ml devops" -- "$cur")) ;;
        debug) COMPREPLY=($(compgen -W "--web --css --perf --mem --verbose --help" -- "$cur")) ;;
        review) COMPREPLY=($(compgen -W "--code --arch --diff --help" -- "$cur")) ;;
        impact) COMPREPLY=($(compgen -W "--diff --deep --verbose --help" -- "$cur")) ;;
        save-point) COMPREPLY=($(compgen -W "list resume restore cleanup --help" -- "$cur")) ;;
        mode) COMPREPLY=($(compgen -W "solo team manual semi-auto auto --help" -- "$cur")) ;;
        complexity) COMPREPLY=($(compgen -W "--threshold --output --format --help" -- "$cur")) ;;
        audit) COMPREPLY=($(compgen -W "--severity --output --format --help" -- "$cur")) ;;
        bench) COMPREPLY=($(compgen -W "--iterations --warmup --output --format --help" -- "$cur")) ;;
        bottleneck) COMPREPLY=($(compgen -W "--threshold --output --format --help" -- "$cur")) ;;
        changelog) COMPREPLY=($(compgen -W "--since --until --output --format --help" -- "$cur")) ;;
        bump) COMPREPLY=($(compgen -W "--major --minor --patch --pre --tag --help" -- "$cur")) ;;
        push-safe) COMPREPLY=($(compgen -W "--dry --force --help" -- "$cur")) ;;
        quick) COMPREPLY=($(compgen -W "--help" -- "$cur")) ;;
        format-check) COMPREPLY=($(compgen -W "--fix --help" -- "$cur")) ;;
        lint-smart) COMPREPLY=($(compgen -W "--fix --help" -- "$cur")) ;;
        brainstorm) COMPREPLY=($(compgen -W "--count --output --format --help" -- "$cur")) ;;
        gate) COMPREPLY=($(compgen -W "--strict --help" -- "$cur")) ;;
        pipeline) COMPREPLY=($(compgen -W "--dry-run --verbose --retry --parallel --help" -- "$cur")) ;;
        trace) COMPREPLY=($(compgen -W "--last --detail --help" -- "$cur")) ;;
        init) COMPREPLY=($(compgen -W "--force --help" -- "$cur")) ;;
        *)
            local skills="$(ls ~/.claude/commands/*.sh 2>/dev/null | xargs -n1 basename | sed 's/\.sh$//' | sort | uniq)"
            COMPREPLY=($(compgen -W "$skills" -- "$cur"))
            ;;
    esac
}

for cmd in stats qa prd debug review impact save-point mode complexity audit bench bottleneck changelog bump push-safe quick format-check lint-smart brainstorm gate pipeline trace init help; do
    complete -F _vibe_skills_complete $cmd
    complete -F _vibe_skills_complete monggle-$cmd
done
COMPLETION_EOF

    chmod +x "$global_dir/completions-v2.bash"
    print_success "completions-v2.bash created"

    if [ $md_count -gt 0 ]; then
        print_success "Copied/updated $md_count skill metadata files to global"
    fi

    print_success "Copied/updated $count skill scripts to global"

    # 하네스 파일도 전역으로 복사
    print_step "Installing harness system to global..."
    local global_brain="$HOME/.claude/brain"
    mkdir -p "$global_brain"

    if [ -f "$SCRIPT_DIR/.claude/brain/harness-tracker.sh" ]; then
        cp "$SCRIPT_DIR/.claude/brain/harness-tracker.sh" "$global_brain/harness-tracker.sh"
        chmod +x "$global_brain/harness-tracker.sh"
    fi

    if [ -f "$SCRIPT_DIR/.claude/brain/skill-harness-wrapper.sh" ]; then
        cp "$SCRIPT_DIR/.claude/brain/skill-harness-wrapper.sh" "$global_brain/skill-harness-wrapper.sh"
        chmod +x "$global_brain/skill-harness-wrapper.sh"
    fi

    # brain 코어를 전역으로 복사 (회상/저장 엔진)
    if [ -f "$SCRIPT_DIR/.claude/brain/brain-core.sh" ]; then
        cp "$SCRIPT_DIR/.claude/brain/brain-core.sh" "$global_brain/brain-core.sh"
        chmod +x "$global_brain/brain-core.sh"
    fi

    # brain 상시 기억 훅 4개를 전역 hooks 디렉토리로 복사
    # (글로벌 settings.json 이 $HOME/.claude/hooks/brain-*.sh 를 가리킴)
    print_step "Installing brain hooks to global..."
    local global_hooks="$HOME/.claude/hooks"
    mkdir -p "$global_hooks"
    local brain_hook
    for brain_hook in brain-prompt-recall.sh brain-turn-save.sh brain-session-start.sh brain-session-end.sh; do
        if [ -f "$SCRIPT_DIR/.claude/hooks/$brain_hook" ]; then
            cp "$SCRIPT_DIR/.claude/hooks/$brain_hook" "$global_hooks/$brain_hook"
            chmod +x "$global_hooks/$brain_hook"
        fi
    done

    # lib도 전역으로 복사
    print_step "Installing lib system to global..."
    local global_lib="$HOME/.claude/lib"
    mkdir -p "$global_lib"

    if [ -d "$SCRIPT_DIR/.claude/lib" ]; then
        for lib_file in "$SCRIPT_DIR/.claude/lib"/*.sh; do
            if [ -f "$lib_file" ]; then
                cp "$lib_file" "$global_lib/"
                chmod +x "$global_lib/$(basename "$lib_file")"
            fi
        done
    fi

    print_success "Lib files installed to global"

    # 스킬 메타데이터 생성 (skill.json, skill.md)
    print_step "Creating skill metadata for Claude Code v1.7+..."
    create_skill_metadata

}

# Set executable permissions
set_permissions() {
    print_step "Setting executable permissions..."

    chmod +x "$SCRIPT_DIR/.claude/commands/gate.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/commands/pipeline.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/commands/trace.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/hooks/pre-tool-use.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/install.sh" 2>/dev/null || true

    # Set all command scripts as executable (portable way)
    if [ -d "$SCRIPT_DIR/.claude/commands" ]; then
        for script in "$SCRIPT_DIR/.claude/commands"/*.sh; do
            if [ -f "$script" ]; then
                chmod +x "$script" 2>/dev/null || true
            fi
        done
    fi

    # 하네스 파일 실행 권한 설정
    chmod +x "$SCRIPT_DIR/.claude/brain/harness-tracker.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/brain/skill-harness-wrapper.sh" 2>/dev/null || true

    # 전역 하네스 파일 실행 권한
    chmod +x "$HOME/.claude/brain/harness-tracker.sh" 2>/dev/null || true
    chmod +x "$HOME/.claude/brain/skill-harness-wrapper.sh" 2>/dev/null || true

    print_success "Permissions set"
}

# Generate settings.json
generate_settings() {
    print_step "Generating settings.json..."

    cd "$PROJECT_ROOT"

    # Check if Python script exists
    if [ -f "$SCRIPT_DIR/scripts/generate_settings.py" ]; then
        # Run Python script
        if $PYTHON_CMD "$SCRIPT_DIR/scripts/generate_settings.py"; then
            print_success "settings.json generated"
        else
            print_error "Failed to generate settings.json"
            return 1
        fi
    else
        # Fallback: Create basic settings.json manually
        mkdir -p "$PROJECT_ROOT/.claude/config"
        cat > "$PROJECT_ROOT/.claude/settings.json" << EOF
{
  "name": "monggle-vibe-coding-rules",
  "version": "3.1.0",
  "description": "Vibe Coding Rules for Claude Code",
  "language": "$PRD_LANGUAGE",
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "hooks": {
    "SessionStart": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "\$CLAUDE_PROJECT_DIR/.claude/hooks/brain-session-start.sh", "timeout": 10 }
        ]
      }
    ],
    "SessionEnd": [
      {
        "matcher": "*",
        "hooks": [
          { "type": "command", "command": "\$CLAUDE_PROJECT_DIR/.claude/hooks/brain-session-end.sh", "timeout": 30 }
        ]
      }
    ]
  }
}
EOF
        print_success "settings.json created (fallback, brain hooks 포함)"
    fi

    # generate_settings.py 가 hooks 를 넣지 않을 수 있으므로, brain 훅 등록을 보장
    _ensure_brain_hooks "$PROJECT_ROOT/.claude/settings.json"
}

# settings.json 에 brain SessionStart/End 훅이 없으면 주입 (멱등)
_ensure_brain_hooks() {
    local settings_file="$1"
    [ -f "$settings_file" ] || return 0
    command -v jq &> /dev/null || { print_warning "jq 없음 - brain 훅 자동등록 건너뜀"; return 0; }
    # 중복 발화 방지: 글로벌 settings.json 에 이미 brain 훅이 등록돼 있으면
    # 프로젝트 단위 등록은 생략한다 (글로벌 1회 등록으로 모든 프로젝트 작동).
    local global_settings="$HOME/.claude/settings.json"
    if [ -f "$global_settings" ] && \
       jq -e '[.hooks[]?[]?.hooks[]?.command] | any(test("brain-prompt-recall"))' "$global_settings" &> /dev/null; then
        print_success "글로벌 brain 훅이 이미 활성 → 프로젝트 등록 생략 (중복 발화 방지)"
        return 0
    fi
    # 상시 기억 회상 훅(brain-prompt-recall)까지 등록됐으면 완료로 간주
    if jq -e '.hooks.UserPromptSubmit[]?.hooks[]?.command | select(test("brain-prompt-recall"))' "$settings_file" &> /dev/null; then
        return 0  # 이미 등록됨
    fi
    local tmp; tmp=$(mktemp)
    # 멱등: 각 이벤트에 해당 brain 훅이 이미 있으면 중복 추가 안 함
    jq '
        .hooks = (.hooks // {})
        | (((.hooks.SessionStart // []) | map(.hooks[]?.command) | any(test("brain-session-start"))) as $h
           | if $h then . else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-session-start.sh","timeout":10}]}]) end)
        | (((.hooks.UserPromptSubmit // []) | map(.hooks[]?.command) | any(test("brain-prompt-recall"))) as $h
           | if $h then . else .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-prompt-recall.sh","timeout":15}]}]) end)
        | (((.hooks.Stop // []) | map(.hooks[]?.command) | any(test("brain-turn-save"))) as $h
           | if $h then . else .hooks.Stop = ((.hooks.Stop // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-turn-save.sh","timeout":15}]}]) end)
        | (((.hooks.SessionEnd // []) | map(.hooks[]?.command) | any(test("brain-session-end"))) as $h
           | if $h then . else .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"matcher":"*","hooks":[{"type":"command","command":"$CLAUDE_PROJECT_DIR/.claude/hooks/brain-session-end.sh","timeout":30}]}]) end)
    ' "$settings_file" > "$tmp" && mv "$tmp" "$settings_file" && print_success "brain 상시 기억 훅 등록(회상/저장/세션)"
}

# 글로벌 ~/.claude/settings.json 에 brain 훅 4개를 멱등 등록 (전역 1회 설치로 모든 프로젝트 작동)
# 프로젝트용($CLAUDE_PROJECT_DIR)과 달리 $HOME 절대 경로를 사용한다.
# 어떤 실패도 설치 전체를 막지 않는다 (return 0).
_ensure_global_brain_hooks() {
    local settings_file="$HOME/.claude/settings.json"
    command -v jq &> /dev/null || { print_warning "jq 없음 - 글로벌 brain 훅 자동등록 건너뜀"; return 0; }

    # settings.json 이 없으면 최소 골격 생성
    if [ ! -f "$settings_file" ]; then
        mkdir -p "$HOME/.claude"
        printf '{\n  "hooks": {}\n}\n' > "$settings_file"
    fi

    # 손상된 JSON 방어: 파싱 불가하면 등록 건너뜀(기존 파일 보존)
    jq -e . "$settings_file" &> /dev/null || { print_warning "글로벌 settings.json 파싱 실패 - brain 훅 등록 건너뜀"; return 0; }

    # 4개 brain 훅이 모두 이미 있으면 완료로 간주 (빠른 멱등 종료)
    if jq -e '
        ([.hooks[]?[]?.hooks[]?.command] // []) as $cmds
        | ($cmds | any(test("brain-session-start")))
          and ($cmds | any(test("brain-prompt-recall")))
          and ($cmds | any(test("brain-turn-save")))
          and ($cmds | any(test("brain-session-end")))
    ' "$settings_file" &> /dev/null; then
        return 0
    fi

    local tmp; tmp=$(mktemp)
    # 멱등: 각 이벤트에 해당 brain 훅이 이미 있으면 중복 추가 안 함. $HOME 경로 사용.
    jq '
        .hooks = (.hooks // {})
        | (((.hooks.SessionStart // []) | map(.hooks[]?.command) | any(test("brain-session-start"))) as $h
           | if $h then . else .hooks.SessionStart = ((.hooks.SessionStart // []) + [{"matcher":"","hooks":[{"type":"command","command":"$HOME/.claude/hooks/brain-session-start.sh","timeout":10}]}]) end)
        | (((.hooks.UserPromptSubmit // []) | map(.hooks[]?.command) | any(test("brain-prompt-recall"))) as $h
           | if $h then . else .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + [{"matcher":"","hooks":[{"type":"command","command":"$HOME/.claude/hooks/brain-prompt-recall.sh","timeout":15}]}]) end)
        | (((.hooks.Stop // []) | map(.hooks[]?.command) | any(test("brain-turn-save"))) as $h
           | if $h then . else .hooks.Stop = ((.hooks.Stop // []) + [{"matcher":"","hooks":[{"type":"command","command":"$HOME/.claude/hooks/brain-turn-save.sh","timeout":15}]}]) end)
        | (((.hooks.SessionEnd // []) | map(.hooks[]?.command) | any(test("brain-session-end"))) as $h
           | if $h then . else .hooks.SessionEnd = ((.hooks.SessionEnd // []) + [{"matcher":"","hooks":[{"type":"command","command":"$HOME/.claude/hooks/brain-session-end.sh","timeout":30}]}]) end)
    ' "$settings_file" > "$tmp" \
        && jq -e . "$tmp" &> /dev/null \
        && mv "$tmp" "$settings_file" \
        && print_success "글로벌 brain 훅 등록 완료 (모든 프로젝트에서 자동 회상/저장)" \
        || { rm -f "$tmp"; print_warning "글로벌 brain 훅 등록 실패 (기존 settings 보존)"; }
}

# Copy PRD templates
copy_prd_templates() {
    print_step "Setting up PRD templates..."

    PRD_DIR="$PROJECT_ROOT/prd"
    TEMPLATES_DIR="$SCRIPT_DIR/scripts/templates"

    # Copy templates if they exist
    if [ -d "$TEMPLATES_DIR" ]; then
        for template in "$TEMPLATES_DIR"/*.md.template; do
            if [ -f "$template" ]; then
                basename=$(basename "$template" .template)
                if [ ! -f "$PRD_DIR/$basename" ]; then
                    cp "$template" "$PRD_DIR/$basename" 2>/dev/null || true
                fi
            fi
        done
    fi

    # Create default templates if not exist
    if [ ! -f "$PRD_DIR/feature.md" ]; then
        cp "$SCRIPT_DIR/prd/feature.md" "$PRD_DIR/feature.md" 2>/dev/null || true
    fi
    if [ ! -f "$PRD_DIR/bug.md" ]; then
        cp "$SCRIPT_DIR/prd/bug.md" "$PRD_DIR/bug.md" 2>/dev/null || true
    fi
    if [ ! -f "$PRD_DIR/refactor.md" ]; then
        cp "$SCRIPT_DIR/prd/refactor.md" "$PRD_DIR/refactor.md" 2>/dev/null || true
    fi
    if [ ! -f "$PRD_DIR/experiment.md" ]; then
        cp "$SCRIPT_DIR/prd/experiment.md" "$PRD_DIR/experiment.md" 2>/dev/null || true
    fi

    print_success "PRD templates ready"
}

# Setup AI Reviewer
setup_ai_reviewer() {
    print_step "Setting up AI Reviewer..."

    # Detect Git settings
    cd "$PROJECT_ROOT"
    GIT_USER_EMAIL=$(git config user.email 2>/dev/null || echo "user@example.com")
    GIT_USER_NAME=$(git config user.name 2>/dev/null || echo "Developer")
    GIT_REMOTE_URL=$(git config remote.origin.url 2>/dev/null || echo "")

    # Detect Git platform
    GIT_PLATFORM="none"
    if [[ "$GIT_REMOTE_URL" =~ github\.com ]]; then
        GIT_PLATFORM="github"
    elif [[ "$GIT_REMOTE_URL" =~ gitlab\.com ]]; then
        GIT_PLATFORM="gitlab"
    fi

    print_success "Git user: $GIT_USER_NAME ($GIT_USER_EMAIL)"
    print_success "Git platform: $GIT_PLATFORM"

    # Create config directory
    mkdir -p "$PROJECT_ROOT/.claude/config"

    # team.yaml is regenerated idempotently on every run.
    # Only the current git user is registered (1 admin + 1 member).
    # We intentionally do NOT parse/re-append existing members, since that
    # caused unbounded duplicate accumulation across repeated installs.
    TEAM_CONFIG="$PROJECT_ROOT/.claude/config/team.yaml"
    if [ -f "$TEAM_CONFIG" ]; then
        print_warning "team.yaml already exists, regenerating (idempotent)..."
    fi

    # Ask for AI reviewer mode (skip in auto mode)
    if [ "${AUTO_MODE:-false}" = true ]; then
        REVIEW_MODE="manual"  # Default in auto mode
        print_success "Selected mode: $REVIEW_MODE (auto-selected)"
    else
        echo ""
        echo -e "${CYAN}Select AI Reviewer mode:${NC}"
        echo "  1) Manual    - Review only when /review command is used"
        echo "  2) Semi-Auto - Auto-review on PR, merge requires admin approval"
        echo "  3) Auto      - Auto-review + auto-merge if confidence >= threshold"
        echo ""
        read -p "Enter mode [1-3] (default: 1): " mode_choice
        mode_choice=${mode_choice:-1}

        case $mode_choice in
            1) REVIEW_MODE="manual" ;;
            2) REVIEW_MODE="semi-auto" ;;
            3) REVIEW_MODE="auto" ;;
            *) REVIEW_MODE="manual" ;;
        esac

        print_success "Selected mode: $REVIEW_MODE"
    fi

    # Create team.yaml
    cat > "$TEAM_CONFIG" << EOF
# Team Configuration for AI Reviewer
# This file is auto-generated by install.sh
# Last updated: $(date +%Y-%m-%d)

team:
  admins:
    - email: "$GIT_USER_EMAIL"
      name: "$GIT_USER_NAME"

  members:
    - email: "$GIT_USER_EMAIL"
      name: "$GIT_USER_NAME"
EOF

    cat >> "$TEAM_CONFIG" << EOF

ai_reviewer:
  enabled: true
  mode: "$REVIEW_MODE"

  # Analysis engine: reviewer 는 규칙 기반(rule-based) 정적 분석을 수행하며
  # 외부 LLM API 를 호출하지 않는다. (LLM 심층 리뷰는 Claude Code 내장 /review 사용)
  engine: "rule-based"

  # Auto Review Settings
  auto_review_on_pr: true
  auto_merge_threshold: 0.9

  # Review Checks
  checks:
    - security
    - performance
    - best_practices
    - test_coverage
    - documentation
    - error_handling

  # Paths to exclude from auto-merge
  no_auto_merge:
    paths:
      - "prod/*"
      - "production/*"
      - ".env*"
      - "secrets/*"
      - "config/secrets*"
    keywords:
      - "TODO"
      - "HACK"
      - "FIXME"
      - "XXX"
      - "BREAKING"

  # Review Comment Templates
  templates:
    approval: "✅ AI Review: PASSED (confidence: {confidence})"
    request_changes: "⚠️ AI Review: NEEDS CHANGES\n\n{feedback}"
    error: "❌ AI Review: ERROR\n\n{error}"

  # Notification Settings
  notifications:
    on_review_complete: true
    on_auto_merge: true
    on_failure: true

# Git Platform Detection
git_platform: "$GIT_PLATFORM"
git_remote_url: "$GIT_REMOTE_URL"
EOF

    print_success "team.yaml created"

    # Setup GitHub Actions if GitHub detected
    if [ "$GIT_PLATFORM" = "github" ]; then
        print_step "Setting up GitHub Actions..."
        mkdir -p "$PROJECT_ROOT/.github/workflows"
        if [ -f "$SCRIPT_DIR/.github/workflows/ai-reviewer.yml" ]; then
            # 파일이 다를 때만 복사
            if ! cmp -s "$SCRIPT_DIR/.github/workflows/ai-reviewer.yml" "$PROJECT_ROOT/.github/workflows/ai-reviewer.yml" 2>/dev/null; then
                cp "$SCRIPT_DIR/.github/workflows/ai-reviewer.yml" "$PROJECT_ROOT/.github/workflows/ai-reviewer.yml"
                print_success "GitHub Actions workflow created"
            else
                print_success "GitHub Actions workflow already up to date"
            fi
        fi
    fi

    # Setup GitLab CI if GitLab detected
    if [ "$GIT_PLATFORM" = "gitlab" ]; then
        print_step "Setting up GitLab CI..."
        if [ -f "$SCRIPT_DIR/.gitlab-ci.yml" ]; then
            # 파일이 다를 때만 복사
            if ! cmp -s "$SCRIPT_DIR/.gitlab-ci.yml" "$PROJECT_ROOT/.gitlab-ci.yml" 2>/dev/null; then
                cp "$SCRIPT_DIR/.gitlab-ci.yml" "$PROJECT_ROOT/.gitlab-ci.yml"
                print_success "GitLab CI configuration created"
            else
                print_success "GitLab CI configuration already up to date"
            fi
        fi
    fi

    # Install Python dependencies for AI reviewer
    print_step "Installing AI Reviewer dependencies..."
    if command -v pip3 &> /dev/null; then
        pip3 install pyyaml openai >/dev/null 2>&1 || print_warning "Failed to install dependencies (install manually: pip3 install pyyaml openai)"
    else
        print_warning "pip3 not found, skipping dependency installation"
    fi

    # Make review.sh executable
    chmod +x "$PROJECT_ROOT/.claude/commands/review.sh" 2>/dev/null || true

    print_success "AI Reviewer setup complete"
}

# Verify installation
verify_installation() {
    print_step "Verifying installation..."

    local errors=0

    # Check settings.json
    if [ -f "$PROJECT_ROOT/.claude/settings.json" ]; then
        print_success "settings.json exists"
    else
        print_error "settings.json not found"
        ((errors++))
    fi

    # Check commands
    for cmd in gate.sh pipeline.sh trace.sh; do
        if [ -f "$PROJECT_ROOT/.claude/commands/$cmd" ]; then
            if [ -x "$PROJECT_ROOT/.claude/commands/$cmd" ]; then
                print_success "$cmd is executable"
            else
                print_warning "$cmd exists but not executable"
                chmod +x "$PROJECT_ROOT/.claude/commands/$cmd"
            fi
        else
            print_error "$cmd not found"
            ((errors++))
        fi
    done

    # Check hook
    if [ -f "$PROJECT_ROOT/.claude/hooks/pre-tool-use.sh" ]; then
        print_success "pre-tool-use.sh exists"
    else
        print_error "pre-tool-use.sh not found"
        ((errors++))
    fi

    # Check PRD templates
    if [ -f "$PROJECT_ROOT/prd/feature.md" ]; then
        print_success "PRD templates exist"
    else
        print_warning "PRD templates not found (optional)"
    fi

    # Check AI Reviewer setup
    if [ -f "$PROJECT_ROOT/.claude/config/team.yaml" ]; then
        print_success "AI Reviewer configured"
    else
        print_warning "AI Reviewer not configured (optional)"
    fi

    if [ -f "$PROJECT_ROOT/.claude/commands/review.sh" ]; then
        if [ -x "$PROJECT_ROOT/.claude/commands/review.sh" ]; then
            print_success "review.sh is executable"
        else
            print_warning "review.sh exists but not executable"
            chmod +x "$PROJECT_ROOT/.claude/commands/review.sh"
        fi
    fi

    # Check harness files
    if [ -f "$PROJECT_ROOT/.claude/brain/harness-tracker.sh" ]; then
        if [ -x "$PROJECT_ROOT/.claude/brain/harness-tracker.sh" ]; then
            print_success "harness-tracker.sh is executable"
        else
            print_warning "harness-tracker.sh exists but not executable"
            chmod +x "$PROJECT_ROOT/.claude/brain/harness-tracker.sh"
        fi
    else
        print_warning "harness-tracker.sh not found (optional)"
    fi

    if [ -f "$PROJECT_ROOT/.claude/brain/skill-harness-wrapper.sh" ]; then
        if [ -x "$PROJECT_ROOT/.claude/brain/skill-harness-wrapper.sh" ]; then
            print_success "skill-harness-wrapper.sh is executable"
        else
            print_warning "skill-harness-wrapper.sh exists but not executable"
            chmod +x "$PROJECT_ROOT/.claude/brain/skill-harness-wrapper.sh"
        fi
    else
        print_warning "skill-harness-wrapper.sh not found (optional)"
    fi

    # Check global harness files
    if [ -f "$HOME/.claude/brain/harness-tracker.sh" ]; then
        print_success "Global harness-tracker.sh exists"
    else
        print_warning "Global harness-tracker.sh not found (optional)"
    fi

    # OS-specific info
    echo ""
    print_step "Platform info: OS=$OS_TYPE"

    return $errors
}

# Shell 설정 자동 추가 (zsh/bash)
setup_shell_config() {
    print_step "Setting up shell configuration..."

    # 쉘 파일 결정
    local shell_config=""
    if [ -n "${ZSH_VERSION:-}" ] || [ -f "$HOME/.zshrc" ]; then
        shell_config="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ] || [ -f "$HOME/.bashrc" ]; then
        shell_config="$HOME/.bashrc"
    else
        print_warning "Unable to detect shell config file"
        return 1
    fi

    # 이미 설정되어 있는지 확인
    local need_add=0

    if ! grep -q "# Vibe Coding Rules - PATH" "$shell_config" 2>/dev/null; then
        need_add=1
    fi

    if [ $need_add -eq 1 ]; then
        # 설정 추가
        cat >> "$shell_config" << 'SHELL_EOF'

# ═══════════════════════════════════════════════════════════════
# Vibe Coding Rules - Auto-generated by install.sh
# ═══════════════════════════════════════════════════════════════

# PATH 추가
export PATH="$HOME/.claude/commands:$PATH"

# 오타 자동 교정 래퍼
source ~/.claude/commands/wrapper.sh 2>/dev/null || true

# 자동 완성
source ~/.claude/commands/completions-v2.bash 2>/dev/null || true
SHELL_EOF

        print_success "Added to $shell_config"
    else
        print_success "Shell config already set up"
    fi

    # 현재 세션에도 적용
    export PATH="$HOME/.claude/commands:$PATH"
    source ~/.claude/commands/wrapper.sh 2>/dev/null || true
    source ~/.claude/commands/completions-v2.bash 2>/dev/null || true

    print_success "Applied to current session"
}

# Print summary
print_summary() {
    local exit_code=$1

    echo ""
    echo -e "${BOLD}═════════════════════════════════════════════════════${NC}"
    echo ""

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}${BOLD}✓ INSTALLATION COMPLETE${NC}"
        echo ""
        echo -e "${CYAN}Platform: ${OS_TYPE}${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo "  ✓ Shell config applied - just restart your terminal or run: source ~/.zshrc"
        echo "  1. Create a PRD: cp prd/feature.md prd/feature-your-feature.md"
        echo "  2. Edit the PRD with your requirements"
        echo "  3. Run: /pipeline prd/feature-your-feature.md"
        echo ""
        echo -e "${CYAN}Available commands:${NC}"
        echo "  /stats     - 통계"
        echo "  /mode      - 모드 변경"
        echo "  /gate      - PRD 검증"
        echo "  /pipeline  - 파이프라인 실행"
        echo "  /trace     - 실행 로그"
        echo ""

        # Platform-specific tips
        case "$OS_TYPE" in
            macos)
                echo -e "${CYAN}macOS tips:${NC}"
                echo "  - Use 'brew install jq' for auto-compact feature"
                echo "  - Bash: /bin/bash on macOS (GNU bash 3.2+)"
                ;;
            linux)
                echo -e "${CYAN}Linux tips:${NC}"
                echo "  - Use 'sudo apt install jq' or 'sudo yum install jq'"
                echo "  - Ensure GNU bash 4.0+ for best compatibility"
                ;;
            windows)
                echo -e "${CYAN}Windows tips:${NC}"
                echo "  - Run in Git Bash or WSL for best compatibility"
                echo "  - Use 'choco install jq' or 'winget install jqlang.jq'"
                echo "  - PowerShell not fully supported yet"
                ;;
        esac
        echo ""
    else
        echo -e "${RED}${BOLD}✗ INSTALLATION FAILED${NC}"
        echo ""
        echo "Please check the errors above and try again."
        echo ""
        echo -e "${CYAN}Platform-specific help:${NC}"
        case "$OS_TYPE" in
            macos)
                echo "  macOS: Ensure Xcode Command Line Tools are installed"
                echo "  xcode-select --install"
                ;;
            linux)
                echo "  Linux: Ensure bash 4.0+ and coreutils are installed"
                ;;
            windows)
                echo "  Windows: Use Git Bash (https://git-scm.com/download/win)"
                echo "  WSL also supported: wsl install"
                ;;
        esac
        echo ""
    fi

    echo -e "${BOLD}═════════════════════════════════════════════════════${NC}"
    echo ""
}

# Prompt for configuration
prompt_configuration() {
    print_step "Configuration"
    echo ""

    # PRD Language Selection
    echo -e "${CYAN}Select PRD template language:${NC}"
    echo "  1) 한국어 (Korean)"
    echo "  2) English"
    echo "  3) 中文 (Chinese)"
    echo ""
    read -p "Enter choice [1-3] (default: 1): " lang_choice
    lang_choice=${lang_choice:-1}

    case $lang_choice in
        1) PRD_LANGUAGE="ko" ;;
        2) PRD_LANGUAGE="en" ;;
        3) PRD_LANGUAGE="zh" ;;
        *) PRD_LANGUAGE="ko" ;;
    esac

    print_success "PRD Language: $PRD_LANGUAGE"

    # Save configuration
    mkdir -p "$PROJECT_ROOT/.claude/config"
    cat > "$PROJECT_ROOT/.claude/config/install.conf" << EOF
# Installation Configuration
# Generated: $(date +%Y-%m-%d)

PRD_LANGUAGE="$PRD_LANGUAGE"
EOF

    echo ""
}

# Main installation
main() {
    print_header

    # Parse arguments
    AUTO_MODE=false
    SYNC_MODE=false
    TARGET_DIR=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                shift
                ;;
            --sync)
                SYNC_MODE=true
                shift
                ;;
            *)
                TARGET_DIR="$1"
                shift
                ;;
        esac
    done

    # Get target directory
    if [ -n "$TARGET_DIR" ]; then
        PROJECT_ROOT="$(cd "$TARGET_DIR" && pwd)"
    else
        PROJECT_ROOT="$SCRIPT_DIR"
    fi

    echo -e "${CYAN}Target directory: ${PROJECT_ROOT}${NC}"
    echo ""

    # Step 0: Configuration
    if [ "$AUTO_MODE" = true ]; then
        print_step "Configuration (auto mode)"
        PRD_LANGUAGE="ko"  # Default to Korean in auto mode
        print_success "PRD Language: $PRD_LANGUAGE (auto-selected)"

        # Save configuration
        mkdir -p "$PROJECT_ROOT/.claude/config"
        cat > "$PROJECT_ROOT/.claude/config/install.conf" << EOF
# Installation Configuration
# Generated: $(date +%Y-%m-%d)

PRD_LANGUAGE="$PRD_LANGUAGE"
EOF
        echo ""
    else
        prompt_configuration
    fi

    # Step 1: Check Python
    if ! check_python; then
        print_summary 1
        exit 1
    fi

    # Step 2: Create directories
    create_directories

    # Step 2.5: Install global skills (brain core + 훅 파일 전역 복사 포함)
    install_global

    # Step 2.6: 글로벌 settings.json 에 brain 훅 4개 멱등 등록
    # → 한 번 설치하면 모든 프로젝트(외부 프로젝트 포함)에서 brain 자동 작동
    _ensure_global_brain_hooks

    # Step 3: Set permissions
    set_permissions

    # Step 4: Generate settings.json
    if ! generate_settings; then
        print_summary 1
        exit 1
    fi

    # Step 5: Copy PRD templates
    copy_prd_templates

    # Step 6: Setup AI Reviewer
    setup_ai_reviewer

    # Step 7: Verify
    if verify_installation; then
        # Step 8: Shell 설정 (항상 실행)
        setup_shell_config

        print_summary 0
        exit 0
    else
        print_summary 1
        exit 1
    fi
}

# Run main
main "$@"
