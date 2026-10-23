#!/bin/bash
# monggle:  Unified Documents Command for Claude Code
# Usage: /docs <index|search|status> [args]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_PYTHON="$HOME/.claude/docs-search/venv/bin/python"
SEARCH_ENGINE="$HOME/.claude/docs-search/lib/search_engine.py"
CONFIG_DIR="$HOME/.claude/docs-search"

# Source input validation helpers (path traversal prevention)
VALIDATION_LIB="$SCRIPT_DIR/../lib/validation.sh"
if [ -f "$VALIDATION_LIB" ]; then
    # shellcheck source=../lib/validation.sh
    . "$VALIDATION_LIB"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ----------------------------------------------------------------------------
# Top-level help
# ----------------------------------------------------------------------------
usage() {
    echo -e "${CYAN}📚 Documents${NC}"
    echo ""
    echo "Index and search documents for relevant content."
    echo ""
    echo "Usage:"
    echo "  /docs <command> [options]"
    echo ""
    echo "Commands:"
    echo "  index [path] [options]   Index documents for search"
    echo "  search <query> [options] Search indexed documents"
    echo "  status                   Show system status"
    echo ""
    echo "Run '/docs <command> -h' for command-specific help."
    echo ""
    echo "Examples:"
    echo "  /docs index"
    echo "  /docs index ~/company-docs"
    echo "  /docs search API authentication"
    echo "  /docs status"
}

# ----------------------------------------------------------------------------
# index
# ----------------------------------------------------------------------------
cmd_index() {
    # Show help
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo -e "${CYAN}📚 Document Indexer${NC}"
        echo ""
        echo "Index documents for search."
        echo ""
        echo "Usage:"
        echo "  /docs index [path] [options]"
        echo ""
        echo "Options:"
        echo "  --scope <scope>    Index scope: global, project (default: auto)"
        echo "  --formats <fmts>   File formats: md,pdf,docx (default: all)"
        echo "  --force            Force re-indexing even if unchanged"
        echo ""
        echo "If no path provided, indexes all configured sources."
        echo ""
        echo "Examples:"
        echo "  /docs index                    # Index all sources"
        echo "  /docs index ~/company-docs     # Index specific directory"
        echo "  /docs index .claude/docs       # Index project docs"
        echo "  /docs index --scope global     # Index global sources only"
        echo ""
        echo "Related commands:"
        echo "  /docs search        Search documents"
        echo "  /docs status        Show system status"
        return 0
    fi

    # Parse arguments
    local SCOPE="auto"
    local FORMATS=""
    local FORCE=""
    local PATH_ARG=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --scope)
                SCOPE="$2"
                shift 2
                ;;
            --formats)
                FORMATS="$2"
                shift 2
                ;;
            --force)
                FORCE="--force"
                shift
                ;;
            -*)
                echo "Warning: Unknown option $1"
                shift
                ;;
            *)
                PATH_ARG="$1"
                shift
                ;;
        esac
    done

    # Check if search engine exists
    if [ ! -f "$SEARCH_ENGINE" ]; then
        echo -e "${YELLOW}⚠️  Search engine not found${NC}"
        echo "Installing dependencies..."
        mkdir -p ~/.claude/docs-search
        cd ~/.claude/docs-search

        # Create venv and install Python dependencies
        if command -v python3 &> /dev/null; then
            python3 -m venv "$HOME/.claude/docs-search/venv" 2>/dev/null || true
            "$HOME/.claude/docs-search/venv/bin/pip" install -q sentence-transformers faiss-cpu PyPDF2 python-docx watchdog pyyaml tqdm
            echo "✅ Dependencies installed"
        else
            echo "Error: python3 not found. Please install Python 3 first."
            return 1
        fi
    fi

    # Verify search engine is actually present (deps install does not create it)
    if [ ! -f "$SEARCH_ENGINE" ]; then
        echo -e "${YELLOW}⚠️  Search engine not installed: $SEARCH_ENGINE${NC}"
        echo "Dependencies were installed, but search_engine.py is missing."
        echo "Run /docs status to verify the docs-search installation."
        return 1
    fi

    # Index
    if [ -z "$PATH_ARG" ]; then
        # Index all sources
        echo -e "${BLUE}📚 Indexing all configured sources...${NC}"
        "$VENV_PYTHON" "$SEARCH_ENGINE" sync
    else
        # Index specific path
        echo -e "${BLUE}📄 Indexing:${NC} $PATH_ARG"

        local EXPANDED_PATH="${PATH_ARG/#\~/$HOME}"

        # Path traversal prevention (if validation lib is available)
        if command -v validate_file_path &>/dev/null; then
            if ! validate_file_path "$EXPANDED_PATH"; then
                echo "Error: Invalid path rejected: $PATH_ARG"
                return 1
            fi
        fi

        if [ -d "$EXPANDED_PATH" ]; then
            # Directory
            "$VENV_PYTHON" "$SEARCH_ENGINE" index "$EXPANDED_PATH" --scope "$SCOPE"
        elif [ -f "$EXPANDED_PATH" ]; then
            # Single file - use processor directly via temp script.
            # Path is passed through the environment (DOC_PATH) and read with
            # os.environ inside Python, so it is never interpolated into the
            # source code. This prevents Python/shell code injection via the path.
            local TEMP_SCRIPT
            TEMP_SCRIPT=$(mktemp)
            cat > "$TEMP_SCRIPT" << 'EOF'
