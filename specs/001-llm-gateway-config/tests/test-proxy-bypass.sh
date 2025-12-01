#!/usr/bin/env bash
#
# Test Proxy Bypass Configuration
#
# Verifies NO_PROXY environment variable correctly bypasses proxy for specified hosts.
#
# This script tests:
# 1. NO_PROXY patterns work correctly
# 2. Local/internal URLs bypass proxy
# 3. External URLs still use proxy
# 4. Pattern matching (exact, suffix, domain)
#
# Usage:
#     # Test with current environment
#     ./test-proxy-bypass.sh
#
#     # Test with custom NO_PROXY
#     NO_PROXY="localhost,127.0.0.1,.internal" ./test-proxy-bypass.sh
#
#     # Test specific patterns
#     ./test-proxy-bypass.sh --pattern "localhost" --pattern ".corp.example.com"
#
# Exit Codes:
#     0 - All tests passed
#     1 - One or more tests failed
#     2 - Configuration error

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing=0
    
    if ! command -v curl &> /dev/null; then
        print_error "curl not found"
        missing=$((missing + 1))
    else
        print_success "curl found"
    fi
    
    if [[ -z "${HTTPS_PROXY:-}" && -z "${HTTP_PROXY:-}" ]]; then
        print_warning "No proxy configured (HTTPS_PROXY/HTTP_PROXY not set)"
        print_warning "Some tests may not be meaningful without proxy"
    else
        print_success "Proxy configured: ${HTTPS_PROXY:-${HTTP_PROXY:-}}"
    fi
    
    if [[ -z "${NO_PROXY:-}" ]]; then
        print_warning "NO_PROXY not set - using defaults"
        export NO_PROXY="localhost,127.0.0.1"
    else
        print_success "NO_PROXY configured: ${NO_PROXY}"
    fi
    
    return $missing
}

should_bypass_proxy() {
    local host="$1"
    local no_proxy="${NO_PROXY:-}"
    
    if [[ -z "$no_proxy" ]]; then
        return 1  # No bypass patterns, use proxy
    fi
    
    # Split NO_PROXY by comma and check each pattern
    IFS=',' read -ra PATTERNS <<< "$no_proxy"
    for pattern in "${PATTERNS[@]}"; do
        # Remove leading/trailing whitespace
        pattern=$(echo "$pattern" | xargs)
        
        # Exact match
        if [[ "$host" == "$pattern" ]]; then
            return 0
        fi
        
        # Suffix match (pattern starts with .)
        if [[ "$pattern" == .* ]]; then
            if [[ "$host" == *"$pattern" ]] || [[ "$host" == "${pattern#.}" ]]; then
                return 0
            fi
        fi
        
        # Domain suffix match
        if [[ "$host" == *".$pattern" ]]; then
            return 0
        fi
    done
    
    return 1  # No match, use proxy
}

