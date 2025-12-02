#!/bin/bash
# Configuration Examples Validation Script
# Validates that all example configurations are correct and complete
# Usage: bash tests/validate-examples.sh [--verbose]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
VERBOSE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Counters
TOTAL_EXAMPLES=0
PASSED_EXAMPLES=0
FAILED_EXAMPLES=0
WARNINGS=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--verbose]"
            echo ""
            echo "Validates all configuration examples in the examples/ directory"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

log_info() {
    if [ "$VERBOSE" = true ]; then
        echo -e "${BLUE}[INFO]${NC} $1"
    fi
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_EXAMPLES++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_EXAMPLES++))
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
    ((WARNINGS++))
}

check_required_sections() {
    local file="$1"
    local sections="$2"
    
    IFS=',' read -ra SECTION_ARRAY <<< "$sections"
    for section in "${SECTION_ARRAY[@]}"; do
        if ! grep -qi "$section" "$file"; then
            return 1
        fi
    done
    return 0
}

check_code_blocks() {
    local file="$1"
    
    # Count opening and closing code blocks
    local opening=$(grep -c '```' "$file" || true)
    
    if [ $((opening % 2)) -ne 0 ]; then
        return 1
    fi
    
    return 0
}

check_broken_links() {
    local file="$1"
    local errors=0
    
    # Extract markdown links [text](path)
    while IFS= read -r link; do
        # Remove markdown syntax
        path=$(echo "$link" | sed 's/.*(\(.*\)).*/\1/')
        
        # Skip URLs
        if [[ "$path" =~ ^https?:// ]]; then
            continue
        fi
        
        # Skip anchors
        if [[ "$path" =~ ^# ]]; then
            continue
        fi
        
        # Check if file exists (relative to examples dir)
        local full_path="$PROJECT_ROOT/$path"
        if [ ! -f "$full_path" ]; then
            log_warn "$(basename "$file"): Broken link: $path"
            ((errors++))
        fi
    done < <(grep -o '\[.*\](.*\.md)' "$file" || true)
    
    return $errors
}

validate_example() {
    local file="$1"
    local filename=$(basename "$file")
    
    ((TOTAL_EXAMPLES++))
    
    log_info "Validating: $filename"
    
    # Check file is not empty
    if [ ! -s "$file" ]; then
        log_fail "$filename: Empty file"
        return 1
    fi
    
    # Check required sections based on user story
    local required_sections=""
    if [[ "$filename" =~ ^us1- ]]; then
        required_sections="Prerequisites,Step,Verify"
    elif [[ "$filename" =~ ^us2- ]]; then
        required_sections="Prerequisites,Configuration,Security"
    elif [[ "$filename" =~ ^us3- ]]; then
        required_sections="Prerequisites,Provider,Configuration"
    elif [[ "$filename" =~ ^us4- ]]; then
        required_sections="Prerequisites,Proxy,Configuration"
    fi
    
    if [ -n "$required_sections" ]; then
        if ! check_required_sections "$file" "$required_sections"; then
            log_fail "$filename: Missing required sections"
            return 1
        fi
    fi
    
    # Check code blocks are balanced
    if ! check_code_blocks "$file"; then
        log_fail "$filename: Unbalanced code blocks"
        return 1
    fi
    
    # Check for broken links (non-fatal)
    check_broken_links "$file" || true
    
    # Check for common issues
    if grep -q 'TODO\|FIXME\|XXX' "$file"; then
        log_warn "$filename: Contains TODO/FIXME markers"
    fi
    
    # Check for placeholder values
    if grep -q 'YOUR_.*\|REPLACE_.*\|<.*>' "$file"; then
        # This is actually expected for templates
        log_info "$filename: Contains placeholder values (expected)"
    fi
    
    log_pass "$filename"
    return 0
}

# Header
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       Configuration Examples Validation                   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Find all example files
EXAMPLES_DIR="$PROJECT_ROOT/examples"

if [ ! -d "$EXAMPLES_DIR" ]; then
    echo "Error: Examples directory not found: $EXAMPLES_DIR"
    exit 1
fi

log_info "Searching for examples in: $EXAMPLES_DIR"
echo ""

# Validate each example
for example_file in "$EXAMPLES_DIR"/*.md; do
    if [ -f "$example_file" ]; then
        validate_example "$example_file" || true
    fi
done

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                  Validation Summary                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total examples:  $TOTAL_EXAMPLES"
echo -e "  ${GREEN}Passed:${NC}          $PASSED_EXAMPLES"
echo -e "  ${RED}Failed:${NC}          $FAILED_EXAMPLES"
echo -e "  ${YELLOW}Warnings:${NC}        $WARNINGS"
echo ""

# Exit status
if [ $FAILED_EXAMPLES -eq 0 ]; then
    echo -e "${GREEN}✓ All examples are valid${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some examples have errors${NC}"
    echo ""
    exit 1
fi
