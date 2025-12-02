#!/bin/bash
# Health Check Verification Script
# Purpose: Verify LiteLLM gateway is running and healthy
# Usage: ./health-check.sh [gateway-url]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default gateway URL
DEFAULT_GATEWAY_URL="http://localhost:4000"
GATEWAY_URL="${1:-${ANTHROPIC_BASE_URL:-$DEFAULT_GATEWAY_URL}}"

# Remove trailing slash
GATEWAY_URL="${GATEWAY_URL%/}"

echo "=========================================="
echo "LiteLLM Gateway Health Check"
echo "=========================================="
echo ""
echo "Gateway URL: $GATEWAY_URL"
echo ""

# Function to print success message
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error message
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning message
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: Gateway reachability
echo "Check 1: Gateway Reachability"
echo "------------------------------"

if ! command -v curl &> /dev/null; then
    print_error "curl is not installed. Please install curl to run health checks."
    exit 1
fi

# Test basic connectivity
if curl -s --connect-timeout 5 "$GATEWAY_URL" > /dev/null 2>&1; then
    print_success "Gateway is reachable"
else
    print_error "Gateway is not reachable at $GATEWAY_URL"
    echo ""
    echo "Troubleshooting tips:"
    echo "  1. Verify the gateway is running: ps aux | grep litellm"
    echo "  2. Check the URL is correct: echo \$ANTHROPIC_BASE_URL"
    echo "  3. Check firewall/network: telnet localhost 4000"
    exit 1
fi

echo ""

# Check 2: Health endpoint
echo "Check 2: Health Endpoint"
echo "------------------------"

HEALTH_URL="$GATEWAY_URL/health"
HEALTH_RESPONSE=$(curl -s -w "\n%{http_code}" "$HEALTH_URL" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$HEALTH_RESPONSE" | tail -n1)
HEALTH_BODY=$(echo "$HEALTH_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Health endpoint returned 200 OK"
    
    # Parse JSON response if jq is available
    if command -v jq &> /dev/null; then
        STATUS=$(echo "$HEALTH_BODY" | jq -r '.status // empty' 2>/dev/null)
        if [ "$STATUS" = "healthy" ]; then
            print_success "Gateway status: healthy"
        elif [ -n "$STATUS" ]; then
            print_warning "Gateway status: $STATUS"
        fi
    else
        echo "  Response: $HEALTH_BODY"
    fi
else
    print_error "Health endpoint returned HTTP $HTTP_CODE"
    echo "  Response: $HEALTH_BODY"
    
    if [ "$HTTP_CODE" = "000" ]; then
        print_error "Connection failed - gateway may not be running"
        exit 1
    fi
fi

echo ""

# Check 3: Models endpoint (optional)
echo "Check 3: Models Endpoint (Optional)"
echo "-----------------------------------"

MODELS_URL="$GATEWAY_URL/models"
MODELS_RESPONSE=$(curl -s -w "\n%{http_code}" "$MODELS_URL" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$MODELS_RESPONSE" | tail -n1)
MODELS_BODY=$(echo "$MODELS_RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Models endpoint accessible"
    
    if command -v jq &> /dev/null; then
        MODEL_COUNT=$(echo "$MODELS_BODY" | jq -r '.data | length' 2>/dev/null || echo "unknown")
        if [ "$MODEL_COUNT" != "unknown" ] && [ "$MODEL_COUNT" -gt 0 ]; then
            print_success "Found $MODEL_COUNT configured model(s)"
            
            # List model names
            echo ""
            echo "  Configured models:"
            echo "$MODELS_BODY" | jq -r '.data[].id' 2>/dev/null | while read -r model; do
                echo "    - $model"
            done
        else
            print_warning "No models configured"
        fi
    fi
elif [ "$HTTP_CODE" = "401" ]; then
    print_warning "Models endpoint requires authentication (this is normal)"
else
    print_warning "Models endpoint returned HTTP $HTTP_CODE (non-critical)"
fi

echo ""

# Check 4: Proxy info endpoint (optional)
echo "Check 4: Proxy Info (Optional)"
echo "------------------------------"

INFO_URL="$GATEWAY_URL/get/config"
INFO_RESPONSE=$(curl -s -w "\n%{http_code}" "$INFO_URL" 2>/dev/null || echo "000")
HTTP_CODE=$(echo "$INFO_RESPONSE" | tail -n1)

if [ "$HTTP_CODE" = "200" ]; then
    print_success "Proxy info endpoint accessible"
elif [ "$HTTP_CODE" = "401" ]; then
    print_warning "Proxy info requires authentication (this is normal)"
else
    print_warning "Proxy info endpoint not accessible (non-critical)"
fi

echo ""

# Final summary
echo "=========================================="
echo "Summary"
echo "=========================================="
echo ""

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
    print_success "Gateway health check passed!"
    echo ""
    echo "Next steps:"
    echo "  1. Run: ./check-status.sh (verify Claude Code configuration)"
    echo "  2. Test completion: claude \"Hello, test!\""
    echo ""
    exit 0
else
    print_error "Gateway health check failed"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check gateway logs: docker logs <container-id>"
    echo "  2. Verify configuration: python validate-config.py litellm_config.yaml"
    echo "  3. Restart gateway: litellm --config litellm_config.yaml"
    echo ""
    exit 1
fi
