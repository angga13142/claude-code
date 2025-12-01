#!/bin/bash
# Integration Test Suite Runner
# Runs all available tests and generates comprehensive report
# Usage: bash tests/run-all-tests.sh [--verbose] [--fail-fast] [--category <category>]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
VERBOSE=false
FAIL_FAST=false
CATEGORY=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Test counters
TOTAL_SUITES=0
PASSED_SUITES=0
FAILED_SUITES=0
SKIPPED_SUITES=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --fail-fast|-f)
            FAIL_FAST=true
            shift
            ;;
        --category|-c)
            CATEGORY="$2"
            shift 2
            ;;
        --help|-h)
            cat << EOF
Integration Test Suite Runner

Usage: $0 [options]

Options:
  --verbose, -v            Enable verbose output
  --fail-fast, -f          Stop on first failure
  --category CAT, -c CAT   Run specific category (unit, integration, validation)
  --help, -h               Show this help message

Categories:
  unit           Unit tests (schema validation, env vars)
  integration    Integration tests (models, proxy, multi-provider)
  validation     Validation tests (examples, checklists)
  all            All tests (default)

Examples:
  $0                       # Run all tests
  $0 --verbose             # Run with detailed output
  $0 --fail-fast           # Stop on first failure
  $0 --category unit       # Run only unit tests
EOF
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
}

log_suite() {
    echo -e "${MAGENTA}[SUITE]${NC} $1"
}

check_command() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

run_test_suite() {
    local suite_name="$1"
    local test_command="$2"
    local category="$3"
    
    ((TOTAL_SUITES++))
    
    # Category filter
    if [ -n "$CATEGORY" ] && [ "$CATEGORY" != "all" ] && [ "$category" != "$CATEGORY" ]; then
        log_skip "$suite_name (category: $category)"
        ((SKIPPED_SUITES++))
        return 0
    fi
    
    log_suite "Running: $suite_name"
    
    local start_time=$(date +%s)
    local output_file="/tmp/test-output-$$.txt"
    
    if [ "$VERBOSE" = true ]; then
        if eval "$test_command" 2>&1 | tee "$output_file"; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "$suite_name (${duration}s)"
            ((PASSED_SUITES++))
            rm -f "$output_file"
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_error "$suite_name (${duration}s)"
            ((FAILED_SUITES++))
            rm -f "$output_file"
            
            if [ "$FAIL_FAST" = true ]; then
                echo ""
                log_error "Stopping due to --fail-fast"
                exit 1
            fi
            return 1
        fi
    else
        if eval "$test_command" > "$output_file" 2>&1; then
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_success "$suite_name (${duration}s)"
            ((PASSED_SUITES++))
            rm -f "$output_file"
            return 0
        else
            local end_time=$(date +%s)
            local duration=$((end_time - start_time))
            log_error "$suite_name (${duration}s)"
            echo "  Error output:"
            cat "$output_file" | head -20 | sed 's/^/    /'
            ((FAILED_SUITES++))
            rm -f "$output_file"
            
            if [ "$FAIL_FAST" = true ]; then
                echo ""
                log_error "Stopping due to --fail-fast"
                exit 1
            fi
            return 1
        fi
    fi
}

# Header
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║         Integration Test Suite Runner                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

if [ -n "$CATEGORY" ]; then
    log_info "Running category: $CATEGORY"
    echo ""
fi

