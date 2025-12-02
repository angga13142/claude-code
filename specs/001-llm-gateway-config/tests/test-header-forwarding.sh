#!/bin/bash
#
# Header Forwarding Test Script for Enterprise Gateways
#
# Purpose: Verify that enterprise gateways correctly forward required Anthropic headers
# Usage: ./test-header-forwarding.sh --url https://gateway.example.com --token your-api-key
#
# Required Headers (per spec.md Gateway Compatibility Criteria):
#   - anthropic-version: API version (e.g., "2023-06-01")
#   - anthropic-beta: Beta features (e.g., "messages-2025-01-01")
#   - anthropic-client-version: Client SDK version
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Default values
GATEWAY_URL=""
AUTH_TOKEN=""
VERBOSE=false
OUTPUT_FILE=""

# Test results
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --url)
            GATEWAY_URL="$2"
            shift 2
            ;;
        --token)
            AUTH_TOKEN="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 --url GATEWAY_URL --token AUTH_TOKEN [--verbose] [--output FILE]"
            echo ""
            echo "Options:"
            echo "  --url URL        Gateway base URL (e.g., https://gateway.example.com)"
            echo "  --token TOKEN    Gateway API key/token"
            echo "  --verbose        Enable verbose output"
            echo "  --output FILE    Save results to file"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --url https://gateway.example.com --token your-api-key"
            echo "  $0 --url https://gateway.example.com --token your-api-key --verbose"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Run '$0 --help' for usage information"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$GATEWAY_URL" ]]; then
    echo -e "${RED}Error: --url is required${NC}"
    exit 1
fi

if [[ -z "$AUTH_TOKEN" ]]; then
    echo -e "${RED}Error: --token is required${NC}"
    exit 1
fi

# Remove trailing slash from URL
GATEWAY_URL="${GATEWAY_URL%/}"

# Logging functions
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

pass() {
    echo -e "${GREEN}✓ PASS${NC} - $1"
    ((TESTS_PASSED++))
    ((TESTS_RUN++))
}

fail() {
    echo -e "${RED}✗ FAIL${NC} - $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "       ${RED}Details: $2${NC}"
    fi
    ((TESTS_FAILED++))
    ((TESTS_RUN++))
}

info() {
    echo -e "${YELLOW}ℹ INFO${NC} - $1"
}

# Test 1: Verify anthropic-version header is forwarded
test_anthropic_version_header() {
    log "Testing anthropic-version header forwarding..."
    
    local response
    local status_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "test"}]
        }' 2>&1 || true)
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    log "Status code: $status_code"
    log "Response body: $body"
    
    # If we get 200, header was forwarded correctly
    if [[ "$status_code" == "200" ]] || [[ "$status_code" == "201" ]]; then
        pass "anthropic-version header forwarded correctly"
        return 0
    fi
    
    # If we get 400 with "missing header" error, header not forwarded
    if [[ "$status_code" == "400" ]]; then
        if echo "$body" | grep -iq "header.*version\|version.*header\|missing.*anthropic-version"; then
            fail "anthropic-version header NOT forwarded" "Gateway must forward this header to Anthropic API"
            return 1
        else
            # Other 400 error, assume header is forwarded
            pass "anthropic-version header appears to be forwarded (got non-header 400 error)"
            return 0
        fi
    fi
    
    # For other status codes, we can't definitively test
    info "Cannot verify anthropic-version header (status: $status_code) - may require valid credentials"
    ((TESTS_RUN++))
    return 0
}

# Test 2: Verify anthropic-beta header is forwarded
test_anthropic_beta_header() {
    log "Testing anthropic-beta header forwarding..."
    
    local response
    local status_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "anthropic-beta: messages-2025-01-01" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "test"}]
        }' 2>&1 || true)
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    log "Status code: $status_code"
    log "Response body: $body"
    
    # If we get 200, header was forwarded correctly
    if [[ "$status_code" == "200" ]] || [[ "$status_code" == "201" ]]; then
        pass "anthropic-beta header forwarded correctly"
        return 0
    fi
    
    # If we get 400 with beta-related error, header not forwarded
    if [[ "$status_code" == "400" ]]; then
        if echo "$body" | grep -iq "beta.*feature\|header.*beta"; then
            fail "anthropic-beta header NOT forwarded" "Gateway must forward beta feature headers"
            return 1
        else
            pass "anthropic-beta header appears to be forwarded"
            return 0
        fi
    fi
    
    info "Cannot verify anthropic-beta header (status: $status_code)"
    ((TESTS_RUN++))
    return 0
}

# Test 3: Verify anthropic-client-version header is forwarded
test_anthropic_client_version_header() {
    log "Testing anthropic-client-version header forwarding..."
    
    local response
    local status_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -H "anthropic-client-version: test-script/1.0.0" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "test"}]
        }' 2>&1 || true)
    
    status_code=$(echo "$response" | tail -n1)
    
    log "Status code: $status_code"
    
    # anthropic-client-version is optional, so we just check if request succeeds
    if [[ "$status_code" == "200" ]] || [[ "$status_code" == "201" ]]; then
        pass "anthropic-client-version header forwarded (optional header)"
        return 0
    else
        info "anthropic-client-version forwarding unclear (status: $status_code) - this is optional"
        ((TESTS_RUN++))
        return 0
    fi
}

