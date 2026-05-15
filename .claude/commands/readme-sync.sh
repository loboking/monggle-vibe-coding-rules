#!/bin/bash
#
# readme-sync.sh - monggle: Keep README in sync
#
# Usage: /readme-sync [options]
#
# Options:
#   --check          Check if README is out of sync (dry run)
#   --update         Update README automatically
#   --sections       List sections to sync
#   --add-section    Add a new section
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
README_FILE="${PROJECT_ROOT}/README.md"
CHECK_ONLY=0
AUTO_UPDATE=0

# List sections that can be synced (defined before use)
list_sections() {
    log_info "Sections that can be synced:"
    echo ""
    echo "  badges       - Project badges (build status, version, etc.)"
    echo "  toc          - Table of contents"
    echo "  installation - Installation instructions"
    echo "  usage        - Usage examples"
    echo "  api          - API documentation links"
    echo "  contributors - Contributors list"
    echo "  license      - License information"
    echo "  changelog    - Recent changes link"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --check)
            CHECK_ONLY=1
            shift
            ;;
        --update)
            AUTO_UPDATE=1
            shift
            ;;
        --sections)
            list_sections
            exit 0
            ;;
        -h|--help)
            echo "Usage: /readme-sync [options]"
            echo ""
            echo "Options:"
            echo "  --check       Check if README is out of sync"
            echo "  --update      Update README automatically"
            echo "  --sections    List sections that can be synced"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "README Synchronizer"

# Check if README exists
if [[ ! -f "$README_FILE" ]]; then
    log_warn "README.md not found. Creating basic template..."
    create_readme_template
    exit 0
fi

# Create basic README template
create_readme_template() {
    cat > "$README_FILE" << 'EOF'
# Project Name

Short description of the project.

## Features

- Feature 1
- Feature 2
- Feature 3

## Installation

```bash
# Installation instructions
```

## Usage

```bash
# Usage examples
```

## API Documentation

See [docs/api](docs/api) for API documentation.

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md).

## License

[License Name](LICENSE)

---

Made with ❤️ by [Your Name](https://github.com/username)
EOF
    log_success "README.md created"
}

# Detect project type and features
detect_project_features() {
    local features
    features=()

    # Check for testing framework
    if [[ -f "pytest.ini" ]] || [[ -f "tests/__init__.py" ]] || grep -q "pytest" requirements.txt 2>/dev/null; then
        features+=("pytest")
    fi

    if [[ -f "jest.config.js" ]] || grep -q "jest" package.json 2>/dev/null; then
        features+=("jest")
    fi

    # Check for CI/CD
    if [[ -d ".github/workflows" ]] || [[ -f ".travis.yml" ]] || [[ -f ".gitlab-ci.yml" ]]; then
        features+=("ci")
    fi

    # Check for documentation
    if [[ -d "docs" ]]; then
        features+=("docs")
    fi

    echo "${features[@]}"
}

# Sync badges section
sync_badges() {
    log_info "Syncing badges..."

    local project_name
    project_name=$(basename "$PROJECT_ROOT")

    local badges=""

    # Check for common CI systems
    if [[ -d ".github/workflows" ]]; then
        badges="${badges}\n[![GitHub Actions](https://img.shields.io/github/actions/workflow/status/${GITHUB_REPOSITORY:-user/repo}/.github/workflows/main.yml)]"
    fi

    # Add npm version if package.json exists
    if [[ -f "package.json" ]]; then
        local version
        version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        badges="${badges}\n[![version](https://img.shields.io/badge/version-${version}-blue)]"
    fi

    # Add license badge if LICENSE file exists
    if [[ -f "LICENSE" ]]; then
        local license
        license=$(head -1 LICENSE | sed 's/ *//')
        badges="${badges}\n[![License](https://img.shields.io/badge/license-${license}-green)]"
    fi

    if [[ -n "$badges" && $AUTO_UPDATE -eq 1 ]]; then
        # Update badges section
        if grep -q "^## " "$README_FILE"; then
            sed -i.bak "/^## /a\\
\\
$badges
" "$README_FILE"
            rm -f "${README_FILE}.bak"
        fi
    fi
}

