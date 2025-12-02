#!/bin/bash
#
# Authentication Troubleshooting Helper for Enterprise Gateways
#
# Purpose: Debug authentication issues between Claude Code and enterprise gateways
# Usage: ./debug-auth.sh --url https://gateway.example.com --token your-api-key
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

# Default values
GATEWAY_URL=""
AUTH_TOKEN=""
VERBOSE=false

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
        -h|--help)
            cat << EOF
Usage: $0 --url GATEWAY_URL --token AUTH_TOKEN [--verbose]

Debug authentication issues with enterprise gateways

Options:
  --url URL        Gateway base URL
  --token TOKEN    Gateway API key/token
  --verbose        Show detailed debugging info
  -h, --help       Show this help

Examples:
  $0 --url https://gateway.example.com --token your-api-key
  $0 --url https://gateway.example.com --token your-api-key --verbose

This script performs:
  1. Token format validation
  2. Connectivity tests
  3. Authentication verification
  4. Authorization checks
  5. Token expiration detection
  6. Gateway-specific diagnostics
EOF
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$GATEWAY_URL" ]] || [[ -z "$AUTH_TOKEN" ]]; then
    echo -e "${RED}Error: --url and --token are required${NC}"
    exit 1
fi

GATEWAY_URL="${GATEWAY_URL%/}"

# Logging functions
log() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
}

header() {
    echo ""
    echo -e "${BOLD}$1${NC}"
    echo "----------------------------------------"
}

# Step 1: Token format validation
validate_token_format() {
    header "Step 1: Validating Token Format"
    
    local token_length=${#AUTH_TOKEN}
    log "Token length: $token_length characters"
    
    # Check token length
    if [[ $token_length -lt 10 ]]; then
        error "Token appears too short (< 10 characters)"
        warning "Valid tokens are typically 32+ characters"
        return 1
    fi
    
    success "Token length acceptable ($token_length characters)"
    
    # Check for common token prefixes
    if [[ "$AUTH_TOKEN" =~ ^sk-ant- ]]; then
        warning "Token starts with 'sk-ant-' (Anthropic API key)"
        warning "This should be your GATEWAY token, not Anthropic's API key"
        return 1
    elif [[ "$AUTH_TOKEN" =~ ^zpka_ ]]; then
        info "Detected Zuplo API key format (zpka_)"
    elif [[ "$AUTH_TOKEN" =~ ^tfk_ ]]; then
        info "Detected TrueFoundry API key format (tfk_)"
    elif [[ "$AUTH_TOKEN" =~ ^Bearer\ ]]; then
        warning "Token contains 'Bearer' prefix"
        warning "Remove 'Bearer ' - it will be added automatically"
        return 1
    fi
    
    # Check for whitespace
    if [[ "$AUTH_TOKEN" =~ [[:space:]] ]]; then
        error "Token contains whitespace"
        warning "Remove any spaces, tabs, or newlines from token"
        return 1
    fi
    
    success "Token format appears valid"
    return 0
}

# Step 2: Network connectivity
test_connectivity() {
    header "Step 2: Testing Network Connectivity"
    
    log "Testing connection to $GATEWAY_URL"
    
    # Extract hostname
    local hostname
    hostname=$(echo "$GATEWAY_URL" | sed -e 's|^[^/]*//||' -e 's|/.*$||' -e 's|:.*$||')
    
    log "Hostname: $hostname"
    
    # Test DNS resolution
    if ! host "$hostname" > /dev/null 2>&1; then
        error "DNS resolution failed for $hostname"
        warning "Check if domain name is correct"
        return 1
    fi
    
    success "DNS resolution successful"
    
    # Test TCP connectivity
    local port=443
    if [[ "$GATEWAY_URL" =~ http://  ]]; then
        port=80
    fi
    
    log "Testing TCP connection on port $port"
    
    if timeout 5 bash -c "cat < /dev/null > /dev/tcp/$hostname/$port" 2>/dev/null; then
        success "TCP connection successful"
    else
        error "Cannot connect to $hostname:$port"
        warning "Check firewall rules and network connectivity"
        return 1
    fi
    
    # Test HTTP/HTTPS
    local status_code
    status_code=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "$GATEWAY_URL" 2>/dev/null || echo "000")
    
    log "HTTP status code: $status_code"
    
    if [[ "$status_code" == "000" ]]; then
        error "Cannot reach gateway (connection timeout)"
        return 1
    fi
    
    success "Gateway is reachable (HTTP $status_code)"
    return 0
}

# Step 3: Authentication test
test_authentication() {
    header "Step 3: Testing Authentication"
    
    log "Sending authenticated request to /v1/messages"
    
    local response
    local status_code
    local headers
    
    response=$(curl -s -w "\n%{http_code}\n" -X POST "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" \
        -H "Content-Type: application/json" \
        -H "anthropic-version: 2023-06-01" \
        -d '{
            "model": "claude-3-5-sonnet-20241022",
            "max_tokens": 10,
            "messages": [{"role": "user", "content": "test"}]
        }' 2>&1)
    
    status_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | head -n-1)
    
    log "Status code: $status_code"
    log "Response: ${body:0:200}"
    
    case "$status_code" in
        200|201)
            success "Authentication successful (HTTP $status_code)"
            info "Token is valid and authorized"
            return 0
            ;;
        401)
            error "Authentication failed (401 Unauthorized)"
            echo "$body" | grep -i "error\|message" || true
            
            info "Possible causes:"
            echo "  1. Invalid or expired token"
            echo "  2. Token revoked by administrator"
            echo "  3. Token not properly configured in gateway"
            echo "  4. Incorrect token format for this gateway"
            return 1
            ;;
        403)
            error "Authorization failed (403 Forbidden)"
            echo "$body" | grep -i "error\|message" || true
            
            info "Possible causes:"
            echo "  1. Token lacks required permissions/scopes"
            echo "  2. IP address not in allowlist"
            echo "  3. Rate limit exceeded"
            echo "  4. Gateway policy blocking access"
            return 1
            ;;
        404)
            error "Endpoint not found (404)"
            warning "Gateway may not support /v1/messages endpoint"
            warning "Check gateway configuration and routing"
            return 1
            ;;
        429)
            warning "Rate limit exceeded (429 Too Many Requests)"
            echo "$body" | grep -i "retry\|limit" || true
            info "Wait before retrying or increase rate limits"
            return 1
            ;;
        500|502|503|504)
            error "Gateway error (HTTP $status_code)"
            warning "Gateway or upstream service issue"
            info "Check gateway logs and service status"
            return 1
            ;;
        *)
            error "Unexpected status code: $status_code"
            echo "Response: $body"
            return 1
            ;;
    esac
}