# ============================================================================
# Unit Tests
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Unit Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# YAML Schema Validation
if [ -f "$SCRIPT_DIR/test-yaml-schemas.py" ]; then
    if check_command python3; then
        run_test_suite "YAML Schema Validation" "python3 $SCRIPT_DIR/test-yaml-schemas.py" "unit"
    else
        log_skip "YAML Schema Validation (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "YAML Schema Validation (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Environment Variable Validation
if [ -f "$SCRIPT_DIR/test-env-vars.py" ]; then
    if check_command python3; then
        run_test_suite "Environment Variable Tests" "python3 $SCRIPT_DIR/test-env-vars.py" "unit"
    else
        log_skip "Environment Variable Tests (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "Environment Variable Tests (test file not found)"
    ((SKIPPED_SUITES++))
fi

echo ""

# ============================================================================
# Integration Tests
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Integration Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Model Tests
if [ -f "$SCRIPT_DIR/test-all-models.py" ]; then
    if check_command python3; then
        if [ -n "$ANTHROPIC_BASE_URL" ]; then
            run_test_suite "All Models Test" "python3 $SCRIPT_DIR/test-all-models.py" "integration"
        else
            log_skip "All Models Test (ANTHROPIC_BASE_URL not set)"
            ((SKIPPED_SUITES++))
        fi
    else
        log_skip "All Models Test (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "All Models Test (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Proxy Gateway Integration
if [ -f "$SCRIPT_DIR/test-proxy-gateway.py" ]; then
    if check_command python3; then
        if [ -n "$HTTPS_PROXY" ]; then
            run_test_suite "Proxy + Gateway Integration" "python3 $SCRIPT_DIR/test-proxy-gateway.py" "integration"
        else
            log_skip "Proxy + Gateway Integration (HTTPS_PROXY not set)"
            ((SKIPPED_SUITES++))
        fi
    else
        log_skip "Proxy + Gateway Integration (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "Proxy + Gateway Integration (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Multi-Provider Routing
if [ -f "$SCRIPT_DIR/test-multi-provider-routing.py" ]; then
    if check_command python3; then
        run_test_suite "Multi-Provider Routing" "python3 $SCRIPT_DIR/test-multi-provider-routing.py" "integration"
    else
        log_skip "Multi-Provider Routing (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "Multi-Provider Routing (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Header Forwarding
if [ -f "$SCRIPT_DIR/test-header-forwarding.sh" ]; then
    run_test_suite "Header Forwarding" "bash $SCRIPT_DIR/test-header-forwarding.sh" "integration"
else
    log_skip "Header Forwarding (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Rate Limiting
if [ -f "$SCRIPT_DIR/test-rate-limiting.py" ]; then
    if check_command python3; then
        run_test_suite "Rate Limiting" "python3 $SCRIPT_DIR/test-rate-limiting.py" "integration"
    else
        log_skip "Rate Limiting (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "Rate Limiting (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Authentication Bypass
if [ -f "$SCRIPT_DIR/test-auth-bypass.sh" ]; then
    run_test_suite "Authentication Bypass" "bash $SCRIPT_DIR/test-auth-bypass.sh" "integration"
else
    log_skip "Authentication Bypass (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Provider Fallback
if [ -f "$SCRIPT_DIR/test-provider-fallback.py" ]; then
    if check_command python3; then
        run_test_suite "Provider Fallback" "python3 $SCRIPT_DIR/test-provider-fallback.py" "integration"
    else
        log_skip "Provider Fallback (python3 not found)"
        ((SKIPPED_SUITES++))
    fi
else
    log_skip "Provider Fallback (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Proxy Bypass
if [ -f "$SCRIPT_DIR/test-proxy-bypass.sh" ]; then
    run_test_suite "Proxy Bypass" "bash $SCRIPT_DIR/test-proxy-bypass.sh" "integration"
else
    log_skip "Proxy Bypass (test file not found)"
    ((SKIPPED_SUITES++))
fi

echo ""

# ============================================================================
# Validation Tests
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Validation Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Configuration Examples
if [ -f "$SCRIPT_DIR/validate-examples.sh" ]; then
    run_test_suite "Configuration Examples" "bash $SCRIPT_DIR/validate-examples.sh" "validation"
else
    log_skip "Configuration Examples (test file not found)"
    ((SKIPPED_SUITES++))
fi

# Usage Logging
if [ -f "$SCRIPT_DIR/verify-usage-logging.sh" ]; then
    run_test_suite "Usage Logging" "bash $SCRIPT_DIR/verify-usage-logging.sh" "validation"
else
    log_skip "Usage Logging (test file not found)"
    ((SKIPPED_SUITES++))
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                      Test Summary                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total suites:  $TOTAL_SUITES"
echo -e "  ${GREEN}Passed:${NC}        $PASSED_SUITES"
echo -e "  ${RED}Failed:${NC}        $FAILED_SUITES"
echo -e "  ${YELLOW}Skipped:${NC}       $SKIPPED_SUITES"
echo ""

# Calculate pass rate
if [ $TOTAL_SUITES -gt 0 ]; then
    PASS_RATE=$(( (PASSED_SUITES * 100) / TOTAL_SUITES ))
    echo "  Pass rate:     $PASS_RATE%"
    echo ""
fi

# Exit status
if [ $FAILED_SUITES -eq 0 ]; then
    if [ $PASSED_SUITES -gt 0 ]; then
        echo -e "${GREEN}✓ All test suites passed!${NC}"
    else
        echo -e "${YELLOW}⚠ No tests were run${NC}"
    fi
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some test suites failed.${NC}"
    echo ""
    echo "Run with --verbose for detailed error messages."
    echo "Run with --fail-fast to stop on first failure."
    echo ""
    exit 1
fi