import os
import sys

lib_dir = os.path.join(os.environ['HOME'], '.claude', 'docs-search', 'lib')
sys.path.insert(0, lib_dir)
from processor import DocumentProcessor

doc_path = os.environ['DOC_PATH']

processor = DocumentProcessor()
doc = processor.process(doc_path, force=True)

if doc:
    print(f'✅ Processed: {doc.title}')
    print(f'   Format: {doc.format}')
    print(f'   Length: {len(doc.content)} chars')
    print(f'   Use /docs search to search this document')
else:
    print(f'❌ Failed to process: {doc_path}')
EOF
            DOC_PATH="$EXPANDED_PATH" "$VENV_PYTHON" "$TEMP_SCRIPT"
            rm -f "$TEMP_SCRIPT"
        else
            echo "Error: Path not found: $PATH_ARG"
            return 1
        fi
    fi

    echo -e "${GREEN}✅ Indexing complete${NC}"
}

# ----------------------------------------------------------------------------
# search
# ----------------------------------------------------------------------------
cmd_search() {
    # Show help
    if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo -e "${CYAN}📚 Document Search${NC}"
        echo ""
        echo "Search indexed documents for relevant content."
        echo ""
        echo "Usage:"
        echo "  /docs search <query> [options]"
        echo ""
        echo "Options:"
        echo "  --scope <scope>    Search scope: global, project, all (default: auto)"
        echo "  --limit <n>        Maximum results (default: 5)"
        echo ""
        echo "Examples:"
        echo "  /docs search API authentication"
        echo "  /docs search --scope global company policy"
        echo "  /docs search deployment --limit 10"
        echo ""
        echo "Related commands:"
        echo "  /docs index         Index documents"
        echo "  /docs status        Show system status"
        return 0
    fi

    # Parse arguments
    local SCOPE="auto"
    local LIMIT=5
    local QUERY=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            --scope)
                if [ $# -lt 2 ]; then
                    echo "Error: --scope requires a value"
                    return 1
                fi
                SCOPE="$2"
                shift 2
                ;;
            --limit)
                if [ $# -lt 2 ]; then
                    echo "Error: --limit requires a value"
                    return 1
                fi
                LIMIT="$2"
                shift 2
                ;;
            --)
                shift
                while [[ $# -gt 0 ]]; do
                    QUERY="$QUERY $1"
                    shift
                done
                ;;
            --*)
                echo "Error: Unknown option: $1"
                echo "Usage: /docs search <query> [options]"
                return 1
                ;;
            *)
                QUERY="$QUERY $1"
                shift
                ;;
        esac
    done

    # Trim query
    QUERY=$(echo "$QUERY" | xargs)

    if [ -z "$QUERY" ]; then
        echo "Error: No query provided"
        echo "Usage: /docs search <query> [options]"
        return 1
    fi

    # Check if search engine exists
    if [ ! -f "$SEARCH_ENGINE" ]; then
        echo "Error: Search engine not found at $SEARCH_ENGINE"
        echo "Please run setup first:"
        echo "  cd ~/.claude/docs-search && python3 -m pip install -r requirements.txt"
        return 1
    fi

    # Run search
    echo -e "${BLUE}🔍 Searching for:${NC} $QUERY"
    echo ""

    "$VENV_PYTHON" "$SEARCH_ENGINE" search "$QUERY" --scope "$SCOPE" --limit "$LIMIT"
}

