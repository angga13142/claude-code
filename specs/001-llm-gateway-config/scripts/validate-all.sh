#!/bin/bash
# Master validation script - runs all validation checks
# Usage: bash scripts/validate-all.sh [--verbose] [--config path/to/config.yaml]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERBOSE=false
CONFIG_FILE=""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --config|-c)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --verbose, -v          Enable verbose output"
            echo "  --config FILE, -c FILE Use specific config file"
            echo "  --help, -h             Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

# Log functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED_TESTS++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED_TESTS++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    ((SKIPPED_TESTS++))
}

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    
    if [ "$VERBOSE" = true ]; then
        log_info "Running: $test_name"
    fi
    
    if eval "$test_command" > /dev/null 2>&1; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        if [ "$VERBOSE" = true ]; then
            eval "$test_command" 2>&1 | sed 's/^/    /'
        fi
        return 1
    fi
}

run_test_with_output() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    
    log_info "Running: $test_name"
    
    if eval "$test_command"; then
        log_success "$test_name"
        return 0
    else
        log_error "$test_name"
        return 1
    fi
}

check_command() {
    local cmd="$1"
    if command -v "$cmd" &> /dev/null; then
        return 0
    else
        return 1
    fi
}

# Header
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  LLM Gateway Configuration - Master Validation Script      ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# 1. Prerequisites Check
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. Prerequisites Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check required commands
if run_test "Check Python 3 installed" "check_command python3"; then
    PYTHON_VERSION=$(python3 --version 2>&1)
    log_info "Python version: $PYTHON_VERSION"
fi

run_test "Check bash installed" "check_command bash"
run_test "Check curl installed" "check_command curl"
run_test "Check jq installed" "check_command jq"

# Check Python packages
if check_command python3; then
    run_test "Check PyYAML installed" "python3 -c 'import yaml'"
    run_test "Check requests installed" "python3 -c 'import requests'"
fi

# Run prerequisite script if available
if [ -f "$SCRIPT_DIR/check-prerequisites.sh" ]; then
    run_test_with_output "Run prerequisite checker" "bash $SCRIPT_DIR/check-prerequisites.sh"
else
    log_skip "Prerequisite checker script not found"
fi

echo ""

# ============================================================================
# 2. Configuration Validation
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. Configuration Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Validate YAML templates
if [ -d "$PROJECT_ROOT/templates" ]; then
    for yaml_file in "$PROJECT_ROOT/templates"/**/*.yaml; do
        if [ -f "$yaml_file" ]; then
            filename=$(basename "$yaml_file")
            run_test "Validate YAML: $filename" "python3 -c 'import yaml; yaml.safe_load(open(\"$yaml_file\"))'"
        fi
    done
else
    log_skip "Templates directory not found"
fi

# Run config validator if available
if [ -f "$SCRIPT_DIR/validate-config.py" ] && [ -n "$CONFIG_FILE" ] && [ -f "$CONFIG_FILE" ]; then
    run_test_with_output "Validate configuration file" "python3 $SCRIPT_DIR/validate-config.py $CONFIG_FILE"
elif [ -f "$SCRIPT_DIR/validate-config.py" ]; then
    log_skip "No config file specified (use --config)"
else
    log_skip "Config validator script not found"
fi

echo ""

# ============================================================================
# 3. Environment Variables Validation
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. Environment Variables Validation"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check core environment variables
if [ -n "$ANTHROPIC_API_KEY" ]; then
    run_test "ANTHROPIC_API_KEY is set" "true"
    if [[ "$ANTHROPIC_API_KEY" =~ ^sk-ant- ]]; then
        log_success "ANTHROPIC_API_KEY format valid (starts with sk-ant-)"
    else
        log_warning "ANTHROPIC_API_KEY format unusual (expected sk-ant-)"
    fi
else
    log_skip "ANTHROPIC_API_KEY not set"
fi

if [ -n "$ANTHROPIC_BASE_URL" ]; then
    log_success "ANTHROPIC_BASE_URL is set: $ANTHROPIC_BASE_URL"
fi

# Run provider env vars validator
if [ -f "$SCRIPT_DIR/validate-provider-env-vars.py" ]; then
    run_test_with_output "Validate provider environment variables" "python3 $SCRIPT_DIR/validate-provider-env-vars.py"
else
    log_skip "Provider env vars validator not found"
fi

echo ""