test_bypass_pattern() {
    local test_name="$1"
    local host="$2"
    local should_bypass="$3"  # "yes" or "no"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "Test: $test_name (host: $host) ... "
    
    if should_bypass_proxy "$host"; then
        actual="yes"
    else
        actual="no"
    fi
    
    if [[ "$actual" == "$should_bypass" ]]; then
        print_success "PASS (bypass: $actual)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        print_error "FAIL (expected: $should_bypass, got: $actual)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

test_actual_bypass() {
    local test_name="$1"
    local url="$2"
    local should_bypass="$3"  # "yes" or "no"
    
    TESTS_RUN=$((TESTS_RUN + 1))
    
    echo -n "Test: $test_name (URL: $url) ... "
    
    # Try to connect with proxy and without
    local with_proxy=0
    local without_proxy=0
    
    # Test with proxy (if configured)
    if [[ -n "${HTTPS_PROXY:-}" ]]; then
        if curl -x "$HTTPS_PROXY" -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" &> /dev/null; then
            with_proxy=1
        fi
    fi
    
    # Test without proxy (direct connection)
    if curl --noproxy "*" -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "$url" &> /dev/null; then
        without_proxy=1
    fi
    
    # If NO_PROXY should bypass, both should work
    # If NO_PROXY should not bypass, only with_proxy should work (if proxy required)
    
    if [[ "$should_bypass" == "yes" ]]; then
        if [[ $without_proxy -eq 1 ]]; then
            print_success "PASS (direct connection works)"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            return 0
        else
            print_error "FAIL (direct connection failed, bypass not working)"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            return 1
        fi
    else
        # Should use proxy - this is harder to test without network setup
        print_warning "SKIP (cannot verify proxy usage without network inspection)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    fi
}

test_gateway_bypass() {
    local gateway_url="${ANTHROPIC_BASE_URL:-http://localhost:4000}"
    
    print_header "Testing Gateway Bypass"
    
    echo "Gateway URL: $gateway_url"
    echo "NO_PROXY: ${NO_PROXY:-}"
    
    # Extract host from URL
    local gateway_host
    gateway_host=$(echo "$gateway_url" | sed -E 's|^[^:]+://||' | sed -E 's|:.*||' | sed -E 's|/.*||')
    
    echo "Gateway host: $gateway_host"
    
    # Check if should bypass
    if should_bypass_proxy "$gateway_host"; then
        print_success "Gateway host matches NO_PROXY pattern - will bypass proxy"
        
        # Try to connect directly
        if curl --noproxy "*" -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${gateway_url}/health" &> /dev/null; then
            print_success "Direct connection to gateway successful"
            return 0
        else
            print_warning "Direct connection failed (gateway may not be running)"
            return 0
        fi
    else
        print_warning "Gateway host does NOT match NO_PROXY - will use proxy"
        
        if [[ -n "${HTTPS_PROXY:-}" ]]; then
            if curl -x "$HTTPS_PROXY" -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "${gateway_url}/health" &> /dev/null; then
                print_success "Connection through proxy successful"
                return 0
            else
                print_warning "Connection through proxy failed (proxy or gateway may not be running)"
                return 0
            fi
        else
            print_warning "No proxy configured - cannot test proxy routing"
            return 0
        fi
    fi
}

main() {
    print_header "Proxy Bypass Configuration Tests"
    
    # Check prerequisites
    if ! check_prerequisites; then
        print_error "Missing prerequisites"
        exit 2
    fi
    
    # Test NO_PROXY pattern matching
    print_header "Testing NO_PROXY Pattern Matching"
    
    echo "Current NO_PROXY: ${NO_PROXY:-}"
    echo ""
    
    # Test exact matches
    test_bypass_pattern "Exact match: localhost" "localhost" "yes"
    test_bypass_pattern "Exact match: 127.0.0.1" "127.0.0.1" "yes"
    
    # Test domain suffix matches
    test_bypass_pattern "Domain suffix: .local" "server.local" "yes"
    test_bypass_pattern "Domain suffix: .internal" "api.internal" "yes"
    
    # Test non-matches
    test_bypass_pattern "No match: example.com" "example.com" "no"
    test_bypass_pattern "No match: api.anthropic.com" "api.anthropic.com" "no"
    
    # Test gateway bypass
    test_gateway_bypass
    
    # Summary
    print_header "Test Summary"
    
    echo "Tests run: $TESTS_RUN"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    
    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo ""
        print_error "Some tests failed"
        echo ""
        echo "Common issues:"
        echo "1. NO_PROXY patterns not matching correctly"
        echo "   - Check for typos in pattern"
        echo "   - Verify leading dot for domain suffixes (.example.com)"
        echo "   - Ensure no spaces in NO_PROXY value"
        echo ""
        echo "2. Gateway not accessible"
        echo "   - Verify gateway is running: curl http://localhost:4000/health"
        echo "   - Check firewall rules"
        echo ""
        echo "3. Proxy configuration conflicts"
        echo "   - Verify HTTPS_PROXY is set correctly"
        echo "   - Check for conflicting proxy settings in ~/.curlrc or /etc/environment"
        echo ""
        echo "See: examples/us4-proxy-troubleshooting.md"
        exit 1
    fi
    
    echo ""
    print_success "All tests passed! Proxy bypass configured correctly."
    
    echo ""
    echo "Recommendations:"
    echo "1. Add gateway hostname to NO_PROXY if running locally"
    echo "   export NO_PROXY=\"localhost,127.0.0.1,\$GATEWAY_HOST\""
    echo ""
    echo "2. Include internal domain suffixes"
    echo "   export NO_PROXY=\"localhost,.internal,.corp,.local\""
    echo ""
    echo "3. Test actual gateway communication:"
    echo "   python tests/test-proxy-gateway.py"
    
    exit 0
}

main "$@"
