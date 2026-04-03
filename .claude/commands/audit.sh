#!/bin/bash
#
# audit.sh - Security vulnerability scanner
#
# Usage: /audit [options]
#
# Options:
#   --full        Run comprehensive scan
#   --severity    Set minimum severity level (low, medium, high, critical)
#   --json        Output in JSON format
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
FULL_SCAN=0
SEVERITY="medium"
JSON_OUTPUT=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_SCAN=1
            shift
            ;;
        --severity)
            SEVERITY="$2"
            shift 2
            ;;
        --json)
            JSON_OUTPUT=1
            shift
            ;;
        -h|--help)
            echo "Usage: /audit [options]"
            echo ""
            echo "Options:"
            echo "  --full        Run comprehensive scan"
            echo "  --severity    Set minimum severity (low, medium, high, critical)"
            echo "  --json        Output in JSON format"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "Security Audit - Project Type: $PROJECT_TYPE"

# Run security scanner based on project type
run_audit() {
    local project_type="$1"

    case "$project_type" in
        python)
            run_python_audit
            ;;
        typescript|nodejs)
            run_nodejs_audit
            ;;
        go)
            run_go_audit
            ;;
        rust)
            run_rust_audit
            ;;
        java)
            run_java_audit
            ;;
        *)
            run_generic_audit
            ;;
    esac
}

# Python security audit
run_python_audit() {
    log_step "Running Python security audit..."

    # Bandit - security linter
    if command_exists bandit; then
        log_info "Running Bandit..."
        bandit -r . -f screen || true
    else
        log_warn "Install Bandit: pip install bandit"
    fi

    # Safety - check for security vulnerabilities
    if command_exists safety; then
        log_info "Running Safety..."
        safety check || true
    else
        log_warn "Install Safety: pip install safety"
    fi

    # Semgrep - static analysis
    if command_exists semgrep; then
        log_info "Running Semgrep..."
        semgrep --config auto || true
    else
        log_warn "Install Semgrep: pip install semgrep"
    fi

    # pip-audit - check dependencies
    if command_exists pip-audit; then
        log_info "Running pip-audit..."
        pip-audit || true
    fi
}

# Node.js security audit
run_nodejs_audit() {
    log_step "Running Node.js security audit..."

    # npm audit
    if command_exists npm; then
        log_info "Running npm audit..."
        npm audit || true
    fi

    # yarn audit
    if command_exists yarn; then
        log_info "Running yarn audit..."
        yarn audit || true
    fi

    # pnpm audit
    if command_exists pnpm; then
        log_info "Running pnpm audit..."
        pnpm audit || true
    fi

    # Semgrep
    if command_exists semgrep; then
        log_info "Running Semgrep..."
        semgrep --config auto || true
    fi

    # eslint-plugin-security
    if [[ -f "node_modules/.bin/eslint" ]]; then
        log_info "Running security ESLint..."
        npm run lint:security 2>/dev/null || true
    fi
}

# Go security audit
run_go_audit() {
    log_step "Running Go security audit..."

    # go vet
    if command_exists go; then
        log_info "Running go vet..."
        go vet ./... || true
    fi

    # gosec - security scanner
    if command_exists gosec; then
        log_info "Running gosec..."
        gosec ./... || true
    else
        log_warn "Install gosec: go install github.com/securego/gosec/v2/cmd/gosec@latest"
    fi

    # govulncheck - vulnerability checker
    if command_exists govulncheck; then
        log_info "Running govulncheck..."
        govulncheck ./... || true
    fi
}

# Rust security audit
run_rust_audit() {
    log_step "Running Rust security audit..."

    # cargo audit
    if command_exists cargo-auditable; then
        log_info "Running cargo auditable..."
        cargo auditable build || true
    fi

    if [[ -f "Cargo.toml" ]]; then
        if command_exists cargo-audit; then
            log_info "Running cargo audit..."
            cargo audit || true
        else
            log_warn "Install cargo-audit: cargo install cargo-audit"
        fi
    fi

    # cargo deny
    if command_exists cargo-deny; then
        log_info "Running cargo deny..."
        cargo deny check || true
    fi
}

# Java security audit
run_java_audit() {
    log_step "Running Java security audit..."

    # OWASP Dependency-Check
    if command_exists dependency-check; then
        log_info "Running OWASP Dependency-Check..."
        dependency-check --scan . || true
    fi

    # For Android projects
    if [[ -f "gradlew" ]]; then
        log_info "Running Android security checks..."
        ./gradlew dependencyCheckAnalyze || true
    fi
}

# Generic security audit
run_generic_audit() {
    log_step "Running generic security audit..."

    # Check for common secrets
    log_info "Checking for secrets in code..."
    check_secrets

    # Semgrep
    if command_exists semgrep; then
        log_info "Running Semgrep..."
        semgrep --config auto || true
    fi

    # truffleHog - secret scanner
    if command_exists trufflehog; then
        log_info "Running trufflehog..."
        trufflehog filesystem . || true
    fi

    # gitleaks - secret scanner
    if command_exists gitleaks; then
        log_info "Running gitleaks..."
        gitleaks detect --source . || true
    fi
}

# Check for common secret patterns
check_secrets() {
    log_info "Scanning for potential secrets..."

    local secrets_found=0

    # Common patterns (be careful not to flag too many false positives)
    local patterns=(
        "password.*=.*['\"][^'\"]{8,}['\"]"
        "api[_-]?key.*=.*['\"][^'\"]{20,}['\"]"
        "secret.*=.*['\"][^'\"]{20,}['\"]"
        "token.*=.*['\"][^'\"]{30,}['\"]"
        "AKIA[0-9A-Z]{16}"  # AWS access key
        "ghp_[a-zA-Z0-9]{36}"  # GitHub personal access token
        "gho_[a-zA-Z0-9]{36}"  # GitHub OAuth token
        "ghu_[a-zA-Z0-9]{36}"  # GitHub user token
        "ghs_[a-zA-Z0-9]{36}"  # GitHub server token
        "ghr_[a-zA-Z0-9]{36}"  # GitHub refresh token
        "xox[baprs]-[0-9]{12}-[0-9]{12}-[0-9]{12}-[a-zA-Z0-9]{32}"  # Slack tokens
    )

    for pattern in "${patterns[@]}"; do
        local matches
        matches=$(grep -rE "$pattern" \
            --exclude-dir=node_modules \
            --exclude-dir=vendor \
            --exclude-dir=.git \
            --exclude-dir=venv \
            --exclude-dir=__pycache__ \
            --exclude="*.min.js" \
            --exclude="*.min.css" \
            . 2>/dev/null || true)

        if [[ -n "$matches" ]]; then
            log_warn "Potential secrets found matching: $pattern"
            echo "$matches" | head -5
            secrets_found=1
        fi
    done

    if [[ $secrets_found -eq 0 ]]; then
        log_success "No obvious secrets detected"
    else
        log_warn "Please review the above matches carefully"
    fi
}

# Main execution
cd "$PROJECT_ROOT"

if [[ $JSON_OUTPUT -eq 1 ]]; then
    echo "{\"project_type\":\"$PROJECT_TYPE\",\"severity\":\"$SEVERITY\"}"
fi

run_audit "$PROJECT_TYPE"

log_success "Security audit complete!"
log_info "Review results and address any critical findings"

exit 0