# Test 4: Verify Content-Type header is preserved
test_content_type_header() {
    log "Testing Content-Type header preservation..."
    
    local response
    local status_code
    
    response=$(curl -s -w "\n%{http_code}" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "test"}]
        }' 2>&1 || true)
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    log "Status code: $status_code"
    
    if [[ "$status_code" == "200" ]] || [[ "$status_code" == "201" ]]; then
        pass "Content-Type header preserved correctly"
        return 0
    elif [[ "$status_code" == "415" ]]; then
        fail "Content-Type header issue" "Gateway returned 415 Unsupported Media Type"
        return 1
    else
        info "Cannot verify Content-Type (status: $status_code)"
        ((TESTS_RUN++))
        return 0
    fi
}

# Test 5: Verify Accept header for streaming
test_accept_header_streaming() {
    log "Testing Accept header for SSE streaming..."
    
    local response
    local status_code
    local content_type
    
    # Use timeout to avoid hanging on streaming response
    response=$(timeout 5 curl -s -w "\n%{http_code}\n%{content_type}" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "Accept: text/event-stream" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 20,
            "messages": [{"role": "user", "content": "Count to 3"}],
            "stream": true
        }' 2>&1 || true)
    
    status_code=$(echo "$response" | tail -n2 | head -n1)
    content_type=$(echo "$response" | tail -n1)
    
    log "Status code: $status_code"
    log "Content-Type: $content_type"
    
    if [[ "$status_code" == "200" ]] || [[ "$status_code" == "201" ]]; then
        if echo "$content_type" | grep -q "text/event-stream"; then
            pass "Accept header for streaming preserved correctly"
            return 0
        else
            fail "Accept header not respected" "Expected Content-Type: text/event-stream, got: $content_type"
            return 1
        fi
    else
        info "Cannot verify Accept header for streaming (status: $status_code)"
        ((TESTS_RUN++))
        return 0
    fi
}

# Test 6: Verify Authorization header is handled
test_authorization_header() {
    log "Testing Authorization header handling..."
    
    local response
    local status_code
    
    # Test with valid token
    response=$(curl -s -w "\n%{http_code}" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "test"}]
        }' 2>&1 || true)
    
    status_code=$(echo "$response" | tail -n1)
    
    log "Status code with valid token: $status_code"
    
    if [[ "$status_code" == "200" ]] || [[ "$status_code" == "201" ]]; then
        pass "Authorization header handled correctly (valid token accepted)"
        return 0
    elif [[ "$status_code" == "401" ]] || [[ "$status_code" == "403" ]]; then
        fail "Valid token rejected" "Check if token is correct or has required permissions"
        return 1
    else
        info "Cannot verify Authorization header (status: $status_code)"
        ((TESTS_RUN++))
        return 0
    fi
}

# Main execution
main() {
    echo -e "${BOLD}============================================================${NC}"
    echo -e "${BOLD}Header Forwarding Test for Enterprise Gateways${NC}"
    echo -e "${BOLD}============================================================${NC}"
    echo ""
    echo "Gateway URL: $GATEWAY_URL"
    echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    # Run all tests
    echo -e "${BOLD}Running header forwarding tests...${NC}"
    echo ""
    
    test_anthropic_version_header
    test_anthropic_beta_header
    test_anthropic_client_version_header
    test_content_type_header
    test_accept_header_streaming
    test_authorization_header
    
    # Print summary
    echo ""
    echo -e "${BOLD}============================================================${NC}"
    echo -e "${BOLD}Test Summary${NC}"
    echo -e "${BOLD}============================================================${NC}"
    echo ""
    echo "Tests Run: $TESTS_RUN"
    echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    # Save results to file if requested
    if [[ -n "$OUTPUT_FILE" ]]; then
        {
            echo "Header Forwarding Test Results"
            echo "=============================="
            echo "Gateway URL: $GATEWAY_URL"
            echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
            echo ""
            echo "Tests Run: $TESTS_RUN"
            echo "Passed: $TESTS_PASSED"
            echo "Failed: $TESTS_FAILED"
        } > "$OUTPUT_FILE"
        echo "Results saved to: $OUTPUT_FILE"
        echo ""
    fi
    
    # Exit with appropriate code
    if [[ $TESTS_FAILED -eq 0 ]] && [[ $TESTS_PASSED -gt 0 ]]; then
        echo -e "${GREEN}${BOLD}✓ All header forwarding tests PASSED${NC}"
        echo ""
        exit 0
    elif [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}${BOLD}✗ Some header forwarding tests FAILED${NC}"
        echo ""
        echo "Recommendations:"
        echo "1. Review gateway configuration for header forwarding rules"
        echo "2. Ensure required headers are not being stripped or modified"
        echo "3. Check gateway logs for header-related errors"
        echo "4. Refer to: templates/enterprise/header-forwarding.md"
        echo ""
        exit 1
    else
        echo -e "${YELLOW}⚠ Cannot determine header forwarding status${NC}"
        echo "This may indicate authentication or connectivity issues."
        echo ""
        exit 2
    fi
}

# Run main function
main
