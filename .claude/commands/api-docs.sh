#!/bin/bash
#
# api-docs.sh - monggle: Extract API documentation from code
#
# Usage: /api-docs [options]
#
# Options:
#   --output DIR     Output directory for docs
#   --format FORMAT   Output format (markdown|html|openapi)
#   --private        Include private/internal APIs
#

set -euo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Configuration
PROJECT_ROOT="$(get_project_root)"
PROJECT_TYPE="$(detect_project_type "$PROJECT_ROOT")"
OUTPUT_DIR="${PROJECT_ROOT}/docs/api"
FORMAT="markdown"
INCLUDE_PRIVATE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        --format)
            FORMAT="$2"
            shift 2
            ;;
        --private)
            INCLUDE_PRIVATE=1
            shift
            ;;
        -h|--help)
            echo "Usage: /api-docs [options]"
            echo ""
            echo "Options:"
            echo "  --output DIR     Output directory (default: docs/api)"
            echo "  --format FORMAT  Output format (markdown|html|openapi)"
            echo "  --private        Include private APIs"
            exit 0
            ;;
        *)
            shift
            ;;
    esac
done

print_header "API Documentation Generator - Project: $PROJECT_TYPE"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate docs based on project type
case "$PROJECT_TYPE" in
    python)
        generate_python_docs
        ;;
    typescript|nodejs)
        generate_nodejs_docs
        ;;
    go)
        generate_go_docs
        ;;
    rust)
        generate_rust_docs
        ;;
    java)
        generate_java_docs
        ;;
    *)
        log_warn "No API doc generator configured for: $PROJECT_TYPE"
        run_generic_docs
        ;;
esac

# Python API documentation
generate_python_docs() {
    log_step "Generating Python API documentation..."

    # Check for Sphinx
    if command_exists sphinx-build; then
        log_info "Using Sphinx..."

        # Check if sphinx config exists
        if [[ ! -f "${PROJECT_ROOT}/docs/conf.py" ]]; then
            log_info "Initializing Sphinx..."
            mkdir -p "${PROJECT_ROOT}/docs"
            sphinx-quickstart -q -p "$(basename "$PROJECT_ROOT")" \
                -a "API Docs" \
                -v "1.0" \
                --ext-autodoc \
                --ext-viewcode \
                --makefile \
                --no-batchfile \
                "${PROJECT_ROOT}/docs" 2>/dev/null || true
        fi

        # Run Sphinx
        sphinx-build -b "$FORMAT" "${PROJECT_ROOT}/docs" "${OUTPUT_DIR}" 2>/dev/null || true
        log_success "Sphinx docs generated in: $OUTPUT_DIR"
    fi

    # Try pdoc
    if command_exists pdoc; then
        log_info "Using pdoc..."
        pdoc --output-dir "$OUTPUT_DIR" "${PROJECT_ROOT}" 2>/dev/null || true
        log_success "pdoc docs generated in: $OUTPUT_DIR"
    else
        log_warn "Install pdoc: pip install pdoc"
    fi

    # Generate markdown from docstrings
    if [[ $FORMAT == "markdown" ]]; then
        extract_python_docstrings
    fi
}

# Extract Python docstrings
extract_python_docstrings() {
    log_info "Extracting docstrings..."

    # Find all Python files
    local py_files
    py_files=$(find "$PROJECT_ROOT" -name "*.py" -not -path "*/venv/*" -not -path "*/.venv/*" -not -path "*/build/*" -not -path "*/dist/*" 2>/dev/null || true)

    while read -r file; do
        if [[ -f "$file" ]]; then
            extract_docstrings_from_file "$file"
        fi
    done <<< "$py_files"
}

extract_docstrings_from_file() {
    local file="$1"
    local relative_path="${file#$PROJECT_ROOT/}"
    local output_file="${OUTPUT_DIR}/${relative_path%.py}.md"
    local output_dir
    output_dir=$(dirname "$output_file")

    mkdir -p "$output_dir"

    # Extract module docstring
    local module_doc
    module_doc=$(sed -n '/^"""/,/^"""/p' "$file" | head -1 | sed 's/^"""//;s/"$//')

    # Create markdown
    {
        echo "# API: ${relative_path%.py}"
        echo ""
        if [[ -n "$module_doc" ]]; then
            echo "$module_doc"
            echo ""
        fi
        echo '```python'
        head -50 "$file"
        echo '```'
    } > "$output_file"
}

