#!/usr/bin/env bash
#
# check-proxy-connectivity.sh
# Purpose: Verify corporate proxy connectivity for Claude Code + LLM gateway setup
# Usage: ./check-proxy-connectivity.sh [--proxy URL] [--test-providers]
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script configuration
SCRIPT_NAME=$(basename "$0")
TIMEOUT=10
VERBOSE=false
TEST_PROVIDERS=false
CUSTOM_PROXY=""

# Provider endpoints to test
ANTHROPIC_API="https://api.anthropic.com"
BEDROCK_API="https://bedrock-runtime.us-east-1.amazonaws.com"
VERTEX_API="https://us-central1-aiplatform.googleapis.com"

#######################################
# Print colored message
# Arguments:
#   $1: color code
#   $2: message
#######################################
print_message() {
    echo -e "${1}${2}${NC}"
}

#######################################
# Print header
#######################################
print_header() {
    echo
    print_message "$BLUE" "=========================================="
    print_message "$BLUE" " Corporate Proxy Connectivity Checker"
    print_message "$BLUE" "=========================================="
    echo
}

#######################################
# Print usage
#######################################
usage() {
    cat << EOF
Usage: $SCRIPT_NAME [OPTIONS]

Verify corporate proxy connectivity for Claude Code setup.

OPTIONS:
    --proxy URL         Override HTTPS_PROXY environment variable
    --test-providers    Test connectivity to AI provider APIs
    --timeout SECONDS   Connection timeout (default: 10)
    --verbose           Enable verbose output
    -h, --help          Show this help message

ENVIRONMENT VARIABLES:
    HTTPS_PROXY        Proxy URL (e.g., http://proxy.company.com:8080)
    HTTP_PROXY         HTTP proxy URL (usually same as HTTPS_PROXY)
    NO_PROXY           Comma-separated list of hosts to bypass proxy

EXAMPLES:
    # Use HTTPS_PROXY environment variable
    export HTTPS_PROXY="http://proxy.company.com:8080"
    $SCRIPT_NAME

    # Specify proxy on command line
    $SCRIPT_NAME --proxy "http://user:pass@proxy.company.com:8080"

    # Test provider connectivity through proxy
    $SCRIPT_NAME --test-providers

    # Verbose mode with custom timeout
    $SCRIPT_NAME --verbose --timeout 30

EXIT CODES:
    0 - All checks passed
    1 - Proxy not configured
    2 - Proxy unreachable
    3 - Proxy authentication failed
    4 - Provider connectivity failed

EOF
}

#######################################
# Parse command line arguments
#######################################
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --proxy)
                CUSTOM_PROXY="$2"
                shift 2
                ;;
            --test-providers)
                TEST_PROVIDERS=true
                shift
                ;;
            --timeout)
                TIMEOUT="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                print_message "$RED" "Error: Unknown option $1"
                usage
                exit 1
                ;;
        esac
    done
}

#######################################
# Get proxy URL
#######################################
get_proxy_url() {
    if [[ -n "$CUSTOM_PROXY" ]]; then
        echo "$CUSTOM_PROXY"
    elif [[ -n "${HTTPS_PROXY:-}" ]]; then
        echo "$HTTPS_PROXY"
    elif [[ -n "${HTTP_PROXY:-}" ]]; then
        echo "$HTTP_PROXY"
    else
        echo ""
    fi
}

#######################################
# Extract proxy host from URL
#######################################
extract_proxy_host() {
    local proxy_url="$1"
    # Remove protocol and credentials, extract host
    echo "$proxy_url" | sed -E 's|^https?://([^:@]+:[^@]+@)?||' | sed 's|:.*||'
}

#######################################
# Extract proxy port from URL
#######################################
extract_proxy_port() {
    local proxy_url="$1"
    # Extract port, default to 8080 if not specified
    local port=$(echo "$proxy_url" | sed -E 's|^https?://([^:@]+:[^@]+@)?[^:]+:([0-9]+).*|\2|')
    if [[ "$port" == "$proxy_url" ]] || [[ -z "$port" ]]; then
        echo "8080"
    else
        echo "$port"
    fi
}

#######################################
# Check if command exists
#######################################
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

