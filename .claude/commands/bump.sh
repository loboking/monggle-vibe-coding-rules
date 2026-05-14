#!/bin/bash
#
# bump.sh - monggle: Bump version and create git tag
#
# Usage: /bump [major|minor|patch] [options]
#
# Options:
#   --dry-run       Show what would be done without doing it
#   --no-tag        Don't create git tag
#   --pre-release   Pre-release version (e.g., beta, rc)
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
DRY_RUN=0
CREATE_TAG=1
PRE_RELEASE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        major|minor|patch)
            BUMP_TYPE="$1"
            shift
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --no-tag)
            CREATE_TAG=0
            shift
            ;;
        --pre-release)
            PRE_RELEASE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: /bump [major|minor|patch] [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run       Show what would be done"
            echo "  --no-tag        Don't create git tag"
            echo "  --pre-release   Pre-release suffix (e.g., beta, rc.1)"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

# Default to patch if not specified
BUMP_TYPE="${BUMP_TYPE:-patch}"

print_header "Version Bumper - Type: $BUMP_TYPE"

# Check if we're in a git repository
cd "$PROJECT_ROOT"
if ! is_git_repo; then
    die "Not a git repository"
fi

# Get current version from various sources
get_current_version() {
    # Try git tags first
    local latest_tag
    latest_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

    if [[ -n "$latest_tag" ]]; then
        # Remove 'v' prefix if present
        echo "${latest_tag#v}"
        return 0
    fi

    # Try package.json
    if [[ -f "package.json" ]]; then
        local version
        version=$(grep '"version"' package.json | head -1 | sed 's/.*"version": *"\([^"]*\)".*/\1/')
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    fi

    # Try pyproject.toml
    if [[ -f "pyproject.toml" ]]; then
        local version
        version=$(grep '^version' pyproject.toml | head -1 | sed 's/version = *"\([^"]*\)"/\1/' | sed "s/version = *'\([^']*\)'/\1/")
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    fi

    # Try Cargo.toml
    if [[ -f "Cargo.toml" ]]; then
        local version
        version=$(grep '^version' Cargo.toml | head -1 | sed 's/version = *"\([^"]*\)"/\1/')
        if [[ -n "$version" ]]; then
            echo "$version"
            return 0
        fi
    fi

    # Try VERSION file
    if [[ -f "VERSION" ]]; then
        cat VERSION
        return 0
    fi

    # Fallback to 0.0.0
    echo "0.0.0"
}

# Bump version
bump_version() {
    local current="$1"
    local bump_type="$2"
    local pre_release="$3"

    # Split version into parts
    local major minor patch pre

    if [[ "$current" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-[^0-9][0-9a-zA-Z.]*)?$ ]]; then
        major="${BASH_REMATCH[1]}"
        minor="${BASH_REMATCH[2]}"
        patch="${BASH_REMATCH[3]}"
        pre="${BASH_REMATCH[4]:-}"
    else
        log_error "Invalid version format: $current"
        return 1
    fi

    # Bump based on type
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
    esac

    local new_version="${major}.${minor}.${patch}"

    # Add pre-release suffix if specified
    if [[ -n "$pre_release" ]]; then
        new_version="${new_version}-${pre_release}"
    fi

    echo "$new_version"
}

# Update version in files
update_version_files() {
    local new_version="$1"

    # Validate version format (prevent sed injection)
    if ! [[ "$new_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9a-zA-Z.]+)?$ ]]; then
        log_error "Invalid version format: $new_version"
        return 1
    fi

    log_step "Updating version to: $new_version"

    # Update package.json
    if [[ -f "package.json" ]]; then
        log_info "Updating package.json..."
        if [[ $DRY_RUN -eq 0 ]]; then
            sed -i.bak "s/\"version\": *\"[^\"]*\"/\"version\": \"$new_version\"/" package.json
            rm -f package.json.bak
        else
            echo "Would update package.json: version -> $new_version"
        fi
    fi

    # Update pyproject.toml
    if [[ -f "pyproject.toml" ]]; then
        log_info "Updating pyproject.toml..."
        if [[ $DRY_RUN -eq 0 ]]; then
            sed -i.bak "s/^version = *\"[^\"]*\"/version = \"$new_version\"/" pyproject.toml
            sed -i.bak "s/^version = *'[^']*'/version = '$new_version'/" pyproject.toml
            rm -f pyproject.toml.bak
        else
            echo "Would update pyproject.toml: version -> $new_version"
        fi
    fi

    # Update Cargo.toml
    if [[ -f "Cargo.toml" ]]; then
        log_info "Updating Cargo.toml..."
        if [[ $DRY_RUN -eq 0 ]]; then
            sed -i.bak "s/^version = *\"[^\"]*\"/version = \"$new_version\"/" Cargo.toml
            rm -f Cargo.toml.bak
        else
            echo "Would update Cargo.toml: version -> $new_version"
        fi
    fi

    # Update VERSION file
    if [[ -f "VERSION" ]]; then
        log_info "Updating VERSION..."
        if [[ $DRY_RUN -eq 0 ]]; then
            echo "$new_version" > VERSION
        else
            echo "Would update VERSION: $new_version"
        fi
    fi

    # Update VERSION variable in __init__.py (Python)
    if find . -name "__init__.py" -exec grep -l "__version__" {} \; 2>/dev/null | head -1 | grep -q .; then
        log_info "Updating __init__.py..."
        if [[ $DRY_RUN -eq 0 ]]; then
            find . -name "__init__.py" -exec sed -i.bak "s/__version__ = *\"[^\"]*\"/__version__ = \"$new_version\"/" {} \; 2>/dev/null || true
            find . -name "__init__.py.bak" -delete 2>/dev/null || true
        else
            echo "Would update __version__ in __init__.py files"
        fi
    fi
}

# Create git tag
create_git_tag() {
    local version="$1"
    local tag_name="v${version}"

    log_step "Creating git tag: $tag_name"

    if [[ $DRY_RUN -eq 0 ]]; then
        if git tag "$tag_name" 2>/dev/null; then
            log_success "Tag created: $tag_name"
            echo ""
            log_info "To push the tag, run:"
            echo "  git push origin $tag_name"
        else
            log_warn "Tag already exists: $tag_name"
        fi
    else
        echo "Would create tag: $tag_name"
    fi
}

# Main execution
current_version=$(get_current_version)
log_info "Current version: $current_version"

new_version=$(bump_version "$current_version" "$BUMP_TYPE" "$PRE_RELEASE")
log_success "New version: $new_version"

echo ""
log_info "Summary:"
echo "  Current:  $current_version"
echo "  Bump:     $BUMP_TYPE"
echo "  New:      $new_version"

if [[ -n "$PRE_RELEASE" ]]; then
    echo "  Pre-release: $PRE_RELEASE"
fi

echo ""

if confirm "Proceed with version bump?" "y"; then
    update_version_files "$new_version"

    if [[ $CREATE_TAG -eq 1 ]]; then
        create_git_tag "$new_version"
    fi

    if [[ $DRY_RUN -eq 0 ]]; then
        log_success "Version bump complete!"
        echo ""
        log_info "Next steps:"
        echo "  1. Review changes with: git diff"
        echo "  2. Commit changes: git commit -am 'chore: bump version to $new_version'"
        if [[ $CREATE_TAG -eq 1 ]]; then
            echo "  3. Push tag: git push origin v${new_version}"
        fi
    else
        log_info "Dry run complete. No changes made."
    fi
else
    log_info "Version bump cancelled"
fi

exit 0