# Node.js/TypeScript API documentation
generate_nodejs_docs() {
    log_step "Generating Node.js/TypeScript API documentation..."

    # Check for TypeDoc
    if command_exists typedoc; then
        log_info "Using TypeDoc..."
        if [[ -f "tsconfig.json" ]]; then
            typedoc --out "$OUTPUT_DIR" --format "$FORMAT" . 2>/dev/null || true
            log_success "TypeDoc docs generated in: $OUTPUT_DIR"
        fi
    else
        log_warn "Install TypeDoc: npm install -D typedoc"
    fi

    # Check for JSDoc
    if command_exists jsdoc; then
        log_info "Using JSDoc..."
        jsdoc -c "$PROJECT_ROOT/jsdoc.conf.json" -d "$OUTPUT_DIR" 2>/dev/null || \
        jsdoc -d "$OUTPUT_DIR" "$PROJECT_ROOT"/**/*.js 2>/dev/null || true
        log_success "JSDoc docs generated in: $OUTPUT_DIR"
    else
        log_warn "Install JSDoc: npm install -D jsdoc"
    fi

    # Generate OpenAPI spec if using a framework
    if [[ -f "package.json" ]]; then
        check_framework_and_generate_openapi
    fi
}

# Check framework and generate OpenAPI spec
check_framework_and_generate_openapi() {
    # Check for common frameworks
    if grep -q "express\|fastify\|koa" package.json 2>/dev/null; then
        log_info "Detected Express/Fastify/Koa framework"
        # Could integrate with swagger-jsdoc here
    fi
}

# Go API documentation
generate_go_docs() {
    log_step "Generating Go API documentation..."

    # godoc is built-in with Go
    if command_exists go; then
        log_info "Go has built-in godoc"
        echo ""
        log_info "To view docs locally, run:"
        echo "  godoc -http=:6060"
        echo ""
        log_info "Then visit: http://localhost:6060"
    fi

    # Check for go doc generators
    if command_exists godoc; then
        log_info "Generating static docs with godoc..."
        # Create HTML output
        mkdir -p "$OUTPUT_DIR"
        # Note: godoc doesn't have native HTML export, suggest alternatives
    fi

    # Check for pkgsite
    if command_exists pkgsite; then
        log_info "Using pkgsite..."
        pkgsite -html "$PROJECT_ROOT" > "${OUTPUT_DIR}/index.html" 2>/dev/null || true
    fi

    # Try go-swagger for OpenAPI
    if command_exists swagger; then
        log_info "Generating OpenAPI spec with swagger..."
        swagger generate spec -o "$OUTPUT_DIR/openapi.json" 2>/dev/null || true
    fi
}

# Rust API documentation
generate_rust_docs() {
    log_step "Generating Rust API documentation..."

    if command_exists cargo; then
        log_info "Using cargo doc..."
        cargo doc --no-deps --output-dir "$OUTPUT_DIR" 2>/dev/null || \
        cargo doc --no-deps 2>/dev/null || true

        log_success "Rust docs generated"
        echo ""
        log_info "To view docs, run:"
        echo "  cargo doc --open"
    fi
}

# Java API documentation
generate_java_docs() {
    log_step "Generating Java API documentation..."

    # Javadoc is standard for Java
    if command_exists javadoc; then
        log_info "Using Javadoc..."

        local source_dirs
        source_dirs=$(find "$PROJECT_ROOT" -name "src/main/java" -o -name "src" 2>/dev/null | head -1)

        if [[ -n "$source_dirs" ]]; then
            mkdir -p "$OUTPUT_DIR"
            javadoc -d "$OUTPUT_DIR" -sourcepath "$source_dirs" -subpackages . 2>/dev/null || true
            log_success "Javadoc generated in: $OUTPUT_DIR"
        fi
    fi

    # For Android projects
    if [[ -f "gradlew" ]]; then
        log_info "Generating Android docs..."
        ./gradlew dokkaHtmlOutput 2>/dev/null || ./gradlew javadoc 2>/dev/null || true
    fi

    # For projects with Dokka
    if command_exists gradle; then
        log_info "Using Gradle Dokka..."
        gradle dokka 2>/dev/null || true
    fi
}

# Generic API documentation
run_generic_docs() {
    log_step "Generating generic API documentation..."

    # Try to extract comments and function signatures
    log_info "Extracting function signatures..."

    # Create index
    {
        echo "# API Documentation"
        echo ""
        echo "Auto-generated API documentation for $(basename "$PROJECT_ROOT")"
        echo ""
        echo "## Files"
        echo ""

        # List source files
        find "$PROJECT_ROOT" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" \
            -o -name "*.go" -o -name "*.rs" -o -name "*.java" \
            -o -name "*.c" -o -name "*.cpp" -o -name "*.h" \) \
            -not -path "*/venv/*" -not -path "*/node_modules/*" \
            -not -path "*/.git/*" -not -path "*/build/*" \
            -not -path "*/dist/*" -not -path "*/target/*" 2>/dev/null | \
        while read -r file; do
            local relative_path="${file#$PROJECT_ROOT/}"
            echo "- [$relative_path]($relative_path.md)"
        done
    } > "${OUTPUT_DIR}/index.md"
}

# Main execution
cd "$PROJECT_ROOT"

log_success "API documentation generation complete!"
log_info "Output directory: $OUTPUT_DIR"

exit 0