#######################################
# Test basic proxy connectivity
#######################################
test_proxy_connectivity() {
    local proxy_url="$1"
    local proxy_host=$(extract_proxy_host "$proxy_url")
    local proxy_port=$(extract_proxy_port "$proxy_url")

    print_message "$BLUE" "→ Testing proxy connectivity..."
    echo "  Proxy: $proxy_host:$proxy_port"

    # Test 1: Check if proxy host resolves
    print_message "$BLUE" "  [1/3] DNS resolution..."
    if ! host "$proxy_host" >/dev/null 2>&1 && ! nslookup "$proxy_host" >/dev/null 2>&1; then
        print_message "$RED" "  ✗ FAIL: Cannot resolve proxy hostname: $proxy_host"
        print_message "$YELLOW" "  → Check proxy URL, VPN connection, or DNS settings"
        return 1
    fi
    print_message "$GREEN" "  ✓ DNS resolution OK"

    # Test 2: Check if proxy port is reachable
    print_message "$BLUE" "  [2/3] Port connectivity..."
    if command_exists nc; then
        if ! timeout "$TIMEOUT" nc -zv "$proxy_host" "$proxy_port" 2>&1 | grep -q succeeded; then
            print_message "$RED" "  ✗ FAIL: Cannot connect to proxy: $proxy_host:$proxy_port"
            print_message "$YELLOW" "  → Check firewall rules, VPN, or verify proxy port"
            return 2
        fi
    elif command_exists telnet; then
        if ! timeout "$TIMEOUT" bash -c "echo quit | telnet $proxy_host $proxy_port 2>&1" | grep -q Connected; then
            print_message "$RED" "  ✗ FAIL: Cannot connect to proxy: $proxy_host:$proxy_port"
            print_message "$YELLOW" "  → Check firewall rules, VPN, or verify proxy port"
            return 2
        fi
    else
        print_message "$YELLOW" "  ⚠ WARN: Neither nc nor telnet available, skipping port test"
    fi
    print_message "$GREEN" "  ✓ Port connectivity OK"

    # Test 3: HTTP request through proxy
    print_message "$BLUE" "  [3/3] HTTP request through proxy..."
    if ! curl -x "$proxy_url" --max-time "$TIMEOUT" -s -o /dev/null -w "%{http_code}" http://example.com 2>&1 | grep -qE "^(200|301|302)$"; then
        local http_code=$(curl -x "$proxy_url" --max-time "$TIMEOUT" -s -o /dev/null -w "%{http_code}" http://example.com 2>&1 || echo "000")
        if [[ "$http_code" == "407" ]]; then
            print_message "$RED" "  ✗ FAIL: Proxy authentication required (407)"
            print_message "$YELLOW" "  → Add credentials to proxy URL: http://user:pass@$proxy_host:$proxy_port"
            print_message "$YELLOW" "  → Or configure .netrc file with proxy credentials"
            return 3
        elif [[ "$http_code" == "000" ]]; then
            print_message "$RED" "  ✗ FAIL: Connection timeout or network error"
            print_message "$YELLOW" "  → Check network connectivity and firewall rules"
            return 2
        else
            print_message "$RED" "  ✗ FAIL: Unexpected HTTP status code: $http_code"
            return 2
        fi
    fi
    print_message "$GREEN" "  ✓ HTTP request OK"

    print_message "$GREEN" "✓ Proxy connectivity: PASS"
    return 0
}

#######################################
# Test HTTPS through proxy
#######################################
test_https_connectivity() {
    local proxy_url="$1"

    print_message "$BLUE" "→ Testing HTTPS through proxy..."

    local http_code=$(curl -x "$proxy_url" --max-time "$TIMEOUT" -s -o /dev/null -w "%{http_code}" https://www.google.com 2>&1 || echo "000")
    
    if [[ "$http_code" == "000" ]]; then
        print_message "$RED" "  ✗ FAIL: HTTPS connection timeout"
        print_message "$YELLOW" "  → Proxy may not support CONNECT method for HTTPS"
        print_message "$YELLOW" "  → Or SSL certificate verification failed"
        return 1
    elif [[ "$http_code" == "407" ]]; then
        print_message "$RED" "  ✗ FAIL: Proxy authentication required (407)"
        return 3
    elif ! echo "$http_code" | grep -qE "^(200|301|302)$"; then
        print_message "$RED" "  ✗ FAIL: Unexpected HTTP status code: $http_code"
        return 2
    fi

    print_message "$GREEN" "✓ HTTPS connectivity: PASS"
    return 0
}

#######################################
# Test provider connectivity
#######################################
test_provider_connectivity() {
    local proxy_url="$1"

    print_message "$BLUE" "→ Testing AI provider connectivity through proxy..."

    # Test Anthropic API
    echo "  Testing Anthropic API..."
    local anthrop_code=$(curl -x "$proxy_url" --max-time "$TIMEOUT" -s -o /dev/null -w "%{http_code}" "$ANTHROPIC_API/v1/messages" 2>&1 || echo "000")
    if echo "$anthrop_code" | grep -qE "^(401|403|404|405)$"; then
        # Expected responses (need auth but connectivity OK)
        print_message "$GREEN" "  ✓ Anthropic API reachable (HTTP $anthrop_code)"
    elif [[ "$anthrop_code" == "000" ]]; then
        print_message "$RED" "  ✗ Anthropic API unreachable (timeout/connection error)"
        print_message "$YELLOW" "  → Proxy may block api.anthropic.com"
    elif [[ "$anthrop_code" == "407" ]]; then
        print_message "$RED" "  ✗ Proxy authentication required"
        return 3
    elif [[ "$anthrop_code" == "502" ]] || [[ "$anthrop_code" == "503" ]]; then
        print_message "$RED" "  ✗ Proxy error: HTTP $anthrop_code"
        print_message "$YELLOW" "  → Proxy may have connectivity issues or policy blocking"
    else
        print_message "$YELLOW" "  ⚠ Anthropic API returned HTTP $anthrop_code (unexpected)"
    fi

    # Test AWS Bedrock (if accessible)
    echo "  Testing AWS Bedrock..."
    local bedrock_code=$(curl -x "$proxy_url" --max-time "$TIMEOUT" -s -o /dev/null -w "%{http_code}" "$BEDROCK_API" 2>&1 || echo "000")
    if echo "$bedrock_code" | grep -qE "^(403|404)$"; then
        print_message "$GREEN" "  ✓ AWS Bedrock reachable (HTTP $bedrock_code)"
    elif [[ "$bedrock_code" == "000" ]]; then
        print_message "$YELLOW" "  ⚠ AWS Bedrock unreachable (may be region-specific or blocked)"
    elif [[ "$bedrock_code" == "407" ]]; then
        print_message "$RED" "  ✗ Proxy authentication required"
        return 3
    else
        print_message "$YELLOW" "  ⚠ AWS Bedrock returned HTTP $bedrock_code"
    fi

    # Test Vertex AI
    echo "  Testing Vertex AI..."
    local vertex_code=$(curl -x "$proxy_url" --max-time "$TIMEOUT" -s -o /dev/null -w "%{http_code}" "$VERTEX_API" 2>&1 || echo "000")
    if echo "$vertex_code" | grep -qE "^(401|403|404)$"; then
        print_message "$GREEN" "  ✓ Vertex AI reachable (HTTP $vertex_code)"
    elif [[ "$vertex_code" == "000" ]]; then
        print_message "$YELLOW" "  ⚠ Vertex AI unreachable (may be blocked by proxy)"
    elif [[ "$vertex_code" == "407" ]]; then
        print_message "$RED" "  ✗ Proxy authentication required"
        return 3
    else
        print_message "$YELLOW" "  ⚠ Vertex AI returned HTTP $vertex_code"
    fi

    print_message "$GREEN" "✓ Provider connectivity tests complete"
    return 0
}

#######################################
# Main execution
#######################################
main() {
    parse_args "$@"

    print_header

    # Get proxy URL
    local proxy_url=$(get_proxy_url)
    
    if [[ -z "$proxy_url" ]]; then
        print_message "$RED" "✗ ERROR: No proxy configured"
        echo
        echo "Please set HTTPS_PROXY environment variable or use --proxy option:"
        echo "  export HTTPS_PROXY=\"http://proxy.company.com:8080\""
        echo "  Or with credentials: export HTTPS_PROXY=\"http://user:pass@proxy.company.com:8080\""
        echo
        exit 1
    fi

    print_message "$BLUE" "Proxy Configuration:"
    # Mask credentials in output
    local masked_proxy=$(echo "$proxy_url" | sed -E 's|(https?://)[^:]+:[^@]+@|\1***:***@|')
    echo "  HTTPS_PROXY: $masked_proxy"
    [[ -n "${NO_PROXY:-}" ]] && echo "  NO_PROXY: $NO_PROXY"
    echo

    # Run tests
    local exit_code=0

    if ! test_proxy_connectivity "$proxy_url"; then
        exit_code=$?
    fi
    echo

    if ! test_https_connectivity "$proxy_url"; then
        [[ $exit_code -eq 0 ]] && exit_code=$?
    fi
    echo

    if [[ "$TEST_PROVIDERS" == "true" ]]; then
        if ! test_provider_connectivity "$proxy_url"; then
            [[ $exit_code -eq 0 ]] && exit_code=4
        fi
        echo
    fi

    # Summary
    print_message "$BLUE" "=========================================="
    if [[ $exit_code -eq 0 ]]; then
        print_message "$GREEN" "✓ All proxy connectivity checks passed!"
        echo
        echo "Next steps:"
        echo "1. Configure provider credentials (ANTHROPIC_API_KEY, etc.)"
        echo "2. Test with Claude Code: claude /status"
        echo "3. If using LiteLLM, start gateway with proxy config"
    else
        print_message "$RED" "✗ Proxy connectivity checks failed (exit code: $exit_code)"
        echo
        echo "Troubleshooting steps:"
        case $exit_code in
            1)
                echo "  - Verify proxy URL is correct"
                echo "  - Check VPN connection is active"
                echo "  - Verify DNS can resolve proxy hostname"
                ;;
            2)
                echo "  - Check firewall allows traffic to proxy"
                echo "  - Verify proxy port is correct"
                echo "  - Check network connectivity"
                ;;
            3)
                echo "  - Add credentials to HTTPS_PROXY URL"
                echo "  - Or configure ~/.netrc file"
                echo "  - Verify username/password are correct"
                ;;
            4)
                echo "  - Contact IT to whitelist AI provider domains"
                echo "  - Check proxy policy for blocked categories"
                ;;
        esac
        echo
        echo "For detailed troubleshooting, see:"
        echo "  templates/proxy/proxy-troubleshooting-flowchart.md"
    fi
    print_message "$BLUE" "=========================================="
    echo

    exit $exit_code
}

# Run main
main "$@"
