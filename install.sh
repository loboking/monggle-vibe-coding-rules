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

    print_success "Directories created"
}

# Set executable permissions
set_permissions() {
    print_step "Setting executable permissions..."

    chmod +x "$SCRIPT_DIR/.claude/commands/gate.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/commands/pipeline.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/commands/trace.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/.claude/hooks/pre-tool-use.sh" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/scripts/generate_settings.py" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/scripts/init_core.py" 2>/dev/null || true
    chmod +x "$SCRIPT_DIR/install.sh" 2>/dev/null || true

    print_success "Permissions set"
}

# Generate settings.json
generate_settings() {
    print_step "Generating settings.json..."

    cd "$PROJECT_ROOT"

    # Run Python script
    if $PYTHON_CMD "$SCRIPT_DIR/scripts/generate_settings.py"; then
        print_success "settings.json generated"
    else
        print_error "Failed to generate settings.json"
        return 1
    fi
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

    # Check if team.yaml already exists
    TEAM_CONFIG="$PROJECT_ROOT/.claude/config/team.yaml"
    if [ -f "$TEAM_CONFIG" ]; then
        print_warning "team.yaml already exists, updating..."
        # Extract existing members to preserve them
        EXISTING_MEMBERS=$(sed -n '/members:/,/^[^ ]/p' "$TEAM_CONFIG" | tail -n +2)
    fi

    # Ask for AI reviewer mode
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

    # Append existing members if any
    if [ -n "${EXISTING_MEMBERS:-}" ]; then
        echo "$EXISTING_MEMBERS" >> "$TEAM_CONFIG"
    fi

    cat >> "$TEAM_CONFIG" << EOF

ai_reviewer:
  enabled: true
  mode: "$REVIEW_MODE"

  # AI Model Configuration
  model: "gpt-4"
  api_key_env: "OPENAI_API_KEY"
  max_tokens: 2000
  temperature: 0.3

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
            cp "$SCRIPT_DIR/.github/workflows/ai-reviewer.yml" "$PROJECT_ROOT/.github/workflows/ai-reviewer.yml"
            print_success "GitHub Actions workflow created"
        fi
    fi

    # Setup GitLab CI if GitLab detected
    if [ "$GIT_PLATFORM" = "gitlab" ]; then
        print_step "Setting up GitLab CI..."
        if [ -f "$SCRIPT_DIR/.gitlab-ci.yml" ]; then
            cp "$SCRIPT_DIR/.gitlab-ci.yml" "$PROJECT_ROOT/.gitlab-ci.yml"
            print_success "GitLab CI configuration created"
        fi
    fi

    # Install Python dependencies for AI reviewer
    print_step "Installing AI Reviewer dependencies..."
    if command -v pip3 &> /dev/null; then
        pip3 install pyyaml openai 2>/dev/null || print_warning "Failed to install dependencies (install manually: pip3 install pyyaml openai)"
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

    return $errors
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
        echo -e "${CYAN}Next steps:${NC}"
        echo "  1. Create a PRD: cp prd/feature.md prd/feature-your-feature.md"
        echo "  2. Edit the PRD with your requirements"
        echo "  3. Run: /pipeline prd/feature-your-feature.md"
        echo ""
        echo -e "${CYAN}Available commands:${NC}"
        echo "  /gate      - Validate PRD"
        echo "  /pipeline  - Run full agent pipeline"
        echo "  /trace     - View execution logs"
        echo ""
    else
        echo -e "${RED}${BOLD}✗ INSTALLATION FAILED${NC}"
        echo ""
        echo "Please check the errors above and try again."
        echo ""
    fi

    echo -e "${BOLD}═════════════════════════════════════════════════════${NC}"
    echo ""
}

# Main installation
main() {
    print_header

    # Get target directory
    if [ $# -gt 0 ]; then
        PROJECT_ROOT="$(cd "$1" && pwd)"
    else
        PROJECT_ROOT="$SCRIPT_DIR"
    fi

    echo -e "${CYAN}Target directory: ${PROJECT_ROOT}${NC}"
    echo ""

    # Step 1: Check Python
    if ! check_python; then
        print_summary 1
        exit 1
    fi

    # Step 2: Create directories
    create_directories

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
        print_summary 0
        exit 0
    else
        print_summary 1
        exit 1
    fi
}

# Run main
main "$@"