# ============================================================================
# 4. Proxy Configuration Check
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. Proxy Configuration Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ -n "$HTTPS_PROXY" ] || [ -n "$https_proxy" ]; then
    PROXY_URL="${HTTPS_PROXY:-$https_proxy}"
    log_success "Proxy configured: $PROXY_URL"
    
    # Check proxy connectivity
    if [ -f "$SCRIPT_DIR/check-proxy-connectivity.sh" ]; then
        run_test_with_output "Test proxy connectivity" "bash $SCRIPT_DIR/check-proxy-connectivity.sh"
    fi
    
    # Check NO_PROXY
    if [ -n "$NO_PROXY" ]; then
        log_success "NO_PROXY configured: $NO_PROXY"
    else
        log_warning "NO_PROXY not set (may affect localhost connections)"
    fi
else
    log_skip "No proxy configured"
fi

# Check SSL certificates
if [ -n "$SSL_CERT_FILE" ]; then
    if [ -f "$SSL_CERT_FILE" ]; then
        log_success "SSL_CERT_FILE exists: $SSL_CERT_FILE"
    else
        log_error "SSL_CERT_FILE not found: $SSL_CERT_FILE"
    fi
else
    log_skip "SSL_CERT_FILE not set"
fi

echo ""

# ============================================================================
# 5. Gateway Health Check
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5. Gateway Health Check"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if gateway is running
if [ -f "$SCRIPT_DIR/health-check.sh" ]; then
    run_test_with_output "Gateway health check" "bash $SCRIPT_DIR/health-check.sh"
else
    # Try direct health check
    if [ -n "$ANTHROPIC_BASE_URL" ]; then
        GATEWAY_URL="$ANTHROPIC_BASE_URL"
    else
        GATEWAY_URL="http://localhost:4000"
    fi
    
    run_test "Gateway health endpoint" "curl -f -s -o /dev/null $GATEWAY_URL/health"
    
    if [ $? -eq 0 ]; then
        run_test "Gateway models endpoint" "curl -f -s $GATEWAY_URL/models | jq -e '.data | length > 0'"
    fi
fi

echo ""

# ============================================================================
# 6. Integration Tests
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "6. Integration Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run available integration tests
if [ -f "$PROJECT_ROOT/tests/test-all-models.py" ]; then
    log_skip "Model tests available (run separately: python3 tests/test-all-models.py)"
fi

if [ -f "$PROJECT_ROOT/tests/test-proxy-gateway.py" ]; then
    log_skip "Proxy gateway tests available (run separately: python3 tests/test-proxy-gateway.py)"
fi

if [ -f "$PROJECT_ROOT/tests/test-multi-provider-routing.py" ]; then
    log_skip "Multi-provider tests available (run separately: python3 tests/test-multi-provider-routing.py)"
fi

echo ""

# ============================================================================
# 7. Documentation Checks
# ============================================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "7. Documentation Checks"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check required documentation exists
run_test "README.md exists" "[ -f $PROJECT_ROOT/README.md ]"
run_test "quickstart.md exists" "[ -f $PROJECT_ROOT/quickstart.md ]"
run_test "docs/ directory exists" "[ -d $PROJECT_ROOT/docs ]"
run_test "examples/ directory exists" "[ -d $PROJECT_ROOT/examples ]"
run_test "templates/ directory exists" "[ -d $PROJECT_ROOT/templates ]"

# Check key documentation files
if [ -d "$PROJECT_ROOT/docs" ]; then
    run_test "configuration-reference.md exists" "[ -f $PROJECT_ROOT/docs/configuration-reference.md ]"
    run_test "troubleshooting-guide.md exists" "[ -f $PROJECT_ROOT/docs/troubleshooting-guide.md ]"
    run_test "faq.md exists" "[ -f $PROJECT_ROOT/docs/faq.md ]"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                     Validation Summary                     ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Total tests:   $TOTAL_TESTS"
echo -e "  ${GREEN}Passed:${NC}        $PASSED_TESTS"
echo -e "  ${RED}Failed:${NC}        $FAILED_TESTS"
echo -e "  ${YELLOW}Skipped:${NC}       $SKIPPED_TESTS"
echo ""

# Calculate pass rate
if [ $TOTAL_TESTS -gt 0 ]; then
    PASS_RATE=$(( (PASSED_TESTS * 100) / TOTAL_TESTS ))
    echo "  Pass rate:     $PASS_RATE%"
    echo ""
fi

# Exit status
if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}✓ All validation checks passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some validation checks failed.${NC}"
    echo ""
    echo "Run with --verbose for detailed error messages."
    echo "See docs/troubleshooting-guide.md for help."
    echo ""
    exit 1
fi