# ----------------------------------------------------------------------------
# status
# ----------------------------------------------------------------------------
cmd_status() {
    if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
        echo -e "${CYAN}📚 Document Search System Status${NC}"
        echo ""
        echo "Usage:"
        echo "  /docs status"
        echo ""
        echo "Shows installed dependencies, indexes, and document sources."
        return 0
    fi

    echo -e "${CYAN}📚 Document Search System Status${NC}"
    echo ""

    # Check if installed
    if [ ! -d "$CONFIG_DIR" ]; then
        echo -e "${RED}❌ Not installed${NC}"
        echo ""
        echo "To install, run:"
        echo "  mkdir -p ~/.claude/docs-search"
        echo "  cd ~/.claude/docs-search"
        echo "  pip3 install -r requirements.txt"
        return 1
    fi

    # Check dependencies
    echo -e "${BLUE}Dependencies:${NC}"

    if "$VENV_PYTHON" -c "import sentence_transformers" 2>/dev/null; then
        local VERSION
        VERSION=$("$VENV_PYTHON" -c "import sentence_transformers; print(sentence_transformers.__version__)" 2>/dev/null)
        echo -e "  ${GREEN}✓${NC} sentence-transformers $VERSION"
    else
        echo -e "  ${RED}✗${NC} sentence-transformers (not installed)"
    fi

    if "$VENV_PYTHON" -c "import faiss" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} faiss (installed)"
    else
        echo -e "  ${RED}✗${NC} faiss (not installed)"
    fi

    if "$VENV_PYTHON" -c "import PyPDF2" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} PyPDF2 (installed)"
    else
        echo -e "  ${YELLOW}○${NC} PyPDF2 (optional, for PDF support)"
    fi

    if "$VENV_PYTHON" -c "import docx" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} python-docx (installed)"
    else
        echo -e "  ${YELLOW}○${NC} python-docx (optional, for DOCX support)"
    fi

    echo ""

    # Check indexes
    echo -e "${BLUE}Indexes:${NC}"
    local INDEXES_DIR="$CONFIG_DIR/indexes"

    if [ -d "$INDEXES_DIR" ]; then
        for index_dir in "$INDEXES_DIR"/*/; do
            if [ -d "$index_dir" ]; then
                local name
                name=$(basename "$index_dir")
                if [ -f "$index_dir/index.faiss" ]; then
                    local chunks size
                    chunks=$(LIB_DIR="$CONFIG_DIR/lib" INDEX_DIR="$index_dir" "$VENV_PYTHON" -c '
import os
import sys
sys.path.insert(0, os.environ["LIB_DIR"])
from vector_store import LocalVectorStore
store = LocalVectorStore(os.environ["INDEX_DIR"])
print(store.get_stats()["total_chunks"])
' 2>/dev/null || echo "?")
                    size=$(du -sh "$index_dir" 2>/dev/null | cut -f1)
                    echo -e "  ${GREEN}✓${NC} $name: $chunks chunks, $size"
                else
                    echo -e "  ${YELLOW}○${NC} $name: empty"
                fi
            fi
        done
    else
        echo -e "  ${YELLOW}○${NC} No indexes found"
    fi

    echo ""

    # Check document sources
    echo -e "${BLUE}Document Sources:${NC}"
    local SOURCES_FILE="$CONFIG_DIR/config/sources.yaml"

    if [ -f "$SOURCES_FILE" ]; then
        echo "  Global sources:"
        if grep -q "global_sources:" "$SOURCES_FILE"; then
            awk '/global_sources:/,/^$/ {if (!/global_sources:/ && !/^$/) print "    " $0}' "$SOURCES_FILE" | head -5
        else
            echo "    (none configured)"
        fi

        echo ""
        echo "  Project sources (.claude/docs, docs/):"
        if [ -d ".claude/docs" ]; then
            local files
            files=$(find .claude/docs -name "*.md" 2>/dev/null | wc -l)
            echo -e "    ${GREEN}✓${NC} .claude/docs/ ($files markdown files)"
        else
            echo -e "    ${YELLOW}○${NC} .claude/docs/ (not found)"
        fi

        if [ -d "docs" ]; then
            local files
            files=$(find docs -name "*.md" 2>/dev/null | wc -l)
            echo -e "    ${GREEN}✓${NC} docs/ ($files markdown files)"
        else
            echo -e "    ${YELLOW}○${NC} docs/ (not found)"
        fi

        if [ -d "$HOME/company-docs" ]; then
            local files
            files=$(find "$HOME/company-docs" -type f 2>/dev/null | wc -l)
            echo -e "    ${GREEN}✓${NC} ~/company-docs/ ($files files)"
        else
            echo -e "    ${YELLOW}○${NC} ~/company-docs/ (not found - create for global docs)"
        fi
    else
        echo "  (sources config not found)"
    fi

    echo ""

    # Show next steps
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  1. Add documents: cp mydoc.md ~/company-docs/ or .claude/docs/"
    echo "  2. Index: /docs index"
    echo "  3. Search: /docs search my query"
    echo ""
}

# ----------------------------------------------------------------------------
# Dispatch
# ----------------------------------------------------------------------------
if [ $# -eq 0 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    usage
    exit 0
fi

SUBCMD="$1"
shift

case "$SUBCMD" in
    index)
        cmd_index "$@"
        ;;
    search)
        cmd_search "$@"
        ;;
    status)
        cmd_status "$@"
        ;;
    *)
        echo "Error: Unknown command: $SUBCMD"
        echo ""
        usage
        exit 1
        ;;
esac