# Sync installation section
sync_installation() {
    log_info "Syncing installation..."

    local install_cmd=""

    # Detect package manager and provide install command
    if [[ -f "package.json" ]]; then
        if [[ -f "yarn.lock" ]]; then
            install_cmd="yarn install"
        elif [[ -f "pnpm-lock.yaml" ]]; then
            install_cmd="pnpm install"
        else
            install_cmd="npm install"
        fi
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        install_cmd="pip install -e ."
    elif [[ -f "go.mod" ]]; then
        install_cmd="go install"
    elif [[ -f "Cargo.toml" ]]; then
        install_cmd="cargo install --path ."
    fi

    if [[ -n "$install_cmd" && $AUTO_UPDATE -eq 1 ]]; then
        # Update or add installation section
        if grep -q "^## Installation" "$README_FILE"; then
            # Section exists, update it
            sed -i.bak "/^## Installation/,/^## /{
                s/\`\`\`bash.*/\`\`\`bash/
                s/^.*$/\n${install_cmd}/
            }" "$README_FILE"
            rm -f "${README_FILE}.bak"
        else
            log_info "Installation section not found. Add it manually."
        fi
    fi
}

# Check for outdated information
check_outdated() {
    local outdated=0

    log_info "Checking for outdated information..."

    # Check if version numbers match
    if [[ -f "package.json" ]]; then
        local pkg_version
        local readme_version
        pkg_version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        readme_version=$(grep -oE "version-[0-9.]+" "$README_FILE" | head -1 | sed 's/version-//')

        if [[ -n "$pkg_version" && -n "$readme_version" && "$pkg_version" != "$readme_version" ]]; then
            log_warn "Version mismatch: package.json ($pkg_version) vs README ($readme_version)"
            outdated=1
        fi
    fi

    # Check for broken links
    log_info "Checking for broken links..."
    local broken_links
    broken_links=$(grep -oE '\[.*\]\([^)]+\)' "$README_FILE" | while read -r link; do
        local url
        url=$(echo "$link" | sed 's/.*](//' | sed 's/)$//')
        if [[ "$url" =~ ^http ]]; then
            if ! curl -s -o /dev/null -w "%{http_code}" "$url" | grep -qE "^(200|301|302)"; then
                echo "$url"
            fi
        fi
    done)

    if [[ -n "$broken_links" ]]; then
        log_warn "Potential broken links:"
        echo "$broken_links"
        outdated=1
    fi

    # Check for TODO/FIXME comments
    local todos
    todos=$(grep -iE "TODO|FIXME|XXX" "$README_FILE" || true)
    if [[ -n "$todos" ]]; then
        log_info "Unresolved TODOs in README:"
        echo "$todos"
    fi

    return $outdated
}

# Generate usage section from code
generate_usage_section() {
    log_info "Generating usage section..."

    # Look for CLI entry points
    if [[ -f "package.json" ]]; then
        local bin_cmd
        bin_cmd=$(grep -A2 '"bin"' package.json | tail -1 | sed 's/.*: *"//;s/".*//' | cut -d/ -f1)
        if [[ -n "$bin_cmd" ]]; then
            echo ""
            echo "## Usage"
            echo ""
            echo "\`\`\`bash"
            echo "$bin_cmd --help"
            echo "\`\`\`"
        fi
    fi

    # Look for main files
    if [[ -f "src/main.py" ]]; then
        grep -A10 "def main" src/main.py || true
    fi

    if [[ -f "src/main.rs" ]]; then
        grep -A10 "fn main" src/main.rs || true
    fi

    if [[ -f "src/main.go" ]]; then
        grep -A10 "func main" src/main.go || true
    fi
}

# Sync contributors section
sync_contributors() {
    log_info "Syncing contributors..."

    if ! command_exists git-authors || ! command_exists git; then
        return
    fi

    local contributors
    contributors=$(git log --format='%an <%ae>' | sort -u | head -20)

    if [[ -n "$contributors" && $AUTO_UPDATE -eq 1 ]]; then
        # Update contributors section
        if grep -q "^## Contributors" "$README_FILE"; then
            local temp_file
            temp_file=$(mktemp)
            awk '
                /^## Contributors/ {print; print ""; print ""; for (i = 1; i <= 20; i++) getline; next}
                {print}
            ' "$README_FILE" > "$temp_file"

            {
                echo "## Contributors"
                echo ""
                echo "Thanks to all contributors:"
                echo ""
                echo "$contributors" | while read -r contributor; do
                    echo "- $contributor"
                done
            } >> "$temp_file"

            mv "$temp_file" "$README_FILE"
        fi
    fi
}

# Main execution
cd "$PROJECT_ROOT"

log_info "Analyzing README: $README_FILE"
echo ""

# Detect features
features=$(detect_project_features)
log_info "Detected features: ${features:-none}"
echo ""

# Check for outdated information
if check_outdated; then
    log_warn "README may have outdated information"
else
    log_success "README appears up to date"
fi

echo ""

# Auto-update if requested
if [[ $AUTO_UPDATE -eq 1 ]]; then
    log_step "Auto-updating README..."
    sync_badges
    sync_installation
    sync_contributors
    log_success "README updated"
elif [[ $CHECK_ONLY -eq 1 ]]; then
    log_info "Check complete. Use --update to apply changes."
else
    log_info "Suggested actions:"
    echo "  - Run with --update to automatically sync"
    echo "  - Run with --sections to see what can be synced"
fi

exit 0