# Step 4: Token expiration check
check_token_expiration() {
    header "Step 4: Checking Token Expiration"
    
    # If token is JWT, decode and check exp claim
    if [[ "$AUTH_TOKEN" =~ ^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$ ]]; then
        info "Token appears to be JWT format"
        
        # Decode JWT payload (base64url)
        local payload
        payload=$(echo "$AUTH_TOKEN" | cut -d'.' -f2)
        
        # Add padding if needed
        local pad=$((4 - ${#payload} % 4))
        [[ $pad -lt 4 ]] && payload="${payload}$(printf '=%.0s' $(seq 1 $pad))"
        
        # Decode (convert base64url to base64)
        payload=$(echo "$payload" | tr '_-' '/+' | base64 -d 2>/dev/null || echo "{}")
        
        log "JWT payload: $payload"
        
        # Extract exp claim
        local exp
        exp=$(echo "$payload" | grep -o '"exp":[0-9]*' | cut -d':' -f2)
        
        if [[ -n "$exp" ]]; then
            local now
            now=$(date +%s)
            
            if [[ $exp -lt $now ]]; then
                error "Token has expired"
                local expired_ago=$((now - exp))
                warning "Expired $expired_ago seconds ago"
                info "Request a new token from gateway administrator"
                return 1
            else
                local expires_in=$((exp - now))
                success "Token is valid (expires in ${expires_in}s / $((expires_in / 3600))h)"
            fi
        else
            info "No expiration claim found in JWT"
        fi
    else
        info "Token is not JWT format (cannot check expiration)"
        info "Check with gateway administrator for token validity"
    fi
    
    return 0
}

# Step 5: Gateway-specific diagnostics
gateway_diagnostics() {
    header "Step 5: Gateway-Specific Diagnostics"
    
    # Try health endpoint
    local health_status
    health_status=$(curl -s -o /dev/null -w "%{http_code}" "${GATEWAY_URL}/health" 2>/dev/null || echo "000")
    
    if [[ "$health_status" == "200" ]]; then
        success "Gateway health endpoint responding (HTTP 200)"
    else
        info "Health endpoint status: $health_status (may not be available)"
    fi
    
    # Check for common gateway headers
    local response_headers
    response_headers=$(curl -s -I "${GATEWAY_URL}/v1/messages" \
        -H "Authorization: Bearer ${AUTH_TOKEN}" 2>/dev/null || true)
    
    if echo "$response_headers" | grep -iq "server:"; then
        local server
        server=$(echo "$response_headers" | grep -i "server:" | cut -d':' -f2- | tr -d '\r\n' | xargs)
        info "Gateway server: $server"
    fi
    
    if echo "$response_headers" | grep -iq "x-powered-by:"; then
        local powered_by
        powered_by=$(echo "$response_headers" | grep -i "x-powered-by:" | cut -d':' -f2- | tr -d '\r\n' | xargs)
        info "Powered by: $powered_by"
    fi
    
    # Check for rate limit headers
    if echo "$response_headers" | grep -iq "x-ratelimit"; then
        success "Gateway provides rate limit headers"
        echo "$response_headers" | grep -i "x-ratelimit" || true
    fi
}

# Main execution
main() {
    echo ""
    echo -e "${BOLD}========================================"
    echo "Authentication Troubleshooting Helper"
    echo -e "========================================${NC}"
    echo ""
    echo "Gateway: $GATEWAY_URL"
    echo "Time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    
    local exit_code=0
    
    validate_token_format || exit_code=1
    test_connectivity || exit_code=1
    test_authentication || exit_code=1
    check_token_expiration || exit_code=1
    gateway_diagnostics
    
    echo ""
    header "Summary"
    
    if [[ $exit_code -eq 0 ]]; then
        success "Authentication is working correctly"
        info "Gateway connection established successfully"
    else
        error "Authentication issues detected"
        info "Review the diagnostics above for specific issues"
        echo ""
        info "Next steps:"
        echo "  1. Verify token with gateway administrator"
        echo "  2. Check gateway configuration and logs"
        echo "  3. Review security policies (IP allowlist, etc.)"
        echo "  4. Refer to gateway documentation"
    fi
    
    echo ""
    exit $exit_code
}

main
